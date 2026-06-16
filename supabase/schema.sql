-- 1. Enable UUID Extension
create extension if not exists "uuid-ossp";

-- 2. Profiles (Extends Supabase Auth)
create table profiles (
  id uuid references auth.users on delete cascade primary key,
  email text unique not null,
  name text not null,
  role text not null check (role in ('admin', 'employee')),
  avatar_url text,
  department text,
  designation text,
  phone text,
  is_active boolean default true,
  onboarding_complete boolean default false,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 3. Clients
create table clients (
  id uuid default uuid_generate_v4() primary key,
  name text not null,
  industry text not null,
  logo_url text,
  status text not null check (status in ('Active', 'Lead', 'Inactive')),
  notes text,
  financials jsonb default '{"total_revenue": 0.0, "pending_payments": 0.0, "last_payment_date": null}'::jsonb,
  contacts jsonb default '[]'::jsonb,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 4. Projects
create table projects (
  id uuid default uuid_generate_v4() primary key,
  name text not null,
  description text,
  client_id uuid references clients(id) on delete set null,
  status text not null check (status in ('Planning', 'In Progress', 'On Hold', 'Completed')),
  progress numeric default 0.0,
  start_date timestamp with time zone,
  due_date timestamp with time zone,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table project_members (
  project_id uuid references projects(id) on delete cascade,
  user_id uuid references profiles(id) on delete cascade,
  role text not null,
  primary key (project_id, user_id)
);

-- 5. Tasks
create table tasks (
  id uuid default uuid_generate_v4() primary key,
  project_id uuid references projects(id) on delete cascade,
  title text not null,
  description text,
  status text not null check (status in ('Todo', 'In Progress', 'Review', 'Done')),
  priority text not null check (priority in ('Low', 'Medium', 'High', 'Urgent')),
  assignee_id uuid references profiles(id) on delete set null,
  due_date timestamp with time zone,
  checklist jsonb default '[]'::jsonb,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 6. Journal Notes
create table journal_notes (
  id uuid default uuid_generate_v4() primary key,
  project_id uuid references projects(id) on delete cascade,
  author_id uuid references profiles(id) on delete cascade,
  title text not null,
  content text not null,
  note_type text not null check (note_type in ('text', 'meeting', 'voice')),
  is_pinned boolean default false,
  is_private boolean default false,
  attachments jsonb default '[]'::jsonb,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 7. Drive Items
create table drive_items (
  id uuid default uuid_generate_v4() primary key,
  project_id uuid references projects(id) on delete cascade,
  parent_folder_id uuid references drive_items(id) on delete cascade,
  name text not null,
  mime_type text not null,
  is_folder boolean default false,
  is_final_export boolean default false,
  gdrive_file_id text,
  web_view_link text,
  web_content_link text,
  delivery_status text check (delivery_status in ('Pending', 'Delivered', 'Client Approved', 'Revisions Requested')),
  delivered_at timestamp with time zone,
  size_bytes bigint,
  uploaded_by uuid references profiles(id) on delete set null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 8. Attendance Sessions
create table attendance_sessions (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references profiles(id) on delete cascade,
  date date not null,
  check_in_time timestamp with time zone not null,
  check_out_time timestamp with time zone,
  status text not null check (status in ('Present', 'Absent', 'Half Day', 'Leave')),
  total_minutes integer default 0,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table attendance_logs (
  id uuid default uuid_generate_v4() primary key,
  session_id uuid references attendance_sessions(id) on delete cascade,
  timestamp timestamp with time zone not null,
  action text not null check (action in ('Check In', 'Check Out', 'System Auto Checkout')),
  bssid text,
  ip_address text
);

-- 9. Audit Logs
create table audit_logs (
  id uuid default uuid_generate_v4() primary key,
  table_name text not null,
  record_id uuid not null,
  action text not null,
  old_data jsonb,
  new_data jsonb,
  changed_by uuid references profiles(id) on delete set null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- ──────────────────────────────────────────────────────────
-- TRIGGERS FOR UPDATED_AT
-- ──────────────────────────────────────────────────────────

create or replace function update_modified_column()
returns trigger as $$
begin
    new.updated_at = now();
    return new;
end;
$$ language 'plpgsql';

create trigger update_profiles_modtime before update on profiles for each row execute procedure update_modified_column();
create trigger update_clients_modtime before update on clients for each row execute procedure update_modified_column();
create trigger update_projects_modtime before update on projects for each row execute procedure update_modified_column();
create trigger update_tasks_modtime before update on tasks for each row execute procedure update_modified_column();
create trigger update_journal_modtime before update on journal_notes for each row execute procedure update_modified_column();
create trigger update_drive_modtime before update on drive_items for each row execute procedure update_modified_column();


-- ──────────────────────────────────────────────────────────
-- AUDIT LOG TRIGGERS
-- ──────────────────────────────────────────────────────────

create or replace function audit_log_trigger()
returns trigger as $$
begin
    if (TG_OP = 'INSERT') then
        insert into audit_logs (table_name, record_id, action, new_data)
        values (TG_TABLE_NAME, new.id, 'INSERT', row_to_json(new));
        return new;
    elsif (TG_OP = 'UPDATE') then
        insert into audit_logs (table_name, record_id, action, old_data, new_data)
        values (TG_TABLE_NAME, new.id, 'UPDATE', row_to_json(old), row_to_json(new));
        return new;
    elsif (TG_OP = 'DELETE') then
        insert into audit_logs (table_name, record_id, action, old_data)
        values (TG_TABLE_NAME, old.id, 'DELETE', row_to_json(old));
        return old;
    end if;
    return null;
end;
$$ language 'plpgsql';

create trigger audit_profiles after insert or update or delete on profiles for each row execute procedure audit_log_trigger();
create trigger audit_clients after insert or update or delete on clients for each row execute procedure audit_log_trigger();
create trigger audit_projects after insert or update or delete on projects for each row execute procedure audit_log_trigger();
create trigger audit_tasks after insert or update or delete on tasks for each row execute procedure audit_log_trigger();


-- ──────────────────────────────────────────────────────────
-- INDEXES
-- ──────────────────────────────────────────────────────────

create index idx_projects_client_id on projects(client_id);
create index idx_tasks_project_id on tasks(project_id);
create index idx_tasks_assignee_id on tasks(assignee_id);
create index idx_journal_project_id on journal_notes(project_id);
create index idx_drive_project_id on drive_items(project_id);
create index idx_drive_parent_folder on drive_items(parent_folder_id);
create index idx_attendance_user_date on attendance_sessions(user_id, date);
create index idx_attendance_logs_session on attendance_logs(session_id);


-- ──────────────────────────────────────────────────────────
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ──────────────────────────────────────────────────────────

-- Profiles
alter table profiles enable row level security;
create policy "Public profiles are viewable by everyone." on profiles for select using (true);
create policy "Users can insert their own profile." on profiles for insert with check (auth.uid() = id);
create policy "Users can update own profile." on profiles for update using (auth.uid() = id);

-- Clients
alter table clients enable row level security;
create policy "Clients are viewable by everyone." on clients for select using (true);
create policy "Admins can insert clients." on clients for insert with check (exists (select 1 from profiles where id = auth.uid() and role = 'admin'));
create policy "Admins can update clients." on clients for update using (exists (select 1 from profiles where id = auth.uid() and role = 'admin'));

-- Projects
alter table projects enable row level security;
create policy "Projects are viewable by everyone." on projects for select using (true);
create policy "Admins can manage projects." on projects for all using (exists (select 1 from profiles where id = auth.uid() and role = 'admin'));

-- Project Members
alter table project_members enable row level security;
create policy "Project members are viewable by everyone." on project_members for select using (true);
create policy "Admins can manage project members." on project_members for all using (exists (select 1 from profiles where id = auth.uid() and role = 'admin'));

-- Tasks
alter table tasks enable row level security;
create policy "Tasks are viewable by everyone." on tasks for select using (true);
create policy "Users can update their assigned tasks." on tasks for update using (assignee_id = auth.uid());
create policy "Admins can manage all tasks." on tasks for all using (exists (select 1 from profiles where id = auth.uid() and role = 'admin'));

-- Journal Notes
alter table journal_notes enable row level security;
create policy "Public journal notes viewable by everyone." on journal_notes for select using (is_private = false);
create policy "Private journal notes viewable by author." on journal_notes for select using (is_private = true and author_id = auth.uid());
create policy "Authors can insert journal notes." on journal_notes for insert with check (author_id = auth.uid());
create policy "Authors can update their journal notes." on journal_notes for update using (author_id = auth.uid());

-- Drive Items
alter table drive_items enable row level security;
create policy "Drive items are viewable by everyone." on drive_items for select using (true);
create policy "Admins can manage drive items." on drive_items for all using (exists (select 1 from profiles where id = auth.uid() and role = 'admin'));
create policy "Users can insert drive items." on drive_items for insert with check (auth.uid() is not null);

-- Attendance Sessions
alter table attendance_sessions enable row level security;
create policy "Users can view their own attendance." on attendance_sessions for select using (user_id = auth.uid());
create policy "Admins can view all attendance." on attendance_sessions for select using (exists (select 1 from profiles where id = auth.uid() and role = 'admin'));
create policy "Users can insert their own attendance." on attendance_sessions for insert with check (user_id = auth.uid());
create policy "Users can update their own attendance." on attendance_sessions for update using (user_id = auth.uid());

-- Attendance Logs
alter table attendance_logs enable row level security;
create policy "Users can view their own logs via session." on attendance_logs for select using (
  exists (select 1 from attendance_sessions s where s.id = session_id and s.user_id = auth.uid())
);
create policy "Admins can view all logs." on attendance_logs for select using (exists (select 1 from profiles where id = auth.uid() and role = 'admin'));
create policy "Users can insert their own logs." on attendance_logs for insert with check (
  exists (select 1 from attendance_sessions s where s.id = session_id and s.user_id = auth.uid())
);

-- Audit Logs
alter table audit_logs enable row level security;
create policy "Admins can view audit logs." on audit_logs for select using (exists (select 1 from profiles where id = auth.uid() and role = 'admin'));
