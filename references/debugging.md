# Dokploy 문제해결 가이드

## 목차

1. [센터 프로젝트 디버깅 스크립트](#센터-프로젝트-디버깅-스크립트)
2. [도메인/접속 문제](#도메인접속-문제)
3. [마운트/볼륨 문제](#마운트볼륨-문제)
4. [Docker Compose 문제](#docker-compose-문제)
5. [Dokploy UI 접근 불가](#dokploy-ui-접근-불가)
6. [기타 문제](#기타-문제)

---

## 센터 프로젝트 디버깅 스크립트

센터 프로젝트에는 배포 문제 해결을 위한 전용 스크립트가 있습니다.

### 배포 에러 확인

```bash
# 최근 실패한 배포 자동 확인
./.claude/skills/center-skill/scripts/deploy-error-check.sh auto

# 특정 배포 ID로 에러 확인
./.claude/skills/center-skill/scripts/deploy-error-check.sh <deploymentId>
```

**출력 정보:**
- 배포 ID, 상태, 생성일, 제목
- 로그 경로 (SSH로 서버 접속하여 확인)
- 오류 로그 내용 (ERROR, WARNING 하이라이트)
- 문제 해결 팁

### 실시간 배포 모니터링

```bash
./.claude/skills/center-skill/scripts/deploy-watch.sh
```

**모니터링 항목:**
- 배포 상태 (running → done/error)
- 새로운 배포 감지
- 상태 변경 알림
- 최근 5개 배포 이력

### 배포 상태 조회

```bash
./.claude/skills/center-skill/scripts/deploy-monitor.sh
```

**조회 정보:**
- 최신 배포 상세 정보 (상태, 생성일, 제목, 배포 ID)
- 최근 10개 배포 목록

---

## 도메인/접속 문제

### 🔧 Traefik 로그 설정 및 디버깅

도메인 접속 문제가 발생하면 먼저 Traefik 로그를 활성화하여 원인을 파악합니다.

**1. Traefik 설정 파일에 로그 설정 추가**

Dokploy UI → Settings → Traefik → traefik.yml 파일에 아래 설정을 추가합니다:

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

**2. SSH로 서버 접속하여 로그 확인**

```bash
# 서버 접속 (config.sh의 ROOT_SSH_CONNECTION 사용)
ssh root@서버IP

# Traefik 접근 로그 실시간 확인
tail -f /etc/dokploy/traefik/dynamic/access.log

# Traefik 서비스 로그 확인
docker logs dokploy-traefik --tail 100 -f

# Traefik 컨테이너 상태 확인
docker ps | grep traefik
```

**3. 문제 해결 후 Docker 재시작**

```bash
# Traefik 재시작
docker restart dokploy-traefik

# 전체 Dokploy 서비스 재시작 (필요 시)
docker service update --force dokploy
```

**4. 로그 분석 시 확인 사항**

| 로그 항목 | 확인 내용 |
|----------|----------|
| `OriginStatus` | 백엔드 서버 응답 코드 (502면 앱 문제) |
| `RequestHost` | 요청된 도메인명 확인 |
| `RouterName` | 라우팅 규칙 매칭 여부 |
| `ServiceName` | 연결된 서비스 확인 |

---

### 애플리케이션 도메인이 작동하지 않음

**확인 사항:**

1. **포트 매핑 확인**
   - Next.js: 3000
   - Laravel: 8000
   - Django: 8000

2. **Advanced → Ports 기능 비활성화** (권장)

3. **Let's Encrypt 인증서 생성 전 도메인이 서버 IP를 가리키는지 확인**

4. **앱이 `0.0.0.0`에서 수신 대기하도록 설정**

```javascript
// Vite 설정 예시
export default defineConfig({
  preview: {
    port: 3000,
    host: true,  // 모든 네트워크 인터페이스에서 수신
  }
});
```

### Bad Gateway (502) 오류

**주요 원인:**

1. **포트 불일치** - 도메인 설정의 Container Port와 앱의 실제 포트 확인
2. **127.0.0.1에서만 수신 대기** - `0.0.0.0`으로 변경 필요

```javascript
// Express.js 예시
app.listen(3000, '0.0.0.0', () => {
  console.log('Server running');
});
```

### 템플릿/Compose에서 404 오류

**원인:**
- **Applications**: Traefik 파일 시스템 사용 (도메인 변경 시 자동 적용)
- **Templates/Compose**: Traefik 라벨 사용 (**도메인 변경 후 재배포 필요**)

**해결:** 도메인 수정 후 항상 서비스를 재배포하세요.

---

## 마운트/볼륨 문제

### 마운트로 인한 애플리케이션 실행 실패

Docker Swarm은 유효하지 않은 마운트가 있으면 배포 성공 후에도 실행하지 않습니다.

**해결:**
1. 마운트 설정 검증
2. Swarm 섹션에서 실제 오류 메시지 확인

### Docker Compose 볼륨 마운트 규칙

파일 마운트는 자동으로 `files` 폴더에 저장됩니다:

```
/application-name
  /code
  /files
```

**올바른 형식:**
```yaml
volumes:
  - "../files/my-database:/var/lib/mysql"
  - "../files/my-configs:/etc/my-app/config"
```

**잘못된 형식:**
```yaml
volumes:
  - "/folder:/path/in/container"  # 절대 경로 사용 금지
```

### 리포지토리 파일 마운트 문제

**문제:** AutoDeploy 사용 시 `git clone`이 각 배포마다 실행되어 리포지토리가 초기화됩니다.

**해결:** 파일을 Dokploy의 File Mount로 이동하고 `../files/` 경로로 참조하세요.

---

## Docker Compose 문제

### 도메인이 작동하지 않음

**해결:** 포트를 노출할 필요 없이 실행 포트만 지정하세요:

```yaml
services:
  app:
    image: dokploy/dokploy:latest
    ports:
      - 3000      # 올바른 방식 (호스트 포트 없이)
      - 80
```

### 다른 워커 노드에서 로그/모니터링 미작동

배포된 애플리케이션이 다른 워커 노드에서 실행되면 UI에서 로그와 모니터링에 접근할 수 없습니다.

**원인:** 같은 노드에 있어야만 데이터에 접근 가능

---

## Dokploy UI 접근 불가

### 진단 단계

**1. 디스크 공간 확인**

공간 부족 시 데이터베이스가 복구 모드로 진입합니다.

```bash
# 불필요한 Docker 리소스 정리
docker system prune -a
docker image prune -a
```

**2. 컨테이너 상태 확인**

```bash
docker ps
# 4개 필수 컨테이너 확인:
# - dokploy
# - dokploy-postgres
# - dokploy-redis
# - dokploy-traefik
```

**3. 로그 검토**

```bash
docker service logs dokploy
docker service logs dokploy-postgres
docker service logs dokploy-redis
docker logs dokploy-traefik
```

**4. 데이터베이스 연결 오류 시 재시작**

```bash
docker service scale dokploy=0
docker service scale dokploy=1
```

**5. Traefik 설정 오류**

잘못된 YAML 구조 확인 및 수정 후 재시작:

```bash
docker restart dokploy-traefik
```

---

## 기타 문제

### Docker Swarm 초기화 실패

**오류:** `must specify a listening address...`

**해결:**
```bash
curl -sSL https://dokploy.com/install.sh | ADVERTISE_ADDR=your-ip sh
```

### 원격 서버 배포 시 로그 미로딩

**가능한 원인:**
1. 서버 성능 부족 (동시 요청 처리 불가, SSL 오류 발생)
2. 디스크 공간 부족

### Traefik 네트워크 종료 오류

재시작 시 네트워크 연결 종료 에러는 **정상 동작**입니다. 무시해도 됩니다.

---

## 핵심 체크리스트

| 증상 | 확인 사항 |
|------|----------|
| 도메인 접속 불가 | 포트, 수신 주소 (0.0.0.0), DNS 설정 |
| 502 Bad Gateway | 포트 일치, 앱 실행 상태 |
| 404 Not Found (Compose) | 도메인 변경 후 재배포 |
| 마운트 후 실행 안됨 | 마운트 경로 유효성, Swarm 로그 |
| UI 접근 불가 | 디스크 공간, 4개 컨테이너 상태 |
