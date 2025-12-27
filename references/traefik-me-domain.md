# traefik.me를 사용한 Dokploy 도메인 설정

DNS 설정 없이 즉시 사용 가능한 와일드카드 도메인 서비스입니다.

---

## ⚠️ 중요 경고: SSL/HTTPS 지원 불가

**traefik.me 도메인은 SSL 인증서 발급이 불가능합니다!**

| 항목 | 상태 | 설명 |
|------|------|------|
| Let's Encrypt HTTP-01 | ❌ **불가** | 챌린지 실패 |
| Let's Encrypt DNS-01 | ❌ **불가** | DNS 제어권 없음 |
| traefik.me 와일드카드 인증서 | ❌ **중단됨** | 서비스 제공 중단, 기존 인증서 만료/폐지 |
| 자체 서명 인증서 | ⚠️ 가능 | 브라우저 경고 발생 |

### 왜 SSL이 안 되는가?

1. **Let's Encrypt HTTP-01 챌린지 실패**: traefik.me는 와일드카드 DNS 서비스로, Let's Encrypt가 도메인 소유권을 검증할 수 없습니다.

2. **DNS-01 챌린지 불가**: traefik.me의 DNS 레코드를 사용자가 제어할 수 없어 DNS 챌린지가 불가능합니다.

3. **기존 와일드카드 인증서 중단**: traefik.me 운영자(@pyrou)가 더 이상 와일드카드 SSL 인증서를 제공하지 않으며, 기존 인증서들은 만료/폐지되었습니다.

### 반드시 HTTP만 사용하세요

```
✅ 올바른 사용: http://myapp.209.97.169.136.traefik.me
❌ 잘못된 사용: https://myapp.209.97.169.136.traefik.me
```

**HTTPS가 필요한 경우 반드시 실제 도메인을 구매하세요!**

---

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
| **HTTPS** | ❌ **반드시 비활성화** | ⚠️ SSL 인증서 발급 불가! |
| **Certificate** | `none` | 인증서 없음 선택 |
| **Port** | `80` 또는 앱 포트 | 애플리케이션 포트 |
| **Path** | `/` | 기본값 |

> ⚠️ **경고**: HTTPS를 활성화하면 자체 서명 인증서(TRAEFIK DEFAULT CERT)가 사용되어 브라우저에서 보안 경고가 발생합니다. Let's Encrypt 인증서 발급은 절대 불가능합니다!

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

### ❌ HTTPS/SSL 절대 불가

**traefik.me는 HTTP만 지원합니다. SSL 인증서 발급이 절대 불가능합니다!**

- ❌ Let's Encrypt 인증서 발급 불가 (HTTP-01, DNS-01 모두 실패)
- ❌ traefik.me 제공 와일드카드 인증서 중단됨 (만료/폐지)
- ❌ Dokploy에서 HTTPS 활성화하면 자체 서명 인증서만 사용됨 (브라우저 경고)

**SSL이 필요한 경우 대안:**
- 실제 도메인 구매 후 Let's Encrypt 사용 (권장)
- Cloudflare 도메인 + DNS-01 챌린지로 와일드카드 인증서 발급
- sslip.io 또는 nip.io 사용 (개별 HTTP-01 챌린지 가능)

### 개발/테스트 용도로만 사용

- ⚠️ **프로덕션 환경에서는 절대 사용 금지**
- ⚠️ 민감한 데이터 전송 시 반드시 실제 도메인 + HTTPS 사용
- ⚠️ 로그인, 결제 등 보안이 필요한 기능은 HTTPS 필수

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
