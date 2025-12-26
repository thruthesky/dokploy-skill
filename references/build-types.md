# Dokploy 빌드 타입 가이드

## 목차

1. [빌드 타입 비교](#빌드-타입-비교)
2. [Nixpacks (기본값)](#nixpacks-기본값)
3. [Railpack (신규)](#railpack-신규)
4. [Dockerfile](#dockerfile)
5. [Buildpack](#buildpack)
6. [Static (정적 사이트)](#static-정적-사이트)
7. [권장 사용 시나리오](#권장-사용-시나리오)

---

## 빌드 타입 비교

| 빌드 타입 | 특징 | 사용 시나리오 |
|----------|------|-------------|
| **Nixpacks** | 자동 감지, 간편함 | 대부분의 프로젝트, 프로토타입 |
| **Railpack** | 현대적, 최적화 | Node.js, Python, Go, PHP |
| **Dockerfile** | 완전한 제어 | 복잡한 빌드, 특수 요구사항 |
| **Heroku Buildpack** | Heroku 호환 | Heroku 마이그레이션 |
| **Paketo Buildpack** | 클라우드 네이티브 | 엔터프라이즈 환경 |
| **Static** | NGINX 최적화 | 정적 사이트, SPA |

---

## Nixpacks (기본값)

Dokploy의 기본 빌드 타입으로, 프로젝트를 자동으로 감지하고 빌드합니다.

### 주요 환경 변수

| 변수 | 설명 | 예시 |
|------|------|------|
| `NIXPACKS_INSTALL_CMD` | 설치 명령어 재정의 | `npm ci --legacy-peer-deps` |
| `NIXPACKS_BUILD_CMD` | 빌드 명령어 재정의 | `npm run build:prod` |
| `NIXPACKS_START_CMD` | 시작 명령어 재정의 | `node server.js` |
| `NIXPACKS_PKGS` | 추가 Nix 패키지 | `ffmpeg imagemagick` |
| `NIXPACKS_APT_PKGS` | 추가 Apt 패키지 | `libssl-dev libpq-dev` |
| `NIXPACKS_NO_CACHE` | 캐싱 비활성화 | `1` |

### 정적 사이트 배포

Nixpacks로 정적 사이트 배포 시 `Publish Directory` 필드를 사용합니다:

```
# Astro 프로젝트
Publish Directory: dist

# Next.js (정적 내보내기)
Publish Directory: out

# React (Vite)
Publish Directory: dist
```

Dokploy가 자동으로 NGINX 최적화 Dockerfile로 실행합니다.

---

## Railpack (신규)

Nixpacks의 후속 버전으로, 최적화된 현대적 빌드 환경을 제공합니다.

### 지원 언어

- Node.js
- Python
- Go
- PHP
- StaticFile
- Shell Scripts

### 주요 환경 변수

| 변수 | 설명 | 예시 |
|------|------|------|
| `RAILPACK_BUILD_CMD` | 빌드 단계 명령어 | `npm run build` |
| `RAILPACK_START_CMD` | 시작 명령어 | `npm start` |
| `RAILPACK_PACKAGES` | Mise 패키지 | `node@20 pnpm@8` |
| `RAILPACK_BUILD_APT_PACKAGES` | 빌드용 Apt 패키지 | `build-essential` |
| `RAILPACK_DEPLOY_APT_PACKAGES` | 배포용 Apt 패키지 | `libpq5` |

### 버전 고정

애플리케이션 설정에서 `Railpack Version` 필드로 특정 버전을 고정할 수 있습니다:

```
Railpack Version: 0.15.1
```

이렇게 하면 일관된 빌드 결과를 보장합니다.

---

## Dockerfile

자신의 Dockerfile로 완전한 빌드 제어가 가능합니다.

### 기본 설정

| 필드 | 설명 | 예시 |
|------|------|------|
| `Dockerfile Path` | Dockerfile 경로 (필수) | `Dockerfile`, `docker/Dockerfile.prod` |
| `Docker Context Path` | 빌드 컨텍스트 경로 | `.` |
| `Docker Build Stage` | 멀티스테이지 빌드 시 타겟 | `production` |

### Build Arguments (빌드 인자)

Dockerfile의 `ARG`에 값을 전달합니다:

```dockerfile
# Dockerfile
ARG NODE_VERSION=20
ARG APP_ENV=production

FROM node:${NODE_VERSION}-alpine
ENV NODE_ENV=${APP_ENV}
```

Dokploy 설정:
```
NODE_VERSION=20
APP_ENV=production
```

### Build Secrets (빌드 시크릿)

민감 정보를 안전하게 전달합니다 (최종 이미지에 노출되지 않음):

```dockerfile
# Dockerfile
RUN --mount=type=secret,id=npm_token \
    NPM_TOKEN=$(cat /run/secrets/npm_token) \
    npm install
```

**장점:** API 토큰, 비밀번호 등이 이미지 레이어에 남지 않습니다.

### 멀티스테이지 빌드 예시

```dockerfile
# 빌드 스테이지
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# 프로덕션 스테이지
FROM node:20-alpine AS production
WORKDIR /app
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
EXPOSE 3000
CMD ["node", "dist/main.js"]
```

Dokploy에서 `Docker Build Stage: production` 설정

---

## Buildpack

### Heroku Buildpack

Heroku 플랫폼에서 마이그레이션할 때 호환성을 제공합니다.

```
# 버전 지정 (기본값: 24)
Buildpack Version: 24
```

### Paketo Buildpack

클라우드 네이티브 표준과 현대적 관행을 활용한 빌드팩입니다.

**장점:**
- 보안 패치 자동 적용
- 빌드 캐싱 최적화
- 다양한 언어 지원

---

## Static (정적 사이트)

정적 콘텐츠를 NGINX로 최적화하여 배포합니다.

### 작동 방식

Root 디렉토리의 모든 파일을 `/usr/share/nginx/html`에 마운트하여 제공합니다.

### 도메인 설정

**중요:** 도메인 설정 시 **포트 80**을 사용해야 합니다.

```
Container Port: 80
```

### 적합한 프로젝트

- HTML/CSS/JS 정적 사이트
- 빌드된 SPA (React, Vue, Angular)
- 문서 사이트 (Docusaurus, VitePress)
- 랜딩 페이지

---

## 권장 사용 시나리오

| 상황 | 권장 빌드 타입 |
|------|--------------|
| 빠른 프로토타입 | **Nixpacks** |
| Node.js/Python 프로젝트 | **Nixpacks** 또는 **Railpack** |
| 복잡한 의존성 | **Dockerfile** |
| Heroku에서 마이그레이션 | **Heroku Buildpack** |
| 정적 사이트 | **Static** 또는 **Nixpacks + Publish Directory** |
| 완전한 제어 필요 | **Dockerfile** |

---

## 빌드 타입 선택 플로우차트

```
시작
  │
  ├─ 정적 사이트인가? ─── Yes ──→ Static 또는 Nixpacks + Publish Directory
  │
  No
  │
  ├─ Dockerfile이 있는가? ─── Yes ──→ Dockerfile
  │
  No
  │
  ├─ Heroku에서 왔는가? ─── Yes ──→ Heroku Buildpack
  │
  No
  │
  ├─ 특수 패키지가 필요한가? ─── Yes ──→ Nixpacks + NIXPACKS_PKGS
  │
  No
  │
  └─ 기본값 사용 ──→ Nixpacks
```
