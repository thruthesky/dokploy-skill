# Dokploy Supabase 셀프호스팅 관리 가이드

## 목차

1. [환경변수 설정 방법](#환경변수-설정-방법)
2. [이메일 서비스 비활성화](#이메일-서비스-비활성화)
3. [Studio Auth Config 업데이트 에러](#studio-auth-config-업데이트-에러)
4. [주요 환경변수 목록](#주요-환경변수-목록)
5. [컨테이너 구성](#컨테이너-구성)
6. [문제 해결](#문제-해결)

---

## 환경변수 설정 방법

> **⚠️ 필수 규칙: Supabase 설정 변경은 반드시 Dokploy 웹 UI → Environment 탭에서 수행합니다.**

Supabase의 모든 설정은 Docker Compose의 `${VAR}` 환경변수 참조를 통해 관리됩니다.
설정을 변경할 때 서버의 `.env` 파일을 직접 수정하면 다음 재배포 시 Dokploy가 덮어씁니다.

### 설정 변경 절차

1. **Dokploy 대시보드** 접속 → 해당 Compose 서비스 페이지로 이동
2. **Environment** 탭 클릭
3. 변경할 환경변수 값 수정
4. **Save** 클릭
5. **General** 탭 → **Deploy** 버튼 클릭 (재배포 필수)

### Studio UI에서 설정 변경 불가

Supabase Studio의 셀프호스팅 버전에서는 일부 설정 변경 시 `405 Method Not Allowed` 에러가 발생합니다.
**Studio UI 대신 Dokploy 웹 UI의 Environment 탭에서 환경변수를 직접 수정하세요.**

---

## 이메일 서비스 비활성화

### 문제

Supabase 셀프호스팅 기본 Compose에는 `supabase-mail` (Inbucket) 서비스가 포함되지 않은 경우가 많습니다.
이 경우 Auth(GoTrue) 서비스에서 이메일 전송 시 DNS 해석 실패 에러가 발생합니다:

```
"error":"dial tcp: lookup supabase-mail on 127.0.0.11:53: server misbehaving"
```

### 해결: 이메일 자동확인 활성화

이메일 서비스를 사용하지 않으려면 아래 환경변수를 변경합니다:

| 환경변수 | 변경 전 | 변경 후 | 설명 |
|---------|--------|--------|------|
| `ENABLE_EMAIL_AUTOCONFIRM` | `false` | `true` | 가입 시 이메일 확인 건너뛰고 즉시 계정 활성화 |

**변경 위치:** Dokploy 웹 UI → 해당 Compose 서비스 → **Environment** 탭

### 효과

- `ENABLE_EMAIL_AUTOCONFIRM=true` → 가입 시 확인 이메일을 **보내지 않음** (즉시 계정 활성화)
- SMTP 서버(`supabase-mail`)가 없어도 회원가입 정상 작동
- `supabase-mail` DNS 해석 실패 에러 해소

### GoTrue 환경변수 매핑

Docker Compose에서 `.env`의 변수가 GoTrue 환경변수로 매핑되는 구조:

```yaml
# docker-compose.yml (auth 서비스)
environment:
  GOTRUE_MAILER_AUTOCONFIRM: ${ENABLE_EMAIL_AUTOCONFIRM}  # .env의 값 참조
  GOTRUE_SMTP_HOST: ${SMTP_HOST}
  GOTRUE_SMTP_PORT: ${SMTP_PORT}
```

---

## Studio Auth Config 업데이트 에러

### 증상

Supabase Studio에서 Auth > Email 설정을 변경하고 저장할 때:

```
Failed to update auth configuration: API error happened while trying to communicate with the server.
```

### 원인

Studio의 Next.js API route (`/api/platform/auth/[ref]/config`)가 PUT 메서드를 지원하지 않아 **405 Method Not Allowed** 반환.
셀프호스팅 Studio 이미지 버전(`supabase/studio:2025.04.21-sha-173cc56` 등)의 호환성 문제입니다.

### 해결

**Studio UI에서 Auth 설정을 변경하지 마세요.**
대신 Dokploy 웹 UI → **Environment** 탭에서 GoTrue 관련 환경변수를 직접 수정하고 재배포합니다.

---

## 주요 환경변수 목록

### 인증 관련

| 환경변수 | 기본값 | 설명 |
|---------|-------|------|
| `ENABLE_EMAIL_AUTOCONFIRM` | `false` | `true`: 이메일 확인 건너뛰기 (SMTP 불필요) |
| `ENABLE_EMAIL_SIGNUP` | `true` | 이메일 기반 회원가입 허용 여부 |
| `ENABLE_PHONE_SIGNUP` | `true` | 전화번호 기반 회원가입 허용 여부 |
| `ENABLE_PHONE_AUTOCONFIRM` | `true` | 전화번호 자동확인 |
| `ENABLE_ANONYMOUS_USERS` | `false` | 익명 사용자 허용 여부 |
| `DISABLE_SIGNUP` | `false` | 전체 회원가입 비활성화 |

### SMTP 관련

| 환경변수 | 기본값 | 설명 |
|---------|-------|------|
| `SMTP_HOST` | `supabase-mail` | SMTP 서버 호스트 |
| `SMTP_PORT` | `2500` | SMTP 포트 |
| `SMTP_USER` | `fake_mail_user` | SMTP 사용자 |
| `SMTP_PASS` | `fake_mail_password` | SMTP 비밀번호 |
| `SMTP_ADMIN_EMAIL` | `admin@example.com` | 관리자 이메일 |
| `SMTP_SENDER_NAME` | `fake_sender` | 발신자 이름 |

### JWT / 보안

| 환경변수 | 설명 |
|---------|------|
| `JWT_SECRET` | JWT 서명 키 (모든 서비스에서 공유) |
| `JWT_EXPIRY` | JWT 만료 시간 (초, 기본 3600) |
| `ANON_KEY` | 익명 사용자용 API 키 |
| `SERVICE_ROLE_KEY` | 서비스 역할 API 키 (admin 권한) |

### URL / 네트워크

| 환경변수 | 설명 |
|---------|------|
| `SUPABASE_PUBLIC_URL` | 외부 접속 URL (Studio에서 사용) |
| `API_EXTERNAL_URL` | API 외부 URL |
| `SITE_URL` | 사이트 URL (리다이렉트 기준) |
| `ADDITIONAL_REDIRECT_URLS` | 추가 허용 리다이렉트 URL (쉼표 구분) |

### 데이터베이스

| 환경변수 | 설명 |
|---------|------|
| `POSTGRES_PASSWORD` | PostgreSQL 비밀번호 |
| `POSTGRES_HOST` | DB 호스트 (기본: `db`) |
| `POSTGRES_PORT` | DB 포트 (기본: `5432`) |
| `POSTGRES_DB` | DB 이름 (기본: `postgres`) |

---

## 컨테이너 구성

### 표준 Supabase Docker Compose 서비스

| 서비스 | 이미지 | 포트 | 역할 |
|--------|-------|------|------|
| `studio` | `supabase/studio` | 3000 | 관리 대시보드 (Next.js) |
| `kong` | `kong:2.8.1` | 8000/8443 | API Gateway |
| `auth` | `supabase/gotrue` | 9999 | 인증 서비스 (GoTrue) |
| `rest` | `postgrest/postgrest` | 3000 | RESTful API |
| `realtime` | `supabase/realtime` | 4000 | 실시간 구독 |
| `storage` | `supabase/storage-api` | 5000 | 파일 스토리지 |
| `meta` | `supabase/postgres-meta` | 8080 | DB 메타데이터 API |
| `functions` | `supabase/edge-runtime` | 9000 | Edge Functions |
| `analytics` | `supabase/logflare` | 4000 | 로그/분석 |
| `db` | `supabase/postgres` | 5432 | PostgreSQL |
| `vector` | `timberio/vector` | - | 로그 수집 |
| `supavisor` | `supabase/supavisor` | 5432/6543 | 커넥션 풀러 |

### Kong API 라우팅

| 경로 | 대상 서비스 | 인증 |
|------|-----------|------|
| `/auth/v1/*` | `auth:9999` | API Key (anon/admin) |
| `/rest/v1/*` | `rest:3000` | API Key (anon/admin) |
| `/storage/v1/*` | `storage:5000` | 없음 (자체 관리) |
| `/realtime/v1/*` | `realtime:4000` | API Key (anon/admin) |
| `/functions/v1/*` | `functions:9000` | 없음 |
| `/pg/*` | `meta:8080` | API Key (admin만) |
| `/*` (기타) | `studio:3000` | Basic Auth |

---

## 문제 해결

### 이메일 전송 실패 (`supabase-mail` DNS 에러)

**증상:** 회원가입 시 500 에러, Auth 로그에 `lookup supabase-mail ... server misbehaving`

**원인:** `supabase-mail` 컨테이너가 Compose에 포함되지 않음

**해결:** `ENABLE_EMAIL_AUTOCONFIRM=true`로 설정 (Dokploy 웹 UI → Environment)

### Studio에서 Auth 설정 변경 실패

**증상:** "Failed to update auth configuration" 에러

**원인:** Studio API route가 PUT 메서드 미지원 (405)

**해결:** Studio 대신 Dokploy 웹 UI → Environment에서 직접 환경변수 수정

### 회원가입 후 로그인 불가

**증상:** 가입은 되지만 로그인 시 "Invalid login credentials"

**원인:** `ENABLE_EMAIL_AUTOCONFIRM=false`일 때 이메일 확인이 안 되어 계정 미활성화

**해결:** `ENABLE_EMAIL_AUTOCONFIRM=true`로 변경 후 재배포
