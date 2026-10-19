-- ============================================================
-- Inventory Tracker — database schema snapshot
-- Source: live Supabase project "Inventory Tracker", exported 2026-10-19
--
-- Reconstructed from the live catalog. Table shapes, defaults, indexes,
-- RLS policies, the record_sale() RPC and realtime publication are exact.
-- Not captured: foreign-key ON DELETE rules (defaults assumed).
--
-- SECURITY MODEL
-- * The anon public key lives in the browser by design. Security comes from
--   row-level policies, not key secrecy. Never use the service_role key here.
-- * Every user table has RLS with  auth.uid() = user_id.
-- * keep_alive is intentionally open to anon (GitHub Actions heartbeat ping).
-- * Supabase grants table privileges to anon/authenticated by default; RLS is
--   what actually restricts access, so never disable it on a table.
-- ============================================================

-- ---------- tables ----------

create table if not exists public.products (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id),
  name        text not null,
  sku         text not null default '',
  category    text not null default 'Uncategorized',
  quantity    integer not null default 0,
  price       numeric not null default 0,
  cost_price  numeric not null default 0,
  low_stock   integer not null default 5,
  created_at  timestamptz not null default now()
);

create table if not exists public.history (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references auth.users(id),
  type            text not null,   -- add | remove | adjust | sale | void (no CHECK constraint)
  name            text not null,
  detail          text not null default '',
  delta           integer,
  price_snapshot  numeric,
  cost_snapshot   numeric,
  created_at      timestamptz not null default now()
);

create table if not exists public.sales (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references auth.users(id),
  subtotal       numeric not null default 0,
  discount       numeric not null default 0,
  discount_note  text default '',
  total          numeric not null,
  payment        text not null,    -- method, or 'split'
  tendered       numeric,
  change_amt     numeric,
  item_count     integer not null default 0,
  note           text default '',
  status         text not null default 'completed',   -- completed | void
  created_at     timestamptz not null default now()
);

create table if not exists public.sale_items (
  id             uuid primary key default gen_random_uuid(),
  sale_id        uuid not null references public.sales(id),
  user_id        uuid not null references auth.users(id),
  product_id     uuid,
  name           text not null,
  sku            text default '',
  quantity       integer not null,
  unit_price     numeric not null,
  unit_cost      numeric not null default 0,
  line_discount  numeric not null default 0,
  line_total     numeric not null,
  is_custom      boolean not null default false,
  created_at     timestamptz not null default now()
);

create table if not exists public.payments (
  id          uuid primary key default gen_random_uuid(),
  sale_id     uuid not null references public.sales(id),
  user_id     uuid not null references auth.users(id),
  method      text not null,
  amount      numeric not null,
  tendered    numeric,
  change_amt  numeric,
  reference   text default '',
  created_at  timestamptz not null default now()
);

create table if not exists public.held_sales (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references auth.users(id),
  label          text not null default '',
  cart           jsonb not null,
  discount       numeric not null default 0,
  discount_note  text default '',
  item_count     integer not null default 0,
  subtotal       numeric not null default 0,
  created_at     timestamptz not null default now()
);

create table if not exists public.suppliers (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id),
  name        text not null,
  contact     text not null default '',
  phone       text not null default '',
  email       text not null default '',
  notes       text not null default '',
  created_at  timestamptz not null default now()
);

create table if not exists public.purchase_orders (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references auth.users(id),
  supplier_id    uuid references public.suppliers(id),
  supplier_name  text not null default '',
  status         text not null default 'draft',   -- draft | received
  notes          text not null default '',
  created_at     timestamptz not null default now()
);

create table if not exists public.purchase_order_items (
  id                uuid primary key default gen_random_uuid(),
  po_id             uuid not null references public.purchase_orders(id),
  user_id           uuid not null references auth.users(id),
  product_id        uuid,
  name              text not null,
  sku               text not null default '',
  quantity_ordered  integer not null default 0,
  unit_cost         numeric not null default 0,
  created_at        timestamptz not null default now()
);

create table if not exists public.keep_alive (
  id         smallint primary key,
  last_ping  timestamptz not null default now()
);

-- ---------- indexes ----------

create index if not exists products_user_idx      on public.products (user_id);
create index if not exists history_user_idx       on public.history (user_id, created_at desc);
create index if not exists sales_user_idx         on public.sales (user_id, created_at desc);
create index if not exists sale_items_sale_idx    on public.sale_items (sale_id);
create index if not exists sale_items_user_idx    on public.sale_items (user_id, created_at desc);
create index if not exists suppliers_user_idx     on public.suppliers (user_id);
create index if not exists po_user_idx            on public.purchase_orders (user_id, created_at desc);
create index if not exists po_items_po_idx        on public.purchase_order_items (po_id);
create index if not exists po_items_user_idx      on public.purchase_order_items (user_id);

-- ---------- row level security ----------

alter table public.products             enable row level security;
alter table public.history              enable row level security;
alter table public.sales                enable row level security;
alter table public.sale_items           enable row level security;
alter table public.payments             enable row level security;
alter table public.held_sales           enable row level security;
alter table public.suppliers            enable row level security;
alter table public.purchase_orders      enable row level security;
alter table public.purchase_order_items enable row level security;
alter table public.keep_alive           enable row level security;

create policy "own products"        on public.products             for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own history"         on public.history              for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own sales"           on public.sales                for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own sale items"      on public.sale_items           for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own payments"        on public.payments             for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own held sales"      on public.held_sales           for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own suppliers"       on public.suppliers            for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own purchase orders" on public.purchase_orders      for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own po items"        on public.purchase_order_items for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- intentionally open to anon: GitHub Actions heartbeat (.github/workflows/keep-alive.yml)
create policy "keep-alive ping"     on public.keep_alive           for all to anon using (true) with check (true);

-- ---------- realtime ----------

alter publication supabase_realtime add table public.products;
alter publication supabase_realtime add table public.history;
alter publication supabase_realtime add table public.suppliers;
alter publication supabase_realtime add table public.purchase_orders;

-- ---------- record_sale(): atomic sale transaction ----------
-- Validates stock and payment, inserts sale + items + payments, decrements
-- stock and writes history rows, all in one transaction. Runs as the caller
-- (SECURITY INVOKER), so RLS still applies.

create or replace function public.record_sale(
  p_items jsonb, p_payments jsonb,
  p_discount numeric default 0, p_discount_note text default ''::text, p_note text default ''::text)
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
begin
  if v_user_id is null then raise exception 'Not authenticated'; end if;
  if jsonb_array_length(p_items)    < 1 then raise exception 'Cart is empty'; end if;
  if jsonb_array_length(p_payments) < 1 then raise exception 'No payments provided'; end if;

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_qty       := (v_item->>'quantity')::integer;
    v_is_custom := coalesce((v_item->>'is_custom')::boolean, false);
    if v_qty is null or v_qty <= 0 then raise exception 'Invalid quantity in cart'; end if;
    if not v_is_custom then
      v_pid := (v_item->>'product_id')::uuid;
      select id, name, quantity into v_prod from public.products
        where id = v_pid and user_id = v_user_id;
      if v_prod.id is null then raise exception 'Product no longer exists'; end if;
      if v_prod.quantity < v_qty then raise exception 'Not enough stock for %', v_prod.name; end if;
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

  insert into public.sales
    (user_id, subtotal, discount, discount_note, total, payment,
     tendered, change_amt, item_count, note, status)
  values
    (v_user_id, v_subtotal, coalesce(p_discount, 0), coalesce(p_discount_note, ''),
     v_total, v_summary, v_tendered, v_change, v_count, coalesce(p_note, ''), 'completed')
  returning id into v_sale_id;

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
      insert into public.history (user_id, type, name, detail, delta, price_snapshot, cost_snapshot)
      values (v_user_id, 'sale', v_item->>'name',
              'Custom item x' || v_qty || ' (POS)', 0,
              (v_item->>'unit_price')::numeric,
              coalesce((v_item->>'unit_cost')::numeric, 0));
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
      insert into public.history (user_id, type, name, detail, delta, price_snapshot, cost_snapshot)
      values (v_user_id, 'sale', v_prod.name,
              'Sold ' || v_qty || ' (POS)', -v_qty,
              (v_item->>'unit_price')::numeric,
              (v_item->>'unit_cost')::numeric);
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
