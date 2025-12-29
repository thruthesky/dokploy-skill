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
---

# Dokploy 서버 관리 스킬

Dokploy는 셀프호스팅 PaaS(Platform as a Service) 도구로, Docker 기반 애플리케이션 배포를 간편하게 관리합니다.

## 필수: 서버 접속 정보 요청

모든 Dokploy 작업 시작 전, **반드시** 사용자에게 아래 정보를 요청합니다:

| 변수 | 설명 | 예시 |
|------|------|------|
| `DOKPLOY_SERVER_IP` | Dokploy 서버 IP | `1.2.3.4` |
| `ROOT_SSH_CONNECTION` | Root SSH 접속 주소 | `root@1.2.3.4` |
| `DOKPLOY_API_KEY` | Dokploy API 키 | Settings → Profile → API/CLI에서 생성 |

**보안 원칙**: 접속 정보는 메모리에만 보관하고, 파일에 저장하지 않습니다.

### 사용자에게 요청할 질문

```
Dokploy 서버 작업을 진행하기 전에 다음 정보가 필요합니다:

1. Dokploy 서버 IP 주소 (예: 1.2.3.4)
2. Root SSH 접속 주소 (예: root@1.2.3.4)
3. Dokploy API 키 (Settings → Profile → API/CLI에서 생성)

※ SSH 키 인증이 설정되어 있어야 합니다 (ssh-copy-id 완료)
```

---

## 참조 문서

작업 유형에 따라 해당 문서를 참조합니다:

| 작업 | 문서 |
|------|------|
| **API를 통한 원격 관리** | [api.md](references/api.md) |
| **애플리케이션 관리/설정** | [applications.md](references/applications.md) |
| **빌드 타입 선택** | [build-types.md](references/build-types.md) |
| **Cloudflare 도메인/SSL** | [cloudflare.md](references/cloudflare.md) |
| **traefik.me 무료 도메인** | [traefik-me-domain.md](references/traefik-me-domain.md) |
| **볼륨 백업/복원** | [volume-backups.md](references/volume-backups.md) |
| **데이터베이스 관리** | [database.md](references/database.md) |
| **Docker Compose 관리** | [docker-compose.md](references/docker-compose.md) |
| **문제 해결/디버깅** | [debugging.md](references/debugging.md) |
| **서버 유지보수/업데이트** | [maintenance.md](references/maintenance.md) |

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
ssh root@$SERVER_IP "docker ps"

# Dokploy 필수 컨테이너 확인 (4개: dokploy, postgres, redis, traefik)
ssh root@$SERVER_IP "docker ps | grep -E 'dokploy|postgres|redis|traefik'"

# 디스크 사용량 확인
ssh root@$SERVER_IP "df -h"
```

### 도메인 접속 문제 진단

```bash
# DNS 확인
dig +short example.com

# HTTP 응답 확인
curl -sI https://example.com | head -10

# Traefik 설정에서 도메인 검색
ssh root@$SERVER_IP "grep -r 'example.com' /etc/dokploy/traefik/dynamic/*.yml"

# SSL 인증서 확인
echo | openssl s_client -connect example.com:443 -servername example.com 2>/dev/null | openssl x509 -noout -dates
```

### 컨테이너 로그 확인

```bash
# Traefik 로그
ssh root@$SERVER_IP "docker logs dokploy-traefik --tail 100"

# 특정 서비스 로그
ssh root@$SERVER_IP "docker service logs <service-name> --tail 100"
```

### Docker 재시작

```bash
# Traefik만 재시작
ssh root@$SERVER_IP "docker restart dokploy-traefik"

# Dokploy 전체 재시작
ssh root@$SERVER_IP "docker service update --force dokploy"
```

---

## API 기반 작업 예시

### 프로젝트/애플리케이션 조회

```bash
# 모든 프로젝트 조회
curl -X GET "http://$SERVER_IP:3000/api/project.all" \
  -H "x-api-key: $API_KEY"

# 특정 애플리케이션 조회
curl -X GET "http://$SERVER_IP:3000/api/application.one?applicationId=$APP_ID" \
  -H "x-api-key: $API_KEY"
```

### 애플리케이션 재배포

```bash
curl -X POST "http://$SERVER_IP:3000/api/application.redeploy" \
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
