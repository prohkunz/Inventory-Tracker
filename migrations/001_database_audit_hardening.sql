-- 001 Database audit hardening (NOT YET APPLIED)
-- Safe on current data: audit found 0 orphans, 0 total mismatches, 0 negative stock.

-- 1. Row-level security: signed-in users only, auth.uid() evaluated once per query
do $$
declare r record;
begin
  for r in select * from (values
    ('products','own products'),('history','own history'),('sales','own sales'),
    ('sale_items','own sale items'),('payments','own payments'),('held_sales','own held sales'),
    ('suppliers','own suppliers'),('purchase_orders','own purchase orders'),
    ('purchase_order_items','own po items'),('cash_drawers','own cash drawers'),
    ('cash_shifts','own cash shifts'),('cash_movements','own cash movements')
  ) as t(tbl,pol) loop
    execute format('drop policy %I on public.%I', r.pol, r.tbl);
    execute format(
      'create policy %I on public.%I for all to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id)',
      r.pol, r.tbl);
  end loop;
end $$;

-- keep_alive: the heartbeat may only touch its single row
drop policy "keep-alive ping" on public.keep_alive;
create policy "keep-alive ping" on public.keep_alive for all to anon
  using (id = 1) with check (id = 1);

-- 2. Table privileges: no TRUNCATE/TRIGGER/REFERENCES for app roles; anon only reaches keep_alive
revoke truncate, trigger, references on all tables in schema public from anon, authenticated;
revoke all on public.products, public.history, public.sales, public.sale_items, public.payments,
  public.held_sales, public.suppliers, public.purchase_orders, public.purchase_order_items,
  public.cash_drawers, public.cash_shifts, public.cash_movements from anon;
revoke delete on public.keep_alive from anon;

-- 3. Indexes for foreign keys
create index if not exists payments_sale_idx on public.payments (sale_id);
create index if not exists payments_user_idx on public.payments (user_id);
create index if not exists held_sales_user_idx on public.held_sales (user_id);
create index if not exists cash_movements_user_idx on public.cash_movements (user_id);
create index if not exists purchase_orders_supplier_idx on public.purchase_orders (supplier_id);

-- 4. Cash tables: deleting an account removes its cash data like every other table
alter table public.cash_drawers drop constraint cash_drawers_user_id_fkey,
  add constraint cash_drawers_user_id_fkey foreign key (user_id) references auth.users(id) on delete cascade;
alter table public.cash_shifts drop constraint cash_shifts_user_id_fkey,
  add constraint cash_shifts_user_id_fkey foreign key (user_id) references auth.users(id) on delete cascade;
alter table public.cash_movements drop constraint cash_movements_user_id_fkey,
  add constraint cash_movements_user_id_fkey foreign key (user_id) references auth.users(id) on delete cascade;

-- 5. Sanity limits (existing data already satisfies all of them)
alter table public.sales add constraint sales_amounts_check
  check (total >= 0 and subtotal >= 0 and discount >= 0);
alter table public.sales add constraint sales_status_check
  check (status in ('completed','void'));
alter table public.sale_items add constraint sale_items_values_check
  check (quantity > 0 and unit_price >= 0 and unit_cost >= 0 and line_total >= 0);
alter table public.payments add constraint payments_amount_check check (amount >= 0);
alter table public.products add constraint products_values_check
  check (price >= 0 and cost_price >= 0 and low_stock >= 0);
alter table public.history add constraint history_type_check
  check (type in ('add','remove','adjust','edit','sale','void'));
