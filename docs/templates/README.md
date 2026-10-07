# 서비스 템플릿 — docker-compose 만 지원하는 앱을 K8s 로 올리기

`docker-compose.yml` 만 제공하는 서비스를 이 저장소(K3s + Traefik + Longhorn + cert-manager + Infisical)
규칙에 맞는 매니페스트로 옮기기 위한 템플릿이다. 기준 사례는 [`pingvin-share-x/pingvin-share-x.yaml`](../../pingvin-share-x/pingvin-share-x.yaml).
(단 기준 사례의 Ingress 에는 `ingressClassName` 이 빠져 있으니, Ingress 는 [`myapp.yaml`](myapp.yaml) 형식을 따를 것.)

> ⚠️ 이 저장소의 설정은 마지막 사용 시점 기준이다. 템플릿의 이미지 태그·API 버전·Infisical CRD 스펙도
> 다음에 사용할 때 최신 버전과 변경 사항(Breaking Changes)을 반드시 확인할 것.

## 저장소 규칙

- **디렉터리 = 네임스페이스** — 최상위 서비스 디렉터리 1개 = 네임스페이스 1개이고 이름이 같다 (`vaultwarden/` → ns `vaultwarden`).
  - 앱과 그 앱 전용 DB/캐시/동반 컴포넌트는 같은 디렉터리·네임스페이스에 둔다 (예: `homarr/` = homarr + valkey, `quartz/` = quartz + syncthing + couchdb).
  - 여러 앱이 같이 쓰는 DB 는 `database/` (postgresql + mariadb + cloudbeaver).
  - 예외 — 업스트림이 네임스페이스를 고정한 것: `longhorn/` → `longhorn-system`, `metallb/` → `metallb-system`, `keel/` → `kube-system`.
  - 이 `docs/templates/` 는 스캐폴드일 뿐 네임스페이스가 아니다.
- **디렉터리 구성**

  | 파일 | 담는 것 |
  |---|---|
  | `values.yaml` | 디렉터리의 앱이 Helm 차트 하나로 배포될 때의 values. 아래 `<설명>.yaml` 같은 보조 매니페스트는 함께 둘 수 있다 (예: `cert-manager/values.yaml` + `cluster-issuer.yaml`) |
  | `values-<component>.yaml` | 컴포넌트가 여럿일 때의 컴포넌트별 values — 앱 + 전용 DB/캐시처럼 차트가 여럿이거나 (예: `homarr/values-homarr.yaml` + `values-valkey.yaml`), 직접 작성한 앱 옆에 차트가 붙는 경우 (예: `snapotter/snapotter.yaml` + `values-valkey.yaml`) |
  | `<app>.yaml` | 직접 작성한 매니페스트. 맨 위에 `kind: Namespace` 문서 포함 |
  | `<설명>.yaml` | Helm 차트 옆의 보조 매니페스트는 내용을 설명하는 kebab-case 이름 (예: `cluster-issuer.yaml`, `metallb-config.yaml`) |
  | `secret.yaml.example` | 이 네임스페이스의 모든 `kind: Secret` 템플릿 (`---` 로 구분한 멀티 문서, 민감값은 전부 `change-me`, 호스트·포트 등 비민감 구조값은 유지) |
  | `secret-sync.yaml.example` | 이 네임스페이스의 모든 `InfisicalSecret` (멀티 문서) — Infisical 값을 위 Secret 으로 주입 |

  앱이 Secret 을 전혀 참조하지 않으면 두 `*.example` 파일은 만들지 않는다.
- **비밀 값은 `change-me`** — 커밋되는 파일(values, 매니페스트, `*.example`, 주석 포함)의 비밀번호·토큰·API 키 등은 전부 `change-me`.
  호스트·포트·DB 이름 같은 비민감 값은 그대로 두고, 연결 문자열은 자격증명 부분만 바꾼다 (`postgresql://app:change-me@postgres.database.svc.cluster.local:5432/app`).
  실제 값은 Infisical 또는 git 에 올리지 않는 `secret.yaml` 에만 둔다. Secret 이름·키 이름·`existingSecret` 같은 **참조**는 그대로 둔다.
- **버전 확인 헤더** — 모든 values / 매니페스트 / `*.example` 맨 위에 헤더를 둔다. values 는 크게 손보지 않고 마지막 사용 시점 그대로 두었으므로,
  다음에 쓸 때 헤더의 버전을 기준으로 최신 차트/이미지와 변경 사항을 반드시 확인한다. Helm values 헤더 형식:

  ```yaml
  # =====================================================================
  # <App> — Helm values
  # Chart     : <repo-alias>/<chart> (<repo URL, 모르면 "repo URL 확인 필요">)
  # Repo      : helm repo add <repo-alias> <repo URL>
  # Version   : chart <x> / app <y> (마지막 사용 기준; 모르면 "확인 필요")
  # Namespace : <ns>
  # Install   : helm upgrade --install <release> <repo-alias>/<chart> -n <ns> --create-namespace -f <file>
  # ⚠️ 마지막 사용 시점 기준 설정입니다. 다음에 사용할 때는 차트/앱 최신 버전과
  #    values 키 변경(Breaking Changes) 여부를 반드시 확인하세요.
  # =====================================================================
  ```

  `<file>` 은 헤더가 들어가는 values 파일 자신이다 (`values.yaml` 또는 `values-<component>.yaml` — 위 표의 이름 규칙대로).
  `Repo` 줄은 URL 을 모르면 생략한다. OCI 차트는 `Repo` 줄 없이 `Chart` 줄에 `<chart> (oci://... — OCI, repo add 불필요)` 를 적고
  `Install` 줄에서 그 `oci://` 주소를 그대로 쓴다 (예: [`forgejo/values.yaml`](../../forgejo/values.yaml)).
  직접 작성한 매니페스트의 헤더는 [`myapp.yaml`](myapp.yaml), Secret / InfisicalSecret 헤더는
  [`secret.yaml.example`](secret.yaml.example) · [`secret-sync.yaml.example`](secret-sync.yaml.example) 맨 위를 참고.

## 파일 구성

| 파일 | 스캐폴딩 후 | 담는 것 |
|---|---|---|
| [`myapp.yaml`](myapp.yaml) | `<svc>/<svc>.yaml` | Namespace, ConfigMap(env), ConfigMap(file), PVC, Deployment, Service, Ingress |
| [`secret.yaml.example`](secret.yaml.example) | `<svc>/secret.yaml.example` | Secret 템플릿 (민감값은 `change-me`, 필요한 키 목록 문서 겸용) |
| [`secret-sync.yaml.example`](secret-sync.yaml.example) | `<svc>/secret-sync.yaml.example` | `InfisicalSecret` — Infisical 의 실제 값을 Secret 으로 주입 |

### Secret 은 같은 매니페스트에 넣어도 되나?

**문법적으로는 가능하지만(멀티 문서 YAML), 이 저장소에서는 분리한다.** 모든 서비스가 같은 방식이고, 이유는:

- `secret.yaml.example` 은 **그대로 apply 하는 파일이 아니다**. 민감값이 `change-me` 라서 수동 방식이면 `secret.yaml` 로 복사해 값을 채운 뒤 apply 하고,
  Infisical 방식이면 아예 apply 하지 않는다(InfisicalSecret 이 Secret 을 직접 생성). secret-sync 가 돌고 있는 상태에서 placeholder Secret 을
  apply 하면 실값이 덮인다(최대 60초 뒤 복구). 앱 매니페스트와 합치면 `kubectl apply -f myapp.yaml` 할 때마다 이 사고가 난다.
- Infisical 프로젝트 생성/권한 부여는 앱 배포와 **수명주기가 다르다** (앱은 자주 바뀌고 secret-sync 는 거의 안 바뀜).
- `.example` 확장자라 `kubectl apply -f <디렉터리>` 에서 자동으로 빠지고, gitleaks/리뷰도 파일 단위로 걸러진다.

굳이 합친다면 `secret-sync.yaml.example`(InfisicalSecret, 비밀 값 없음)만 앱 매니페스트 뒤에 이어 붙이는 건 안전하다. Secret 템플릿만은 반드시 분리할 것.

## 사용법

```bash
# 1) 스캐폴딩 (myapp → 실제 서비스명 = 디렉터리명 = 네임스페이스명)
NEW=newapp   # 아직 없는 이름이어야 한다 — 이미 있는 디렉터리면 mkdir 이 실패하고 아무것도 복사하지 않는다
mkdir "$NEW" && for f in myapp.yaml secret.yaml.example secret-sync.yaml.example; do
  sed "s/myapp/$NEW/g" "docs/templates/$f" > "$NEW/${f/myapp/$NEW}"
done
# → $NEW/$NEW.yaml, $NEW/secret.yaml.example, $NEW/secret-sync.yaml.example

# 2) TODO 주석을 채운다 (이미지/포트/볼륨 경로/호스트/Infisical projectSlug/Secret 키)
#    각 파일 맨 위 헤더(Images 등)도 실제 값으로 갱신한다

# 3) 검증 (문법·스키마)
kubectl apply --dry-run=client -f "$NEW/$NEW.yaml"

# 4) apply — 반드시 앱 매니페스트(Namespace 포함)부터
kubectl apply -f "$NEW/$NEW.yaml"
# Secret 방법 1) Infisical
kubectl apply -f "$NEW/secret-sync.yaml.example"
# Secret 방법 2) 수동 (Infisical 미사용 시) — secret.yaml 은 커밋 금지
# cp "$NEW/secret.yaml.example" "$NEW/secret.yaml"   # change-me → 실제 값
# kubectl apply -f "$NEW/secret.yaml"

# 이후 수정분은 API 서버 검증(admission 포함)까지 미리 볼 수 있다.
# 단 --dry-run=server 는 네임스페이스가 "실제로 존재해야" 동작한다.
# 최초 배포 전에 쓰면 Namespace 가 생성되지 않은 채 나머지가 전부 NotFound 로 실패한다.
kubectl apply --dry-run=server -f "$NEW/$NEW.yaml"

# 5) 확인
kubectl -n "$NEW" get pod,svc,ingress,pvc
kubectl -n "$NEW" logs deploy/"$NEW" -f
```

> `kubectl apply -f <디렉터리>` 는 `.yaml`/`.yml`/`.json` 만 읽으므로 `*.example` 은 건너뛴다 (파일을 직접 지정하면 확장자와 무관하게 적용된다).
> 다만 직접 만든 `secret.yaml` 은 포함되고 파일명 알파벳순으로 처리돼 Namespace 보다 먼저 적용될 수 있으므로 **파일 단위로 위 순서대로** apply 할 것.

## docker-compose → K8s 매핑

| docker-compose | K8s | 비고 |
|---|---|---|
| `services.<name>` | Deployment + Service 한 쌍 | compose 서비스 여러 개 = Deployment 여러 개(같은 ns). 사이드카(같은 볼륨/localhost 공유)만 한 Pod 에 |
| `image:` | `spec.containers[].image` | 태그 고정 필수. `:latest` 는 Diun/Keel 알림·롤백을 무력화 |
| `container_name:` | `metadata.name` | |
| `restart: unless-stopped` | 불필요 | Deployment 기본 `restartPolicy: Always` |
| `ports: "3000:8080"` | Service(ClusterIP) + Ingress | 호스트 포트(3000)는 버린다. NodePort/hostPort 쓰지 말 것 |
| `environment:` / `env_file:` | ConfigMap + `envFrom.configMapRef` | 비밀 값은 Secret 으로 분리 |
| (비밀 env) | Secret + `envFrom.secretRef` / `secretKeyRef` | `secret.yaml.example` 에 키 나열, Infisical 에서 주입 |
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
- **Secret 은 네임스페이스를 못 넘는다** — 공용 SMTP(Brevo) 는 [`infisical/secret-sync.yaml.example`](../../infisical/secret-sync.yaml.example) 의 `brevo-secret-sync`
  `managedKubeSecretReferences` 에 새 ns 를 추가해 fan-out 한다 (수동 방식이면 `<svc>/secret.yaml.example` 에 `brevo-secret` 문서 추가 — 예: [`mealie/secret.yaml.example`](../../mealie/secret.yaml.example)).
- **Traefik 미들웨어 이름** — `<미들웨어 ns>-<이름>@kubernetescrd`. 이 클러스터의 Middleware 는 전부 `traefik` ns 에 있다
  (`traefik-cloudflare-only`, `traefik-crowdsec-bouncer`, `traefik-authentik-forwardauth` + `@kubernetescrd`). 다른 접두사로 적으면 동작하지 않는다.
- **Ingress 만 만들고 DNS 를 빼먹음** — Cloudflare 에 레코드가 없으면 DNS-01 인증서 발급까지 같이 막힌다.

## 배포 전 체크리스트

- [ ] 디렉터리명 = 네임스페이스명 = 서비스명 (앱 전용 DB/캐시는 같은 디렉터리에, 공용 DB 는 `database/`)
- [ ] 맨 위에 `kind: Namespace`, 모든 리소스에 `namespace:` 명시
- [ ] 이미지 태그 고정
- [ ] PVC 에 `storageClassName: longhorn`
- [ ] Ingress: `ingressClassName: traefik`, 호스트 `*.techbara.dev`, cluster-issuer `letsencrypt-cloudflare`, TLS secretName 지정
- [ ] Cloudflare DNS 레코드 추가
- [ ] `secret.yaml.example` 의 민감값(비밀번호·토큰·키, 연결 문자열의 자격증명 부분)이 전부 `change-me` 인지 (실제 값은 Infisical 또는 커밋하지 않는 `secret.yaml` 에만)
- [ ] Infisical 프로젝트·prod 환경·키 등록 완료 (`projectSlug` 일치)
- [ ] 각 파일 맨 위 버전 확인 헤더(Images / Namespace / Apply) 갱신
- [ ] `kubectl apply --dry-run=client` 통과 (네임스페이스 생성 후에는 `--dry-run=server` 로 재확인)

관련 문서: [`AGENTS.md`](../../AGENTS.md), [`docs/INFRASTRUCTURE.md`](../INFRASTRUCTURE.md)
