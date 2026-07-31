# 서비스 템플릿 — docker-compose 만 지원하는 앱을 K8s 로 올리기

`docker-compose.yml` 만 제공하는 서비스를 이 클러스터(K3s + Traefik + Longhorn + cert-manager + Infisical)
규칙에 맞는 매니페스트로 옮기기 위한 템플릿이다. 기준 사례는 [`pingvin-share-x/pingvin-share-x.yaml`](../../pingvin-share-x/pingvin-share-x.yaml).

## 파일 구성

| 파일 | 담는 것 |
|---|---|
| [`myapp.yaml`](myapp.yaml) | Namespace, ConfigMap(env), ConfigMap(file), PVC, Deployment, Service, Ingress |
| [`myapp-secret.yaml`](myapp-secret.yaml) | placeholder Secret (실제 값 금지, 키 목록 문서용) |
| [`myapp-secret-sync.yaml`](myapp-secret-sync.yaml) | `InfisicalSecret` — 실제 값 주입 |

### Secret 은 같은 매니페스트에 넣어도 되나?

**문법적으로는 가능하지만(멀티 문서 YAML), 이 저장소에서는 분리한다.** 라이브 서비스 17개 전부 분리되어 있고, 이유는:

- `*-secret.yaml` 은 **apply 하면 안 되는 경우가 있는 파일**이다. secret-sync 가 돌고 있는 상태에서 apply 하면 실값이 placeholder 로 덮인다(최대 60초 뒤 복구). 앱 매니페스트와 합치면 `kubectl apply -f myapp.yaml` 할 때마다 이 사고가 난다.
- Infisical 프로젝트 생성/권한 부여는 앱 배포와 **수명주기가 다르다** (앱은 자주 바뀌고 secret-sync 는 거의 안 바뀜).
- gitleaks/리뷰가 `*-secret*.yaml` 파일 단위로 걸러진다.

굳이 합친다면 `myapp-secret-sync.yaml`(InfisicalSecret)만 앱 매니페스트 뒤에 이어 붙이는 건 안전하다. placeholder Secret 만은 반드시 분리할 것.

## 사용법

```bash
# 1) 스캐폴딩 (myapp → 실제 서비스명)
NEW=changedetection
mkdir -p "$NEW"
for f in docs/templates/myapp*.yaml; do
  base=$(basename "$f")
  sed "s/myapp/$NEW/g" "$f" > "$NEW/${base/myapp/$NEW}"
done

# 2) TODO 주석을 채운다 (이미지/포트/볼륨 경로/호스트/Infisical projectSlug)

# 3) 검증 (문법·스키마)
kubectl apply --dry-run=client -f "$NEW/$NEW.yaml"

# 4) apply — 반드시 앱 매니페스트(Namespace 포함)부터
kubectl apply -f "$NEW/$NEW.yaml"
kubectl apply -f "$NEW/$NEW-secret-sync.yaml"
# kubectl apply -f "$NEW/$NEW-secret.yaml"   # 최초 부트스트랩 때만, 보통 불필요

# 이후 수정분은 API 서버 검증(admission 포함)까지 미리 볼 수 있다.
# 단 --dry-run=server 는 네임스페이스가 "실제로 존재해야" 동작한다.
# 최초 배포 전에 쓰면 Namespace 가 생성되지 않은 채 나머지가 전부 NotFound 로 실패한다.
kubectl apply --dry-run=server -f "$NEW/$NEW.yaml"

# 5) 확인
kubectl -n "$NEW" get pod,svc,ingress,pvc
kubectl -n "$NEW" logs deploy/"$NEW" -f
```

> `kubectl apply -f <디렉터리>` 는 파일명 알파벳순으로 처리해 `*-secret-sync.yaml` 이 먼저 적용된다.
> 그 시점엔 네임스페이스가 없어 실패하므로 **파일 단위로 위 순서대로** apply 할 것.

## docker-compose → K8s 매핑

| docker-compose | K8s | 비고 |
|---|---|---|
| `services.<name>` | Deployment + Service 한 쌍 | compose 서비스 여러 개 = Deployment 여러 개(같은 ns). 사이드카(같은 볼륨/localhost 공유)만 한 Pod 에 |
| `image:` | `spec.containers[].image` | 태그 고정 필수. `:latest` 는 Diun/Keel 알림·롤백을 무력화 |
| `container_name:` | `metadata.name` | |
| `restart: unless-stopped` | 불필요 | Deployment 기본 `restartPolicy: Always` |
| `ports: "3000:8080"` | Service(ClusterIP) + Ingress | 호스트 포트(3000)는 버린다. NodePort/hostPort 쓰지 말 것 |
| `environment:` / `env_file:` | ConfigMap + `envFrom.configMapRef` | 비밀 값은 Secret 으로 분리 |
| (비밀 env) | Secret + `envFrom.secretRef` / `secretKeyRef` | Infisical 에서 주입 |
| `volumes: data:/path` (named) | PVC + `volumeMounts` | `storageClassName: longhorn` 명시 |
| `volumes: ./conf.yml:/etc/conf.yml` (bind) | ConfigMap + `subPath` 마운트 | subPath 안 쓰면 대상 디렉터리 전체가 가려짐 |
| `volumes: /mnt/media:/media` (host bind) | `hostPath` | 단일 노드라 동작은 하지만 백업/이동성 없음 → 최후수단 |
| `tmpfs:` | `emptyDir: {medium: Memory}` | |
| `networks:` | 같은 네임스페이스 | DNS: `<svc>` / `<svc>.<ns>.svc.cluster.local` |
| `depends_on:` | initContainer 대기 or readinessProbe | K8s 에는 기동 순서 보장이 없다 |
| `healthcheck:` | `readinessProbe` / `livenessProbe` (+ `startupProbe`) | 부팅 느린 앱은 startupProbe 로 liveness 조기 kill 방지 |
| `command:` / `entrypoint:` | `args:` / `command:` | **순서가 반대다**. compose `entrypoint` → k8s `command`, compose `command` → k8s `args` |
| `user: "1000:1000"` | `securityContext.runAsUser/runAsGroup/fsGroup` | linuxserver.io 계열은 `PUID`/`PGID` env 그대로 사용 |
| `cap_add:` / `privileged:` | `securityContext.capabilities.add` / `privileged` | |
| `sysctls:` | `securityContext.sysctls` | k3s 기본 allowlist 밖이면 kubelet 설정 필요 |
| `extra_hosts:` | `hostAliases` | |
| `deploy.resources.limits` | `resources.requests/limits` | requests 는 스케줄링, limits 는 상한 |
| `labels: diun.enable=true` | `metadata.annotations` 동일 키 | |
| `logging:` | 불필요 | k3s(containerd) 가 처리 |

### 자주 걸리는 것

- **`:latest` + `imagePullPolicy: Always`** — 재시작 때 조용히 메이저 버전이 올라가 데이터가 깨질 수 있다. 태그 고정 + `IfNotPresent`.
- **RWO PVC + RollingUpdate** — 새 Pod 가 볼륨을 못 잡고 무한 Pending. 템플릿처럼 `strategy.type: Recreate` 를 쓸 것.
- **StorageClass 기본값 2개** (`local-path`, `longhorn` 둘 다 default) — `storageClassName` 을 안 적으면 어느 쪽이 잡힐지 보장이 없다.
- **ConfigMap 수정 후 미반영** — Pod 자동 재시작 없음. `kubectl rollout restart deployment/<name> -n <ns>`.
- **Secret 은 네임스페이스를 못 넘는다** — 공용 SMTP(Resend/Brevo) 같은 값이 필요하면 그 서비스의 `*-secret-sync.yaml` 에 항목을 추가해 해당 ns 로 동기화한다.
- **Traefik 미들웨어 이름** — `<미들웨어 ns>-<이름>@kubernetescrd`. 이 클러스터의 Middleware 는 전부 `traefik` ns 에 있다 (`traefik-crowdsec-bouncer@kubernetescrd` 등). `core-infra-...` 로 적힌 옛 파일은 오타가 아니라 레거시이며 동작하지 않는다.
- **Ingress 만 만들고 DNS 를 빼먹음** — Cloudflare 에 레코드가 없으면 DNS-01 인증서 발급까지 같이 막힌다.

## 배포 전 체크리스트

- [ ] 폴더명 = 네임스페이스명 = 서비스명 (그룹형 `apps/`·`core-infra/` 에 넣지 말 것)
- [ ] 모든 리소스에 `namespace:` 명시
- [ ] 이미지 태그 고정
- [ ] PVC 에 `storageClassName: longhorn`
- [ ] Ingress: `ingressClassName: traefik`, 호스트 `*.techbara.dev`, cluster-issuer `letsencrypt-cloudflare`, TLS secretName 지정
- [ ] Cloudflare DNS 레코드 추가
- [ ] 비밀 값이 `*-secret.yaml` 에 실제 값으로 들어가지 않았는지 확인
- [ ] Infisical 프로젝트·prod 환경·키 등록 완료 (`projectSlug` 일치)
- [ ] `kubectl apply --dry-run=client` 통과 (네임스페이스 생성 후에는 `--dry-run=server` 로 재확인)

관련 문서: [`AGENTS.md`](../../AGENTS.md), [`docs/INFRASTRUCTURE.md`](../INFRASTRUCTURE.md)
