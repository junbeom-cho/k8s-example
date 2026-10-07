-- =====================================================================
-- Database — 앱 전용 DB/계정 생성 SQL (수동 실행, 클러스터에 자동 적용되지 않음)
-- 대상    : database ns 의 공유 PostgreSQL (postgres.database.svc.cluster.local:5432)
-- 생성    : 로그인 계정 _user, DB _db (owner: _user), _db 전체 권한,
--           public 스키마 권한/소유권 (PostgreSQL 15+ 에서도 앱이 테이블을 만들 수 있도록)
-- 사용법  : _user / _db / change-me 를 앱에 맞게 바꾼 뒤 superuser(postgres)로 psql 에서 실행
--           (중간의 DB 전환 명령은 psql 전용). 비밀번호는 openssl rand -hex 32 등으로 생성해
--           앱 쪽 Secret(Infisical)에도 같은 값으로 넣으세요.
-- MariaDB : 공유 MariaDB (mariadb.database.svc.cluster.local:3306) 는 문법이 다릅니다. 예)
--           CREATE DATABASE _db; CREATE USER '_user'@'%' IDENTIFIED BY 'change-me';
--           GRANT ALL PRIVILEGES ON _db.* TO '_user'@'%';
-- ⚠️ 실제 비밀번호를 채운 상태로 커밋하지 마세요.
-- =====================================================================
CREATE USER _user WITH PASSWORD 'change-me';
CREATE DATABASE _db OWNER _user;
GRANT ALL PRIVILEGES ON DATABASE _db TO _user;

\c _db
GRANT ALL ON SCHEMA public TO _user;
ALTER SCHEMA public OWNER TO _user;
