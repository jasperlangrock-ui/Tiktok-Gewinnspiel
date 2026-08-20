-- TikTok-Gewinnspiel: komplette Supabase-Datenbankstruktur
create extension if not exists pgcrypto;

create type public.user_role as enum ('user','admin');
create type public.giveaway_status as enum ('draft','active','completed');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  role public.user_role not null default 'user',
  created_at timestamptz not null default now()
);

create table public.giveaways (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  start_date date not null,
  end_date date not null,
  status public.giveaway_status not null default 'draft',
  created_at timestamptz not null default now(),
  constraint valid_dates check (end_date > start_date)
);

create table public.participants (
  id uuid primary key default gen_random_uuid(),
  giveaway_id uuid not null references public.giveaways(id) on delete cascade,
  username text not null,
  tickets smallint not null default 1 check (tickets in (1,3)),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint participants_username_unique unique (giveaway_id, username)
);

create table public.draws (
  id uuid primary key default gen_random_uuid(),
  giveaway_id uuid not null references public.giveaways(id) on delete restrict,
  winner_participant_id uuid not null references public.participants(id) on delete restrict,
  winner_username text not null,
  drawn_at timestamptz not null default now(),
  participant_count integer not null check (participant_count >= 0),
  ticket_count integer not null check (ticket_count >= 0),
  round_number integer not null,
  constraint one_draw_per_giveaway unique (giveaway_id)
);

create index participants_giveaway_idx on public.participants(giveaway_id);
create index participants_username_idx on public.participants using btree(lower(username));
create index draws_drawn_at_idx on public.draws(drawn_at desc);

create or replace function public.set_updated_at() returns trigger
language plpgsql set search_path = '' as $$
begin new.updated_at = now(); return new; end; $$;
create trigger participants_updated_at before update on public.participants for each row execute function public.set_updated_at();

create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles(id,email) values (new.id,new.email) on conflict (id) do update set email=excluded.email;
  return new;
end; $$;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.profiles where id = (select auth.uid()) and role = 'admin');
$$;

-- Sichere serverseitige Ziehung. Der Gewinner wird anhand der Ticketgewichte gewählt.
create or replace function public.draw_winner(p_giveaway_id uuid)
returns table(draw_id uuid,winner_participant_id uuid,winner_username text,participant_count integer,ticket_count integer,drawn_at timestamptz,round_number integer)
language plpgsql security definer set search_path = '' as $$
declare
  v_total bigint;
  v_target bigint;
  v_running bigint := 0;
  v_p record;
  v_count integer;
  v_round integer;
  v_draw_id uuid;
  v_drawn timestamptz := now();
begin
  if not public.is_admin() then raise exception 'not_authorized'; end if;
  if not exists(select 1 from public.giveaways where id=p_giveaway_id and status='active') then raise exception 'giveaway_not_active'; end if;
  if exists(select 1 from public.draws where giveaway_id=p_giveaway_id) then raise exception 'already_drawn'; end if;
  select count(*),coalesce(sum(tickets),0) into v_count,v_total from public.participants where giveaway_id=p_giveaway_id;
  if v_total <= 0 then raise exception 'no_participants'; end if;
  -- random() liefert einen Wert in [0,1); für ein Gewinnspiel ist das eine ausreichende PRNG-Quelle.
  v_target := floor(random()*v_total)::bigint + 1;
  for v_p in select id,username,tickets from public.participants where giveaway_id=p_giveaway_id order by id loop
    v_running := v_running + v_p.tickets;
    if v_running >= v_target then
      select coalesce(max(round_number),0)+1 into v_round from public.draws;
      insert into public.draws(giveaway_id,winner_participant_id,winner_username,drawn_at,participant_count,ticket_count,round_number)
      values(p_giveaway_id,v_p.id,v_p.username,v_drawn,v_count,v_total,v_round) returning id into v_draw_id;
      return query select v_draw_id,v_p.id,v_p.username,v_count,v_total,v_drawn,v_round;
      return;
    end if;
  end loop;
  raise exception 'draw_failed';
end; $$;

-- RLS
alter table public.profiles enable row level security;
alter table public.giveaways enable row level security;
alter table public.participants enable row level security;
alter table public.draws enable row level security;

-- Öffentlich: aktive Runde + deren Teilnehmer + Ziehungen. Keine Schreibrechte.
create policy "public can view active giveaways" on public.giveaways for select to anon,authenticated using (status='active');
create policy "public can view active participants" on public.participants for select to anon,authenticated using (exists(select 1 from public.giveaways g where g.id=participants.giveaway_id and g.status='active'));
create policy "public can view draws" on public.draws for select to anon,authenticated using (exists(select 1 from public.giveaways g where g.id=draws.giveaway_id and (g.status='active' or g.status='completed')));

-- Admin: vollständige Verwaltung.
create policy "admins can view profiles" on public.profiles for select to authenticated using ((select public.is_admin()));
create policy "users can view own profile" on public.profiles for select to authenticated using ((select auth.uid())=id);
create policy "admins can manage giveaways" on public.giveaways for all to authenticated using ((select public.is_admin())) with check ((select public.is_admin()));
create policy "admins can manage participants" on public.participants for all to authenticated using ((select public.is_admin())) with check ((select public.is_admin()));
create policy "admins can manage draws" on public.draws for select to authenticated using ((select public.is_admin()));

-- Funktionen nicht pauschal öffentlich ausführbar machen.
revoke execute on function public.is_admin() from public,anon,authenticated;
grant execute on function public.is_admin() to authenticated;
revoke execute on function public.draw_winner(uuid) from public,anon;
grant execute on function public.draw_winner(uuid) to authenticated;
revoke execute on function public.handle_new_user() from public,anon,authenticated;

-- Neue Runde als einzige aktive Runde erzwingen.
create or replace function public.ensure_single_active_giveaway() returns trigger
language plpgsql set search_path = '' as $$
begin
  if new.status='active' then
    update public.giveaways set status='completed' where status='active' and id<>new.id;
  end if;
  return new;
end; $$;
create trigger single_active_giveaway before insert or update of status on public.giveaways for each row execute function public.ensure_single_active_giveaway();

-- Erste Runde (optional; erst nach Admin-Anlage ausführen oder IDs anpassen)
-- insert into public.giveaways(title,start_date,end_date,status) values ('Gewinnspielrunde 1','2026-08-20','2026-09-03','active');
