# Dokploy API 사용방법

Dokploy는 RESTful API를 제공하여 애플리케이션 배포, 관리 및 모니터링을 자동화할 수 있습니다. 이 문서에서는 Dokploy API의 주요 기능과 사용법을 안내합니다.

**공식 문서**: https://docs.dokploy.com/docs/api

---

## 센터 프로젝트 API 설정

> **참고**: 센터 프로젝트의 Dokploy API 설정은 `.claude/skills/center-skill/scripts/config.sh`에 정의되어 있습니다.

### 주요 설정 값

| 변수 | 설명 |
|------|------|
| `DOKPLOY_URL` | `http://209.97.169.136:3000` |
| `DOKPLOY_APP_ID` | `DYmNZmKYtRG0RdNrsGcfn` |
| `DOKPLOY_API_KEY` | config.sh 파일 참조 |

### 공통 API 함수 (config.sh)

```bash
# Dokploy API 호출 함수
dokploy_api() {
  local endpoint="$1"
  curl -s "$DOKPLOY_URL$endpoint" -H "x-api-key: $DOKPLOY_API_KEY"
}

# 배포 목록 가져오기
get_deployments() {
  dokploy_api "/api/deployment.all?applicationId=$DOKPLOY_APP_ID"
}

# 최신 배포 정보 가져오기
get_latest_deployment() {
  get_deployments | jq -r '.[0]'
}

# 최신 배포 상태 가져오기
get_latest_status() {
  get_deployments | jq -r '.[0].status'
}
```

### 센터 프로젝트 API 사용 예시

```bash
# 설정 파일 로드
source ./.claude/skills/center-skill/scripts/config.sh

# 배포 목록 조회
get_deployments | jq '.[] | {status, createdAt, title}'

# 최신 배포 상태 확인
get_latest_status
```

---

## 1. API 인증 (Authentication)

### 1.1 API 토큰 생성

Dokploy API는 **JWT 토큰 기반 인증**을 사용합니다.

**토큰 생성 방법:**
1. Dokploy 대시보드에 로그인
2. `/settings/profile` 페이지로 이동
3. **API/CLI** 섹션에서 토큰 생성 버튼 클릭
4. 생성된 토큰을 안전한 곳에 저장

### 1.2 인증 헤더

모든 API 요청에 다음 헤더를 포함해야 합니다:

```
x-api-key: YOUR-GENERATED-API-KEY
```

---

## 2. API 기본 정보

| 항목 | 값 |
|------|-----|
| **Base URL** | `https://your-dokploy-domain.com/api` |
| **인증 방식** | API Key (헤더: `x-api-key`) |
| **응답 형식** | JSON |
| **Swagger UI** | `https://your-dokploy-domain.com/swagger` |

---

## 3. 접근 권한

### 3.1 관리자 (Admin)
- Swagger UI에서 직접 API 테스트 가능
- 모든 API 엔드포인트 접근 가능
- 기본적으로 인증된 관리자만 접근

### 3.2 일반 사용자
- 기본적으로 API 접근 **불가**
- 관리자가 부여할 수 있는 권한:
  - 접근 토큰 생성 권한
  - Swagger UI 접근 권한

---

## 4. 주요 API 엔드포인트

### 4.1 프로젝트 API (Project)

#### 모든 프로젝트 조회
```bash
curl -X 'GET' \
  'https://your-domain.com/api/project.all' \
  -H 'accept: application/json' \
  -H 'x-api-key: YOUR-API-KEY'
```

#### 프로젝트 생성
```bash
curl -X 'POST' \
  'https://your-domain.com/api/project.create' \
  -H 'Content-Type: application/json' \
  -H 'x-api-key: YOUR-API-KEY' \
  -d '{
    "name": "my-project",
    "description": "프로젝트 설명"
  }'
```

---

### 4.2 애플리케이션 API (Application)

#### 애플리케이션 생성
```bash
curl -X 'POST' \
  'https://your-domain.com/api/application.create' \
  -H 'Content-Type: application/json' \
  -H 'x-api-key: YOUR-API-KEY' \
  -d '{
    "name": "my-app",
    "projectId": "project-id-here",
    "appName": "my-app"
  }'
```

#### 애플리케이션 시작
```bash
curl -X 'POST' \
  'https://your-domain.com/api/application.start' \
  -H 'Content-Type: application/json' \
  -H 'x-api-key: YOUR-API-KEY' \
  -d '{
    "applicationId": "app-id-here"
  }'
```

#### 애플리케이션 중지
```bash
curl -X 'POST' \
  'https://your-domain.com/api/application.stop' \
  -H 'Content-Type: application/json' \
  -H 'x-api-key: YOUR-API-KEY' \
  -d '{
    "applicationId": "app-id-here"
  }'
```

#### 애플리케이션 재배포
```bash
curl -X 'POST' \
  'https://your-domain.com/api/application.redeploy' \
  -H 'Content-Type: application/json' \
  -H 'x-api-key: YOUR-API-KEY' \
  -d '{
    "applicationId": "app-id-here"
  }'
```

#### 환경 변수 저장
```bash
curl -X 'POST' \
  'https://your-domain.com/api/application.saveEnvironment' \
  -H 'Content-Type: application/json' \
  -H 'x-api-key: YOUR-API-KEY' \
  -d '{
    "applicationId": "app-id-here",
    "env": "KEY1=value1\nKEY2=value2"
  }'
```

#### 빌드 타입 설정
```bash
curl -X 'POST' \
  'https://your-domain.com/api/application.saveBuildType' \
  -H 'Content-Type: application/json' \
  -H 'x-api-key: YOUR-API-KEY' \
  -d '{
    "applicationId": "app-id-here",
    "buildType": "dockerfile"
  }'
```

**지원되는 빌드 타입:**
- `dockerfile` - Dockerfile 사용
- `heroku_buildpacks` - Heroku 빌드팩
- `paketo_buildpacks` - Paketo 빌드팩
- `nixpacks` - Nixpacks
- `static` - 정적 파일
- `railpack` - Rails용 빌드팩

---

### 4.3 데이터베이스 API

#### PostgreSQL 생성
```bash
curl -X 'POST' \
  'https://your-domain.com/api/postgres.create' \
  -H 'Content-Type: application/json' \
  -H 'x-api-key: YOUR-API-KEY' \
  -d '{
    "name": "my-postgres",
    "projectId": "project-id-here",
    "databaseName": "mydb",
    "databaseUser": "admin",
    "databasePassword": "secure-password"
  }'
```

#### MySQL 생성
```bash
curl -X 'POST' \
  'https://your-domain.com/api/mysql.create' \
  -H 'Content-Type: application/json' \
  -H 'x-api-key: YOUR-API-KEY' \
  -d '{
    "name": "my-mysql",
    "projectId": "project-id-here",
    "databaseName": "mydb",
    "databaseRootPassword": "root-password",
    "databaseUser": "admin",
    "databasePassword": "secure-password"
  }'
```

#### MongoDB 생성
```bash
curl -X 'POST' \
  'https://your-domain.com/api/mongo.create' \
  -H 'Content-Type: application/json' \
  -H 'x-api-key: YOUR-API-KEY' \
  -d '{
    "name": "my-mongo",
    "projectId": "project-id-here",
    "databaseUser": "admin",
    "databasePassword": "secure-password"
  }'
```

#### Redis 생성
```bash
curl -X 'POST' \
  'https://your-domain.com/api/redis.create' \
  -H 'Content-Type: application/json' \
  -H 'x-api-key: YOUR-API-KEY' \
  -d '{
    "name": "my-redis",
    "projectId": "project-id-here"
  }'
```

---

### 4.4 도메인 API

#### 도메인 생성
```bash
curl -X 'POST' \
  'https://your-domain.com/api/domain.create' \
  -H 'Content-Type: application/json' \
  -H 'x-api-key: YOUR-API-KEY' \
  -d '{
    "applicationId": "app-id-here",
    "host": "myapp.example.com",
    "https": true,
    "certificateType": "letsencrypt"
  }'
```

---

### 4.5 배포 API (Deployment)

#### 배포 목록 조회
```bash
curl -X 'GET' \
  'https://your-domain.com/api/deployment.all?applicationId=app-id-here' \
  -H 'accept: application/json' \
  -H 'x-api-key: YOUR-API-KEY'
```

---

## 5. Swagger UI 사용법

Swagger UI를 통해 API를 시각적으로 테스트할 수 있습니다.

### 접속 방법
1. 브라우저에서 `https://your-dokploy-domain.com/swagger` 접속
2. Dokploy 계정으로 로그인
3. "Authorize" 버튼 클릭
4. API 키 입력

### Swagger UI 기능
- 모든 사용 가능한 API 엔드포인트 목록 확인
- 각 엔드포인트의 파라미터와 응답 형식 확인
- "Try it out" 버튼으로 실시간 API 테스트
- 요청/응답 예제 확인

---

## 6. 에러 처리

### 일반적인 HTTP 상태 코드

| 상태 코드 | 설명 |
|-----------|------|
| `200` | 성공 |
| `201` | 생성 성공 |
| `400` | 잘못된 요청 (파라미터 오류) |
| `401` | 인증 실패 (API 키 누락 또는 유효하지 않음) |
| `403` | 권한 없음 |
| `404` | 리소스를 찾을 수 없음 |
| `500` | 서버 내부 오류 |

### 401 Unauthorized 해결 방법

1. **API 키 확인**: `x-api-key` 헤더가 올바르게 설정되었는지 확인
2. **토큰 유효성**: 토큰이 만료되지 않았는지 확인
3. **권한 확인**: 해당 API에 접근할 권한이 있는지 확인

---

## 7. 실용적인 사용 예제

### 7.1 새 프로젝트와 애플리케이션 배포 (전체 플로우)

```bash
# 환경 변수 설정
export DOKPLOY_API_KEY="your-api-key"
export DOKPLOY_URL="https://your-dokploy-domain.com/api"

# 1. 프로젝트 생성
PROJECT_RESPONSE=$(curl -s -X 'POST' \
  "${DOKPLOY_URL}/project.create" \
  -H 'Content-Type: application/json' \
  -H "x-api-key: ${DOKPLOY_API_KEY}" \
  -d '{"name": "production-app", "description": "프로덕션 애플리케이션"}')

PROJECT_ID=$(echo $PROJECT_RESPONSE | jq -r '.projectId')
echo "프로젝트 ID: $PROJECT_ID"

# 2. 애플리케이션 생성
APP_RESPONSE=$(curl -s -X 'POST' \
  "${DOKPLOY_URL}/application.create" \
  -H 'Content-Type: application/json' \
  -H "x-api-key: ${DOKPLOY_API_KEY}" \
  -d "{\"name\": \"web-app\", \"projectId\": \"${PROJECT_ID}\", \"appName\": \"web-app\"}")

APP_ID=$(echo $APP_RESPONSE | jq -r '.applicationId')
echo "애플리케이션 ID: $APP_ID"

# 3. 환경 변수 설정
curl -X 'POST' \
  "${DOKPLOY_URL}/application.saveEnvironment" \
  -H 'Content-Type: application/json' \
  -H "x-api-key: ${DOKPLOY_API_KEY}" \
  -d "{\"applicationId\": \"${APP_ID}\", \"env\": \"NODE_ENV=production\nPORT=3000\"}"

# 4. 애플리케이션 배포
curl -X 'POST' \
  "${DOKPLOY_URL}/application.redeploy" \
  -H 'Content-Type: application/json' \
  -H "x-api-key: ${DOKPLOY_API_KEY}" \
  -d "{\"applicationId\": \"${APP_ID}\"}"

echo "배포 완료!"
```

### 7.2 CI/CD 파이프라인 연동 (GitHub Actions 예제)

```yaml
name: Deploy to Dokploy

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Trigger Dokploy Deployment
        run: |
          curl -X 'POST' \
            '${{ secrets.DOKPLOY_URL }}/api/application.redeploy' \
            -H 'Content-Type: application/json' \
            -H 'x-api-key: ${{ secrets.DOKPLOY_API_KEY }}' \
            -d '{"applicationId": "${{ secrets.DOKPLOY_APP_ID }}"}'
```

---

## 8. 주의사항

⚠️ **보안 주의사항:**
- API 키를 코드에 직접 하드코딩하지 마세요
- 환경 변수나 시크릿 매니저를 사용하세요
- API 키가 노출되면 즉시 재생성하세요

⚠️ **API 사용 시 주의:**
- API는 고급 기능을 제공하므로 수행 중인 작업을 충분히 이해해야 합니다
- 의도하지 않은 시스템 변경을 방지하기 위해 테스트 환경에서 먼저 테스트하세요
- Swagger 문서와 실제 API가 다를 수 있으니 항상 최신 문서를 확인하세요

---

## 9. 참고 링크

- [Dokploy 공식 문서](https://docs.dokploy.com/docs/core)
- [Dokploy API 문서](https://docs.dokploy.com/docs/api)
- [Application API 레퍼런스](https://docs.dokploy.com/docs/api/reference-application)
- [Dokploy GitHub](https://github.com/Dokploy/dokploy)
