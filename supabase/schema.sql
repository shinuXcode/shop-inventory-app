create extension if not exists pgcrypto;

create table if not exists public.businesses (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  phone text,
  email text,
  address text,
  gst_number text,
  currency text not null default 'INR',
  invoice_prefix text not null default 'INV',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.business_members (
  business_id uuid not null references public.businesses(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'owner' check (role in ('owner','manager','cashier')),
  created_at timestamptz not null default now(),
  primary key (business_id, user_id)
);

create table if not exists public.items (
  id uuid primary key,
  business_id uuid not null references public.businesses(id) on delete cascade,
  sku text not null,
  name text not null,
  description text,
  barcode text,
  price_minor bigint not null default 0,
  cost_minor bigint not null default 0,
  tax_rate numeric(6,3) not null default 0,
  stock_quantity numeric(14,3) not null default 0,
  low_stock_threshold numeric(14,3) not null default 0,
  category text,
  is_active boolean not null default true,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  unique (business_id, sku)
);

create table if not exists public.customers (
  id uuid primary key,
  business_id uuid not null references public.businesses(id) on delete cascade,
  name text not null,
  phone text,
  email text,
  address text,
  notes text,
  created_at timestamptz not null,
  updated_at timestamptz not null
);

create table if not exists public.invoices (
  id uuid primary key,
  business_id uuid not null references public.businesses(id) on delete cascade,
  invoice_number text not null,
  customer_id uuid references public.customers(id) on delete set null,
  subtotal_minor bigint not null,
  discount_minor bigint not null default 0,
  tax_minor bigint not null default 0,
  total_minor bigint not null,
  payment_method text not null,
  status text not null default 'paid',
  notes text,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  unique (business_id, invoice_number)
);

create table if not exists public.invoice_items (
  id uuid primary key,
  business_id uuid not null references public.businesses(id) on delete cascade,
  invoice_id uuid not null references public.invoices(id) on delete cascade,
  item_id uuid references public.items(id) on delete set null,
  item_name_snapshot text not null,
  sku_snapshot text not null,
  quantity numeric(14,3) not null,
  unit_price_minor bigint not null,
  tax_rate numeric(6,3) not null,
  tax_minor bigint not null,
  line_total_minor bigint not null
);

create table if not exists public.sync_events (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  entity_type text not null,
  entity_id uuid not null,
  operation text not null,
  created_at timestamptz not null default now()
);

create index if not exists items_business_idx on public.items(business_id);
create index if not exists items_barcode_idx on public.items(business_id, barcode);
create index if not exists items_name_idx on public.items(business_id, name);
create index if not exists customers_business_idx on public.customers(business_id);
create index if not exists invoices_business_date_idx on public.invoices(business_id, created_at desc);
create index if not exists invoice_items_invoice_idx on public.invoice_items(invoice_id);

alter table public.businesses enable row level security;
alter table public.business_members enable row level security;
alter table public.items enable row level security;
alter table public.customers enable row level security;
alter table public.invoices enable row level security;
alter table public.invoice_items enable row level security;
alter table public.sync_events enable row level security;

create or replace function public.is_business_member(target_business uuid)
returns boolean language sql security definer stable set search_path = public as $$
  select exists (
    select 1 from public.business_members
    where business_id = target_business and user_id = auth.uid()
  );
$$;

create or replace function public.is_business_manager(target_business uuid)
returns boolean language sql security definer stable set search_path = public as $$
  select exists (
    select 1 from public.business_members
    where business_id = target_business
      and user_id = auth.uid()
      and role in ('owner','manager')
  );
$$;

drop policy if exists "members can read businesses" on public.businesses;
create policy "members can read businesses" on public.businesses for select using (public.is_business_member(id));
drop policy if exists "managers can update businesses" on public.businesses;
create policy "managers can update businesses" on public.businesses for update using (public.is_business_manager(id)) with check (public.is_business_manager(id));

drop policy if exists "users can read memberships" on public.business_members;
create policy "users can read memberships" on public.business_members for select using (user_id = auth.uid() or public.is_business_manager(business_id));

drop policy if exists "members can read items" on public.items;
create policy "members can read items" on public.items for select using (public.is_business_member(business_id));
drop policy if exists "members can insert items" on public.items;
create policy "members can insert items" on public.items for insert with check (public.is_business_member(business_id));
drop policy if exists "members can update items" on public.items;
create policy "members can update items" on public.items for update using (public.is_business_member(business_id)) with check (public.is_business_member(business_id));

drop policy if exists "members can read customers" on public.customers;
create policy "members can read customers" on public.customers for select using (public.is_business_member(business_id));
drop policy if exists "members can insert customers" on public.customers;
create policy "members can insert customers" on public.customers for insert with check (public.is_business_member(business_id));
drop policy if exists "members can update customers" on public.customers;
create policy "members can update customers" on public.customers for update using (public.is_business_member(business_id)) with check (public.is_business_member(business_id));

drop policy if exists "members can read invoices" on public.invoices;
create policy "members can read invoices" on public.invoices for select using (public.is_business_member(business_id));
drop policy if exists "members can insert invoices" on public.invoices;
create policy "members can insert invoices" on public.invoices for insert with check (public.is_business_member(business_id));
drop policy if exists "managers can update invoices" on public.invoices;
create policy "managers can update invoices" on public.invoices for update using (public.is_business_manager(business_id)) with check (public.is_business_manager(business_id));

drop policy if exists "members can read invoice items" on public.invoice_items;
create policy "members can read invoice items" on public.invoice_items for select using (public.is_business_member(business_id));
drop policy if exists "members can insert invoice items" on public.invoice_items;
create policy "members can insert invoice items" on public.invoice_items for insert with check (
  public.is_business_member(public.invoice_items.business_id)
  and exists (
    select 1
    from public.invoices i
    where i.id = public.invoice_items.invoice_id
      and i.business_id = public.invoice_items.business_id
  )
);

drop policy if exists "members can update invoice items" on public.invoice_items;
create policy "members can update invoice items" on public.invoice_items for update using (
  public.is_business_member(public.invoice_items.business_id)
) with check (
  public.is_business_member(public.invoice_items.business_id)
  and exists (
    select 1
    from public.invoices i
    where i.id = public.invoice_items.invoice_id
      and i.business_id = public.invoice_items.business_id
  )
);

drop policy if exists "members can read sync events" on public.sync_events;
create policy "members can read sync events" on public.sync_events for select using (public.is_business_member(business_id));
drop policy if exists "members can insert sync events" on public.sync_events;
create policy "members can insert sync events" on public.sync_events for insert with check (public.is_business_member(business_id));


create or replace function public.create_business(
  p_name text,
  p_phone text default null,
  p_address text default null,
  p_gst_number text default null,
  p_currency text default 'INR',
  p_invoice_prefix text default 'INV'
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  new_business uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  if nullif(trim(p_name), '') is null then
    raise exception 'Business name is required';
  end if;

  insert into public.businesses(name, phone, address, gst_number, currency, invoice_prefix)
  values (trim(p_name), p_phone, p_address, p_gst_number, coalesce(nullif(trim(p_currency), ''), 'INR'),
          coalesce(nullif(trim(p_invoice_prefix), ''), 'INV'))
  returning id into new_business;

  insert into public.business_members(business_id, user_id, role)
  values (new_business, auth.uid(), 'owner');

  return new_business;
end;
$$;

revoke all on function public.create_business(text,text,text,text,text,text) from public;
grant execute on function public.create_business(text,text,text,text,text,text) to authenticated;


-- Support portal: shared by the SBILL app and website account.
create table if not exists public.support_tickets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  business_id uuid references public.businesses(id) on delete set null,
  category text not null default 'General',
  subject text not null,
  message text not null,
  status text not null default 'open' check (status in ('open','in_progress','closed')),
  priority text not null default 'normal' check (priority in ('low','normal','high')),
  admin_reply text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists support_tickets_user_updated_idx
  on public.support_tickets(user_id, updated_at desc);

alter table public.support_tickets enable row level security;

drop policy if exists "users can read own support tickets" on public.support_tickets;
create policy "users can read own support tickets"
  on public.support_tickets for select
  using (user_id = auth.uid());

drop policy if exists "users can create own support tickets" on public.support_tickets;
create policy "users can create own support tickets"
  on public.support_tickets for insert
  with check (
    user_id = auth.uid()
    and (business_id is null or public.is_business_member(business_id))
  );

drop policy if exists "users can update own support tickets" on public.support_tickets;

create or replace function public.close_support_ticket(p_ticket_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  update public.support_tickets
  set status = 'closed', updated_at = now()
  where id = p_ticket_id and user_id = auth.uid();
end;
$;

revoke all on function public.close_support_ticket(uuid) from public;
grant execute on function public.close_support_ticket(uuid) to authenticated;
