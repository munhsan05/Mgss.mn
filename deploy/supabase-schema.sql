-- МГСС Төгсөгчдийн холбоо — Supabase схем
-- Supabase → SQL Editor → New query → энэ файлыг бүтнээр нь буулгаад RUN дарна.

create extension if not exists pgcrypto;

create table if not exists admins (user_id uuid primary key references auth.users on delete cascade);
create or replace function is_admin() returns boolean language sql stable security definer set search_path = public
  as $$ select exists (select 1 from admins where user_id = auth.uid()) $$;
grant execute on function is_admin() to anon, authenticated;

create table if not exists site_content (key text primary key, data jsonb not null, updated_at timestamptz default now());

create table if not exists profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid unique references auth.users on delete set null,
  name text not null, year int, cat text, job text, org text, loc text, phone text,
  tags text[] default '{}', hide boolean default false, fb text, ig text, photo text,
  status text not null default 'pending' check (status in ('pending','approved')),
  created_at timestamptz default now());

create table if not exists events (
  id uuid primary key default gen_random_uuid(),
  date date not null, type text, title text not null, place text, descr text,
  proposed boolean default false, created_by uuid references auth.users on delete set null,
  created_at timestamptz default now());

create table if not exists rsvps (event_id uuid references events on delete cascade, user_id uuid references auth.users on delete cascade, primary key (event_id, user_id));

create table if not exists voices (
  id uuid primary key default gen_random_uuid(),
  type text, text text not null, by_name text, status text default 'Шинэ', reply text default '',
  user_id uuid references auth.users on delete set null, created_at timestamptz default now());

create table if not exists voice_votes (voice_id uuid references voices on delete cascade, user_id uuid references auth.users on delete cascade, primary key (voice_id, user_id));

create table if not exists ny_bookings (
  id uuid primary key default gen_random_uuid(),
  name text not null, phone text not null, year int, seats int default 1 check (seats between 1 and 20), note text,
  status text default 'pending', user_id uuid references auth.users on delete set null, created_at timestamptz default now());

-- Тоолуурууд (хэн бүртгүүлснийг ил гаргахгүйгээр зөвхөн тоо)
create or replace view event_going_counts as select event_id, count(*)::int as n from rsvps group by event_id;
create or replace view voice_vote_counts as select voice_id, count(*)::int as n from voice_votes group by voice_id;
grant select on event_going_counts, voice_vote_counts to anon, authenticated;
create or replace function ny_seats_booked() returns int language sql stable security definer set search_path = public
  as $$ select coalesce(sum(seats),0)::int from ny_bookings where status <> 'cancelled' $$;
grant execute on function ny_seats_booked() to anon, authenticated;

-- Гишүүн өөрийгөө батлах боломжгүй
create or replace function guard_profile_status() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if not is_admin() then
    if tg_op = 'INSERT' then new.status := 'pending';
    elsif new.status is distinct from old.status then new.status := old.status; end if;
  end if;
  return new;
end $$;
drop trigger if exists profiles_guard on profiles;
create trigger profiles_guard before insert or update on profiles for each row execute function guard_profile_status();

alter table admins enable row level security;
alter table site_content enable row level security;
alter table profiles enable row level security;
alter table events enable row level security;
alter table rsvps enable row level security;
alter table voices enable row level security;
alter table voice_votes enable row level security;
alter table ny_bookings enable row level security;

create policy "admins read self" on admins for select using (user_id = auth.uid());

create policy "content read" on site_content for select using (true);
create policy "content admin" on site_content for all using (is_admin()) with check (is_admin());

create policy "profiles read" on profiles for select using (status = 'approved' or user_id = auth.uid() or is_admin());
create policy "profiles insert own" on profiles for insert with check (user_id = auth.uid() or is_admin());
create policy "profiles update own" on profiles for update using (user_id = auth.uid() or is_admin());
create policy "profiles delete admin" on profiles for delete using (is_admin());

create policy "events read" on events for select using (true);
create policy "events insert member" on events for insert with check (auth.uid() is not null and (created_by = auth.uid() or is_admin()));
create policy "events update" on events for update using (is_admin() or created_by = auth.uid());
create policy "events delete" on events for delete using (is_admin() or created_by = auth.uid());

create policy "rsvps own" on rsvps for all using (user_id = auth.uid() or is_admin()) with check (user_id = auth.uid());

create policy "voices read" on voices for select using (true);
create policy "voices insert" on voices for insert with check (user_id is null or user_id = auth.uid());
create policy "voices admin update" on voices for update using (is_admin());
create policy "voices admin delete" on voices for delete using (is_admin());

create policy "votes own" on voice_votes for all using (user_id = auth.uid() or is_admin()) with check (user_id = auth.uid());

create policy "ny insert" on ny_bookings for insert with check (user_id is null or user_id = auth.uid());
create policy "ny read own" on ny_bookings for select using (user_id = auth.uid() or is_admin());
create policy "ny admin" on ny_bookings for update using (is_admin());
create policy "ny admin delete" on ny_bookings for delete using (is_admin());

-- АДМИН НЭМЭХ: сайт дээр өөрийн и-мэйлээр бүртгүүлсний дараа доорх мөрийг и-мэйлээ солиод ажиллуулна.
-- insert into admins (user_id) select id from auth.users where email = 'tanii@email.mn';

-- ШИНЭЧЛЭЛ (өмнө нь схемээ ажиллуулсан бол зөвхөн энэ хэсгийг ажиллуулна):
alter table profiles add column if not exists fb text;
alter table profiles add column if not exists ig text;
alter table profiles add column if not exists photo text;

-- П.Мөнхсан-д админ эрх олгох (сайт дээр бүртгүүлж, профайл үүсгэсний дараа ажиллуулна):
insert into admins (user_id) select user_id from profiles where name ilike '%Мөнхсан%' and user_id is not null on conflict do nothing;
update profiles set status = 'approved' where name ilike '%Мөнхсан%';

-- ===== ШИНЭЧЛЭЛ 2: ажлын зар, профайл зураг, утасны нууцлал =====
create table if not exists jobs (
  id uuid primary key default gen_random_uuid(),
  type text default 'Ажил', title text not null, org text, loc text, contact text, descr text, deadline date,
  created_by uuid references auth.users on delete set null, created_at timestamptz default now());
alter table jobs enable row level security;
drop policy if exists "jobs read" on jobs; drop policy if exists "jobs insert" on jobs; drop policy if exists "jobs own" on jobs; drop policy if exists "jobs del" on jobs;
create policy "jobs read" on jobs for select using (true);
create policy "jobs insert" on jobs for insert with check (auth.uid() is not null and created_by = auth.uid());
create policy "jobs own" on jobs for update using (created_by = auth.uid() or is_admin());
create policy "jobs del" on jobs for delete using (created_by = auth.uid() or is_admin());

-- Утасны дугаарыг зөвхөн нэвтэрсэн хэрэглэгч харна
revoke select on profiles from anon;
grant select (id,user_id,name,year,cat,job,org,loc,tags,hide,fb,ig,photo,status,created_at) on profiles to anon;

-- Профайл зургийн сан
insert into storage.buckets (id, name, public) values ('avatars', 'avatars', true) on conflict (id) do nothing;
drop policy if exists "avatars read" on storage.objects; drop policy if exists "avatars write" on storage.objects; drop policy if exists "avatars update" on storage.objects; drop policy if exists "avatars delete" on storage.objects;
create policy "avatars read" on storage.objects for select using (bucket_id = 'avatars');
create policy "avatars write" on storage.objects for insert to authenticated with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "avatars update" on storage.objects for update to authenticated using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "avatars delete" on storage.objects for delete to authenticated using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
