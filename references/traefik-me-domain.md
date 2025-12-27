# traefik.me를 사용한 Dokploy 도메인 설정

DNS 설정 없이 즉시 사용 가능한 와일드카드 도메인 서비스입니다.

## traefik.me란?

traefik.me는 **마법 도메인** 서비스로, IP 주소를 도메인에 포함시키면 해당 IP로 자동 resolve됩니다.

| 도메인 예시 | Resolve 결과 |
|------------|-------------|
| `10.0.0.1.traefik.me` | 10.0.0.1 |
| `www.10.0.0.1.traefik.me` | 10.0.0.1 |
| `myapp.209.97.169.136.traefik.me` | 209.97.169.136 |
| `api.209-97-169-136.traefik.me` | 209.97.169.136 |

**장점:**
- DNS 설정 불필요
- 즉시 사용 가능
- 개발/테스트 환경에 적합
- 무료

---

## Dokploy에서 traefik.me 도메인 설정

### 1단계: 도메인 형식 결정

Dokploy 서버 IP가 `209.97.169.136`인 경우:

```
# 점(.) 방식 - 권장
myapp.209.97.169.136.traefik.me

# 대시(-) 방식
myapp.209-97-169-136.traefik.me
```

### 2단계: Dokploy 대시보드에서 도메인 추가

1. **Dokploy 대시보드** 접속
2. **프로젝트** → **애플리케이션** 선택
3. **Domains** 탭 클릭
4. **Add Domain** 버튼 클릭
5. 다음 정보 입력:

| 항목 | 값 | 설명 |
|------|-----|------|
| **Host** | `myapp.209.97.169.136.traefik.me` | 앱 이름 + IP + traefik.me |
| **HTTPS** | ❌ 비활성화 | traefik.me는 HTTP만 지원 |
| **Port** | `80` 또는 앱 포트 | 애플리케이션 포트 |
| **Path** | `/` | 기본값 |

6. **Create** 버튼 클릭

### 3단계: 접속 테스트

```bash
# HTTP로 접속 테스트
curl http://myapp.209.97.169.136.traefik.me

# 또는 브라우저에서 접속
# http://myapp.209.97.169.136.traefik.me
```

---

## API를 통한 도메인 설정

```bash
# 환경 변수 설정
DOKPLOY_SERVER_URL="http://209.97.169.136:3000"
DOKPLOY_API_KEY="your-api-key"
APPLICATION_ID="your-app-id"

# traefik.me 도메인 추가
curl -X 'POST' \
  "${DOKPLOY_SERVER_URL}/api/domain.create" \
  -H 'Content-Type: application/json' \
  -H "x-api-key: ${DOKPLOY_API_KEY}" \
  -d '{
    "applicationId": "'${APPLICATION_ID}'",
    "host": "myapp.209.97.169.136.traefik.me",
    "https": false,
    "port": 80,
    "path": "/",
    "certificateType": "none"
  }'
```

---

## 여러 앱에 도메인 설정 예시

Dokploy 서버 IP: `209.97.169.136`

| 애플리케이션 | traefik.me 도메인 |
|-------------|------------------|
| 웹 앱 | `web.209.97.169.136.traefik.me` |
| API 서버 | `api.209.97.169.136.traefik.me` |
| 어드민 패널 | `admin.209.97.169.136.traefik.me` |
| 개발 환경 | `dev.209.97.169.136.traefik.me` |
| 스테이징 | `staging.209.97.169.136.traefik.me` |

---

## 주의사항

### HTTPS 지원 불가

traefik.me는 **HTTP만 지원**합니다. SSL 인증서가 필요한 경우:
- 실제 도메인을 구매하고 Let's Encrypt 사용
- Cloudflare를 통한 SSL 프록시 사용

### 개발/테스트 용도로 권장

- 프로덕션 환경에서는 실제 도메인 사용 권장
- 민감한 데이터는 HTTPS가 지원되는 도메인 사용

### DNS Resolve 확인

```bash
# 도메인이 올바르게 resolve 되는지 확인
dig myapp.209.97.169.136.traefik.me +short
# 출력: 209.97.169.136

# 또는 nslookup 사용
nslookup myapp.209.97.169.136.traefik.me
```

---

## 문제 해결

### 접속 안 됨

1. **포트 확인**: 애플리케이션이 올바른 포트에서 실행 중인지 확인
2. **방화벽 확인**: 80 포트가 열려 있는지 확인
3. **Traefik 상태 확인**:
   ```bash
   ssh root@209.97.169.136 "docker ps | grep traefik"
   ```

### 502 Bad Gateway

- 애플리케이션이 실행 중인지 확인
- 애플리케이션이 `0.0.0.0`에서 수신 대기하는지 확인
- 컨테이너 로그 확인:
  ```bash
  ssh root@209.97.169.136 "docker service logs <service-name> --tail 50"
  ```

---

## 요약

| 단계 | 설명 |
|------|------|
| 1 | 도메인 형식 결정: `앱이름.서버IP.traefik.me` |
| 2 | Dokploy 대시보드 → Domains → Add Domain |
| 3 | HTTPS 비활성화, 포트 설정 |
| 4 | 저장 후 HTTP로 접속 테스트 |

**예시:**
- 서버 IP: `209.97.169.136`
- 앱 이름: `myapp`
- 도메인: `http://myapp.209.97.169.136.traefik.me`
