---
name: dokploy-skills
description: "Dokploy 셀프호스팅 PaaS 전체 관리 스킬. SSH/API 서버 관리, 앱 배포, Docker Compose/Swarm, DB(PostgreSQL/MySQL/MongoDB/Redis), Traefik, SSL, 도메인, 볼륨 백업, 모니터링, 디버깅 지원. 'Dokploy' 언급, 배포/재배포, Docker Compose, 도메인/SSL/HTTPS, Traefik/502에러, DB관리, 볼륨백업/S3, 컨테이너로그, 서버유지보수, 빌드타입선택, 와일드카드서브도메인라우팅, pgAdmin4 작업 시 사용."
---

# Dokploy 서버 관리 스킬

Dokploy는 셀프호스팅 PaaS 도구로, Docker 기반 애플리케이션 배포를 간편하게 관리합니다.

---

## 필수 파라미터

> **아래 4가지 정보 없이는 어떤 작업도 시작하지 마세요.**
> 사용자가 Dokploy 관련 작업을 요청하면, **첫 번째 응답에서** 아래 정보를 확인하세요.

| # | 항목 | 예시 |
|---|------|------|
| 1 | **Dokploy 서버 URL** | `http://1.2.3.4:3000` |
| 2 | **프로덕션 사이트 URL** | `https://example.com` |
| 3 | **Root SSH 접속 정보** | `root@1.2.3.4` |
| 4 | **애플리케이션 ID** | `DYmNZmKYtRG0RdNrsGcfn` |

- SSH는 반드시 **키 인증** 방식이어야 합니다 (비밀번호 인증 미지원).
- 정보가 누락된 경우, 작업을 진행하지 말고 사용자에게 요청하세요.

---

## 참조 문서

작업 유형에 따라 해당 references 문서를 읽고 진행합니다:

| 작업 | 문서 |
|------|------|
| API를 통한 원격 관리 | [api.md](references/api.md) |
| 애플리케이션 관리/설정 | [applications.md](references/applications.md) |
| 빌드 타입 선택 | [build-types.md](references/build-types.md) |
| Cloudflare 도메인/SSL | [cloudflare.md](references/cloudflare.md) |
| traefik.me 무료 도메인 | [traefik-me-domain.md](references/traefik-me-domain.md) |
| 볼륨 백업/복원 | [volume-backups.md](references/volume-backups.md) |
| 데이터베이스 관리 | [database.md](references/database.md) |
| Docker Compose 관리 | [docker-compose.md](references/docker-compose.md) |
| 와일드카드 서브도메인 라우팅 | [wildcard-subdomain-routing.md](references/wildcard-subdomain-routing.md) |
| pgAdmin4 설치/설정 | [pgadmin.md](references/pgadmin.md) |
| 문제 해결/디버깅 | [debugging.md](references/debugging.md) |
| 서버 유지보수/업데이트 | [maintenance.md](references/maintenance.md) |
| OpenClaw(Moltbot) 배포 | [openclaw.md](references/openclaw.md) |

---

## 빠른 참조

### 프레임워크별 기본 포트

| 프레임워크 | 포트 |
|------------|------|
| Next.js / Node.js | 3000 |
| Laravel / PHP | 8000 |
| Django / Python | 8000 |
| NGINX (정적) | 80 |

### 필수 규칙

- 컨테이너는 반드시 `0.0.0.0`에서 수신 (`127.0.0.1` 사용 금지)
- Docker Compose 볼륨은 상대 경로 사용 (`../files/data:/var/lib/data`)
- Dokploy 필수 컨테이너 4개: `dokploy`, `postgres`, `redis`, `traefik`

---

## 주요 워크플로우

### 새 애플리케이션 배포

1. 프로젝트 생성 → 2. 애플리케이션 생성 및 Git 소스 연결 → 3. 빌드 타입 선택 ([build-types.md](references/build-types.md)) → 4. 환경 변수 설정 → 5. 도메인 및 SSL 설정 → 6. 배포 실행

### 도메인 설정

1. DNS A 레코드 설정 → 2. Dokploy에서 도메인 추가 → 3. HTTPS 활성화 → 4. 접속 테스트

Cloudflare: [cloudflare.md](references/cloudflare.md) | 테스트용: [traefik-me-domain.md](references/traefik-me-domain.md)

### 문제 해결 순서

1. 포트 확인 → 2. 수신 주소(`0.0.0.0`) 확인 → 3. DNS 확인 → 4. 컨테이너 로그 → 5. Traefik 설정 → 6. API 배포 상태

상세 가이드: [debugging.md](references/debugging.md)

---

## 스크립트

| 스크립트 | 용도 |
|----------|------|
| [config.sh](scripts/config.sh) | 서버 설정 자동화 |
| [swagger.sh](scripts/swagger.sh) | Dokploy API 스펙 조회 |
| [traefik-setting.sh](scripts/traefik-setting.sh) | Traefik 설정 관리 |
