-- =============================================================
-- Supabase Bootstrap: rollen, schema's, extensions en grants
-- =============================================================
-- Dit script draait bij eerste database-initialisatie (lege data dir).
-- Alle statements zijn idempotent (IF NOT EXISTS / DO $$ ... END $$).
--
-- BELANGRIJK: Het wachtwoord 'CHANGEME' wordt door install.sh vervangen
-- door het werkelijke POSTGRES_PASSWORD vóór dit script naar
-- /opt/supabase/volumes/db/init/ wordt gekopieerd.
-- =============================================================

-- =====================
-- 1. EXTENSIONS
-- =====================
CREATE SCHEMA IF NOT EXISTS extensions;

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

-- pgjwt is niet altijd beschikbaar in de image — skip als het niet bestaat
DO $$ BEGIN
  CREATE EXTENSION IF NOT EXISTS pgjwt WITH SCHEMA extensions;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'pgjwt extension niet beschikbaar — overgeslagen (niet kritiek)';
END $$;

-- =====================
-- 2. ROLLEN
-- =====================

-- Supabase admin (zonder REPLICATION/BYPASSRLS — die vereisen superuser)
DO $$ BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'supabase_admin') THEN
    CREATE ROLE supabase_admin LOGIN CREATEROLE CREATEDB;
  END IF;
END $$;

-- Anonyme rol (niet-ingelogde API requests)
DO $$ BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'anon') THEN
    CREATE ROLE anon NOLOGIN NOINHERIT;
  END IF;
END $$;

-- Geauthenticeerde rol (ingelogde API requests)
DO $$ BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'authenticated') THEN
    CREATE ROLE authenticated NOLOGIN NOINHERIT;
  END IF;
END $$;

-- Service role (server-side, bypass RLS)
DO $$ BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'service_role') THEN
    CREATE ROLE service_role NOLOGIN NOINHERIT BYPASSRLS;
  END IF;
END $$;

-- Authenticator (PostgREST login role, wisselt naar anon/authenticated/service_role)
-- Wachtwoord 'CHANGEME' wordt door install.sh vervangen door POSTGRES_PASSWORD
DO $$ BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'authenticator') THEN
    CREATE ROLE authenticator NOINHERIT LOGIN PASSWORD 'CHANGEME';
  ELSE
    ALTER ROLE authenticator WITH PASSWORD 'CHANGEME';
  END IF;
END $$;

-- Auth admin (GoTrue migraties en tabellen) — LOGIN nodig voor GoTrue connectie
DO $$ BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'supabase_auth_admin') THEN
    CREATE ROLE supabase_auth_admin LOGIN NOINHERIT CREATEROLE PASSWORD 'CHANGEME';
  ELSE
    ALTER ROLE supabase_auth_admin WITH LOGIN PASSWORD 'CHANGEME';
  END IF;
END $$;

-- Storage admin — LOGIN nodig voor storage-api connectie
DO $$ BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'supabase_storage_admin') THEN
    CREATE ROLE supabase_storage_admin LOGIN NOINHERIT PASSWORD 'CHANGEME';
  ELSE
    ALTER ROLE supabase_storage_admin WITH LOGIN PASSWORD 'CHANGEME';
  END IF;
END $$;

-- Realtime admin
DO $$ BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'supabase_realtime_admin') THEN
    CREATE ROLE supabase_realtime_admin NOLOGIN NOINHERIT;
  END IF;
END $$;

-- Dashboard user
DO $$ BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'dashboard_user') THEN
    CREATE ROLE dashboard_user NOLOGIN NOINHERIT;
  END IF;
END $$;

-- =====================
-- 3. ROL-GRANTS
-- =====================

-- Authenticator kan wisselen naar deze rollen
GRANT anon TO authenticator;
GRANT authenticated TO authenticator;
GRANT service_role TO authenticator;
GRANT supabase_admin TO authenticator;

-- Supabase admin krijgt alle rollen
GRANT anon TO supabase_admin;
GRANT authenticated TO supabase_admin;
GRANT service_role TO supabase_admin;
GRANT supabase_auth_admin TO supabase_admin;
GRANT supabase_storage_admin TO supabase_admin;

-- =====================
-- 4. SCHEMA'S
-- =====================
CREATE SCHEMA IF NOT EXISTS auth AUTHORIZATION supabase_auth_admin;
CREATE SCHEMA IF NOT EXISTS storage AUTHORIZATION supabase_storage_admin;
CREATE SCHEMA IF NOT EXISTS realtime;
CREATE SCHEMA IF NOT EXISTS _realtime;

-- =====================
-- 5. SCHEMA GRANTS
-- =====================

-- Auth schema
GRANT USAGE ON SCHEMA auth TO anon, authenticated, service_role;
GRANT ALL ON SCHEMA auth TO supabase_auth_admin;

-- Storage schema
GRANT USAGE ON SCHEMA storage TO anon, authenticated, service_role;
GRANT ALL ON SCHEMA storage TO supabase_storage_admin;

-- Public schema
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON SCHEMA public TO supabase_admin;

-- Extensions schema
GRANT USAGE ON SCHEMA extensions TO anon, authenticated, service_role, supabase_admin;

-- Realtime schema's
GRANT ALL ON SCHEMA realtime TO supabase_realtime_admin;
GRANT USAGE ON SCHEMA realtime TO anon, authenticated, service_role;
GRANT ALL ON SCHEMA _realtime TO supabase_realtime_admin;

-- =====================
-- 6. DEFAULT PRIVILEGES
-- =====================

-- Toekomstige tabellen in public zijn toegankelijk
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO anon, authenticated, service_role;

-- Extensions toegankelijk
ALTER DEFAULT PRIVILEGES IN SCHEMA extensions GRANT EXECUTE ON FUNCTIONS TO anon, authenticated, service_role;

-- =====================
-- 7. SEARCH PATH
-- =====================
ALTER ROLE authenticator SET search_path TO public, extensions;
ALTER ROLE anon SET search_path TO public, extensions;
ALTER ROLE authenticated SET search_path TO public, extensions;
ALTER ROLE service_role SET search_path TO public, extensions;

-- =====================
-- 8. KLAAR
-- =====================
-- GoTrue (auth), Storage en Realtime draaien hun eigen migraties
-- bovenop deze basis-structuur.
