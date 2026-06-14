-- Supabase Schema for Virtual Pet App (per new architecture spec)
-- Run this in Supabase SQL editor for production multiplayer/RBAC version.
-- Local MVP still uses JSON file persistence.

-- Core pet table (JSON-ready, matches the spec example)
create table if not exists pets (
  pet_id uuid primary key default gen_random_uuid(),
  owner_id uuid references auth.users not null,
  species text not null check (species in ('whale','cow','snake')),
  name text not null,
  stats jsonb not null default '{"hunger":70,"hygiene":70,"growth_stage":0,"growth_progress":0.0}',
  memory_vector_id text,
  last_interaction timestamptz default now(),
  created_at timestamptz default now(),
  -- For multiplayer shared space
  shared_state jsonb default '{}',
  interaction_count integer default 0
);

-- Memories / RAG log (episodic memory for LLM context)
create table if not exists pet_memories (
  id uuid primary key default gen_random_uuid(),
  pet_id uuid references pets(pet_id) on delete cascade,
  timestamp timestamptz default now(),
  event_type text,
  text text not null,
  metadata jsonb,
  importance float default 0.5,
  embedding vector(768), -- for pgvector RAG (enable extension)
  stat_snapshot jsonb
);

-- Profiles for RBAC (Owner vs Guest)
create table if not exists profiles (
  id uuid primary key references auth.users,
  role text not null default 'guest' check (role in ('owner','guest')),
  display_name text
);

-- Row Level Security (RLS) policies per spec
alter table pets enable row level security;
alter table pet_memories enable row level security;

-- Owners have full control
create policy "Owners full access to their pets"
  on pets for all
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

-- Guests can read + limited writes (e.g. one feed/day via app logic or trigger)
create policy "Guests can read shared pets"
  on pets for select
  using (true); -- or join on a shares table for specific guests

-- Similar for memories (read for context, write on interaction)

-- For real-time multiplayer: enable Realtime on pets table in Supabase dashboard.
-- Use optimistic concurrency: app sends last_interaction timestamp; server rejects if stale.

-- Growth + milestone logic can be in app or Postgres functions/triggers.
-- LLM thoughts: Store context in shared_state or call edge function that queries memories + stats.