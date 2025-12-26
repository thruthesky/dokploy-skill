# Cloudflare 도메인 설정 가이드

## 목차

1. [SSL 모드 개요](#ssl-모드-개요)
2. [Full (Strict) 모드 설정](#full-strict-모드-설정)
3. [Flexible 모드 설정](#flexible-모드-설정)
4. [주의사항](#주의사항)

---

## SSL 모드 개요

Cloudflare는 5가지 SSL 암호화 모드를 제공합니다:

| 모드 | 설명 | 보안 수준 |
|------|------|----------|
| **Off** | 암호화 미적용 | 없음 |
| **Flexible** | Cloudflare ↔ 방문자 간만 암호화 | 낮음 |
| **Full** | 종단 간 암호화 (자체 서명 인증서 허용) | 중간 |
| **Full (Strict)** | 종단 간 암호화 + 원본 인증서 검증 | 높음 |
| **Strict (SSL-Only Origin Pull)** | 원본 서버 암호화 강제 | 최고 |

**권장:** 프로덕션 환경에서는 **Full (Strict)** 사용

---

## SSL 모드 변경 방법

1. Cloudflare 대시보드 접속
2. Account Home → 도메인 선택
3. SSL/TLS → Overview
4. Configure SSL/TLS Encryption
5. 원하는 모드 선택 후 저장

---

## Full (Strict) 모드 설정

### 중요: 단계별 순서 준수 필수

인증서 생성 방식은 두 가지가 있습니다:

### 방식 1: Let's Encrypt (권장)

**장점:** 자동 갱신, 간편한 설정

**단계:**

1. **Cloudflare DNS 설정**
   ```
   Type: A
   Name: api (또는 원하는 서브도메인)
   Content: 서버 IP (예: 1.2.3.4)
   Proxy status: Proxied (주황색 구름)
   ```

2. **Dokploy 도메인 설정**
   - Domains → Create Domain
   - Host: `api.dokploy.com`
   - HTTPS: **ON**
   - Certificate: **Let's Encrypt**

3. **인증서 발급 대기** (보통 1-2분)

### 방식 2: Cloudflare Origin CA

**장점:** 최대 15년 유효, 갱신 불필요

**단계:**

1. **Cloudflare에서 인증서 생성**
   - SSL/TLS → Origin Server
   - Create Certificate 클릭
   - 호스트명 입력 (예: `*.example.com`, `example.com`)
   - 유효기간 선택 (최대 15년)
   - Create 클릭

2. **인증서 정보 복사**
   - Origin Certificate (PEM 형식)
   - Private Key (PEM 형식)

   **경고: Private Key는 이 시점에만 표시됩니다. 반드시 저장하세요!**

3. **Dokploy에 인증서 등록**
   - Settings → Certificates
   - Add Certificate
   - 인증서와 개인키 붙여넣기

4. **Dokploy 도메인 설정**
   - Domains → Create Domain
   - Host: `api.example.com`
   - HTTPS: **ON**
   - Certificate: **None** (등록한 인증서가 자동 적용)

---

## Flexible 모드 설정

**주의:** 원본 서버와 Cloudflare 간 트래픽이 암호화되지 않습니다.

**단계:**

1. **Cloudflare DNS 설정**
   ```
   Type: A
   Name: api
   Content: 서버 IP
   Proxy status: Proxied
   ```

2. **Dokploy 도메인 설정**
   - Domains → Create Domain
   - Host: `api.example.com`
   - HTTPS: **OFF**
   - Certificate: **None**

---

## 주의사항

### 컨테이너 포트 구분

| 설정 위치 | 용도 |
|----------|------|
| Domains → Container Port | Traefik 내부 라우팅 (외부 노출 안됨) |
| Advanced → Ports | 호스트 포트 직접 노출 |

**중요:** 도메인 설정의 Container Port는 앱의 실제 수신 포트와 일치해야 합니다.

### 무료 Cloudflare 계정 제한

| 지원 | 미지원 |
|------|--------|
| `example.com` | `staging.api.example.com` |
| `api.example.com` | (서브-서브도메인) |

**해결:** 서브-서브도메인이 필요하면 유료 플랜 사용 또는 별도 도메인 사용

### 인증서 호스트명 일치

Origin CA 사용 시 인증서의 호스트명과 도메인이 정확히 일치해야 합니다:

```
# 인증서: *.example.com
api.example.com      # 작동
www.example.com      # 작동
staging.example.com  # 작동

# 인증서: example.com
example.com          # 작동
api.example.com      # 작동 안함 (와일드카드 필요)
```

---

## 빠른 설정 체크리스트

### Full (Strict) + Let's Encrypt

- [ ] Cloudflare에 A 레코드 추가 (Proxied)
- [ ] Dokploy에서 HTTPS ON
- [ ] Certificate: Let's Encrypt 선택
- [ ] 도메인 접속 테스트

### Full (Strict) + Origin CA

- [ ] Cloudflare에서 Origin CA 인증서 생성
- [ ] 인증서와 개인키 안전하게 저장
- [ ] Dokploy Settings에 인증서 등록
- [ ] Dokploy에서 HTTPS ON, Certificate: None
- [ ] 도메인 접속 테스트

### Flexible

- [ ] Cloudflare에 A 레코드 추가 (Proxied)
- [ ] Dokploy에서 HTTPS OFF
- [ ] Certificate: None 선택
- [ ] 도메인 접속 테스트
