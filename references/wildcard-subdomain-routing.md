# 와일드카드 도메인에서 특정 서브도메인을 별도 컨테이너로 라우팅

## 목차

1. [개요](#개요)
2. [문제 상황](#문제-상황)
3. [해결 원리](#해결-원리)
4. [서브도메인 라우팅 추가 (전체 프로세스)](#서브도메인-라우팅-추가-전체-프로세스)
5. [서브도메인 라우팅 삭제](#서브도메인-라우팅-삭제)
6. [핵심 트러블슈팅](#핵심-트러블슈팅)
7. [실전 사례: Supabase Studio 라우팅](#실전-사례-supabase-studio-라우팅)

---

## 개요

Dokploy에서 `*.example.com` 와일드카드 SAN 인증서를 사용할 때, 기본적으로 모든 서브도메인이 하나의 메인 애플리케이션으로 라우팅됩니다. 이때 **특정 서브도메인 하나만** 다른 컨테이너(별도 애플리케이션)로 보내려면 Traefik 동적 설정을 수동으로 추가해야 합니다.

### 핵심 조건 3가지

| # | 조건 | 설명 |
|---|------|------|
| 1 | **Traefik 라우터 추가** | 와일드카드보다 높은 priority로 전용 라우터 생성 |
| 2 | **네트워크 연결** | 대상 컨테이너를 `dokploy-network`에 연결 |
| 3 | **바인딩 주소** | 대상 컨테이너가 `0.0.0.0`에서 리스닝해야 함 |

---

## 문제 상황

### 와일드카드 라우터가 모든 서브도메인을 가로채는 구조

Dokploy에서 `*.example.com` SAN 인증서를 사용하면, Traefik 동적 설정 파일에 다음과 같은 와일드카드 라우터가 생성됩니다:

```yaml
# /etc/dokploy/traefik/dynamic/app-xxx.yml (기존 설정)
http:
  routers:
    app-router-websecure:
      rule: Host(`example.com`) || HostRegexp(`{subdomain:.*}.example.com`)
      priority: 1
      service: main-app-service
      entryPoints:
        - websecure
      tls:
        certResolver: letsencrypt_wildcard
        domains:
          - main: example.com
            sans:
              - "*.example.com"
```

**문제**: `sub.example.com`으로 접근해도 `priority: 1`인 와일드카드 라우터가 매칭되어 메인 앱으로 라우팅됩니다.

---

## 해결 원리

### Traefik priority 규칙

Traefik은 **priority 값이 높은 라우터를 먼저 매칭**합니다. 와일드카드 라우터의 priority가 1이면, 특정 서브도메인 라우터의 priority를 100으로 설정하면 해당 서브도메인 요청을 가로챌 수 있습니다.

```
요청: sub.example.com
  ├─ 라우터 A: Host(`sub.example.com`) priority=100  ← 매칭됨!
  └─ 라우터 B: HostRegexp(`{subdomain:.*}.example.com`) priority=1  ← 건너뜀
```

### Dokploy 네트워크 구조

```
dokploy-network (Traefik이 접근 가능한 네트워크)
  ├── dokploy-traefik
  ├── main-app (메인 앱)
  └── target-container (여기에 연결 필요!)

app-specific-network (별도 Compose 네트워크)
  └── target-container (기본 위치)
```

Traefik은 `dokploy-network`에서만 컨테이너에 접근 가능합니다. 대상 컨테이너가 다른 네트워크에만 있으면 **502 Bad Gateway** 발생.

---

## 서브도메인 라우팅 추가 (전체 프로세스)

### 1단계: 진단 - 현재 상태 확인

```bash
# 대상 컨테이너 확인
ssh $ROOT_SSH "docker ps --format '{{.Names}}\t{{.Ports}}' | grep <keyword>"

# 와일드카드 라우터 설정 확인
ssh $ROOT_SSH "cat /etc/dokploy/traefik/dynamic/<app-config>.yml"

# DNS 확인
dig +short sub.example.com
```

### 2단계: 대상 컨테이너를 dokploy-network에 연결

```bash
# 현재 네트워크 확인
ssh $ROOT_SSH "docker inspect <container-name> --format '{{json .NetworkSettings.Networks}}' | python3 -m json.tool"

# dokploy-network에 연결
ssh $ROOT_SSH "docker network connect dokploy-network <container-name>"

# 연결 확인
ssh $ROOT_SSH "docker inspect <container-name> --format '{{json .NetworkSettings.Networks}}' | python3 -c \"import json,sys; d=json.loads(sys.stdin.read()); [print(k) for k in d.keys()]\""
```

### 3단계: 컨테이너 바인딩 주소 확인

```bash
# 컨테이너 내부 리스닝 포트 확인
ssh $ROOT_SSH "docker exec <container-name> cat /proc/net/tcp"
```

**`/proc/net/tcp` 해석 방법:**

| local_address (hex) | 의미 |
|---------------------|------|
| `00000000:0BB8` | `0.0.0.0:3000` - 모든 인터페이스 리스닝 (정상) |
| `0D0016AC:0BB8` | `172.22.0.13:3000` - 특정 IP만 리스닝 (문제!) |

**hex → 포트 변환**: `0BB8` = 3000, `1F90` = 8080, `0050` = 80

### 3-1단계: 바인딩 문제 해결 (특정 IP에만 바인딩된 경우)

컨테이너가 특정 IP에만 바인딩되어 있으면 dokploy-network IP에서 접근 불가.

**해결: Docker Compose에 HOSTNAME 환경변수 추가**

```bash
# Compose 파일 위치 찾기
ssh $ROOT_SSH "find /etc/dokploy/compose -name 'docker-compose.yml' | grep <app-name>"

# Compose 파일에서 해당 서비스 environment에 추가
# HOSTNAME: 0.0.0.0
```

**Next.js 앱의 경우** (Supabase Studio 등):

```yaml
services:
  studio:
    environment:
      HOSTNAME: 0.0.0.0  # 이 줄 추가!
```

**Node.js/Express 앱의 경우**:

```yaml
services:
  app:
    environment:
      HOST: 0.0.0.0  # 프레임워크에 따라 변수명 다름
```

**서비스 재시작:**

```bash
# Compose 디렉토리로 이동하여 해당 서비스만 재시작
ssh $ROOT_SSH "cd /etc/dokploy/compose/<app-dir>/code && docker compose -p <project-name> up -d <service-name>"
```

**재시작 후 바인딩 확인:**

```bash
# 0.0.0.0:PORT 로 변경되었는지 확인
ssh $ROOT_SSH "docker exec <container-name> cat /proc/net/tcp | head -5"
# 00000000:0BB8 이면 성공
```

### 3-2단계: Docker Compose에 dokploy-network 영구 설정

컨테이너 재배포 시에도 네트워크 연결이 유지되도록 Compose 파일을 수정합니다.

```yaml
# docker-compose.yml 수정

services:
  target-service:
    # ... 기존 설정 ...
    networks:
      - app-network
      - dokploy-network  # 추가!

# 파일 하단 networks 정의에 추가
networks:
  app-network:
    name: app-network
    external: true
  dokploy-network:        # 추가!
    name: dokploy-network
    external: true
```

### 4단계: Traefik에서 연결 가능한지 검증

```bash
# Traefik 컨테이너에서 대상 컨테이너로 직접 접근 테스트
ssh $ROOT_SSH "docker exec dokploy-traefik wget -q -O - http://<container-name>:<port>/ 2>&1 | head -5"

# 성공 예시: HTML 또는 JSON 응답 반환
# 실패 예시: "Connection refused" 또는 "can't connect"
```

### 5단계: Traefik 동적 설정 파일 생성

```bash
ssh $ROOT_SSH 'cat > /etc/dokploy/traefik/dynamic/<subdomain-name>.yml << '\''EOF'\''
http:
  routers:
    <subdomain>-router:
      rule: Host(`sub.example.com`)
      priority: 100
      service: <subdomain>-service
      middlewares:
        - redirect-to-https
      entryPoints:
        - web
    <subdomain>-router-websecure:
      rule: Host(`sub.example.com`)
      priority: 100
      service: <subdomain>-service
      entryPoints:
        - websecure
      tls:
        certResolver: <cert-resolver-name>
        domains:
          - main: example.com
            sans:
              - "*.example.com"
  services:
    <subdomain>-service:
      loadBalancer:
        servers:
          - url: http://<container-name>:<port>
        passHostHeader: true
EOF'
```

**설정 파일 핵심 필드:**

| 필드 | 값 | 설명 |
|------|-----|------|
| `rule` | `Host(\`sub.example.com\`)` | 정확한 서브도메인 매칭 |
| `priority` | `100` | 와일드카드(1)보다 높아야 함 |
| `certResolver` | 기존 와일드카드 라우터와 동일한 값 사용 | `traefik.yml`에서 확인 |
| `service.url` | `http://<container-name>:<port>` | dokploy-network 내 컨테이너 DNS명 |

**certResolver 이름 확인 방법:**

```bash
# traefik.yml에서 certResolver 이름 확인
ssh $ROOT_SSH "cat /etc/dokploy/traefik/traefik.yml"

# 기존 와일드카드 라우터에서 certResolver 확인
ssh $ROOT_SSH "grep 'certResolver' /etc/dokploy/traefik/dynamic/<app-config>.yml"
```

### 6단계: 접속 테스트

Traefik은 `watch: true` 설정으로 동적 설정 파일 변경을 자동 감지합니다. 별도 재시작 불필요.

```bash
# HTTPS 접속 테스트
curl -sI https://sub.example.com/ | head -10

# 기대 결과: HTTP/2 200 또는 HTTP/2 307 (앱의 정상 응답)
# 문제 결과: HTTP/2 502 (네트워크/바인딩 문제) 또는 기존 메인 앱 응답 (priority 문제)
```

---

## 서브도메인 라우팅 삭제

### 1단계: Traefik 동적 설정 파일 삭제

```bash
# 설정 파일 삭제
ssh $ROOT_SSH "rm -f /etc/dokploy/traefik/dynamic/<subdomain-name>.yml"

# 삭제 확인
ssh $ROOT_SSH "ls /etc/dokploy/traefik/dynamic/*.yml"
```

Traefik이 자동으로 파일 삭제를 감지하고 라우터를 제거합니다.

### 2단계: (선택) 네트워크 정리

Dokploy에서 해당 APPLICATION을 이미 삭제한 경우, 컨테이너와 네트워크가 함께 정리되므로 추가 작업 불필요.

APPLICATION이 여전히 존재하지만 도메인만 제거하는 경우:

```bash
# dokploy-network에서 컨테이너 분리 (선택)
ssh $ROOT_SSH "docker network disconnect dokploy-network <container-name>"
```

### 3단계: 접속 테스트

```bash
# 서브도메인이 더 이상 별도 컨테이너로 라우팅되지 않는지 확인
# 와일드카드 라우터에 의해 메인 앱으로 라우팅되거나, APPLICATION 삭제 시 접근 불가
curl -sI https://sub.example.com/ | head -10
```

### 삭제 체크리스트

- [ ] Traefik 동적 설정 파일(`/etc/dokploy/traefik/dynamic/<name>.yml`) 삭제
- [ ] 접속 테스트로 라우팅 해제 확인
- [ ] (선택) Docker Compose에서 `dokploy-network` 설정 제거
- [ ] (선택) `docker network disconnect` 실행

---

## 핵심 트러블슈팅

### 502 Bad Gateway 발생 시

| 원인 | 진단 명령어 | 해결 |
|------|------------|------|
| 컨테이너가 dokploy-network에 없음 | `docker inspect <container> --format '{{json .NetworkSettings.Networks}}'` | `docker network connect dokploy-network <container>` |
| 특정 IP에만 바인딩 | `docker exec <container> cat /proc/net/tcp` | `HOSTNAME: 0.0.0.0` 환경변수 추가 후 재시작 |
| Traefik에서 DNS resolve 실패 | `docker exec dokploy-traefik wget http://<container>:<port>/` | 컨테이너명 정확한지 확인 |

### 기존 메인 앱이 계속 응답하는 경우

**원인**: priority 설정 누락 또는 와일드카드보다 낮음

```bash
# 현재 설정 확인
ssh $ROOT_SSH "grep 'priority' /etc/dokploy/traefik/dynamic/*.yml"

# 와일드카드 라우터 priority 확인 → 그보다 높은 값 사용
```

### Dokploy 재배포 시 설정 유실 주의

**중요**: Dokploy UI에서 Compose 서비스를 재배포하면 서버의 `docker-compose.yml`이 덮어쓰일 수 있습니다.

**영구 설정 방법:**

1. Dokploy UI의 Compose 에디터에서도 `HOSTNAME`, `networks` 설정을 동일하게 반영
2. Traefik 동적 설정 파일(`/etc/dokploy/traefik/dynamic/`)은 Dokploy 재배포와 무관하게 유지됨

---

## 실전 사례: Supabase Studio 라우팅

### 환경

- 메인 도메인: `sonub.com` (와일드카드 SAN 인증서: `*.sonub.com`)
- 서브도메인: `supabase.sonub.com` → Supabase Studio 컨테이너
- certResolver: `letsencrypt_sonub` (Cloudflare DNS Challenge)

### 발견된 문제와 해결

**문제 1: Traefik 라우터 부재**
- `*.sonub.com` 와일드카드가 priority: 1로 모든 서브도메인을 center-web으로 라우팅
- 해결: priority: 100으로 `supabase.sonub.com` 전용 라우터 생성

**문제 2: 네트워크 격리**
- Supabase Studio가 `center-supabase-d8tn9m` 네트워크에만 있어 Traefik 접근 불가
- 해결: `docker network connect dokploy-network center-supabase-d8tn9m-supabase-studio`

**문제 3: Next.js 바인딩**
- Supabase Studio(Next.js 앱)가 컨테이너 hostname IP(`172.22.0.13:3000`)에만 바인딩
- `0.0.0.0:3000`이 아니라서 dokploy-network IP에서 접근 시 Connection refused
- 진단: `/proc/net/tcp`에서 `0D0016AC:0BB8` (특정 IP) 확인
- 해결: `HOSTNAME: 0.0.0.0` 환경변수 추가 → 재시작 후 `00000000:0BB8` (모든 인터페이스) 확인

### 생성된 Traefik 설정 파일

```yaml
# /etc/dokploy/traefik/dynamic/supabase-studio.yml
http:
  routers:
    supabase-studio-router:
      rule: Host(`supabase.sonub.com`)
      priority: 100
      service: supabase-studio-service
      middlewares:
        - redirect-to-https
      entryPoints:
        - web
    supabase-studio-router-websecure:
      rule: Host(`supabase.sonub.com`)
      priority: 100
      service: supabase-studio-service
      entryPoints:
        - websecure
      tls:
        certResolver: letsencrypt_sonub
        domains:
          - main: sonub.com
            sans:
              - "*.sonub.com"
  services:
    supabase-studio-service:
      loadBalancer:
        servers:
          - url: http://center-supabase-d8tn9m-supabase-studio:3000
        passHostHeader: true
```

### Docker Compose 수정 내용

```yaml
# Studio 서비스에 추가
services:
  studio:
    environment:
      HOSTNAME: 0.0.0.0        # Next.js가 모든 인터페이스에서 리스닝
    networks:
      - center-supabase-d8tn9m
      - dokploy-network          # Traefik 접근용

# 하단 networks 정의에 추가
networks:
  center-supabase-d8tn9m:
    name: center-supabase-d8tn9m
    external: true
  dokploy-network:
    name: dokploy-network
    external: true
```