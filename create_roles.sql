-- БД

CREATE DATABASE "taxi_service";

-- Роли
CREATE ROLE "guest"         NOLOGIN;
CREATE ROLE "client"        NOLOGIN;
CREATE ROLE "driver"        NOLOGIN;
CREATE ROLE "admin"         NOLOGIN CREATEROLE;

GRANT "client" TO "admin" WITH ADMIN OPTION;
GRANT "driver" TO "admin" WITH ADMIN OPTION;

-- Схемы

CREATE SCHEMA "private" AUTHORIZATION "postgres";
CREATE SCHEMA "admin" AUTHORIZATION "postgres";
CREATE SCHEMA "authorized" AUTHORIZATION "postgres";
CREATE SCHEMA "workers" AUTHORIZATION "postgres";
CREATE SCHEMA "crypto" AUTHORIZATION "postgres";
CREATE SCHEMA "analytics" AUTHORIZATION "postgres";

CREATE EXTENSION IF NOT EXISTS pgcrypto SCHEMA crypto;

REVOKE ALL ON SCHEMA "private" FROM PUBLIC;
REVOKE ALL ON SCHEMA "admin" FROM PUBLIC;
REVOKE ALL ON SCHEMA "authorized" FROM PUBLIC;
REVOKE ALL ON SCHEMA "workers" FROM PUBLIC;
REVOKE ALL ON SCHEMA "crypto" FROM PUBLIC;
REVOKE ALL ON SCHEMA "analytics" FROM PUBLIC;

GRANT USAGE ON SCHEMA "admin"       TO "admin";
GRANT USAGE ON SCHEMA "authorized"  TO "admin", "client", "driver";
GRANT USAGE ON SCHEMA "workers"     TO "admin", "driver";
GRANT USAGE ON SCHEMA "analytics"   TO "admin", "client", "driver";

GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA "admin" TO "admin";
GRANT EXECUTE ON ALL PROCEDURES IN SCHEMA "admin" TO "admin";
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA "authorized" TO "admin", "client", "driver";
GRANT EXECUTE ON ALL PROCEDURES IN SCHEMA "authorized" TO "admin", "client", "driver";
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA "workers" TO "admin", "driver";
GRANT EXECUTE ON ALL PROCEDURES IN SCHEMA "workers" TO "admin", "driver";

-- Технический пользователь

CREATE USER "guest_account" WITH PASSWORD 'guest_account';
GRANT "guest" TO guest_account;