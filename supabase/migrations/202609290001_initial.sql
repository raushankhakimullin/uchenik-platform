-- Run in a NEW Supabase project through the SQL editor or Supabase CLI.
-- Never put the service_role key in the browser.
create extension if not exists pgcrypto;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  created_at timestamptz not null default now()
);
create table public.roles (name text primary key);
insert into public.roles values ('ученик'), ('ведущий'), ('наставник'), ('региональный координатор'), ('администратор');
create table public.user_roles (
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null references public.roles(name),
  primary key (user_id, role)
);

create function public.is_admin() returns boolean language sql stable security definer set search_path = ''
as $$ select exists(select 1 from public.user_roles where user_id = auth.uid() and role = 'администратор') $$;

create function public.new_profile() returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.profiles(id, display_name) values (new.id, coalesce(new.raw_user_meta_data->>'display_name', ''));
  insert into public.user_roles(user_id, role) values(new.id, 'ученик');
  return new;
end $$;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.new_profile();

create table public.courses (
  id integer primary key,
  title text not null,
  description text not null default '',
  published boolean not null default false
);
create table public.modules (
  id integer primary key,
  course_id integer not null references public.courses(id),
  title text not null,
  position integer not null unique,
  published boolean not null default false
);
create table public.lessons (
  id uuid primary key default gen_random_uuid(),
  module_id integer not null references public.modules(id),
  title text not null,
  status text not null default 'draft' check(status in ('draft','published','archived')),
  version integer not null default 1,
  updated_at timestamptz not null default now()
);
create table public.lesson_blocks (
  id uuid primary key default gen_random_uuid(),
  lesson_id uuid not null references public.lessons(id) on delete cascade,
  position integer not null,
  kind text not null check(kind in ('scripture','video','text','quote','question','reflection','obedience_action','practice','person_selector','prayer','download','image','divider','next_step')),
  content jsonb not null default '{}'::jsonb,
  unique(lesson_id, position)
);
create table public.enrollments (
  user_id uuid not null references public.profiles(id) on delete cascade,
  course_id integer not null references public.courses(id),
  created_at timestamptz not null default now(),
  primary key(user_id,course_id)
);
create table public.lesson_progress (
  user_id uuid not null references public.profiles(id) on delete cascade,
  lesson_id uuid not null references public.lessons(id),
  answers jsonb not null default '{}'::jsonb,
  step integer not null default 0 check(step >= 0),
  updated_at timestamptz not null default now(),
  primary key(user_id,lesson_id)
);
create table public.contacts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  name text not null check(length(trim(name)) between 1 and 100),
  category text not null check(category in ('семья','друзья','работа','соседи','знакомые')),
  status text not null check(status in ('молюсь','открыт','общаемся о вере','читаем Писание','ученические отношения')),
  created_at timestamptz not null default now()
);
create table public.obedience_actions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  lesson_id uuid references public.lessons(id),
  decision text not null check(length(trim(decision)) > 0),
  due_date date not null,
  contact_id uuid references public.contacts(id) on delete set null,
  status text not null default 'запланировано' check(status in ('запланировано','сделал','пока нет','нужна помощь')),
  result_note text not null default '',
  transferred boolean not null default false,
  created_at timestamptz not null default now()
);
create function public.check_action_contact() returns trigger language plpgsql set search_path = ''
as $$ begin
  if new.contact_id is not null and not exists(select 1 from public.contacts where id=new.contact_id and user_id=new.user_id) then
    raise exception 'Этот контакт вам не принадлежит';
  end if;
  return new;
end $$;
create trigger action_contact before insert or update on public.obedience_actions for each row execute function public.check_action_contact();
create table public.reflections (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  lesson_id uuid not null references public.lessons(id),
  body text not null,
  created_at timestamptz not null default now()
);

create table public.disciple_relationships (
  id uuid primary key default gen_random_uuid(),
  mentor_id uuid not null references public.profiles(id) on delete cascade,
  disciple_id uuid references public.profiles(id) on delete cascade,
  contact_id uuid references public.contacts(id) on delete set null,
  started_at date not null default current_date,
  next_meeting date,
  status text not null default 'личная запись' check(status in ('личная запись','ожидает подтверждения','подтверждено','завершено')),
  check (mentor_id is distinct from disciple_id),
  check ((disciple_id is null and status in ('личная запись','завершено')) or disciple_id is not null)
);
create unique index one_confirmed_mentor on public.disciple_relationships(disciple_id) where status='подтверждено';
create function public.check_relationship() returns trigger language plpgsql set search_path = ''
as $$
begin
  if new.contact_id is not null and not exists(select 1 from public.contacts where id=new.contact_id and user_id=new.mentor_id) then
    raise exception 'Контакт не принадлежит наставнику';
  end if;
  if new.disciple_id is null and new.status not in ('личная запись','завершено') then
    raise exception 'Незарегистрированный человек не может подтвердить связь';
  end if;
  if new.status='подтверждено' then
    perform pg_advisory_xact_lock(520041);
    if new.mentor_id = new.disciple_id or exists(
      with recursive descendants(id) as (
        select r.disciple_id from public.disciple_relationships r where r.mentor_id=new.disciple_id and r.status='подтверждено' and r.id<>new.id
        union
        select r.disciple_id from public.disciple_relationships r join descendants d on r.mentor_id=d.id where r.status='подтверждено' and r.id<>new.id
      )
      select 1 from descendants where id=new.mentor_id
    ) then raise exception 'Цикл ученических связей запрещён'; end if;
  end if;
  return new;
end $$;
create trigger relationship_guard before insert or update on public.disciple_relationships for each row execute function public.check_relationship();

create table public.gbo_paths (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  published boolean not null default false
);
create table public.gbo_lessons (
  id uuid primary key default gen_random_uuid(),
  path_id uuid not null references public.gbo_paths(id),
  title text not null,
  content jsonb not null default '{}'::jsonb,
  position integer not null default 1
);
create table public.groups (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  name text not null check(length(trim(name)) between 1 and 100),
  path_id uuid references public.gbo_paths(id),
  created_at timestamptz not null default now()
);
create table public.group_members (
  group_id uuid not null references public.groups(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'участник' check(role in ('участник','ведущий')),
  primary key(group_id,user_id)
);
create table public.group_invitations (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  inviter_id uuid not null references public.profiles(id) on delete cascade,
  invitee_email text not null,
  token uuid not null default gen_random_uuid() unique,
  status text not null default 'ожидает' check(status in ('ожидает','принято','отменено')),
  created_at timestamptz not null default now()
);
create table public.meetings (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  starts_at timestamptz not null,
  leader_id uuid not null references public.profiles(id),
  path_id uuid references public.gbo_paths(id)
);
create table public.gbo_sessions (
  id uuid primary key default gen_random_uuid(),
  meeting_id uuid not null unique references public.meetings(id) on delete cascade,
  leader_id uuid not null references public.profiles(id),
  step integer not null default 0 check(step between 0 and 15),
  notes jsonb not null default '{}'::jsonb,
  summary text not null default '',
  status text not null default 'в процессе' check(status in ('в процессе','завершено')),
  updated_at timestamptz not null default now()
);
create table public.gbo_responses (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.gbo_sessions(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  section text not null,
  answer text not null,
  unique(session_id,user_id,section)
);
create table public.telegram_connections (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  telegram_chat_id text not null,
  verified_at timestamptz
);
create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  kind text not null,
  payload jsonb not null default '{}'::jsonb,
  sent_at timestamptz
);

create function public.is_group_member(gid uuid) returns boolean language sql stable security definer set search_path = ''
as $$ select exists(select 1 from public.group_members where group_id=gid and user_id=auth.uid()) $$;
create function public.is_group_leader(gid uuid) returns boolean language sql stable security definer set search_path = ''
as $$ select exists(select 1 from public.group_members where group_id=gid and user_id=auth.uid() and role='ведущий') $$;
create function public.is_group_member_of_user(other_id uuid) returns boolean language sql stable security definer set search_path = ''
as $$ select exists(select 1 from public.group_members a join public.group_members b on a.group_id=b.group_id where a.user_id=auth.uid() and b.user_id=other_id) $$;
create function public.add_group_owner() returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.group_members(group_id,user_id,role) values(new.id,new.owner_id,'ведущий');
  insert into public.user_roles(user_id,role) values(new.owner_id,'ведущий') on conflict do nothing;
  return new;
end $$;
create trigger owner_is_member after insert on public.groups for each row execute function public.add_group_owner();
create function public.check_meeting_leader() returns trigger language plpgsql set search_path = ''
as $$ begin
  if not exists(select 1 from public.group_members where group_id=new.group_id and user_id=new.leader_id) then raise exception 'Ведущий должен быть участником группы'; end if;
  return new;
end $$;
create trigger meeting_leader_guard before insert or update on public.meetings for each row execute function public.check_meeting_leader();

alter table public.profiles enable row level security;
alter table public.roles enable row level security;
alter table public.user_roles enable row level security;
alter table public.courses enable row level security;
alter table public.modules enable row level security;
alter table public.lessons enable row level security;
alter table public.lesson_blocks enable row level security;
alter table public.enrollments enable row level security;
alter table public.lesson_progress enable row level security;
alter table public.contacts enable row level security;
alter table public.obedience_actions enable row level security;
alter table public.reflections enable row level security;
alter table public.disciple_relationships enable row level security;
alter table public.gbo_paths enable row level security;
alter table public.gbo_lessons enable row level security;
alter table public.groups enable row level security;
alter table public.group_members enable row level security;
alter table public.group_invitations enable row level security;
alter table public.meetings enable row level security;
alter table public.gbo_sessions enable row level security;
alter table public.gbo_responses enable row level security;
alter table public.telegram_connections enable row level security;
alter table public.notifications enable row level security;

create policy profiles_read on public.profiles for select to authenticated using (id=auth.uid() or public.is_group_member_of_user(id));
create policy profiles_update on public.profiles for update to authenticated using(id=auth.uid()) with check(id=auth.uid());
create policy roles_read on public.roles for select to authenticated using(true);
create policy user_roles_read on public.user_roles for select to authenticated using(user_id=auth.uid() or public.is_admin());
create policy user_roles_manage on public.user_roles for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy courses_read on public.courses for select using(published or public.is_admin());
create policy courses_admin on public.courses for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy modules_read on public.modules for select using(published or public.is_admin());
create policy modules_admin on public.modules for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy lessons_read on public.lessons for select using(status='published' or public.is_admin());
create policy lessons_admin on public.lessons for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy blocks_read on public.lesson_blocks for select using(public.is_admin() or exists(select 1 from public.lessons l where l.id=lesson_id and l.status='published'));
create policy blocks_admin on public.lesson_blocks for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy enrollments_self on public.enrollments for all to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy progress_self on public.lesson_progress for all to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy contacts_self on public.contacts for all to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy actions_self on public.obedience_actions for all to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy reflections_self on public.reflections for all to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy relationships_read on public.disciple_relationships for select to authenticated using(mentor_id=auth.uid() or disciple_id=auth.uid());
create policy relationships_insert on public.disciple_relationships for insert to authenticated with check(mentor_id=auth.uid() and disciple_id is null and status='личная запись');
create policy relationships_update on public.disciple_relationships for update to authenticated using(mentor_id=auth.uid() and disciple_id is null) with check(mentor_id=auth.uid() and disciple_id is null and status in ('личная запись','завершено'));
create policy paths_read on public.gbo_paths for select using(published or public.is_admin());
create policy paths_admin on public.gbo_paths for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy gbo_lessons_read on public.gbo_lessons for select using(public.is_admin() or exists(select 1 from public.gbo_paths p where p.id=path_id and p.published));
create policy gbo_lessons_admin on public.gbo_lessons for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy groups_read on public.groups for select to authenticated using(public.is_group_member(id));
create policy groups_insert on public.groups for insert to authenticated with check(owner_id=auth.uid());
create policy groups_update on public.groups for update to authenticated using(owner_id=auth.uid()) with check(owner_id=auth.uid());
create policy groups_delete on public.groups for delete to authenticated using(owner_id=auth.uid());
create policy members_read on public.group_members for select to authenticated using(public.is_group_member(group_id));
create policy invites_read on public.group_invitations for select to authenticated using(public.is_group_leader(group_id) or lower(invitee_email)=lower(auth.jwt()->>'email'));
create policy invites_insert on public.group_invitations for insert to authenticated with check(public.is_group_leader(group_id) and inviter_id=auth.uid() and status='ожидает');
create policy invites_cancel on public.group_invitations for update to authenticated using(public.is_group_leader(group_id)) with check(public.is_group_leader(group_id) and status='отменено');
create policy meetings_read on public.meetings for select to authenticated using(public.is_group_member(group_id));
create policy meetings_write on public.meetings for insert to authenticated with check(public.is_group_leader(group_id));
create policy meetings_update on public.meetings for update to authenticated using(public.is_group_leader(group_id)) with check(public.is_group_leader(group_id));
create policy meetings_delete on public.meetings for delete to authenticated using(public.is_group_leader(group_id));
create policy sessions_read on public.gbo_sessions for select to authenticated using(exists(select 1 from public.meetings m where m.id=meeting_id and public.is_group_member(m.group_id)));
create policy sessions_insert on public.gbo_sessions for insert to authenticated with check(leader_id=auth.uid() and exists(select 1 from public.meetings m where m.id=meeting_id and m.leader_id=auth.uid()));
create policy sessions_update on public.gbo_sessions for update to authenticated using(leader_id=auth.uid()) with check(leader_id=auth.uid());
create policy responses_read on public.gbo_responses for select to authenticated using(exists(select 1 from public.gbo_sessions s join public.meetings m on m.id=s.meeting_id where s.id=session_id and public.is_group_member(m.group_id)));
create policy responses_write on public.gbo_responses for insert to authenticated with check(user_id=auth.uid() and exists(select 1 from public.gbo_sessions s join public.meetings m on m.id=s.meeting_id where s.id=session_id and public.is_group_member(m.group_id)));
create policy responses_update on public.gbo_responses for update to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy telegram_self on public.telegram_connections for select to authenticated using(user_id=auth.uid());
create policy notifications_self on public.notifications for select to authenticated using(user_id=auth.uid());

-- Membership cannot be granted by writing to group_members directly.
create function public.accept_group_invitation(invitation_token uuid) returns uuid
language plpgsql security definer set search_path = '' as $$
declare invitation public.group_invitations%rowtype;
begin
  if auth.uid() is null then raise exception 'Нужен вход'; end if;
  select * into invitation from public.group_invitations where token=invitation_token and status='ожидает' for update;
  if not found or lower(invitation.invitee_email) <> lower(auth.jwt()->>'email') then raise exception 'Приглашение недоступно'; end if;
  insert into public.group_members(group_id,user_id) values(invitation.group_id,auth.uid()) on conflict do nothing;
  update public.group_invitations set status='принято' where id=invitation.id;
  return invitation.group_id;
end $$;
create function public.invite_disciple(invitee_email text) returns boolean
language plpgsql security definer set search_path = '' as $$
declare target_id uuid;
begin
  if auth.uid() is null then raise exception 'Нужен вход'; end if;
  select id into target_id from auth.users where lower(email)=lower(trim(invitee_email)) and id<>auth.uid();
  if target_id is null then return false; end if;
  if exists(select 1 from public.disciple_relationships where mentor_id=auth.uid() and disciple_id=target_id and status in ('ожидает подтверждения','подтверждено')) then return true; end if;
  insert into public.disciple_relationships(mentor_id,disciple_id,status) values(auth.uid(),target_id,'ожидает подтверждения');
  return true;
end $$;
create function public.respond_disciple_relationship(relationship_id uuid, accept boolean) returns void
language plpgsql security definer set search_path = '' as $$
begin
  update public.disciple_relationships
    set status=case when accept then 'подтверждено' else 'завершено' end
    where id=relationship_id and disciple_id=auth.uid() and status='ожидает подтверждения';
  if not found then raise exception 'Приглашение недоступно'; end if;
end $$;
create function public.leave_disciple_relationship(relationship_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  update public.disciple_relationships set status='завершено'
  where id=relationship_id and (mentor_id=auth.uid() or disciple_id=auth.uid()) and status in ('личная запись','ожидает подтверждения','подтверждено');
  if not found then raise exception 'Связь недоступна'; end if;
end $$;
create function public.my_generations() returns table(generation integer, people bigint)
language sql stable security definer set search_path = '' as $$
with recursive tree(id, generation, trail) as (
  select r.disciple_id, 1, array[auth.uid(),r.disciple_id]
  from public.disciple_relationships r where r.mentor_id=auth.uid() and r.status='подтверждено'
  union all
  select r.disciple_id,t.generation+1,t.trail||r.disciple_id
  from tree t join public.disciple_relationships r on r.mentor_id=t.id
  where r.status='подтверждено' and t.generation < 4 and not r.disciple_id=any(t.trail)
) select t.generation,count(distinct t.id) from tree t group by t.generation order by t.generation $$;
revoke all on function public.is_admin(), public.is_group_member(uuid), public.is_group_leader(uuid), public.is_group_member_of_user(uuid) from public, anon;
grant execute on function public.is_admin(), public.is_group_member(uuid), public.is_group_leader(uuid), public.is_group_member_of_user(uuid) to authenticated;
revoke all on function public.accept_group_invitation(uuid), public.invite_disciple(text), public.respond_disciple_relationship(uuid,boolean), public.leave_disciple_relationship(uuid), public.my_generations() from public, anon;
grant execute on function public.accept_group_invitation(uuid), public.invite_disciple(text), public.respond_disciple_relationship(uuid,boolean), public.leave_disciple_relationship(uuid), public.my_generations() to authenticated;

-- Admin bootstrap: after the first real account is registered, a Supabase project
-- owner executes this manually in SQL editor with that account's UUID:
-- insert into public.user_roles(user_id,role) values ('ACCOUNT_UUID','администратор');