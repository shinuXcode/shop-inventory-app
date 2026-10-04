create extension if not exists pgcrypto;

create table if not exists public.items (
  id text primary key, sku text, name text not null, description text,
  price_minor bigint not null, cost_minor bigint not null default 0,
  tax_rate numeric not null default 0, stock_quantity integer not null default 0,
  low_stock_threshold integer not null default 5, category text, barcode text,
  is_active boolean not null default true, created_at timestamptz not null,
  updated_at timestamptz not null, user_id uuid not null default auth.uid()
);
create table if not exists public.customers (
  id text primary key, name text not null, phone text, email text, address text, notes text,
  created_at timestamptz not null, updated_at timestamptz not null,
  user_id uuid not null default auth.uid()
);
create table if not exists public.invoices (
  id text primary key, invoice_number text not null, customer_id text,
  subtotal_minor bigint not null, discount_minor bigint not null default 0,
  tax_minor bigint not null default 0, total_minor bigint not null,
  payment_method text not null, status text not null default 'completed', notes text,
  created_at timestamptz not null, updated_at timestamptz not null,
  user_id uuid not null default auth.uid()
);
alter table public.items enable row level security;
alter table public.customers enable row level security;
alter table public.invoices enable row level security;
create policy "users manage own items" on public.items for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "users manage own customers" on public.customers for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "users manage own invoices" on public.invoices for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());
