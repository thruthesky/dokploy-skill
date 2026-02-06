---
name: dokploy-skill
description: |
  Dokploy 셀프호스팅 PaaS 플랫폼의 전체 관리 스킬. SSH 및 API를 통한 서버 관리,
  애플리케이션 배포, Docker Compose/Swarm 관리, 데이터베이스(PostgreSQL, MySQL, MongoDB, Redis) 관리,
  Traefik 리버스 프록시 설정, SSL 인증서(Let's Encrypt, Cloudflare Origin CA), 도메인 설정,
  볼륨 백업/복원, 컨테이너 모니터링, 서버 문제 해결 및 디버깅을 지원합니다.

  이 스킬 사용 시점:
  (1) "Dokploy", "dokploy" 언급 시
  (2) 애플리케이션 배포/재배포 요청
  (3) Docker Compose 또는 Swarm 관련 작업
  (4) 도메인 설정, SSL 인증서, HTTPS 설정
  (5) Traefik 설정 확인/수정, 502 에러, 도메인 접속 문제
  (6) 데이터베이스 생성, 백업, 복원
  (7) 볼륨 백업/복원, S3 연동
  (8) 컨테이너 로그 확인, 서버 상태 점검
  (9) 서버 유지보수, Dokploy 업데이트
  (10) 빌드 타입 선택 (Nixpacks, Dockerfile, Buildpack)
  (11) 와일드카드 도메인(SAN 인증서)에서 특정 서브도메인을 별도 컨테이너로 라우팅
  (12) pgAdmin4 설치, 설정, 도메인 연결
---

# Dokploy 서버 관리 스킬

Dokploy는 셀프호스팅 PaaS(Platform as a Service) 도구로, Docker 기반 애플리케이션 배포를 간편하게 관리합니다.

---

## 🚨🚨🚨 필수 파라미터 (MANDATORY) 🚨🚨🚨

> **⛔⛔⛔ 절대 규칙: 아래 4가지 정보 없이는 어떤 작업도 시작하지 마세요! ⛔⛔⛔**
>
> 사용자가 Dokploy 관련 작업을 요청하면, **반드시 첫 번째 응답에서** 아래 필수 정보를 확인하세요.
> 정보가 누락된 경우, 작업을 진행하지 말고 즉시 사용자에게 요청하세요.

### 필수 입력 항목 (4가지)

| # | 항목 | 설명 | 예시 |
|---|------|------|------|
| 1 | **Dokploy 서버 URL** | Dokploy 대시보드 접속 주소 | `http://1.2.3.4:3000` |
| 2 | **프로덕션 사이트 URL** | 배포된 애플리케이션 URL | `https://example.com` |
| 3 | **Root SSH 접속 정보** | 서버 SSH 접속 주소 | `root@1.2.3.4` 또는 `root@example.com` |
| 4 | **애플리케이션 ID** | Dokploy 애플리케이션 고유 ID | `DYmNZmKYtRG0RdNrsGcfn` |

### 🔐 SSH 키 인증 필수 조건

> **⚠️ 중요: 비밀번호 인증은 지원하지 않습니다!**
>
> SSH 접속은 반드시 **SSH 키 인증** 방식으로 설정되어 있어야 합니다.
> 사용자에게 아래 명령어로 SSH 키 복사가 완료되었는지 확인하세요:
>
> ```bash
> # SSH 키가 서버에 등록되어 있어야 합니다
> ssh-copy-id root@서버IP
>
> # 비밀번호 없이 접속 가능한지 테스트
> ssh root@서버IP "echo 'SSH 키 인증 성공'"
> ```

### 사용자에게 요청할 메시지 템플릿

정보가 누락된 경우, 아래 메시지를 사용하여 사용자에게 요청하세요:

```
🚨 Dokploy 작업을 시작하기 전에 다음 4가지 필수 정보가 필요합니다:

1. 📍 Dokploy 서버 URL (예: http://1.2.3.4:3000)
2. 🌐 프로덕션 사이트 URL (예: https://example.com)
3. 🔑 Root SSH 접속 정보 (예: root@1.2.3.4)
4. 🆔 애플리케이션 ID (Dokploy 대시보드에서 확인)

⚠️ SSH 키 인증 필수:
   비밀번호 없이 SSH 접속이 가능해야 합니다.
   아직 설정하지 않았다면: ssh-copy-id root@서버IP

위 정보를 모두 알려주시면 작업을 시작하겠습니다.
```

### 정보 검증 체크리스트

작업 시작 전 반드시 확인:

- [ ] Dokploy 서버 URL이 `http://IP:3000` 형식인지
- [ ] 프로덕션 URL이 유효한 도메인/IP인지
- [ ] SSH 접속이 `root@` 형식인지
- [ ] 애플리케이션 ID가 알파벳+숫자 조합인지

---

## 참조 문서

작업 유형에 따라 해당 문서를 참조합니다:

| 작업 | 문서 | 주요 내용 |
|------|------|----------|
| **API를 통한 원격 관리** | [api.md](references/api.md) | Dokploy REST API, 인증, 배포 자동화 |
| **애플리케이션 관리/설정** | [applications.md](references/applications.md) | 환경변수, 모니터링, 리소스 관리, Swarm 설정 |
| **빌드 타입 선택** | [build-types.md](references/build-types.md) | Nixpacks, Dockerfile, Buildpack 비교 |
| **Cloudflare 도메인/SSL** | [cloudflare.md](references/cloudflare.md) | Cloudflare DNS, Origin CA, 프록시 설정 |
| **traefik.me 무료 도메인** | [traefik-me-domain.md](references/traefik-me-domain.md) | 테스트용 무료 도메인 (HTTP only) |
| **볼륨 백업/복원** | [volume-backups.md](references/volume-backups.md) | S3 연동, Named Volume 백업/복원 |
| **데이터베이스 관리** | [database.md](references/database.md) | PostgreSQL, MySQL, MongoDB, Redis 관리 |
| **Docker Compose 관리** | [docker-compose.md](references/docker-compose.md) | 멀티 컨테이너 설정, 볼륨 마운트 규칙 |
| **와일드카드 서브도메인 라우팅** | [wildcard-subdomain-routing.md](references/wildcard-subdomain-routing.md) | 와일드카드 SAN 인증서 환경에서 특정 서브도메인을 별도 컨테이너로 라우팅 추가/삭제 |
| **pgAdmin4 설치/설정** | [pgadmin.md](references/pgadmin.md) | pgAdmin4 Docker Compose 배포, 와일드카드 도메인 연결, PostgreSQL 서버 등록 |
| **문제 해결/디버깅** | [debugging.md](references/debugging.md) | 502 에러, 도메인 접속 문제, Traefik 로그 |
| **서버 유지보수/업데이트** | [maintenance.md](references/maintenance.md) | Dokploy 업데이트, 디스크 관리, 백업 |

---

## 빠른 참조

### 필수 포트 설정

| 프레임워크 | 기본 포트 |
|------------|----------|
| Next.js / Node.js | 3000 |
| Laravel / PHP | 8000 |
| Django / Python | 8000 |
| NGINX (정적) | 80 |

### 컨테이너 수신 주소

```bash
# 올바른 설정 (모든 인터페이스에서 수신)
0.0.0.0:3000

# 잘못된 설정 (외부 접근 불가)
127.0.0.1:3000
```

### Docker Compose 볼륨 마운트

```yaml
# 올바른 형식 (상대 경로)
volumes:
  - "../files/my-data:/var/lib/data"

# 잘못된 형식 (절대 경로 사용 금지)
volumes:
  - "/folder:/path/in/container"
```

---

## SSH 기반 작업 예시

### 서버 상태 확인

```bash
# Docker 컨테이너 상태 확인
ssh $ROOT_SSH "docker ps"

# Dokploy 필수 컨테이너 확인 (4개: dokploy, postgres, redis, traefik)
ssh $ROOT_SSH "docker ps | grep -E 'dokploy|postgres|redis|traefik'"

# 디스크 사용량 확인
ssh $ROOT_SSH "df -h"
```

### 도메인 접속 문제 진단

```bash
# DNS 확인
dig +short $PRODUCTION_DOMAIN

# HTTP 응답 확인
curl -sI https://$PRODUCTION_DOMAIN | head -10

# Traefik 설정에서 도메인 검색
ssh $ROOT_SSH "grep -r '$PRODUCTION_DOMAIN' /etc/dokploy/traefik/dynamic/*.yml"

# SSL 인증서 확인
echo | openssl s_client -connect $PRODUCTION_DOMAIN:443 -servername $PRODUCTION_DOMAIN 2>/dev/null | openssl x509 -noout -dates
```

### 컨테이너 로그 확인

```bash
# Traefik 로그
ssh $ROOT_SSH "docker logs dokploy-traefik --tail 100"

# 특정 서비스 로그
ssh $ROOT_SSH "docker service logs <service-name> --tail 100"
```

### Docker 재시작

```bash
# Traefik만 재시작
ssh $ROOT_SSH "docker restart dokploy-traefik"

# Dokploy 전체 재시작
ssh $ROOT_SSH "docker service update --force dokploy"
```

---

## API 기반 작업 예시

### 프로젝트/애플리케이션 조회

```bash
# 모든 프로젝트 조회
curl -X GET "$DOKPLOY_URL/api/project.all" \
  -H "x-api-key: $API_KEY"

# 특정 애플리케이션 조회
curl -X GET "$DOKPLOY_URL/api/application.one?applicationId=$APP_ID" \
  -H "x-api-key: $API_KEY"
```

### 애플리케이션 재배포

```bash
curl -X POST "$DOKPLOY_URL/api/application.redeploy" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -d "{\"applicationId\": \"$APP_ID\"}"
```

상세한 API 사용법은 [api.md](references/api.md) 참조.

---

## 문제 해결 순서

1. **포트 확인**: 앱이 올바른 포트에서 실행 중인지
2. **수신 주소 확인**: `0.0.0.0`에서 수신 대기하는지
3. **DNS 확인**: 도메인이 서버 IP를 가리키는지
4. **컨테이너 로그 확인**: `docker service logs <service-name>`
5. **Traefik 설정 확인**: `/etc/dokploy/traefik/dynamic/*.yml`
6. **API로 배포 상태 확인**: `deployment.all` 엔드포인트

상세한 문제 해결 가이드는 [debugging.md](references/debugging.md) 참조.

---

## 주요 작업 워크플로우

### 새 애플리케이션 배포

1. 프로젝트 생성 (UI 또는 API)
2. 애플리케이션 생성 및 Git 소스 연결
3. 빌드 타입 선택 ([build-types.md](references/build-types.md) 참조)
4. 환경 변수 설정
5. 도메인 설정 및 SSL 인증서 발급
6. 배포 실행

### 도메인 설정

1. DNS 레코드 설정 (A 레코드 → 서버 IP)
2. Dokploy에서 도메인 추가
3. HTTPS 활성화 및 인증서 타입 선택
4. 접속 테스트

Cloudflare 사용 시 [cloudflare.md](references/cloudflare.md), 테스트용 도메인은 [traefik-me-domain.md](references/traefik-me-domain.md) 참조.

### 볼륨 백업 설정

1. S3 호환 스토리지 연결
2. 명명 볼륨(Named Volume) 사용 확인
3. 백업 스케줄 설정 (Cron 형식)
4. 테스트 백업 실행

상세 가이드는 [volume-backups.md](references/volume-backups.md) 참조.
