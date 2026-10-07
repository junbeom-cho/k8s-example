# INFRASTRUCTURE.md

> [!IMPORTANT]
> **운영 종료 · 아카이브 문서** — 이 클러스터는 더 이상 운영하지 않습니다. 이 문서는 **최종 라이브 스냅샷(2026-07-21)** 과
> 저장소의 최종 구조를 기록한 것입니다. 다시 사용할 때는 각 파일 헤더의 버전을 기준으로 최신 차트·이미지와
> 변경 사항(Breaking Changes)을 반드시 확인하세요.
> 저장소 규칙·사용법·디렉터리 목록은 [`../README.md`](../README.md), 에이전트용 가이드는 [`../AGENTS.md`](../AGENTS.md) 를 참고하세요.

---

## 1. 한눈에 보기

- **무엇**: 단일 노드 홈서버에서 돌리던 **K3s** 클러스터의 선언형 배포 설정 모음. 자동 동기화나 CI/CD 없이 서비스별로 `kubectl` / `helm` 으로 직접 적용했습니다.
- **노드** (2026-07-21 기준): `techbara-server` / `192.168.50.200` / Ubuntu 24.04.4 / K3s `v1.35.5+k3s1` / 단일 control-plane 노드.
- **배포 방식**: 서비스마다 Helm values(`values.yaml`, `values-<component>.yaml`) 또는 직접 작성한 매니페스트(`<app>.yaml`).
- **구조**: 최상위 디렉터리 = 네임스페이스 (예외: `longhorn-system`, `metallb-system`, `kube-system`). → [3장](#3-저장소-디렉터리-구조-최종)
- **비밀 관리**: Infisical(self-hosted) + secrets-operator. 저장소에는 `secret.yaml.example` / `secret-sync.yaml.example` 템플릿만 있고 민감값은 모두 `change-me` 입니다. → [5장](#5-비밀-관리-infisical)
- **도메인**: `*.techbara.dev` (Cloudflare DNS·프록시, DNS-01 인증서). 예전 도메인 `junbeom.work` 를 가리키던 참조는 모두 `techbara.dev` 로 정리했습니다.

---

## 2. 아키텍처 개요

```
Internet ──> Cloudflare (DNS + proxy, DNS-01 ACME)
                  │
                  ▼
        MetalLB L2 (192.168.50.210-250)
                  │  192.168.50.210
                  ▼
        Traefik (IngressController, ingressClassName: traefik)
          │  ├─ Middleware: cloudflare-only (Cloudflare IP + 내부망만 허용)
          │  ├─ Middleware: authentik-forwardauth (SSO)
          │  └─ Middleware: crowdsec-bouncer (WAF/IP ban)
          ▼
    각 네임스페이스의 Service ──> Pod
                  │
                  ▼
        Longhorn (분산 블록 스토리지, PVC)
```

**핵심 플랫폼 컴포넌트** (버전은 2026-07-21 라이브 기준)

| 역할 | 구현체 | 네임스페이스 | 디렉터리 | 비고 |
|---|---|---|---|---|
| Ingress / TLS 종단 | **Traefik** v3.7.1 | `traefik` | [`traefik/`](../traefik/) | `LoadBalancer` @ `192.168.50.210`, `ingressClassName: traefik` |
| LoadBalancer IP 할당 | **MetalLB** v0.16.1 (L2) | `metallb-system` | [`metallb/`](../metallb/) | IP 풀 `192.168.50.210-250` |
| 인증서 발급 | **cert-manager** v1.20.2 | `cert-manager` | [`cert-manager/`](../cert-manager/) | ClusterIssuer `letsencrypt-cloudflare` (DNS-01 / Cloudflare API token) |
| 스토리지 | **Longhorn** v1.12.0 | `longhorn-system` | [`longhorn/`](../longhorn/) | 기본 SC `longhorn` (ReclaimPolicy **Retain**) |
| 비밀 관리 | **Infisical** (infisical-standalone 1.9.0) + secrets-operator v0.11.0 | `infisical` | [`infisical/`](../infisical/) | `InfisicalSecret` CRD로 K8s Secret 동기화 |
| SSO / 인증 | **Authentik** 2026.5.3 | `authentik` | [`authentik/`](../authentik/) | Traefik forwardAuth 미들웨어로 연동 |
| 침입 차단 | **CrowdSec** v1.7.8 + Traefik bouncer | `crowdsec` | [`crowdsec/`](../crowdsec/) | |
| 모니터링 | **kube-prometheus-stack** 86.2.3 (app v0.91.0) | `kube-prometheus-stack` | [`kube-prometheus-stack/`](../kube-prometheus-stack/) | Prometheus + Alertmanager + Grafana |
| 이미지 자동 갱신 | **Keel** | `kube-system` | [`keel/`](../keel/) | 스냅샷 시점에는 미배포로 보임 (저장소에 설정만 존재) |

---

## 3. 저장소 디렉터리 구조 (최종)

```
server-k3s/
├── README.md              # 저장소 규칙 · 사용법 · 디렉터리 목록
├── AGENTS.md / CLAUDE.md  # 에이전트·기여자 가이드 (CLAUDE.md 가 AGENTS.md 를 import)
├── docs/
│   ├── INFRASTRUCTURE.md  # (이 문서) 아키텍처 · 최종 스냅샷
│   └── templates/         # docker-compose → K8s 스캐폴드 (네임스페이스 아님)
│
├── metallb/  traefik/  cert-manager/  longhorn/  keel/  headlamp/          # 플랫폼
├── infisical/  crowdsec/  authentik/                                       # 보안 · 인증 · 시크릿
├── database/  minio/                                                       # 공유 데이터
├── kube-prometheus-stack/  uptime-kuma/  scrutiny/  diun/                  # 모니터링
└── vaultwarden/  n8n/  karakeep/  wordpress/  umami/  paperless-ngx/       # 애플리케이션
    shlink/  homarr/  hoppscotch/  changedetection/  adguard/  forgejo/
    mealie/  yuvomi/  pingvin-share-x/  it-tools/  ai-stack/  filebrowser/
    snapotter/  quartz/  homepage/
```

- **디렉터리 = 네임스페이스**: 최상위 서비스 디렉터리 하나가 네임스페이스 하나이고 이름이 같습니다.
  예외는 업스트림이 정해 둔 네임스페이스를 쓰는 `longhorn/` → `longhorn-system`, `metallb/` → `metallb-system`, `keel/` → `kube-system` 뿐입니다.
- **관련 컴포넌트는 한 디렉터리에**: 앱 전용 DB·캐시는 앱과 같은 디렉터리에 두고(`quartz/`, `homarr/`, `snapotter/`, `shlink/`, `ai-stack/`),
  여러 앱이 함께 쓰는 PostgreSQL · MariaDB 는 `database/` 에 둡니다.

**서비스 디렉터리 구성**

| 파일 | 내용 |
|---|---|
| `values.yaml` / `values-<component>.yaml` | Helm 릴리스 values (차트가 하나면 `values.yaml`, 여럿이거나 직접 작성한 앱 매니페스트(`<app>.yaml`) 옆에 붙으면 컴포넌트별) |
| `<app>.yaml` | 직접 작성한 매니페스트 (맨 위 `kind: Namespace` 포함) |
| `<설명>.yaml` | Helm 차트 옆 보조 매니페스트 (`cluster-issuer.yaml`, `metallb-config.yaml` 등) |
| `secret.yaml.example` | 네임스페이스의 모든 Secret 템플릿 (민감값 `change-me`) |
| `secret-sync.yaml.example` | 네임스페이스의 모든 `InfisicalSecret` |

디렉터리별 구성 요소와 마지막 사용 버전은 README 의 [디렉터리 목록](../README.md#디렉터리-목록) 표를 참고하세요.

---

## 4. 최종 라이브 스냅샷 (2026-07-21)

> 2026-07-21 에 실제 클러스터에서 확인한 상태입니다. 그 뒤 저장소에 추가된 설정(예: `headlamp/`, `snapotter/`, `forgejo/`)은 여기에 없습니다.
> 네임스페이스는 저장소 최종 이름으로 적었습니다 (스냅샷 당시 이름이 달랐던 것: `kube-prometheus-stack` ← `grafana`, `pingvin-share-x` ← `pingvin-share`).

### Helm 릴리스

| 릴리스 | 네임스페이스 | 차트 / 버전 | 저장소 파일 |
|---|---|---|---|
| traefik | traefik | traefik-40.2.0 (v3.7.1) | `traefik/values.yaml` |
| cert-manager | cert-manager | v1.20.2 | `cert-manager/values.yaml` |
| longhorn | longhorn-system | 1.12.0 | `longhorn/values.yaml` |
| metallb | metallb-system | 0.16.1 | values 없음 (차트 기본값) + `metallb/metallb-config.yaml` |
| infisical | infisical | infisical-standalone-1.9.0 | `infisical/values.yaml` |
| secrets-operator | infisical | v0.11.0 | values 없음 (차트 기본값) |
| authentik | authentik | 2026.5.3 | `authentik/values.yaml` |
| crowdsec | crowdsec | 0.24.0 | `crowdsec/values.yaml` |
| kube-prometheus-stack | kube-prometheus-stack | 86.2.3 | `kube-prometheus-stack/values.yaml` |
| postgres | database | postgresql-2.0.4 (PG 18) | `database/values-postgresql.yaml` |
| mariadb | database | mariadb-2.0.3 (12.3.2) | `database/values-mariadb.yaml` |
| cloudbeaver | database | 1.1.5 | `database/values-cloudbeaver.yaml` |
| vaultwarden | vaultwarden | 1.12.8 (2026-07-30 에 1.12.10 으로 업그레이드, 이미지 1.37.0) | `vaultwarden/values.yaml` |
| n8n | n8n | 1.6.3 | `n8n/values.yaml` |
| mealie | mealie | (helm, 차트 미기록) | 저장소에는 직접 작성 매니페스트 `mealie/mealie.yaml` 만 있음 |
| wordpress | wordpress | 2.1.0 | `wordpress/values.yaml` |
| karakeep | karakeep | 1.2.6 | `karakeep/values.yaml` |
| paperless-ngx | paperless-ngx | 0.2.0 | `paperless-ngx/values.yaml` |
| shlink-backend / shlink-web | shlink | 11.7.4 / 1.12.1 | `shlink/values-backend.yaml` / `shlink/values-web.yaml` |
| umami | umami | 2.2.0 | `umami/values.yaml` |
| homarr + valkey | homarr | 1.1.16 / 1.0.1 | `homarr/values-homarr.yaml` / `homarr/values-valkey.yaml` |
| syncthing | quartz | 5.1.2 | `quartz/values-syncthing.yaml` |

### Ingress 호스트 (라이브)

`auth`, `vault`, `n8n`, `mealie`, `karakeep`, `paper`, `flower`, `share`, `wiki`,
`sync`, `link`, `shlink`, `umami`, `home`, `grafana`, `longhorn`, `infisical`,
`beaver`, `www`, `family` → 모두 `*.techbara.dev`.

### 스냅샷 당시 미배포로 보이던 것

`adguard`, `ai-stack`, `changedetection`, `filebrowser`, `hoppscotch`, `it-tools`, `minio`,
CouchDB(`quartz/values-couchdb.yaml`), `scrutiny`, `uptime-kuma`, `diun`, `keel`, `homepage`
(정확한 배포 여부는 확인되지 않았습니다).

---

## 5. 비밀 관리 (Infisical)

서비스 디렉터리마다 두 파일이 한 쌍으로 동작합니다.

1. **`secret.yaml.example`** — 그 네임스페이스의 모든 Secret 템플릿 (`---` 로 구분한 멀티 문서). 민감값은 모두 `change-me` 이고, 연결 문자열은 자격 증명 부분만 `change-me` 입니다.
   ```yaml
   apiVersion: v1
   kind: Secret
   metadata:
     name: vaultwarden-secret
     namespace: vaultwarden
   type: Opaque
   stringData:
     ADMIN_TOKEN: 'change-me'
     DATABASE_URL: 'postgresql://vaultwarden:change-me@postgres.database.svc.cluster.local:5432/vaultwarden'
   ```
2. **`secret-sync.yaml.example`** — `InfisicalSecret` CRD. Infisical 프로젝트의 실제 값을 위 Secret 으로 60초마다 동기화합니다.
   ```yaml
   apiVersion: secrets.infisical.com/v1alpha1
   kind: InfisicalSecret
   metadata:
     name: vaultwarden-secret-sync
     namespace: vaultwarden
   spec:
     hostAPI: https://infisical.techbara.dev/api
     resyncInterval: 60
     authentication:
       universalAuth:
         secretsScope:
           projectSlug: "vaultwarden"
           envSlug: "prod"
           secretsPath: "/"
         credentialsRef:
           secretName: infisical-auth-token
           secretNamespace: infisical
     managedKubeSecretReferences:
       - secretName: vaultwarden-secret
         secretNamespace: vaultwarden
         secretType: Opaque
   ```

- **인증 토큰**: 모든 `InfisicalSecret` 은 `infisical` 네임스페이스의 `infisical-auth-token` (Universal Auth `clientId` / `clientSecret`)을 참조합니다.
  부트스트랩용 자격 증명이라 항상 수동으로 만듭니다 → [`infisical/secret.yaml.example`](../infisical/secret.yaml.example)
- **적용 방법**: Infisical 로 동기화하거나(`kubectl apply -f secret-sync.yaml.example`), `secret.yaml.example` 을 `secret.yaml` 로 복사해 값을 채운 뒤 직접 적용합니다. 두 방법을 섞으면 동기화 주기마다 값이 덮어써집니다.
- **네임스페이스 간 복제(fan-out)**: `brevo-secret` → karakeep · vaultwarden · yuvomi · mealie (`infisical/`),
  `minio-secret` → minio · wordpress · karakeep (`minio/`). `resend-secret` → karakeep 동기화도 남아 있지만 이 값을 읽는 설정은 없습니다.
- **SMTP**: 마지막 설정 기준 메일 발송은 Brevo(`smtp-relay.brevo.com`, `brevo-secret`)를 사용합니다.
- **가드레일**: 커밋 훅(husky)은 제거했습니다. 커밋 전에 `gitleaks protect --staged --verbose` 를 직접 실행해 비밀이 없는지 확인하세요.
  `.gitignore` 는 `*.env` 와 값을 채운 `secret.yaml` / `secret-sync.yaml` 을 제외합니다. **실제 크레덴셜은 git 에 절대 올리지 마세요.**

---

## 6. 재사용 워크플로우

중앙 Makefile/CI 는 없습니다. 서비스 단위로 검증하고 배포합니다.

```bash
# YAML 문법 확인 (클러스터 불필요, *.example 포함)
python3 -c "import yaml,sys; [list(yaml.safe_load_all(open(f))) for f in sys.argv[1:]]" mealie/*.yaml mealie/*.example

# 매니페스트 검증 (kubectl 은 API discovery 를 위해 접속 가능한 클러스터가 필요)
kubectl apply --dry-run=client -f mealie/mealie.yaml

# Helm 렌더 확인 (apply 전 항상)
helm template vaultwarden helmforge/vaultwarden -n vaultwarden -f vaultwarden/values.yaml

# 배포 — 직접 작성한 매니페스트
kubectl apply -f mealie/mealie.yaml

# 배포 — Helm
helm upgrade --install traefik traefik/traefik -n traefik --create-namespace -f traefik/values.yaml
```

**적용 전 체크리스트**: 헤더 버전과 최신 버전 비교, ingress 호스트, Secret 이름·키, `storageClassName`, 참조 PVC, 네임스페이스 = 디렉터리명.
처음부터 다시 구축하는 순서는 README 의 [부트스트랩 순서](../README.md#처음부터-다시-구축할-때-부트스트랩-순서)를 따릅니다.

**커밋 규칙**: `feat:` / `fix:` / `refactor:` / `chore:` / `docs:` prefix + 짧은 명령형 (예: `feat: Add n8n`). 커밋 1개 = 서비스 1개 또는 인프라 변경 1개로 범위를 유지합니다.

---

## 7. 알려진 주의점 (다시 쓸 때)

1. **버전**: 모든 설정이 마지막 사용 시점 기준입니다. `latest` / `main` / `master-omnibus` 처럼 태그를 고정하지 않은 이미지는 그대로 배포하면 예상치 못한 버전이 올라옵니다.
   `bitnamilegacy/*` 이미지(MinIO, Infisical 내장 Redis)는 더 이상 업데이트되지 않는 레거시 저장소입니다.
2. **`확인 필요`**: 기록이 없어 알 수 없는 값은 헤더에 `확인 필요` 로 남아 있습니다. keel · headlamp · uptime-kuma 의 차트 버전(keel · headlamp 는 앱 버전도)과
   changedetection 의 차트 버전(1.1.9 로 추정)이 해당합니다. keel · headlamp · uptime-kuma 는 로컬 저장소 기록도 없어 헤더에 각 프로젝트의 공식 저장소 주소를 적었습니다.
3. **StorageClass 기본값 2개**: `local-path`(k3s 기본)와 `longhorn` 이 **둘 다 `(default)`** 였습니다. 새 PVC 는 `storageClassName: longhorn` 을 명시하세요.
4. **단일 노드**: HA 가 없습니다. 노드가 내려가면 전체가 내려갑니다.
5. **hostPath 의존**: `quartz/` (`/home/techbara/quartz`, `/home/techbara/obsidian-vault`), `ai-stack/` (`/var/local/k3s-hostpath/ollama`),
   `filebrowser/` (`/data/filebrowser`), `homepage/` (`/home/techbara/server-k3s/homepage/config`), `scrutiny/` (`/dev/nvme0`, `/dev/nvme1`) 는 노드에 해당 경로가 있어야 동작합니다.
6. **호스트 충돌**: `homarr/` 와 `homepage/` 가 같은 `home.techbara.dev` 를 씁니다. 하나만 배포하세요.
7. **비밀**: `*.example` 은 `change-me` 템플릿입니다. 값을 채운 파일은 커밋하지 마세요 (커밋 전 gitleaks 로 직접 확인).
8. **shlink-backend** 등 일부 파드는 스냅샷 당시 재시작 횟수가 높았습니다. 다시 쓸 때 DB 연결을 먼저 점검하세요.

---

## 8. 관련 문서

- [`../README.md`](../README.md) — 저장소 규칙, 사용법, 디렉터리 목록 (한국어).
- [`../AGENTS.md`](../AGENTS.md) — 명령어·코딩 규칙·기여 가이드 (에이전트용).
- [`templates/README.md`](templates/README.md) — docker-compose → Kubernetes 스캐폴드.
