-- SIGA - schema completo do Supabase
-- Execute no SQL Editor do projeto. Este script pode ser executado mais de uma vez.

create extension if not exists pgcrypto;

do $$ begin
  create type public.perfil_cargo as enum ('vendedor', 'gerente');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type public.condicional_status as enum ('aberta', 'resolvida');
exception when duplicate_object then null;
end $$;

create table if not exists public.lojas (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  slug text not null unique,
  configuracoes jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.perfis (
  id uuid primary key default gen_random_uuid(),
  loja_id uuid not null references public.lojas(id) on delete cascade,
  nome text not null,
  cargo public.perfil_cargo not null default 'vendedor',
  username text not null,
  password text not null,
  slug text not null,
  full_slug text not null unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (loja_id, username),
  unique (loja_id, slug)
);

create table if not exists public.tarefas (
  id uuid primary key default gen_random_uuid(),
  loja_id uuid not null references public.lojas(id) on delete cascade,
  responsavel_id uuid references public.perfis(id) on delete set null,
  titulo text not null,
  horario time not null,
  data date not null,
  owner text not null default 'user',
  concluida boolean not null default false,
  observacao text not null default '',
  serie_id uuid,
  dias_repeticao smallint[],
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.vendas (
  id uuid primary key default gen_random_uuid(),
  loja_id uuid not null references public.lojas(id) on delete cascade,
  vendedor_id uuid references public.perfis(id) on delete set null,
  cliente text not null default '',
  valor numeric(12,2) not null check (valor >= 0),
  data_hora timestamptz not null default now(),
  produtos jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.condicionais (
  id uuid primary key default gen_random_uuid(),
  loja_id uuid not null references public.lojas(id) on delete cascade,
  vendedor_id uuid references public.perfis(id) on delete set null,
  cliente text not null,
  telefone text not null default '',
  produtos jsonb not null default '[]'::jsonb,
  observacao text not null default '',
  status public.condicional_status not null default 'aberta',
  task_id uuid references public.tarefas(id) on delete set null,
  prazo date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.atendimentos (
  id uuid primary key default gen_random_uuid(),
  loja_id uuid not null references public.lojas(id) on delete cascade,
  vendedor_id uuid references public.perfis(id) on delete set null,
  cliente text not null default '',
  resultado text not null,
  resultado_label text not null default '',
  valor numeric(12,2) not null default 0 check (valor >= 0),
  telefone text not null default '',
  produtos jsonb not null default '[]'::jsonb,
  produtos_apresentados jsonb not null default '[]'::jsonb,
  demanda text not null default '',
  observacao text not null default '',
  venda_id uuid references public.vendas(id) on delete set null,
  condicional_id uuid references public.condicionais(id) on delete set null,
  data_hora timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.metas (
  id uuid primary key default gen_random_uuid(),
  loja_id uuid not null references public.lojas(id) on delete cascade,
  vendedor_id uuid not null references public.perfis(id) on delete cascade,
  semana_inicio date not null,
  semana_fim date not null,
  bronze numeric(12,2) not null default 0 check (bronze >= 0),
  prata numeric(12,2) not null default 0 check (prata >= bronze),
  ouro numeric(12,2) not null default 0 check (ouro >= prata),
  diamante numeric(12,2) not null check (diamante > 0 and diamante >= ouro),
  mes_referencia date not null,
  meta_mensal numeric(12,2) not null default 0 check (meta_mensal >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (semana_fim >= semana_inicio),
  unique (vendedor_id, semana_inicio, mes_referencia)
);

alter table public.metas add column if not exists mensal_bronze numeric(12,2) not null default 0;
alter table public.metas add column if not exists mensal_prata numeric(12,2) not null default 0;
alter table public.metas add column if not exists mensal_ouro numeric(12,2) not null default 0;
alter table public.metas add column if not exists mensal_diamante numeric(12,2) not null default 0;
update public.metas set mensal_diamante = meta_mensal where mensal_diamante = 0 and meta_mensal > 0;

create index if not exists perfis_loja_id_idx on public.perfis(loja_id);
create index if not exists tarefas_responsavel_data_idx on public.tarefas(responsavel_id, data);
create index if not exists vendas_vendedor_data_idx on public.vendas(vendedor_id, data_hora);
create index if not exists atendimentos_vendedor_data_idx on public.atendimentos(vendedor_id, data_hora);
create index if not exists condicionais_vendedor_status_idx on public.condicionais(vendedor_id, status);
create index if not exists metas_vendedor_periodo_idx on public.metas(vendedor_id, semana_inicio, semana_fim, mes_referencia);

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists lojas_set_updated_at on public.lojas;
create trigger lojas_set_updated_at before update on public.lojas for each row execute function public.set_updated_at();
drop trigger if exists perfis_set_updated_at on public.perfis;
create trigger perfis_set_updated_at before update on public.perfis for each row execute function public.set_updated_at();
drop trigger if exists tarefas_set_updated_at on public.tarefas;
create trigger tarefas_set_updated_at before update on public.tarefas for each row execute function public.set_updated_at();
drop trigger if exists vendas_set_updated_at on public.vendas;
create trigger vendas_set_updated_at before update on public.vendas for each row execute function public.set_updated_at();
drop trigger if exists condicionais_set_updated_at on public.condicionais;
create trigger condicionais_set_updated_at before update on public.condicionais for each row execute function public.set_updated_at();
drop trigger if exists atendimentos_set_updated_at on public.atendimentos;
create trigger atendimentos_set_updated_at before update on public.atendimentos for each row execute function public.set_updated_at();
drop trigger if exists metas_set_updated_at on public.metas;
create trigger metas_set_updated_at before update on public.metas for each row execute function public.set_updated_at();

alter table public.lojas enable row level security;
alter table public.perfis enable row level security;
alter table public.tarefas enable row level security;
alter table public.vendas enable row level security;
alter table public.condicionais enable row level security;
alter table public.atendimentos enable row level security;
alter table public.metas enable row level security;

-- O site usa login próprio para vendedores/gerentes, não supabase.auth.
-- Estas policies permitem o funcionamento do cliente com a publishable key.
-- Para produção, migre os acessos de equipe para Supabase Auth e restrinja por auth.uid().
do $$ declare table_name text; begin
  foreach table_name in array array['lojas','perfis','tarefas','vendas','condicionais','atendimentos','metas'] loop
    execute format('drop policy if exists siga_public_select on public.%I', table_name);
    execute format('drop policy if exists siga_public_insert on public.%I', table_name);
    execute format('drop policy if exists siga_public_update on public.%I', table_name);
    execute format('drop policy if exists siga_public_delete on public.%I', table_name);
    execute format('create policy siga_public_select on public.%I for select to anon, authenticated using (true)', table_name);
    execute format('create policy siga_public_insert on public.%I for insert to anon, authenticated with check (true)', table_name);
    execute format('create policy siga_public_update on public.%I for update to anon, authenticated using (true) with check (true)', table_name);
    execute format('create policy siga_public_delete on public.%I for delete to anon, authenticated using (true)', table_name);
  end loop;
end $$;

notify pgrst, 'reload schema';
