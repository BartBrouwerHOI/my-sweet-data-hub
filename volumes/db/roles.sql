-- This script runs after the Supabase image's built-in init scripts.
-- It sets the correct password on service roles so GoTrue, Storage, and PostgREST can connect.

\set pgpass `echo "$POSTGRES_PASSWORD"`

ALTER USER authenticator WITH PASSWORD :'pgpass';
ALTER USER supabase_auth_admin WITH PASSWORD :'pgpass';
ALTER USER supabase_storage_admin WITH PASSWORD :'pgpass';
ALTER USER supabase_admin WITH PASSWORD :'pgpass';

-- Realtime vereist het _realtime schema
CREATE SCHEMA IF NOT EXISTS _realtime;
ALTER SCHEMA _realtime OWNER TO supabase_admin;
GRANT ALL ON SCHEMA _realtime TO supabase_admin;
