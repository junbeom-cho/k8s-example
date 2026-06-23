CREATE USER _user WITH PASSWORD '$(openssl rand -hex 32)';
CREATE DATABASE _db OWNER _user;
GRANT ALL PRIVILEGES ON DATABASE _db TO _user;

\c _db
GRANT ALL ON SCHEMA public TO _user;
ALTER SCHEMA public OWNER TO _user;