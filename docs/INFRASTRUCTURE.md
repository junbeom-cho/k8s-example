# INFRASTRUCTURE.md

> **목적**: 이 문서는 웹 기반 LLM(ChatGPT, Claude.ai 등)이나 새로 합류한 사람이 이 저장소와
> 실제 K3s 클러스터의 상태를 **파일 접근 없이** 이해하고 안전하게 유지보수하도록 돕는 단일 참조 문서입니다.
> 클러스터에 접근할 수 있는 에이전트(Claude Code)는 이 문서 대신/함께 [`../AGENTS.md`](../AGENTS.md)의
> 명령어 규칙을 따르세요.
>
> **최종 확인 기준일**: 2026-07-21 (클러스터 라이브 상태 스냅샷 기준)

---

## 1. 한눈에 보기 (TL;DR)

- **무엇**: 단일 노드 홈서버에서 돌아가는 **K3s** 클러스터의 선언형 배포 설정 모음 (GitOps 스타일이지만 자동 동기화는 없음 — 수동 `kubectl`/`helm` apply).
- **노드**: `techbara-server` / `192.168.50.200` / Ubuntu 24.04.4 / K3s `v1.35.5+k3s1` / 단일 control-plane 노드.
- **배포 방식**: 서비스별로 **Helm `values.yaml`** 또는 **원시 매니페스트(`*.yaml`)** 중 하나. 중앙 CI/CD 없음.
- **비밀 관리**: **Infisical**(self-hosted) + Infisical **secrets-operator**. 저장소의 `*-secret.yaml`은 항상 **placeholder 템플릿**이며, 실제 값은 `*-secret-sync.yaml`(InfisicalSecret CRD)이 런타임에 주입.
- **⚠️ 저장소는 리팩터링 진행 중** — 목표는 **서비스별 폴더 + 서비스별 네임스페이스**. 현행 `apps/`·`core-infra/`·`database/` 그룹형은 **정리(AS-IS) 대상**. 아래 [섹션 3](#3-중요-진행-중인-리팩터링-반드시-먼저-읽기)을 반드시 먼저 읽으세요. 저장소 파일 상태 ≠ 라이브 클러스터 상태.

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
          │  ├─ Middleware: authentik-forwardauth (SSO)
          │  └─ Middleware: crowdsec bouncer (WAF/IP ban)
          ▼
    각 네임스페이스의 Service ──> Pod
                  │
                  ▼
        Longhorn (분산 블록 스토리지, PVC)
```

**핵심 플랫폼 컴포넌트**

| 역할 | 구현체 | 네임스페이스 | 비고 |
|---|---|---|---|
| Ingress / TLS 종단 | **Traefik** v3.7.1 | `traefik` | `LoadBalancer` @ `192.168.50.210`, `ingressClassName: traefik` |
| LoadBalancer IP 할당 | **MetalLB** v0.16.1 (L2) | `metallb-system` | IP 풀 `192.168.50.210-250` |
| 인증서 발급 | **cert-manager** v1.20.2 | `cert-manager` | ClusterIssuer `letsencrypt-cloudflare` (DNS-01 / Cloudflare API token) |
| 스토리지 | **Longhorn** v1.12.0 | `longhorn-system` | 기본 SC `longhorn` (ReclaimPolicy **Retain**) |
| 비밀 관리 | **Infisical** + secrets-operator v0.11.0 | `infisical` | `InfisicalSecret` CRD로 K8s Secret 동기화 |
| SSO / 인증 | **Authentik** 2026.5.3 | `authentik` | Traefik forwardAuth 미들웨어로 연동 |
| 침입 차단 | **CrowdSec** v1.7.8 + Traefik bouncer | `crowdsec` | |
| 모니터링 | **kube-prometheus-stack** (Grafana v0.91.0) | `grafana` | Prometheus + Alertmanager + Grafana |
| 이미지 자동 갱신 | **Keel** (`kube-system/keel/values.yaml`) | `kube-system` | ※ 저장소에 설정만 존재 |

---

## 3. ⚠️ 중요: 진행 중인 리팩터링 (반드시 먼저 읽기)

이 저장소는 **디렉터리·네임스페이스 구조를 서비스별로 되돌리는 리팩터링**이 진행 중입니다. 그 결과 **저장소의 그룹형 파일이 라이브 클러스터를 반영하지 않습니다.** 변경 전 항상 `kubectl`로 실제 상태를 확인하세요.

### 최종 목표(TO-BE) vs 현행(AS-IS)
- **TO-BE (목표)**: **서비스마다 개별 폴더 + 개별 네임스페이스**로 관리 (예: `vaultwarden/` → ns `vaultwarden`, `n8n/` → ns `n8n`).
- **AS-IS (정리 대상)**: `apps/`, `core-infra/`, `database/`, `monitoring/` 로 묶은 **그룹형 폴더 + 그룹 네임스페이스** (`namespace: apps` 36곳, `core-infra` 8곳, `database` 5곳). 이 그룹형 방식은 폐기됩니다.

### 라이브 클러스터는 이미 목표에 더 가까움
- 라이브는 **대부분 서비스별 네임스페이스**로 운영 중: `vaultwarden`, `n8n`, `mealie`, `karakeep`, `traefik`, `authentik`, `wordpress`, `umami`, `shlink`, `paperless-ngx`, `pingvin-share`, `quartz`, `yuvomi`, `homarr`, `infisical`, `crowdsec`, `cert-manager` 등.
- **예외**: `database` 네임스페이스는 아직 그룹형으로 존재 (postgres/mariadb/cloudbeaver 공유). 모니터링은 `grafana` ns 사용.
- `apps` / `core-infra` / `monitoring` 네임스페이스는 **라이브에 존재하지 않습니다** — 즉 저장소의 그룹형 매니페스트(`namespace: apps` 등)는 아직 어디에도 배포되지 않은 미래(폐기 예정) 상태.

### 정리해야 할 작업 (리팩터링 To-Do)
1. 그룹형 폴더(`apps/`, `core-infra/`, `database/`, `monitoring/`) 안 매니페스트를 **서비스별 폴더**로 이동/정리.
2. 파일 내 `namespace: apps|core-infra|database|monitoring` → **해당 서비스 네임스페이스**로 교정.
3. Infisical `*-secret-sync.yaml` 의 `secretNamespace` 와 `credentialsRef.secretNamespace` 도 서비스 네임스페이스에 맞게 교정.

### 도메인
- **현재 사용 도메인(TO-BE)**: `*.techbara.dev`. 라이브 Ingress 21개 전부 이 도메인이며, 파드 env/ConfigMap에도 `junbeom.work` 참조는 **0개**.
- **레거시(정리 대상)**: `*.junbeom.work` — 예전에 쓰던 도메인. 저장소 일부 파일(그룹형 `apps/**`, homepage 설정, Infisical `hostAPI`)에만 남아 있음.
- 저장소에서 `junbeom.work`를 만나면 **`techbara.dev`로 교정**하세요. apply 전 `kubectl get ingress -A` 로 실제 호스트 재확인.
- 부수적: SMTP **Brevo → Resend**, 일부 DB 차트 **Bitnami → HelmForge** (`values-*-bitnami.yaml` / `values-*-helmforge.yaml` 병존).

**유지보수 규칙**: 새 작업은 **서비스별 폴더 + 서비스별 네임스페이스**(TO-BE) 기준으로 작성합니다. 그룹형(`apps/` 등)에는 새 서비스를 추가하지 마세요. apply 전 라이브 네임스페이스/도메인과의 불일치를 반드시 확인하세요.

---

## 4. 저장소 디렉터리 구조 (현행 AS-IS: 그룹형 — 정리 대상)

> 아래는 **현재 존재하는** 그룹형 레이아웃입니다. 목표(TO-BE)는 이 그룹을 풀어 **서비스별 최상위 폴더 + 서비스별 네임스페이스**로 되돌리는 것입니다([섹션 3](#3-중요-진행-중인-리팩터링-반드시-먼저-읽기)). 실제로 최상위에는 이미 서비스별 폴더(`vaultwarden/`, `traefik/`, `n8n/` …)가 다수 존재하며, 이들이 목표 형태에 가깝습니다.

```
server-k3s/
├── AGENTS.md              # 에이전트/기여자용 명령어·규칙 (유지보수 가이드)
├── CLAUDE.md              # Claude Code 진입점 (AGENTS.md import)
├── README.md              # 개요 (한국어)
├── docs/
│   └── INFRASTRUCTURE.md  # (이 문서) 인프라/프로젝트 상태 가이드
├── package.json / .husky/ # husky + gitleaks pre-commit 훅
│
├── core-infra/            # 클러스터 기반 (ns: core-infra 목표)
│   ├── traefik/           #   Ingress, forwardauth 미들웨어
│   ├── cert-manager/      #   ClusterIssuer, Cloudflare secret
│   ├── longhorn/          #   스토리지
│   ├── crowdsec/          #   침입 차단 + traefik bouncer
│   └── infisical/         #   비밀 관리 + auth token
│
├── apps/                  # 사용자용 웹 서비스 (ns: apps 목표)
│   ├── vaultwarden/  n8n/  mealie/  wordpress/  karakeep/
│   ├── shlink/  pingvin-share-x/  filebrowser/  syncthing/
│   ├── homepage/     # 대시보드 + config/ (services/widgets/bookmarks…)
│   ├── ai-stack/     # Ollama + Open WebUI (원시 매니페스트)
│   ├── cloudbeaver/  changedetection/  it-tools/  quartz-blog/ …
│
├── database/             # 공유 데이터 서비스 (ns: database 목표)
│   ├── postgresql/  mariadb/  redis/  valkey/  couchdb/  cloudbeaver/
│   (values-*-bitnami.yaml / values-*-helmforge.yaml 병존)
│
├── monitoring/           # 관측/업타임 (ns: monitoring 목표)
│   ├── kube-prometheus-stack? (→ 최상위 kube-prometheus-stack/ 에도 존재)
│   ├── scrutiny/  uptime-kuma/
│
├── metallb/  kube-system/keel/   # 클러스터 애드온
│
└── (레거시 최상위 폴더들)  # authentik/ traefik/ vaultwarden/ … 마이그레이션 중 잔존
```

**서비스 폴더 관례** (README 참고):
- `values.yaml` (또는 `values-<name>-<vendor>.yaml`) — Helm 릴리스 values.
- `*-secret.yaml` — Secret 템플릿 (**placeholder만**, 실제 값 금지).
- `*-secret-sync.yaml` — `InfisicalSecret` 리소스 (실제 값을 Infisical에서 주입).
- 원시 매니페스트(`<name>.yaml`) — Helm 차트가 없는 서비스 (예: `ai-stack.yaml`, `homepage.yaml`).

---

## 5. 라이브 서비스 인벤토리 (2026-07-21 스냅샷)

> 아래는 **실제 클러스터**에서 확인된 상태입니다 (호스트는 라이브 `techbara.dev`; 저장소 목표는 `junbeom.work`).

### Helm 릴리스
| 릴리스 | 네임스페이스 | 차트 / 버전 |
|---|---|---|
| traefik | traefik | traefik-40.2.0 (v3.7.1) |
| cert-manager | cert-manager | v1.20.2 |
| longhorn | longhorn-system | 1.12.0 |
| metallb | metallb-system | 0.16.1 |
| infisical | infisical | infisical-standalone-1.9.0 |
| secrets-operator | infisical | v0.11.0 |
| authentik | authentik | 2026.5.3 |
| crowdsec | crowdsec | 0.24.0 |
| kube-prometheus-stack | grafana | 86.2.3 |
| postgres | database | postgresql-2.0.4 (PG 18) |
| mariadb | database | mariadb-2.0.3 (12.3.2) |
| cloudbeaver | database | 1.1.5 |
| vaultwarden | vaultwarden | 1.12.8 |
| n8n | n8n | 1.6.3 |
| mealie | mealie | (helm) |
| wordpress | wordpress | 2.1.0 |
| karakeep | karakeep | 1.2.6 |
| paperless-ngx | paperless-ngx | 0.2.0 |
| shlink-backend / shlink-web | shlink | 11.7.4 / 1.12.1 |
| umami | umami | 2.2.0 |
| homarr + valkey | homarr | 1.1.16 / 1.0.1 |
| syncthing | quartz | 5.1.2 |

### Ingress 호스트 (라이브)
`auth`, `vault`, `n8n`, `mealie`, `karakeep`, `paper`, `flower`, `share`, `wiki`,
`sync`, `link`, `shlink`, `umami`, `home`, `grafana`, `longhorn`, `infisical`,
`beaver`, `www`, `family` → 모두 `*.techbara.dev`.

### 원시 매니페스트 서비스 (Helm 아님)
- **ai-stack**: Ollama(`hostPath: /var/local/k3s-hostpath/ollama`) + Open WebUI.
- **homepage**: 대시보드, `config/` 하위 YAML로 서비스/위젯/북마크 정의.
- **quartz / quartz-blog, yuvomi, pingvin-share-x, adguard** 등.

### 저장소에는 있으나 라이브에 아직 미배포로 보이는 것
`adguard`, `ai-stack`, `changedetection`, `filebrowser`, `hoppscotch`, `it-tools`,
`minio`, `couchdb`, `redis`, `scrutiny`, `uptime-kuma`, `keel`, `homepage`
(정확한 배포 여부는 `kubectl get all -A` 로 재확인 필요).

---

## 6. 비밀 관리 (Infisical) — 동작 방식

두 파일이 한 쌍으로 동작합니다:

1. **`*-secret.yaml`** — placeholder만 담긴 Secret 템플릿 (git에 커밋됨, 실제 값 없음).
   ```yaml
   apiVersion: v1
   kind: Secret
   metadata: { name: vaultwarden-secret, namespace: apps }
   type: Opaque
   stringData: { admin-token: 'your-admin-token', ... }
   ```
2. **`*-secret-sync.yaml`** — `InfisicalSecret` CRD. Infisical 프로젝트에서 실제 값을 받아 위 Secret을 덮어씀.
   ```yaml
   apiVersion: secrets.infisical.com/v1alpha1
   kind: InfisicalSecret
   spec:
     hostAPI: https://infisical.techbara.dev/api   # 현재 도메인 (파일에 남은 junbeom.work 는 레거시 → techbara.dev 로 교정)
     authentication.universalAuth:
       secretsScope: { projectSlug: "vaultwarden", envSlug: "prod", secretsPath: "/" }
       credentialsRef: { secretName: infisical-auth-token, secretNamespace: core-infra }
     managedKubeSecretReferences:
       - { secretName: vaultwarden-secret, secretNamespace: apps, secretType: Opaque }
   ```

- 인증 토큰: `infisical-auth-token` Secret (레거시는 `infisical` ns, 목표는 `core-infra` ns).
- **가드레일**: `.husky/pre-commit` 이 `gitleaks protect --staged` 실행 → 실제 비밀 커밋 차단.
  `.gitignore`가 `*.env` 제외. **실제 크레덴셜은 로컬 `.env`에만, git에는 절대 금지.**

---

## 7. 유지보수 워크플로우

중앙 Makefile/CI 없음 — 서비스 단위로 검증·배포.

```bash
# 원시 매니페스트 검증
kubectl apply --dry-run=client -f apps/n8n/n8n.yaml

# Helm 렌더 확인 (apply 전 항상)
helm template <release> <chart> -n <ns> -f apps/<svc>/values.yaml

# 배포 — 원시 매니페스트
kubectl apply -f apps/wordpress/wordpress.yaml

# 배포 — Helm
helm upgrade --install traefik traefik/traefik -n core-infra -f core-infra/traefik/values.yaml
```

**변경 전 체크리스트**: ingress 호스트, secret 이름, `storageClassName`, 참조 PVC, 네임스페이스 일치 여부(마이그레이션 상태!).

**커밋 규칙**: 짧은 명령형, `feat:`/`fix:`/`refactor:`/`chore:` prefix (예: `feat: Add n8n`). 커밋 1개 = 서비스 1개 또는 인프라 변경 1개로 스코프 유지.

---

## 8. 알려진 주의점 / 리스크 (LLM이 특히 유의)

1. **저장소 ≠ 라이브**: 그룹형→서비스별 리팩터링 진행 중. 저장소의 그룹형 파일(`namespace: apps` 등)은 라이브에 미배포. apply 전 `kubectl get` 으로 실제 상태 확인 필수.
2. **StorageClass 기본값 2개**: `local-path`(k3s 기본)와 `longhorn`이 **둘 다 `(default)`** 로 표시됨 → PVC가 의도치 않은 SC를 잡을 수 있음. 새 PVC는 `storageClassName: longhorn` 명시 권장.
3. **단일 노드**: HA 없음. 노드 다운 = 전체 다운. 리소스/재시작(RESTARTS) 카운트 주의.
4. **비밀**: `*-secret.yaml`은 절대 실제 값으로 채우지 말 것 (gitleaks가 차단하지만 규율 우선).
5. **shlink-backend** 등 일부 파드는 재시작 횟수가 높음 (관측 시점 기준) — 배포/DB 연결 점검 대상.
6. **중복 파일**: 같은 서비스가 최상위 폴더(서비스별=목표)와 `apps/`(그룹형=정리 대상)에 다른 네임스페이스·도메인으로 존재. 원칙적으로 **서비스별 폴더 + 서비스별 네임스페이스** 쪽을 수정하고, 그룹형에는 새로 추가하지 말 것.

---

## 9. 관련 문서

- [`../AGENTS.md`](../AGENTS.md) — 명령어·코딩 규칙·기여 가이드 (에이전트용, 권위 있음).
- [`../README.md`](../README.md) — 프로젝트 개요 (한국어).
- 서비스별 README: `apps/README.md`, `core-infra/README.md`, `database/README.md`, `monitoring/README.md`.
