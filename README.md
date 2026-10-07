# server-k3s

단일 노드 **K3s** 홈서버(`techbara-server`)에 서비스를 올릴 때 쓰던 배포 설정 모음입니다.
Helm 차트의 values 파일과 직접 작성한 Kubernetes 매니페스트로 이루어져 있습니다.

> [!WARNING]
> **운영 종료 — 아카이브 / 예시 저장소입니다.** 이 클러스터는 더 이상 운영하지 않으며, 파일은 마지막 사용 시점 그대로입니다.
> 모든 설정 파일 맨 위에 **버전 확인 헤더**가 있습니다. ⚠️ 다음에 사용할 때는 헤더에 적힌 차트·이미지 버전을 기준으로
> 최신 버전과 변경 사항(Breaking Changes)을 반드시 확인하세요. 비밀 값은 모두 `change-me` 로 바꿔 두었습니다.

- 아키텍처, 플랫폼 구성, 최종 라이브 스냅샷(2026-07-21): [`docs/INFRASTRUCTURE.md`](docs/INFRASTRUCTURE.md)
- docker-compose 만 제공하는 앱을 이 규칙에 맞게 옮길 때 쓰는 스캐폴드: [`docs/templates/`](docs/templates/README.md)

## 구조 규칙

### 디렉터리 = 네임스페이스

- 최상위 서비스 디렉터리 하나가 Kubernetes 네임스페이스 하나이고, 이름이 같습니다 (`vaultwarden/` → ns `vaultwarden`).
- 예외는 업스트림이 정해 둔 네임스페이스를 쓰는 세 개입니다: `longhorn/` → `longhorn-system`, `metallb/` → `metallb-system`, `keel/` → `kube-system`.
- `docs/templates/` 는 스캐폴드일 뿐 네임스페이스가 아닙니다.

### 관련 컴포넌트는 한 디렉터리에

- 앱과 그 앱 전용 DB·캐시·동반 컴포넌트는 같은 디렉터리(= 네임스페이스)에 둡니다:
  `quartz/` (블로그 + Syncthing + CouchDB), `homarr/` (Homarr + Valkey), `snapotter/` (SnapOtter + Valkey),
  `shlink/` (backend + web), `ai-stack/` (Ollama + Open WebUI).
- 여러 앱이 함께 쓰는 DB 는 `database/` (PostgreSQL + MariaDB + CloudBeaver) 에 있습니다. 앱은
  `postgres.database.svc.cluster.local:5432` / `mariadb.database.svc.cluster.local:3306` 으로 접속하고,
  앱별 DB·계정은 [`database/create-db.sql`](database/create-db.sql) 로 만듭니다.

### 파일 이름

| 파일 | 내용 |
|---|---|
| `values.yaml` | 디렉터리의 앱이 Helm 차트 하나뿐일 때의 values |
| `values-<component>.yaml` | 차트가 여러 개이거나 직접 작성한 앱 매니페스트(`<app>.yaml`) 옆에 차트가 붙을 때 (`homarr/values-homarr.yaml` + `values-valkey.yaml`, `shlink/values-backend.yaml` + `values-web.yaml`, `snapotter/snapotter.yaml` + `values-valkey.yaml`) |
| `<app>.yaml` | 직접 작성한 매니페스트 (예: `mealie/mealie.yaml`) |
| `<설명>.yaml` | Helm 차트 옆의 보조 매니페스트 (`cluster-issuer.yaml`, `cloudflare-only.yaml`, `metallb-config.yaml`, `crowdsec-traefik-bouncer.yaml`, `minio-cli.yaml`) |
| `secret.yaml.example` | 그 네임스페이스의 모든 `Secret` 템플릿 (`---` 로 구분한 멀티 문서, 민감값은 `change-me`) |
| `secret-sync.yaml.example` | 그 네임스페이스의 모든 `InfisicalSecret` (멀티 문서) |

- 직접 작성한 매니페스트는 맨 위에 `kind: Namespace` 문서가 있고, 모든 리소스에 `namespace` 를 명시합니다.
- Secret 을 참조하지 않는 앱에는 두 `*.example` 파일이 없습니다.
- 그 밖의 데이터 파일은 원래 이름 그대로 둡니다: `homepage/config/*`, `minio/policy/*`, `database/create-db.sql`,
  `snapotter/docker-compose.yml` (변환할 때 기준으로 삼은 업스트림 원본, 적용 대상 아님).

### 버전 확인 헤더

모든 `values*.yaml`, 매니페스트, `*.example` 맨 위에 헤더가 있습니다. values 는 크게 손보지 않고 마지막 사용 시점 그대로
두었으므로, 다시 쓸 때는 헤더의 버전을 기준으로 최신 차트·이미지와 변경 사항을 확인하세요. 버전을 알 수 없는 항목은
`확인 필요` 로 적혀 있습니다. Helm values 헤더 예시:

```yaml
# =====================================================================
# Traefik — Helm values
# Chart     : traefik/traefik (https://traefik.github.io/charts)
# Repo      : helm repo add traefik https://traefik.github.io/charts
# Version   : chart 40.2.0 / app v3.7.1 (마지막 사용 기준)
# Namespace : traefik
# Install   : helm upgrade --install traefik traefik/traefik -n traefik --create-namespace -f values.yaml
# ⚠️ 마지막 사용 시점 기준 설정입니다. 다음에 사용할 때는 차트/앱 최신 버전과
#    values 키 변경(Breaking Changes) 여부를 반드시 확인하세요.
# =====================================================================
```

- `Repo` 줄은 그 차트 저장소를 등록하는 명령입니다 (별칭은 마지막 사용 당시 등록해 둔 이름 그대로). OCI 차트는 `Repo` 줄 없이
  `Chart` / `Install` 줄에 `oci://` 주소가 적혀 있습니다. 전체 목록은 아래 [Helm 저장소](#helm-저장소) 를 참고하세요.
- 매니페스트 헤더에는 `Images` / `Namespace` / `Apply`, `*.example` 헤더에는 적용 방법이 적혀 있습니다.
- 헤더의 추가 설명(Secret·DB 참조, 원본 차트 주석 등)은 ⚠️ 줄 앞에 두고, ⚠️ 줄 뒤에 덧붙일 때는 `# ----` 구분선 다음에 적습니다.
- 헤더의 `Install` / `Apply` 줄은 해당 디렉터리 안에서 실행하는 기준입니다.
- JSON·CSS·JS 와 앱 설정 데이터 파일(`homepage/config/*`, `minio/policy/*`)에는 헤더가 없습니다.

### 비밀 값은 `change-me`

- 커밋되는 모든 파일(values, 매니페스트, `*.example`, 주석 포함)의 비밀번호·토큰·API 키·웹훅 URL·세션/암호화 키 등은 `change-me` 입니다.
- 연결 문자열은 자격 증명 부분만 바꿨습니다: `postgresql://app:change-me@postgres.database.svc.cluster.local:5432/app`
- Secret 이름, 키 이름, `existingSecret` 같은 **참조**는 그대로 두었습니다.
- 실제 값은 Infisical 이나 커밋하지 않는 `secret.yaml` 에만 둡니다.

### Infisical 연동

- `secret-sync.yaml.example` 의 `InfisicalSecret` 은 Infisical 프로젝트(`projectSlug`, env `prod`, path `/`)의 값을
  같은 이름의 Kubernetes Secret 으로 60초마다 동기화합니다 (Infisical secrets-operator 필요, hostAPI `https://infisical.techbara.dev/api`).
- 모든 `InfisicalSecret` 은 `infisical` 네임스페이스의 `infisical-auth-token`(Universal Auth `clientId` / `clientSecret`)으로 인증합니다.
  이 Secret 은 부트스트랩용이라 항상 수동으로 만듭니다 → [`infisical/secret.yaml.example`](infisical/secret.yaml.example)
- 일부 Secret 은 다른 네임스페이스로 복제(fan-out)됩니다:
  `brevo-secret`(SMTP) → karakeep · vaultwarden · yuvomi · mealie ([`infisical/`](infisical/)),
  `minio-secret` → minio · wordpress · karakeep ([`minio/`](minio/)).
  `resend-secret`(→ karakeep) 동기화도 남아 있지만 이 값을 읽는 설정은 없습니다.
- 표준 형식은 [`docs/templates/secret-sync.yaml.example`](docs/templates/secret-sync.yaml.example) 를 참고하세요.

### 도메인 · Traefik 미들웨어

- 도메인은 `*.techbara.dev` (Cloudflare DNS·프록시)입니다. TLS 는 cert-manager ClusterIssuer `letsencrypt-cloudflare` (DNS-01) 로 발급합니다.
- Ingress 는 `ingressClassName: traefik` 과 `cert-manager.io/cluster-issuer: letsencrypt-cloudflare` 어노테이션을 씁니다.
  단 `mealie` · `yuvomi` · `pingvin-share-x` 의 Ingress 는 `ingressClassName` 없이 Traefik 기본 IngressClass 에 의존합니다 (마지막 사용 그대로 — 재사용 시 추가 권장).
- Traefik Middleware 는 모두 `traefik` 네임스페이스에 있고, `traefik.ingress.kubernetes.io/router.middlewares` 어노테이션에
  `<ns>-<이름>@kubernetescrd` 형식으로 지정합니다:

  | 참조 | 역할 |
  |---|---|
  | `traefik-cloudflare-only@kubernetescrd` | Cloudflare IP 대역 + 내부망(`192.168.0.0/16`)만 허용 |
  | `traefik-crowdsec-bouncer@kubernetescrd` | CrowdSec bouncer 로 차단 대상 IP 거부 |
  | `traefik-authentik-forwardauth@kubernetescrd` | Authentik SSO (forwardAuth) |

## 사용 방법

### Helm 으로 배포하는 디렉터리

```bash
# 헤더의 Repo 줄에 있는 저장소 등록 (OCI 차트는 등록 없이 oci:// 주소로 바로 설치)
helm repo add traefik https://traefik.github.io/charts
helm repo update

# 최신 버전 확인 → 헤더의 버전과 비교해 변경 사항(Breaking Changes) 검토
helm search repo traefik/traefik --versions | head

# 렌더링 확인 후 설치 (마지막 사용 버전을 그대로 쓰려면 --version <헤더의 chart 버전> 추가)
helm template traefik traefik/traefik -n traefik -f traefik/values.yaml
helm upgrade --install traefik traefik/traefik -n traefik --create-namespace -f traefik/values.yaml
```

### Helm 저장소

헤더의 `Repo` 줄을 모은 목록입니다. 별칭은 마지막 사용 당시 등록해 둔 이름 그대로입니다.

```bash
# 플랫폼 · 보안
helm repo add metallb https://metallb.github.io/metallb
helm repo add traefik https://traefik.github.io/charts
helm repo add jetstack https://charts.jetstack.io
helm repo add longhorn https://charts.longhorn.io
helm repo add infisical-helm-charts https://dl.cloudsmith.io/public/infisical/helm-charts/helm/charts/
helm repo add crowdsec https://crowdsecurity.github.io/helm-charts
helm repo add goauthentik https://charts.goauthentik.io/
# 데이터베이스 · 애플리케이션
helm repo add helmforge https://repo.helmforge.dev
helm repo add avisto https://avistotelecom.github.io/charts/
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add christianhuth https://charts.christianhuth.de
helm repo add k8s-home-lab https://k8s-home-lab.github.io/helm-charts/
helm repo add couchdb https://apache.github.io/couchdb-helm
# 로컬 저장소 목록에 기록이 없던 차트 — 각 프로젝트의 공식 저장소 주소
helm repo add keel https://charts.keel.sh
helm repo add headlamp https://kubernetes-sigs.github.io/headlamp/
helm repo add uptime-kuma https://helm.irsigler.cloud
helm repo update
```

- OCI 차트는 `helm repo add` 없이 `oci://` 주소로 설치합니다:
  `kube-prometheus-stack/` (`oci://ghcr.io/prometheus-community/charts/kube-prometheus-stack`),
  `paperless-ngx/` (`oci://ghcr.io/alexmorbo/helm-charts/paperless-ngx`), `forgejo/` (`oci://code.forgejo.org/forgejo-helm/forgejo`).

### 직접 작성한 매니페스트

```bash
kubectl apply --dry-run=client -f mealie/mealie.yaml   # 문법·스키마 검증 (kubectl 이 접속할 클러스터 필요)
kubectl apply -f mealie/mealie.yaml                    # Namespace 포함
```

Helm 차트 옆의 보조 매니페스트(`metallb-config.yaml`, traefik 미들웨어, `cluster-issuer.yaml` 등)는 CRD 가 필요하므로 차트를 설치한 뒤에 적용합니다.

### Secret

| 방법 | 순서 |
|---|---|
| 1) Infisical | Infisical 에 프로젝트(`projectSlug`)와 `prod` 환경, 키 등록 → `kubectl apply -f <dir>/secret-sync.yaml.example` |
| 2) 수동 | `cp <dir>/secret.yaml.example <dir>/secret.yaml` → `change-me` 를 실제 값으로 수정 → `kubectl apply -f <dir>/secret.yaml` |

- Secret 은 네임스페이스가 있어야 만들 수 있습니다. Helm 앱은 `kubectl create namespace <ns>` → Secret → `helm upgrade --install`,
  매니페스트 앱은 `<app>.yaml`(Namespace 포함) → Secret 순서로 적용합니다.
- 두 방법을 섞지 마세요. secret-sync 가 동작 중일 때 템플릿을 적용하면 다음 동기화(최대 60초)까지 실제 값이 덮어써집니다.
- 값을 채운 `secret.yaml` / `secret-sync.yaml` 은 `.gitignore` 로 제외됩니다. 절대 커밋하지 마세요.
- `kubectl apply -f <디렉터리>` 는 `*.example` 을 건너뜁니다. 파일 단위로 적용하세요.

### 처음부터 다시 구축할 때 (부트스트랩 순서)

1. **metallb** — 차트 기본값으로 설치 → `metallb-config.yaml`
2. **traefik** — `values.yaml` → 미들웨어 `cloudflare-only.yaml`, `crowdsec-forwardauth.yaml`, `authentik-forwardauth.yaml`
3. **cert-manager** — `values.yaml` → `cert-manager-secret`(Cloudflare API 토큰) → `cluster-issuer.yaml`
4. **longhorn**
5. **database** — `postgres-secret` / `mariadb-secret` → PostgreSQL · MariaDB (· CloudBeaver) → 앱별 DB·계정은 `create-db.sql`
6. **infisical** — `infisical-secret` 수동 생성 → infisical-standalone → Infisical 에서 Universal Auth 머신 아이덴티티 발급
   → `infisical-auth-token` 수동 생성 → secrets-operator
7. **crowdsec / authentik** — 각 Secret → Helm 설치 → `crowdsec/crowdsec-traefik-bouncer.yaml`
8. **애플리케이션** — Cloudflare DNS 레코드 → Secret → Helm 또는 매니페스트

- Infisical·Authentik·CrowdSec 은 외부 PostgreSQL 을 쓰므로 `database` 를 먼저 올립니다.
- Infisical 이 준비되기 전 단계(1–6)의 Secret 은 방법 2(수동)로 만들고, 그 뒤로는 secret-sync 로 넘어갈 수 있습니다.
- traefik 의 `crowdsec-bouncer` / `authentik-forwardauth` 미들웨어는 7단계가 끝나야 동작합니다.

## 디렉터리 목록

유형: **Helm** = Helm 차트로 설치, **Manifest** = 직접 작성한 매니페스트만 적용, **Helm+Manifest** = Helm 차트 + 매니페스트
(`metallb/` 는 values 파일 없이 차트 기본값으로 설치). 버전은 각 파일 헤더 기준이며, 공개 호스트는 모두 `*.techbara.dev` 입니다.

### 플랫폼

| 디렉터리 | Namespace | 유형 | 구성 요소 | 차트·이미지 (마지막 사용 버전) | 비고 |
|---|---|---|---|---|---|
| [`metallb/`](metallb/) | `metallb-system` | Helm+Manifest | MetalLB (차트 기본값, values 파일 없음) · IPAddressPool `local-ip-pool` · L2Advertisement | `metallb/metallb` 0.16.1 (app v0.16.1) | IP 풀 `192.168.50.210-192.168.50.250` |
| [`traefik/`](traefik/) | `traefik` | Helm+Manifest | Traefik Ingress Controller (DaemonSet, hostNetwork) · Middleware `cloudflare-only` · `crowdsec-bouncer` · `authentik-forwardauth` | `traefik/traefik` 40.2.0 (app v3.7.1) | LoadBalancer `192.168.50.210` |
| [`cert-manager/`](cert-manager/) | `cert-manager` | Helm+Manifest | cert-manager · ClusterIssuer `letsencrypt-cloudflare` (Let's Encrypt, DNS-01) | `jetstack/cert-manager` v1.20.2 (app v1.20.2) | Secret `cert-manager-secret` (Cloudflare API 토큰) |
| [`longhorn/`](longhorn/) | `longhorn-system` | Helm | Longhorn 블록 스토리지 (복제본 1, reclaimPolicy Retain) · UI Ingress | `longhorn/longhorn` 1.12.0 (app v1.12.0) | `longhorn.techbara.dev`, 데이터 경로 `/data/longhorn` |
| [`keel/`](keel/) | `kube-system` | Helm | Keel 이미지 자동 업데이트 (1시간 폴링, Discord 알림) | `keel/keel` 확인 필요 (`ghcr.io/keel-hq/keel:latest`) | 디렉터리명 예외. Discord webhook URL 은 `change-me` |
| [`headlamp/`](headlamp/) | `headlamp` | Helm | Headlamp (Kubernetes 웹 UI) | `headlamp/headlamp` 확인 필요 | 차트 기본값 기반. Ingress 없음(ClusterIP), ServiceAccount 에 `cluster-admin` |

### 보안 · 인증 · 시크릿

| 디렉터리 | Namespace | 유형 | 구성 요소 | 차트·이미지 (마지막 사용 버전) | 비고 |
|---|---|---|---|---|---|
| [`infisical/`](infisical/) | `infisical` | Helm | Infisical (내장 Redis) · secrets-operator (별도 차트, 기본값) | `infisical-helm-charts/infisical-standalone` 1.9.0 (app v0.158.0) · `infisical-helm-charts/secrets-operator` 0.11.0 (app v0.11.0) | `infisical.techbara.dev`. 외부 PostgreSQL 사용. `infisical-auth-token` 보관, `brevo-secret` · `resend-secret` fan-out |
| [`crowdsec/`](crowdsec/) | `crowdsec` | Helm+Manifest | CrowdSec LAPI · agent (Traefik 로그 수집) · Traefik bouncer | `crowdsec/crowdsec` 0.24.0 (app v1.7.8) · `fbonalair/traefik-crowdsec-bouncer:latest` | DB: 공유 PostgreSQL (`crowdsec_db`) |
| [`authentik/`](authentik/) | `authentik` | Helm | Authentik server · worker (SSO) | `goauthentik/authentik` 2026.5.3 (app 2026.5.3) | `auth.techbara.dev`. DB: 공유 PostgreSQL |

### 데이터베이스

| 디렉터리 | Namespace | 유형 | 구성 요소 | 차트·이미지 (마지막 사용 버전) | 비고 |
|---|---|---|---|---|---|
| [`database/`](database/) | `database` | Helm | 공유 PostgreSQL (`postgres`) · 공유 MariaDB (`mariadb`) · CloudBeaver (웹 DB GUI) · `create-db.sql` | `helmforge/postgresql` 2.0.4 (PostgreSQL 18.4) · `helmforge/mariadb` 2.0.3 (MariaDB 12.3.2) · `avisto/cloudbeaver` 1.1.5 (app 26.1.0) | `beaver.techbara.dev`. 여러 앱이 함께 쓰는 DB 네임스페이스 |
| [`minio/`](minio/) | `minio` | Helm+Manifest | MinIO (S3 API + 콘솔) · mc 관리 파드 · 버킷 정책 스크립트 (`policy/`) | `bitnami/minio` 17.0.21 (app 2025.7.23, 실제 이미지는 `bitnamilegacy/minio*:latest`) | `s3.techbara.dev`, `minio.techbara.dev`. `minio-secret` fan-out (wordpress · karakeep) |

### 모니터링

| 디렉터리 | Namespace | 유형 | 구성 요소 | 차트·이미지 (마지막 사용 버전) | 비고 |
|---|---|---|---|---|---|
| [`kube-prometheus-stack/`](kube-prometheus-stack/) | `kube-prometheus-stack` | Helm | Prometheus · Alertmanager · Grafana · node-exporter · kube-state-metrics | `oci://ghcr.io/prometheus-community/charts/kube-prometheus-stack` 86.2.3 (app v0.91.0) | `grafana.techbara.dev`. Grafana 관리자 계정은 `grafana-secret` |
| [`uptime-kuma/`](uptime-kuma/) | `uptime-kuma` | Helm | Uptime Kuma | `uptime-kuma/uptime-kuma` 확인 필요 (app 2.3.0) | `kuma.techbara.dev` |
| [`scrutiny/`](scrutiny/) | `scrutiny` | Manifest | Scrutiny omnibus (디스크 S.M.A.R.T. 모니터링: web + collector + InfluxDB) | `ghcr.io/analogj/scrutiny:master-omnibus` | `scrutiny.techbara.dev`. privileged + hostPath `/dev/nvme0`, `/dev/nvme1` |
| [`diun/`](diun/) | `diun` | Manifest | Diun (이미지 업데이트 알림, Discord) · ClusterRole | `crazymax/diun:latest` | `diun.enable` 어노테이션이 붙은 워크로드만 감시 |

### 애플리케이션

| 디렉터리 | Namespace | 유형 | 구성 요소 | 차트·이미지 (마지막 사용 버전) | 비고 |
|---|---|---|---|---|---|
| [`vaultwarden/`](vaultwarden/) | `vaultwarden` | Helm | Vaultwarden (비밀번호 관리) | `helmforge/vaultwarden` 1.12.10 (app 1.37.0) | `vault.techbara.dev`. DB: 공유 PostgreSQL. SMTP: `brevo-secret` |
| [`n8n/`](n8n/) | `n8n` | Helm | n8n (워크플로 자동화) · 외부 task runner | `helmforge/n8n` 1.6.3 (app 2.26.4) | `n8n.techbara.dev`. DB: 공유 PostgreSQL |
| [`karakeep/`](karakeep/) | `karakeep` | Helm | Karakeep (북마크 관리) · Meilisearch · Chromium | `helmforge/karakeep` 1.2.6 (app 0.32.0) | `karakeep.techbara.dev`. SQLite (Longhorn PVC). SMTP: `brevo-secret` |
| [`wordpress/`](wordpress/) | `wordpress` | Helm | WordPress (Apache) | `helmforge/wordpress` 2.1.0 (app 7.0.0) | `www.techbara.dev`. DB: 공유 MariaDB. 백업(MinIO S3)은 비활성 |
| [`umami/`](umami/) | `umami` | Helm | Umami (웹 분석) | `helmforge/umami` 2.2.0 (app 3.1.0) | `umami.techbara.dev`. DB: 공유 PostgreSQL |
| [`paperless-ngx/`](paperless-ngx/) | `paperless-ngx` | Helm | Paperless-ngx (문서 관리) · Flower · Tika · Gotenberg · 내장 Valkey | `oci://ghcr.io/alexmorbo/helm-charts/paperless-ngx` 0.2.0 (app 2.20.5) | `paper.techbara.dev`, `flower.techbara.dev`. DB: 공유 PostgreSQL |
| [`shlink/`](shlink/) | `shlink` | Helm | Shlink backend (URL 단축) · Shlink web client | `christianhuth/shlink-backend` 11.7.4 (app 5.1.3) · `christianhuth/shlink-web` 1.12.1 (app 4.7.1) | `link.techbara.dev`, `shlink.techbara.dev`. DB: 공유 PostgreSQL |
| [`homarr/`](homarr/) | `homarr` | Helm | Homarr (대시보드) · Valkey (캐시) | `helmforge/homarr` 1.1.16 (app v1.64.0) · `helmforge/valkey` 1.0.1 (app 9.1.0) | `home.techbara.dev`. DB: 공유 PostgreSQL. Valkey 먼저 설치 |
| [`hoppscotch/`](hoppscotch/) | `hoppscotch` | Helm | Hoppscotch AIO (API 개발 도구) | `helmforge/hoppscotch` 1.1.4 (app 2026.5.0) | `hoppscotch.techbara.dev`. DB: 공유 PostgreSQL |
| [`changedetection/`](changedetection/) | `changedetection` | Helm | changedetection.io (웹페이지 변경 감지) | `helmforge/changedetection` 1.1.9 추정, 확인 필요 (app 0.55.5) | `change.techbara.dev` |
| [`adguard/`](adguard/) | `adguard` | Helm | AdGuard Home (DNS 광고 차단) | `helmforge/adguard-home` 1.4.11 (app v0.107.77) | Ingress 없음. MetalLB `192.168.50.212` (web 80 / DNS 53). dns 서비스의 `loadBalancerIP: 192.168.50.211` 과 어긋나므로 사용 전 확인 |
| [`forgejo/`](forgejo/) | `forgejo` | Helm | Forgejo (Git 서버, rootless) | `oci://code.forgejo.org/forgejo-helm/forgejo` 17.1.3 (app 15.0.5) | `git.techbara.dev`. DB: 공유 PostgreSQL. 관리자·DB 비밀번호(`change-me`)는 설치 시 교체 |
| [`mealie/`](mealie/) | `mealie` | Manifest | Mealie (레시피 관리) | `ghcr.io/mealie-recipes/mealie:v3.21.0` | `mealie.techbara.dev`. DB: 공유 PostgreSQL. SMTP: `brevo-secret` |
| [`yuvomi/`](yuvomi/) | `yuvomi` | Manifest | Yuvomi (SQLite) | `ghcr.io/ulsklyc/yuvomi:latest` | `family.techbara.dev`. SMTP: `brevo-secret` |
| [`pingvin-share-x/`](pingvin-share-x/) | `pingvin-share-x` | Manifest | Pingvin Share X (파일 공유) · ClamAV (바이러스 검사) | `smp46/pingvin-share-x:v1.21.2` · `clamav/clamav:latest` | `share.techbara.dev`. PVC 500Gi |
| [`it-tools/`](it-tools/) | `it-tools` | Manifest | IT-Tools (개발자 도구 모음) | `ghcr.io/sharevb/it-tools:latest` | `tools.techbara.dev` |
| [`ai-stack/`](ai-stack/) | `ai-stack` | Manifest | Ollama · Open WebUI | `docker.io/ollama/ollama:latest` · `ghcr.io/open-webui/open-webui:main` | `ai.techbara.dev`. Ollama 모델은 hostPath `/var/local/k3s-hostpath/ollama` |
| [`filebrowser/`](filebrowser/) | `filebrowser` | Manifest | File Browser (웹 파일 관리) | `filebrowser/filebrowser:latest` | `drive.techbara.dev`. 데이터는 hostPath `/data/filebrowser` |
| [`snapotter/`](snapotter/) | `snapotter` | Helm+Manifest | SnapOtter (docker-compose 를 변환한 매니페스트) · Valkey · `docker-compose.yml` (업스트림 참고용) | `docker.io/snapotter/snapotter:2.2.0` · `helmforge/valkey` 1.0.1 (app 9.1.0) | `snapotter.techbara.dev`. DB: 공유 PostgreSQL. `values-valkey.yaml` 헤더의 auth 주의사항 확인 |
| [`quartz/`](quartz/) | `quartz` | Helm+Manifest | Quartz 블로그 (Nginx 정적 호스팅) · Syncthing (Obsidian vault 동기화) · CouchDB | `nginx:stable-alpine` · `k8s-home-lab/syncthing` 5.1.2 (이미지 `lscr.io/linuxserver/syncthing:2.1.0`) · `couchdb/couchdb` 4.6.3 (app 3.5.1) | `wiki` · `sync` · `couchdb.techbara.dev`. 콘텐츠와 vault 는 hostPath. CouchDB 는 PV 비활성(emptyDir) |
| [`homepage/`](homepage/) | `homepage` | Manifest | Homepage 대시보드 · `config/` (services · widgets · bookmarks 등) | `ghcr.io/gethomepage/homepage:latest` | `home.techbara.dev` (homarr 와 같은 호스트라 함께 배포하면 충돌). `config/` 는 hostPath 로 마운트 |

> [`docs/templates/`](docs/templates/README.md) 는 서비스 디렉터리가 아니라 스캐폴드입니다. docker-compose 만 제공하는 앱을
> 위 규칙(`<app>.yaml` + `secret.yaml.example` + `secret-sync.yaml.example`)에 맞게 옮길 때 복사해서 씁니다.

## 보안

- 저장소의 모든 민감값은 `change-me` 입니다. 실제 값은 Infisical 또는 커밋하지 않는 로컬 파일에만 둡니다.
- `.gitignore` 가 `*.env` 와, `*.example` 을 복사해 값을 채운 `secret.yaml` / `secret-sync.yaml` 을 제외합니다.
- 커밋 훅(husky)은 제거했습니다. 커밋 전에 `gitleaks protect --staged --verbose`
  (또는 `gitleaks detect --source . --no-git`)를 직접 실행해 확인하세요 (gitleaks 는 별도 설치 필요).

## 관련 문서

- [`docs/INFRASTRUCTURE.md`](docs/INFRASTRUCTURE.md) — 아키텍처, 플랫폼 구성, 최종 라이브 스냅샷
- [`docs/templates/README.md`](docs/templates/README.md) — docker-compose → Kubernetes 스캐폴드
- [`AGENTS.md`](AGENTS.md) — 에이전트·기여자용 가이드 (`CLAUDE.md` 가 import)
