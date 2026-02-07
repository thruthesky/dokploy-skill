# Dokploy에서 pgAdmin4 설치 및 설정 가이드

## 목차

1. [개요](#개요)
2. [Dokploy UI에서 Compose 서비스 생성](#dokploy-ui에서-compose-서비스-생성)
3. [Docker Compose 파일 작성](#docker-compose-파일-작성)
4. [배포 에러 해결](#배포-에러-해결)
5. [와일드카드 도메인 연결 (HTTPS)](#와일드카드-도메인-연결-https)
6. [PostgreSQL 서버 등록](#postgresql-서버-등록)
7. [보안 설정](#보안-설정)

---

## 개요

pgAdmin4는 PostgreSQL 데이터베이스를 웹 브라우저에서 관리할 수 있는 오픈소스 GUI 도구입니다. Dokploy에서 Docker Compose 서비스로 배포하여 사용합니다.

### 핵심 정보

| 항목 | 값 |
|------|-----|
| 이미지 | `dpage/pgadmin4:latest` |
| 컨테이너 내부 포트 | `80` (HTTP) |
| 데이터 볼륨 | `/var/lib/pgadmin` |
| 기본 로그인 | 환경변수 `PGADMIN_DEFAULT_EMAIL` / `PGADMIN_DEFAULT_PASSWORD` |

---

## Dokploy UI에서 Compose 서비스 생성

1. Dokploy 대시보드 접속 → 프로젝트 선택
2. **Create Service** → **Compose** 선택
3. Source Type: **Docker (raw)** 선택
4. Compose 에디터에 아래 Docker Compose 파일 입력
5. **Deploy** 클릭

---

## Docker Compose 파일 작성

### 최소 구성 (권장)

```yaml
services:
  pgadmin:
    image: dpage/pgadmin4:latest
    container_name: pgadmin
    restart: always
    environment:
      PGADMIN_DEFAULT_EMAIL: admin@example.com
      PGADMIN_DEFAULT_PASSWORD: your-secure-password
      PGADMIN_CONFIG_SERVER_MODE: "True"
    volumes:
      - pgadmin_data:/var/lib/pgadmin
    ports:
      - "5050:80"

volumes:
  pgadmin_data:
```

### 핵심 주의사항

**`volumes:` 정의 필수**: 서비스에서 `pgadmin_data:/var/lib/pgadmin`을 사용하면, 파일 하단에 반드시 `volumes:` 섹션에 `pgadmin_data:`를 정의해야 합니다. 누락 시 다음 에러 발생:

```
service "pgadmin" refers to undefined volume pgadmin_data: invalid compose project
```

**`version` 속성 불필요**: Docker Compose V2에서는 `version: "3.8"` 등의 속성이 더 이상 필요 없으며, 경고가 발생합니다:

```
the attribute `version` is obsolete, it will be ignored, please remove it to avoid potential confusion
```

### 환경변수 설명

| 환경변수 | 설명 | 예시 |
|---------|------|------|
| `PGADMIN_DEFAULT_EMAIL` | 웹 로그인 이메일 | `admin@example.com` |
| `PGADMIN_DEFAULT_PASSWORD` | 웹 로그인 비밀번호 | 강력한 비밀번호 사용 |
| `PGADMIN_CONFIG_SERVER_MODE` | 서버 모드 활성화 (멀티 유저) | `"True"` |
| `PGADMIN_LISTEN_PORT` | (선택) 내부 리스닝 포트 변경 | `80` (기본값) |

---

## 배포 에러 해결

### 에러: undefined volume

```
service "pgadmin" refers to undefined volume pgadmin_data: invalid compose project
```

**원인**: Docker Compose 파일 하단에 `volumes:` 정의 누락

**해결**: 파일 맨 하단에 추가:

```yaml
volumes:
  pgadmin_data:
```

### SSH로 직접 수정 및 배포

Dokploy UI에서 수정할 수 없는 경우 SSH로 직접 수정:

```bash
# Compose 파일 위치 확인
ssh $ROOT_SSH "find /etc/dokploy/compose -name 'docker-compose.yml' | grep pgadmin"

# 파일 수정 후 직접 배포
ssh $ROOT_SSH "cd /etc/dokploy/compose/<pgadmin-app-dir>/code && docker compose -p <project-name> up -d"
```

**`<project-name>` 확인 방법**: Dokploy 배포 로그에서 `docker compose -p <name>` 부분 확인.

---

## 와일드카드 도메인 연결 (HTTPS)

`*.example.com` 와일드카드 SAN 인증서를 사용하는 환경에서 `pgadmin.example.com`으로 접속하려면 [wildcard-subdomain-routing.md](wildcard-subdomain-routing.md)의 프로세스를 따릅니다.

### 요약 (3단계)

**1. dokploy-network에 연결**

```bash
ssh $ROOT_SSH "docker network connect dokploy-network pgadmin"
```

**2. Traefik에서 접근 가능한지 확인**

```bash
# pgAdmin은 0.0.0.0:80에서 리스닝하므로 바인딩 문제 없음
ssh $ROOT_SSH "docker exec dokploy-traefik wget -q -O - http://pgadmin:80/ 2>&1 | head -3"
```

**3. Traefik 동적 설정 파일 생성**

```bash
ssh $ROOT_SSH 'cat > /etc/dokploy/traefik/dynamic/pgadmin.yml << '\''EOF'\''
http:
  routers:
    pgadmin-router:
      rule: Host(`pgadmin.example.com`)
      priority: 100
      service: pgadmin-service
      middlewares:
        - redirect-to-https
      entryPoints:
        - web
    pgadmin-router-websecure:
      rule: Host(`pgadmin.example.com`)
      priority: 100
      service: pgadmin-service
      entryPoints:
        - websecure
      tls:
        certResolver: <cert-resolver-name>
        domains:
          - main: example.com
            sans:
              - "*.example.com"
  services:
    pgadmin-service:
      loadBalancer:
        servers:
          - url: http://pgadmin:80
        passHostHeader: true
EOF'
```

**4. 접속 테스트**

```bash
curl -sI https://pgadmin.example.com/ | head -10
# 기대 결과: HTTP/2 302 → /login (pgAdmin 로그인 페이지 리다이렉트)
```

### pgAdmin은 바인딩 문제가 없음

pgAdmin4(gunicorn 기반)는 기본적으로 `0.0.0.0:80`에서 리스닝합니다. Supabase Studio(Next.js)와 달리 `HOSTNAME` 환경변수 추가가 필요 없습니다.

### Dokploy 재배포 시 네트워크 유실 방지

`docker network connect`는 컨테이너 재시작 시 유지되지만, Dokploy UI에서 **재배포** 시 새 컨테이너가 생성되면서 유실됩니다.

**영구 설정**: Docker Compose 파일에 `dokploy-network` 추가:

```yaml
services:
  pgadmin:
    image: dpage/pgadmin4:latest
    container_name: pgadmin
    restart: always
    environment:
      PGADMIN_DEFAULT_EMAIL: admin@example.com
      PGADMIN_DEFAULT_PASSWORD: your-secure-password
      PGADMIN_CONFIG_SERVER_MODE: "True"
    volumes:
      - pgadmin_data:/var/lib/pgadmin
    ports:
      - "5050:80"
    networks:
      - default
      - dokploy-network

volumes:
  pgadmin_data:

networks:
  dokploy-network:
    name: dokploy-network
    external: true
```

---

## PostgreSQL 서버 등록

pgAdmin 웹 UI에 로그인한 후 PostgreSQL 서버를 등록합니다.

### Dokploy 내장 PostgreSQL 연결

Dokploy는 내장 PostgreSQL을 사용합니다. pgAdmin에서 연결하려면:

| 항목 | 값 |
|------|-----|
| Host | `dokploy-postgres` (Docker 네트워크 내 DNS명) |
| Port | `5432` |
| Username | Dokploy 설치 시 설정한 값 |
| Password | Dokploy 설치 시 설정한 값 |

### 외부에서 PostgreSQL 접근 시

서버 IP와 노출된 포트를 사용:

| 항목 | 값 |
|------|-----|
| Host | 서버 IP (예: `209.97.169.136`) |
| Port | 노출된 포트 (예: `5433`) |
| Username / Password | DB 설정에 따라 |

---

## 보안 설정

### 필수 변경 사항

1. **기본 비밀번호 변경**: `PGADMIN_DEFAULT_PASSWORD`에 강력한 비밀번호 사용
2. **기본 이메일 변경**: `PGADMIN_DEFAULT_EMAIL`을 실제 관리자 이메일로 변경
3. **포트 노출 제한**: HTTPS 도메인 연결 후 `ports: - "5050:80"` 제거 가능 (Traefik 경유만 허용)

### 포트 직접 접근 차단 (HTTPS 전용)

도메인 연결 후 외부 포트 노출이 불필요하면 Compose에서 `ports` 제거:

```yaml
services:
  pgadmin:
    image: dpage/pgadmin4:latest
    # ports 섹션 제거 → Traefik 경유만 가능
    # ports:
    #   - "5050:80"
```

---

## 실전 사례: sonub.com 서버 pgAdmin 설정

### 환경

| 항목 | 값 |
|------|-----|
| Dokploy URL | `http://209.97.169.136:3000` |
| 도메인 | `pgadmin.sonub.com` |
| certResolver | `letsencrypt_sonub` (Cloudflare DNS Challenge) |
| 컨테이너명 | `pgadmin` |
| Compose 프로젝트명 | `center-pgadmin-rxzxui` |

### 배포된 Compose 파일

```yaml
services:
  pgadmin:
    image: dpage/pgadmin4:latest
    container_name: pgadmin
    restart: always
    environment:
      PGADMIN_DEFAULT_EMAIL: admin@yourcompany.com
      PGADMIN_DEFAULT_PASSWORD: strongpassword
      PGADMIN_CONFIG_SERVER_MODE: "True"
    volumes:
      - pgadmin_data:/var/lib/pgadmin
    ports:
      - "5050:80"

volumes:
  pgadmin_data:
```

### Traefik 설정 파일

```yaml
# /etc/dokploy/traefik/dynamic/pgadmin.yml
http:
  routers:
    pgadmin-router:
      rule: Host(`pgadmin.sonub.com`)
      priority: 100
      service: pgadmin-service
      middlewares:
        - redirect-to-https
      entryPoints:
        - web
    pgadmin-router-websecure:
      rule: Host(`pgadmin.sonub.com`)
      priority: 100
      service: pgadmin-service
      entryPoints:
        - websecure
      tls:
        certResolver: letsencrypt_sonub
        domains:
          - main: sonub.com
            sans:
              - "*.sonub.com"
  services:
    pgadmin-service:
      loadBalancer:
        servers:
          - url: http://pgadmin:80
        passHostHeader: true
```

### 설정 파일 위치

| 파일 | 경로 |
|------|------|
| Docker Compose | `/etc/dokploy/compose/center-pgadmin-rxzxui/code/docker-compose.yml` |
| Traefik 라우팅 | `/etc/dokploy/traefik/dynamic/pgadmin.yml` |
| pgAdmin 데이터 | Docker volume `center-pgadmin-rxzxui_pgadmin_data` |
