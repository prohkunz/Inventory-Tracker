-- 002 E5: idempotent, offline-aware sale recording — APPLIED 2026-10-28. Old record_sale() is left untouched (anon access revoked).
alter table public.sales add column if not exists client_key uuid;
alter table public.sales add column if not exists needs_review boolean not null default false;
create unique index if not exists sales_user_client_key_uidx
  on public.sales (user_id, client_key) where client_key is not null;

create or replace function public.record_sale_v2(
  p_items jsonb, p_payments jsonb,
  p_discount numeric default 0, p_discount_note text default ''::text, p_note text default ''::text,
  p_client_key uuid default null, p_shift_id uuid default null,
  p_sold_at timestamptz default null, p_offline boolean default false)
returns uuid
language plpgsql
set search_path to 'public'
as $function$
declare
  v_user_id   uuid := auth.uid();
  v_sale_id   uuid;
  v_item      jsonb;
  v_pay       jsonb;
  v_pid       uuid;
  v_qty       integer;
  v_is_custom boolean;
  v_prod      record;
  v_subtotal  numeric(12,2) := 0;
  v_total     numeric(12,2) := 0;
  v_count     integer := 0;
  v_paid      numeric(12,2) := 0;
  v_tendered  numeric(12,2);
  v_change    numeric(12,2) := 0;
  v_method    text;
  v_summary   text;
  v_pay_count int := 0;
  v_at        timestamptz := now();
  v_shift     uuid := null;
  v_review    boolean := false;
begin
  if v_user_id is null then raise exception 'Not authenticated'; end if;

  -- Idempotency: a retry of an already-saved sale returns the original sale.
  if p_client_key is not null then
    select id into v_sale_id from public.sales
      where user_id = v_user_id and client_key = p_client_key;
    if v_sale_id is not null then return v_sale_id; end if;
  end if;

  if jsonb_array_length(p_items)    < 1 then raise exception 'Cart is empty'; end if;
  if jsonb_array_length(p_payments) < 1 then raise exception 'No payments provided'; end if;

  -- Device time for queued sales: never in the future, never older than 30 days.
  if p_sold_at is not null and p_sold_at <= now() and p_sold_at > now() - interval '30 days' then
    v_at := p_sold_at;
  end if;
  if p_shift_id is not null then
    select id into v_shift from public.cash_shifts where id = p_shift_id and user_id = v_user_id;
  end if;

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_qty       := (v_item->>'quantity')::integer;
    v_is_custom := coalesce((v_item->>'is_custom')::boolean, false);
    if v_qty is null or v_qty <= 0 then raise exception 'Invalid quantity in cart'; end if;
    if not v_is_custom then
      v_pid := (v_item->>'product_id')::uuid;
      select id, name, quantity into v_prod from public.products
        where id = v_pid and user_id = v_user_id;
      if v_prod.id is null then raise exception 'Product no longer exists'; end if;
      if v_prod.quantity < v_qty then
        -- A sale already made at the counter (offline) is recorded and flagged, not rejected.
        if p_offline then v_review := true;
        else raise exception 'Not enough stock for %', v_prod.name; end if;
      end if;
    end if;
    v_subtotal := v_subtotal + (v_item->>'line_total')::numeric;
    v_count    := v_count + v_qty;
  end loop;

  v_total := greatest(0, v_subtotal - coalesce(p_discount, 0));

  for v_pay in select * from jsonb_array_elements(p_payments) loop
    v_paid := v_paid + (v_pay->>'amount')::numeric;
    v_pay_count := v_pay_count + 1;
    if v_pay_count = 1 then
      v_method := v_pay->>'method';
      if (v_pay->>'tendered') is not null then
        v_tendered := (v_pay->>'tendered')::numeric;
      end if;
    end if;
  end loop;
  if v_paid + 0.005 < v_total then
    raise exception 'Payment total (%) is less than sale total (%)', v_paid, v_total;
  end if;
  v_change := greatest(0, v_paid - v_total);
  v_summary := case when v_pay_count > 1 then 'split' else v_method end;

  begin
    insert into public.sales
      (user_id, subtotal, discount, discount_note, total, payment,
       tendered, change_amt, item_count, note, status, created_at,
       client_key, shift_id, needs_review)
    values
      (v_user_id, v_subtotal, coalesce(p_discount, 0), coalesce(p_discount_note, ''),
       v_total, v_summary, v_tendered, v_change, v_count, coalesce(p_note, ''), 'completed', v_at,
       p_client_key, v_shift, v_review)
    returning id into v_sale_id;
  exception when unique_violation then
    -- Two copies of the same sale arrived at once: keep the first, return it.
    select id into v_sale_id from public.sales
      where user_id = v_user_id and client_key = p_client_key;
    if v_sale_id is not null then return v_sale_id; end if;
    raise;
  end;

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_qty       := (v_item->>'quantity')::integer;
    v_is_custom := coalesce((v_item->>'is_custom')::boolean, false);
    if v_is_custom then
      insert into public.sale_items
        (sale_id, user_id, product_id, name, sku, quantity,
         unit_price, unit_cost, line_discount, line_total, is_custom)
      values
        (v_sale_id, v_user_id, null,
         v_item->>'name', coalesce(v_item->>'sku',''), v_qty,
         (v_item->>'unit_price')::numeric,
         coalesce((v_item->>'unit_cost')::numeric, 0),
         coalesce((v_item->>'line_discount')::numeric, 0),
         (v_item->>'line_total')::numeric, true);
      insert into public.history (user_id, type, name, detail, delta, price_snapshot, cost_snapshot, created_at)
      values (v_user_id, 'sale', v_item->>'name',
              'Custom item x' || v_qty || ' (POS)', 0,
              (v_item->>'unit_price')::numeric,
              coalesce((v_item->>'unit_cost')::numeric, 0), v_at);
    else
      v_pid := (v_item->>'product_id')::uuid;
      select id, name, sku into v_prod from public.products where id = v_pid;
      insert into public.sale_items
        (sale_id, user_id, product_id, name, sku, quantity,
         unit_price, unit_cost, line_discount, line_total, is_custom)
      values
        (v_sale_id, v_user_id, v_prod.id, v_prod.name, coalesce(v_prod.sku,''),
         v_qty,
         (v_item->>'unit_price')::numeric,
         (v_item->>'unit_cost')::numeric,
         coalesce((v_item->>'line_discount')::numeric, 0),
         (v_item->>'line_total')::numeric, false);
      update public.products
         set quantity = quantity - v_qty
       where id = v_prod.id and user_id = v_user_id;
      insert into public.history (user_id, type, name, detail, delta, price_snapshot, cost_snapshot, created_at)
      values (v_user_id, 'sale', v_prod.name,
              'Sold ' || v_qty || ' (POS)', -v_qty,
              (v_item->>'unit_price')::numeric,
              (v_item->>'unit_cost')::numeric, v_at);
    end if;
  end loop;

  for v_pay in select * from jsonb_array_elements(p_payments) loop
    insert into public.payments (sale_id, user_id, method, amount, tendered, change_amt, reference)
    values (
      v_sale_id, v_user_id, v_pay->>'method',
      (v_pay->>'amount')::numeric,
      case when (v_pay->>'tendered') is not null then (v_pay->>'tendered')::numeric else null end,
      case when (v_pay->>'change')   is not null then (v_pay->>'change')::numeric   else null end,
      coalesce(v_pay->>'reference', '')
    );
  end loop;

  return v_sale_id;
end;
$function$;

revoke execute on function public.record_sale_v2(jsonb, jsonb, numeric, text, text, uuid, uuid, timestamptz, boolean) from public, anon;
grant execute on function public.record_sale_v2(jsonb, jsonb, numeric, text, text, uuid, uuid, timestamptz, boolean) to authenticated;
-- the old function stays for older app versions, but no longer callable without signing in
revoke execute on function public.record_sale(jsonb, jsonb, numeric, text, text) from public, anon;
