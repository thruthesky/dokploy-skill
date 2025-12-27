---
name: dokploy-skill
description: |
  Dokploy 서버 관리 및 배포 가이드. 애플리케이션 배포, Docker Compose, 데이터베이스 관리,
  Cloudflare 도메인 설정, 볼륨 백업, 문제해결 등 Dokploy 관련 작업 시 사용.
  트리거: "Dokploy", "배포 서버", "도메인 설정", "SSL 인증서", "컨테이너 관리", "볼륨 백업"
---

# Dokploy 서버 관리 스킬

Dokploy는 셀프호스팅 PaaS(Platform as a Service) 도구로, Docker 기반 애플리케이션 배포를 간편하게 관리합니다.

## 🚨🚨🚨 Standard Workflow: 서버 접속 정보 필수 입력 🚨🚨🚨

**⛔ 스크립트 실행 전 반드시 사용자에게 아래 정보를 요청해야 합니다 ⛔**

모든 Dokploy 관련 작업(서버 설정 확인, Docker 관리, 소프트웨어 설치 등)을 수행하기 전에 **반드시** 아래의 정보를 사용자에게 입력받아야 합니다:

| 변수 | 설명 | 예시 |
|------|------|------|
| `DOKPLOY_SERVER_IP` | Dokploy 서버 IP 주소 | `1.2.3.4` |
| `ROOT_SSH_CONNECTION` | Root SSH 접속 주소 | `root@1.2.3.4` |
| `DOKPLOY_API_KEY` | Dokploy API 키 | `abcd1234efgh5678ijkl9012mnop3456` |

위 정보를 항상 사용자에게 요청하세요. 이 정보가 없으면 Dokploy 서버에 접속하거나 API를 호출할 수 없습니다.

### 필수 확인 사항

1. **SSH 키 인증 설정 완료**: `ssh-copy-id root@서버IP` 명령으로 비밀번호 없이 접속 가능해야 함
2. **Root 권한 필수**: 서버 관리 작업에는 root 권한이 필요함
3. **API 키 준비**: Dokploy 대시보드에서 API 키를 생성하고 준비해야 함

### 사용자에게 요청할 질문 예시

```
Dokploy 서버 작업을 진행하기 전에 다음 정보가 필요합니다:

1. Dokploy 서버 IP 주소를 알려주세요 (예: 1.2.3.4)
2. Root SSH 접속 주소를 알려주세요 (예: root@1.2.3.4)
3. Dokploy API 키를 알려주세요 (Settings → Profile → API/CLI에서 생성)

※ SSH 키 인증이 설정되어 있어야 합니다 (ssh-copy-id 완료)
※ API 키는 디버깅 및 원격 관리에 필요합니다
```

### 정보 입력 후 가능한 작업

**SSH 기반 작업:**
- ✅ 서버 설정 확인 및 변경
- ✅ Docker 컨테이너 관리 (재부팅, 재시작, 설정)
- ✅ Docker Compose 서비스 관리
- ✅ 필요한 소프트웨어 설치
- ✅ 로그 분석 및 문제 해결
- ✅ 볼륨 백업 및 복원

**API 기반 작업:**
- ✅ 프로젝트/애플리케이션 상태 조회
- ✅ 애플리케이션 시작/중지/재배포
- ✅ 환경 변수 확인 및 수정
- ✅ 데이터베이스 관리 (생성, 삭제, 상태 확인)
- ✅ 도메인 설정 확인 및 추가
- ✅ 배포 이력 조회

### 🔒 정보 관리 방식 (보안)

**⛔ 서버 접속 정보를 config.sh 파일에 저장하지 않습니다 ⛔**

사용자로부터 받은 정보는 **메모리에만 보관**하고, 스크립트 실행 시 **파라미터로 전달**합니다:

```bash
# 스크립트 실행 시 파라미터로 전달
./scripts/traefik-setting.sh \
  --ssh-connection=root@1.2.3.4 \
  --dokploy-server-url=http://1.2.3.4:3000

# 또는 직접 SSH 명령 실행
ssh root@1.2.3.4 "cat /etc/dokploy/traefik/traefik.yml"
```

### 스크립트 파라미터 규격

| 파라미터 | 설명 | 예시 |
|----------|------|------|
| `--ssh-connection` | Root SSH 접속 주소 | `root@1.2.3.4` |
| `--dokploy-server-url` | Dokploy 대시보드 URL | `http://1.2.3.4:3000` |

### AI 어시스턴트 동작 방식

1. 사용자에게 서버 정보 요청
2. **메모리에만 저장** (파일에 기록하지 않음)
3. 스크립트 실행 시 파라미터로 전달
4. 대화 종료 시 정보 자동 삭제

---

## 주요 기능 요약

| 기능 | 설명 |
|------|------|
| **애플리케이션 배포** | 단일 컨테이너 앱을 손쉽게 배포 |
| **Docker Compose** | 멀티 컨테이너 환경 지원 |
| **데이터베이스** | MySQL, PostgreSQL, MongoDB, Redis, MariaDB 지원 |
| **도메인 관리** | 커스텀 도메인, Let's Encrypt SSL 자동 발급 |
| **모니터링** | CPU, 메모리, 디스크, 네트워크 실시간 모니터링 |
| **볼륨 백업** | S3 스토리지로 명명 볼륨 백업/복원 |

## 참조 문서

작업에 따라 아래 문서를 참조하세요:

| 작업 | 문서 |
|------|------|
| **API를 통한 원격 관리/디버깅** | [api.md](references/api.md) |
| 애플리케이션 생성/관리/고급 설정 | [applications.md](references/applications.md) |
| 빌드 타입 선택 (Nixpacks, Dockerfile 등) | [build-types.md](references/build-types.md) |
| Cloudflare 도메인 및 SSL 설정 | [cloudflare.md](references/cloudflare.md) |
| 볼륨 백업 및 복원 | [volume-backups.md](references/volume-backups.md) |
| 오류 발생 시 문제해결 | [troubleshooting.md](references/troubleshooting.md) |

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
# 올바른 형식
volumes:
  - "../files/my-data:/var/lib/data"

# 잘못된 형식 (절대 경로 사용 금지)
volumes:
  - "/folder:/path/in/container"
```

## 서버 접속 후 문제 해결 시 확인 사항

- SSH 접속이 정상적으로 되는지 확인
- root 권한으로 접속되었는지 확인
- 필요한 로그 파일 및 설정 파일에 접근 권한이 있는지 확인

### 서버 접속하여 필요한 모든 명령어를 직접 실행하기

아래의 예제와 같이 SSH로 서버에 접속하여 필요한 설정 파일을 확인하거나 명령어를 실행할 수 있습니다:

```bash
ssh root@167.88.45.173 "cat /etc/dokploy/traefik/dynamic/middlewares.yml && echo '---' && curl -s -o /dev/null -w '%{http_code}' https://javapad.com 2>/dev/null || echo 'SSL 연결 확인 필요'"
```

예를 들어 사용자가 아래와 같이 요청하면,
```txt
Dokploy 에 새로운 앱을 만들고, 도메인을 https://thruthesky.vibers.kr 와 같이 연결했는데, 잘 동작하는지 확인해 주세요.
```

아래와 같은 명령어로 잘 접속되는지 확인하고, 접속이 잘 안되면 각종 명령어 실행하여 Dokply/Traefik 설정을 확인, 수정하고 Docker 명령으로 컨테이너 상태를 점검하고 재 실행을 하면 됩니다.

```bash
ssh root@167.88.45.173 "grep -l 'thruthesky.vibers.kr' /etc/dokploy/traefik/dynamic/*.yml 2>/dev/null | xargs cat 2>/dev/null || echo '해당 도메인 설정을 찾을 수 없습니다'"
curl -sI https://thruthesky.vibers.kr 2>&1 | head -20
dig +short thruthesky.vibers.kr 2>/dev/null || nslookup thruthesky.vibers.kr 2>/dev/null | grep Address
```



## 🔌 API를 활용한 원격 관리 및 디버깅

Dokploy API를 사용하면 SSH 접속 없이도 서버 상태를 확인하고 관리할 수 있습니다.

### API 활용 시나리오

| 상황 | SSH | API | 권장 |
|------|-----|-----|------|
| 애플리케이션 상태 확인 | ✅ | ✅ | API |
| 앱 재배포/재시작 | ✅ | ✅ | API |
| 환경 변수 수정 | ✅ | ✅ | API |
| Traefik 설정 확인 | ✅ | ❌ | SSH |
| 컨테이너 로그 실시간 확인 | ✅ | ❌ | SSH |
| 데이터베이스 생성 | ✅ | ✅ | API |

### 디버깅 시 API 활용 예제

**1. 모든 프로젝트 및 애플리케이션 상태 조회**
```bash
# 프로젝트 목록 조회
curl -X 'GET' \
  "http://${DOKPLOY_SERVER_IP}:3000/api/project.all" \
  -H 'accept: application/json' \
  -H "x-api-key: ${DOKPLOY_API_KEY}"
```

**2. 특정 애플리케이션 상태 확인**
```bash
# 애플리케이션 상세 정보 조회 (applicationId 필요)
curl -X 'GET' \
  "http://${DOKPLOY_SERVER_IP}:3000/api/application.one?applicationId=${APP_ID}" \
  -H 'accept: application/json' \
  -H "x-api-key: ${DOKPLOY_API_KEY}"
```

**3. 문제 발생 시 애플리케이션 재배포**
```bash
# 애플리케이션 재배포 (문제 해결 후)
curl -X 'POST' \
  "http://${DOKPLOY_SERVER_IP}:3000/api/application.redeploy" \
  -H 'Content-Type: application/json' \
  -H "x-api-key: ${DOKPLOY_API_KEY}" \
  -d "{\"applicationId\": \"${APP_ID}\"}"
```

**4. 환경 변수 확인 및 수정**
```bash
# 환경 변수 저장
curl -X 'POST' \
  "http://${DOKPLOY_SERVER_IP}:3000/api/application.saveEnvironment" \
  -H 'Content-Type: application/json' \
  -H "x-api-key: ${DOKPLOY_API_KEY}" \
  -d "{\"applicationId\": \"${APP_ID}\", \"env\": \"NODE_ENV=production\nPORT=3000\"}"
```

**5. 배포 이력 조회 (오류 분석)**
```bash
# 최근 배포 이력 확인
curl -X 'GET' \
  "http://${DOKPLOY_SERVER_IP}:3000/api/deployment.all?applicationId=${APP_ID}" \
  -H 'accept: application/json' \
  -H "x-api-key: ${DOKPLOY_API_KEY}"
```

### AI 어시스턴트 디버깅 워크플로우

문제 해결 시 다음 순서로 진행합니다:

1. **API로 상태 확인**: 프로젝트/앱 목록 조회하여 현재 상태 파악
2. **API로 배포 이력 확인**: 최근 배포 실패 여부 확인
3. **SSH로 상세 로그 분석**: 컨테이너 로그, Traefik 로그 확인
4. **API로 수정 적용**: 환경 변수 수정, 재배포 실행
5. **결과 확인**: curl로 도메인 접속 테스트

### API 문서 참조

상세한 API 엔드포인트 및 파라미터는 [api.md](references/api.md)를 참조하세요.

---

## 문제 발생 시 확인 순서

1. 포트가 올바르게 설정되었는지 확인
2. 앱이 `0.0.0.0`에서 수신 대기하는지 확인
3. 도메인이 서버 IP를 가리키는지 확인
4. 컨테이너 로그 확인: `docker service logs <service-name>`
5. **API로 배포 상태 확인**: `deployment.all` 엔드포인트로 최근 배포 상태 조회
6. 상세 문제해결은 [troubleshooting.md](references/troubleshooting.md) 참조

## 🔧 Traefik 디버깅 (도메인 접속 문제)

도메인 접속 문제 발생 시 Traefik 로그를 활성화하고 SSH로 서버에 접속하여 분석합니다.

### 1단계: Traefik 로그 설정

Dokploy UI → Settings → Traefik → traefik.yml에 추가:

```yaml
log:
  level: INFO

accessLog:
  format: json
  filePath: /etc/dokploy/traefik/dynamic/access.log
  fields:
    defaultMode: keep
    headers:
      defaultMode: drop
```

### 2단계: SSH 접속 후 로그 확인

```bash
# 서버 접속
ssh $ROOT_SSH_CONNECTION

# Traefik 접근 로그 실시간 확인
tail -f /etc/dokploy/traefik/dynamic/access.log

# Traefik 서비스 로그 확인
docker logs dokploy-traefik --tail 100 -f

# 컨테이너 상태 확인
docker ps | grep traefik
```

### 3단계: 문제 해결 후 재시작

```bash
# Traefik만 재시작
docker restart dokploy-traefik

# 전체 서비스 재시작 (필요 시)
docker service update --force dokploy
```

### 로그 분석 포인트

| 항목 | 의미 |
|------|------|
| `OriginStatus: 502` | 백엔드 앱 문제 (포트, 실행 상태 확인) |
| `OriginStatus: 404` | 라우팅 규칙 미매칭 |
| `RouterName: 없음` | 도메인 설정 누락 |

자세한 내용은 [debugging.md](references/debugging.md)를 참조하세요.
