-- NY Packaging database: schema copied from the shared project's ny_* tables (2026-09-22).

-- Access = the ny_members list, not 'any company email'.

create extension if not exists pgcrypto;

create table if not exists public.ny_members (
  email text primary key check (email = lower(email)),
  added_at timestamptz not null default now()
);

create or replace function public.is_staff() returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from auth.users u join public.ny_members m on m.email = lower(u.email)
    where u.id = auth.uid() and u.email_confirmed_at is not null
  )
$$;

alter table public.ny_members enable row level security;

create policy ny_members_read on public.ny_members for select to authenticated using (public.is_staff());

CREATE OR REPLACE FUNCTION public.ny_shift_calc()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
declare mins int;
begin
  if new.clock_in is not null and new.clock_out is not null then
    mins := (extract(epoch from (new.clock_out - new.clock_in)) / 60)::int;
    if mins < 0 then mins := mins + 24*60; end if;
    mins := mins - coalesce(new.break_minutes, 0);
    if mins < 0 then mins := 0; end if;
    new.hours := round(mins / 60.0, 3);
  elsif new.source = 'import' then
    new.hours := coalesce(new.hours, 0);   -- paid leave has no punches; the importer's number stands
  else
    new.hours := 0;
  end if;
  new.total := round(coalesce(new.hours,0) * coalesce(new.rate,0) * coalesce(new.people,1), 2);
  new.updated_at := now();
  return new;
end $function$;

CREATE OR REPLACE FUNCTION public.touch_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin new.updated_at := now(); return new; end $function$;

create table public.ny_roster (
  "id" uuid default gen_random_uuid() not null,
  "last" text,
  "first" text not null,
  "full_name" text,
  "team" text,
  "default_company" text,
  "default_rate" numeric(8,2),
  "aliases" text[],
  "active" boolean default true not null,
  "created_at" timestamp with time zone default now() not null,
  "gusto_uuid" text,
  "gusto_synced_at" timestamp with time zone,
  constraint "ny_roster_pkey" PRIMARY KEY (id)
);

create table public.ny_shifts (
  "id" uuid default gen_random_uuid() not null,
  "category" text default 'distro'::text not null,
  "work_date" date not null,
  "company" text,
  "team" text,
  "roster_id" uuid,
  "last" text,
  "first" text,
  "clock_in" time without time zone,
  "clock_out" time without time zone,
  "break_minutes" integer default 0 not null,
  "hours" numeric(7,3) default 0 not null,
  "rate" numeric(8,2) default 0 not null,
  "total" numeric(10,2) default 0 not null,
  "people" integer default 1 not null,
  "pay_period" date,
  "source_id" text,
  "overlap_ok" boolean default false not null,
  "source" text default 'manual'::text not null,
  "photo_path" text,
  "note" text,
  "updated_by" uuid,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  constraint "ny_shifts_category_check" CHECK ((category = 'distro'::text)),
  constraint "ny_shifts_source_check" CHECK ((source = ANY (ARRAY['manual'::text, 'ocr'::text, 'import'::text, 'notes'::text]))),
  constraint "ny_shifts_roster_id_fkey" FOREIGN KEY (roster_id) REFERENCES ny_roster(id) ON DELETE SET NULL,
  constraint "ny_shifts_updated_by_fkey" FOREIGN KEY (updated_by) REFERENCES auth.users(id),
  constraint "ny_shifts_pkey" PRIMARY KEY (id)
);

create table public.ny_tasks (
  "id" uuid default gen_random_uuid() not null,
  "work_date" date not null,
  "task" text not null,
  "people" integer,
  "begin_at" time without time zone,
  "end_at" time without time zone,
  "packaged" integer,
  "labeled" integer,
  "seconds" integer,
  "hours" numeric(7,3),
  "cost" numeric(10,2),
  "note" text,
  "updated_by" uuid,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  constraint "ny_tasks_updated_by_fkey" FOREIGN KEY (updated_by) REFERENCES auth.users(id),
  constraint "ny_tasks_pkey" PRIMARY KEY (id)
);

create table public.ny_notes (
  "work_date" date not null,
  "note" text,
  "updated_by" uuid,
  "updated_at" timestamp with time zone default now() not null,
  constraint "ny_notes_updated_by_fkey" FOREIGN KEY (updated_by) REFERENCES auth.users(id),
  constraint "ny_notes_pkey" PRIMARY KEY (work_date)
);

create table public.ny_units_days (
  "work_date" date not null,
  "p10_prod" numeric(12,2),
  "p10_pre" numeric(12,2),
  "p10_post" numeric(12,2),
  "pk5_prod" numeric(12,2),
  "pk5_pre" numeric(12,2),
  "pk5_post" numeric(12,2),
  "jar_pack" numeric(12,2),
  "jar_label" numeric(12,2),
  "bud_pack" numeric(12,2),
  "bud_label" numeric(12,2),
  "pouch_pack" numeric(12,2),
  "pouch_label" numeric(12,2),
  "prep" numeric(12,2),
  "hours" numeric(8,2),
  "ppl" numeric(6,2),
  "tot_pack" numeric(12,2),
  "tot_label" numeric(12,2),
  "tot_prep" numeric(12,2),
  "uph" numeric(16,6),
  "lbs_pack" numeric(12,6),
  "lbs_label" numeric(12,6),
  "source" text default 'edit'::text not null,
  "updated_by" uuid,
  "updated_at" timestamp with time zone default now() not null,
  "vape_fill" numeric,
  "vape_pack" numeric,
  "vape_label" numeric,
  constraint "ny_units_days_source_check" CHECK ((source = ANY (ARRAY['import'::text, 'edit'::text]))),
  constraint "ny_units_days_updated_by_fkey" FOREIGN KEY (updated_by) REFERENCES auth.users(id),
  constraint "ny_units_days_pkey" PRIMARY KEY (work_date)
);

create table public.ny_labor_history (
  "id" bigint generated always as identity not null,
  "work_date" date not null,
  "task" text not null,
  "people" integer,
  "begin_at" time without time zone,
  "end_at" time without time zone,
  "seconds" integer,
  "hours" numeric(7,3),
  "packaged" integer,
  "labeled" integer,
  "cost" numeric(10,2),
  "note" text,
  constraint "ny_labor_history_pkey" PRIMARY KEY (id)
);

create table public.gusto_pull_requests (
  "id" uuid default gen_random_uuid() not null,
  "requested_by" uuid,
  "requested_at" timestamp with time zone default now() not null,
  "status" text default 'pending'::text not null,
  "detail" text,
  "completed_at" timestamp with time zone,
  constraint "gusto_pull_requests_status_check" CHECK ((status = ANY (ARRAY['pending'::text, 'running'::text, 'done'::text, 'error'::text]))),
  constraint "gusto_pull_requests_requested_by_fkey" FOREIGN KEY (requested_by) REFERENCES auth.users(id),
  constraint "gusto_pull_requests_pkey" PRIMARY KEY (id)
);

CREATE INDEX ny_labor_history_date_ix ON public.ny_labor_history USING btree (work_date);

CREATE UNIQUE INDEX ny_roster_gusto_uuid_ux ON public.ny_roster USING btree (gusto_uuid) WHERE (gusto_uuid IS NOT NULL);

CREATE INDEX ny_shifts_date_ix ON public.ny_shifts USING btree (work_date);

CREATE INDEX ny_shifts_source_date_ix ON public.ny_shifts USING btree (source, work_date);

CREATE UNIQUE INDEX ny_shifts_source_id_ux ON public.ny_shifts USING btree (source_id);

CREATE INDEX ny_tasks_date_ix ON public.ny_tasks USING btree (work_date);

CREATE TRIGGER trg_ny_task_touch BEFORE INSERT OR UPDATE ON public.ny_tasks FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

CREATE TRIGGER trg_ny_note_touch BEFORE INSERT OR UPDATE ON public.ny_notes FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

CREATE TRIGGER trg_ny_units_touch BEFORE INSERT OR UPDATE ON public.ny_units_days FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

CREATE TRIGGER trg_ny_shift BEFORE INSERT OR UPDATE ON public.ny_shifts FOR EACH ROW EXECUTE FUNCTION ny_shift_calc();

alter table public.ny_roster enable row level security;

alter table public.ny_shifts enable row level security;

alter table public.ny_tasks enable row level security;

alter table public.ny_notes enable row level security;

alter table public.ny_units_days enable row level security;

alter table public.ny_labor_history enable row level security;

alter table public.gusto_pull_requests enable row level security;

create policy "gusto_pull_staff_insert" on public.gusto_pull_requests as permissive for insert to authenticated with check ((is_staff() AND (requested_by = auth.uid())));

create policy "gusto_pull_staff_select" on public.gusto_pull_requests as permissive for select to authenticated using (is_staff());

create policy "ny_labor_history_staff_read" on public.ny_labor_history as permissive for select to authenticated using (is_staff());

create policy "ny_notes_staff_all" on public.ny_notes as permissive for all to authenticated using (is_staff()) with check (is_staff());

create policy "ny_roster_staff_all" on public.ny_roster as permissive for all to authenticated using (is_staff()) with check (is_staff());

create policy "ny_shifts_staff_all" on public.ny_shifts as permissive for all to authenticated using (is_staff()) with check (is_staff());

create policy "ny_tasks_staff_all" on public.ny_tasks as permissive for all to authenticated using (is_staff()) with check (is_staff());

create policy "ny_units_days_staff_all" on public.ny_units_days as permissive for all to authenticated using (is_staff()) with check (is_staff());

alter publication supabase_realtime add table public.ny_shifts, public.ny_roster, public.ny_tasks, public.ny_notes, public.ny_units_days;

insert into storage.buckets (id, name, public) values ('timesheets','timesheets',false) on conflict (id) do nothing;

create policy timesheets_staff_rw on storage.objects for all to authenticated using (bucket_id = 'timesheets' and public.is_staff()) with check (bucket_id = 'timesheets' and public.is_staff());

