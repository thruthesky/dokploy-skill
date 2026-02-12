# OpenClaw (Moltbot) Dokploy 배포 레퍼런스

## 목차

0. [⛔ 설치 전 필수 사전 정보 (반드시 먼저 확인!)](#0-설치-전-필수-사전-정보)
1. [핵심 개념](#1-핵심-개념)
2. [아키텍처 및 포트](#2-아키텍처-및-포트)
3. [Docker Compose YAML](#3-docker-compose-yaml)
4. [Gateway Token 설정](#4-gateway-token-설정)
5. [Dokploy API를 통한 자동 설치](#5-dokploy-api를-통한-자동-설치)
6. [도메인 및 HTTPS 설정](#6-도메인-및-https-설정)
7. [Device Pairing (기기 승인)](#7-device-pairing-기기-승인)
8. [API 키 및 모델 Provider 설정](#8-api-키-및-모델-provider-설정)
9. [템플릿 파일 생성](#9-템플릿-파일-생성)
10. [트러블슈팅](#10-트러블슈팅)
11. [서버 SSH를 통한 전체 설정 스크립트](#11-서버-ssh를-통한-전체-설정-스크립트)
12. [Dokploy API 자동화 전체 스크립트](#12-dokploy-api-자동화-전체-스크립트)

---

## 0. ⛔ 설치 전 필수 사전 정보 (반드시 먼저 확인!)

> **⛔⛔⛔ 경고: 아래 6가지 정보 없이는 설치를 절대 시작하지 마세요! ⛔⛔⛔**
>
> 이 정보가 불완전하면 설치 중간에 막혀서 처음부터 다시 해야 하며, 시간을 심각하게 낭비하게 됩니다.
> **스킬은 반드시 설치 작업의 첫 번째 단계에서 사용자에게 아래 정보를 모두 요청해야 합니다.**

### 필수 수집 정보 (6가지)

| # | 항목 | 예시 | 설명 |
|---|------|------|------|
| 1 | **Root SSH 접속 정보** | `root@167.88.45.173` | SSH 키 인증 방식 필수 (비밀번호 인증 미지원) |
| 2 | **Dokploy 프로젝트 이름/ID** | `a6NDIzHNbE4Q7j4yByowW` | 기존 프로젝트에 추가할 경우 프로젝트 ID, 새로 만들 경우 프로젝트 이름 |
| 3 | **생성할 서비스 앱 이름** | `Claw3` | Dokploy Compose 서비스 이름 (한글 불가, 영문/숫자만) |
| 4 | **AI Provider 종류** | `DeepSeek` / `Anthropic` / `OpenAI` | 사용할 AI 모델 제공자 |
| 5 | **API Key** | `sk-f3d2f3ccc2924b2cafe96af4787673b4` | 해당 Provider의 API 키 |
| 6 | **도메인 이름** | `claw3.vibers.kr` | DNS A 레코드가 서버 IP를 가리키도록 사전 설정 필요 |

### 스킬 첫 응답 템플릿

```
OpenClaw 설치를 시작하겠습니다. 먼저 아래 6가지 정보가 필요합니다:

  1. Root SSH 접속 정보: (예: root@1.2.3.4, SSH 키 인증 필수)
  2. Dokploy 프로젝트: (기존 프로젝트 ID 또는 새로 생성할 이름)
  3. 서비스 앱 이름: (예: Claw3, 영문/숫자만)
  4. AI Provider: (DeepSeek / Anthropic / OpenAI / OpenRouter)
  5. API Key: (해당 Provider의 API 키)
  6. 도메인 이름: (예: claw3.vibers.kr, DNS A 레코드 사전 설정 필요)

모든 정보를 알려주시면 한 번에 설치를 완료하겠습니다.
```

### ⛔ 반드시 `plugins.slots.memory: "none"` 설정 필수!

> **이것은 OpenClaw Dokploy 설치의 가장 치명적인 문제입니다. 이 설정 없이는 모든 설정 변경이 실패합니다.**

#### 문제 요약

`moltbot/moltbot` Docker 이미지의 기본 config에는 `plugins.slots.memory: "memory-core"`가 설정되어 있다.
그런데 **`memory-core` 플러그인은 이미지에 포함되어 있지 않다.** 이것은 이미지의 알려진 버그이다.
(`patched` 태그 이미지에서도 moltbot.json 생성 시 이 설정이 필요하다.)

이로 인해 다음 **모든 상황에서** 설정 변경이 실패한다:

| 시도 방법 | 결과 | 에러 메시지 |
|-----------|------|-------------|
| Web UI → Settings → Config → Save | ❌ 실패 | `Error: invalid config` (상세 원인 표시 안 함) |
| CLI: `node dist/index.js config set ...` | ❌ 실패 | `Config validation failed: plugins.slots.memory: plugin not found: memory-core` |
| moltbot.json 직접 생성 (`plugins.slots.memory` 미포함) | ❌ 실패 | deep merge로 기본값 `memory-core`가 적용되어 validation 실패 |
| moltbot.json에 `plugins: { slots: {} }` | ❌ 실패 | deep merge로 기본값 유지 |
| moltbot.json에 `plugins: { slots: { memory: null } }` | ❌ 실패 | `expected string, received null` |
| moltbot.json에 `plugins: { slots: { memory: "" } }` | ❌ 실패 | 빈 문자열은 기본값으로 폴백 |
| **moltbot.json에 `plugins: { slots: { memory: "none" } }`** | **✅ 성공** | 유일하게 유효한 값 |

#### 해결 방법

**moltbot.json에 반드시 `"plugins": { "slots": { "memory": "none" } }`을 포함해야 한다.**

```json
{
  "plugins": { "slots": { "memory": "none" } },
  "agents": { ... },
  "models": { ... }
}
```

- `"none"` 문자열만 유효하다. `null`, `""`, `{}`, `false`, `0` 등은 모두 실패한다.
- 소스 코드 `/app/dist/config/schema.js`에 `'Select the active memory plugin by id, or "none" to disable memory plugins.'`로 정의되어 있다.
- `"none"`은 메모리 플러그인을 명시적으로 비활성화하여 validation을 통과시킨다.

#### moltbot.json 없이 시작하면?

- moltbot.json이 없으면 Gateway는 관대한 모드로 시작하며, memory-core는 단순 경고 로그만 출력하고 정상 작동한다.
- 하지만 moltbot.json이 존재하는 순간 **엄격한 validation**이 적용되므로, 반드시 `"none"`을 포함해야 한다.
- AI Provider와 모델을 설정하려면 moltbot.json이 반드시 필요하므로, **`"none"` 설정은 사실상 필수**이다.

#### 발견 과정 (디버깅 히스토리)

1. Web UI Config → Save에서 `Error: invalid config` 발생 — 원인 불명
2. CLI `config set`에서 `plugins.slots.memory: plugin not found: memory-core` 확인 — Web UI에서는 보이지 않던 상세 에러
3. `plugins install memory-core` 시도 → npm 404, 패키지 존재하지 않음
4. `plugins: { slots: {} }` 시도 → deep merge로 기본값 유지, 실패
5. `plugins: { slots: { memory: null } }` 시도 → "expected string, received null" 실패
6. `plugins: { slots: { memory: "" } }` 시도 → 빈 문자열은 기본값으로 폴백, 실패
7. `/app/dist/config/schema.js` 소스 분석에서 `"none"` 값 발견
8. `plugins: { slots: { memory: "none" } }` → **성공!** Hot Reload 정상 작동 확인

> **이 문제 하나로 수시간의 디버깅 시간을 허비했습니다. 스킬은 moltbot.json 생성 시 반드시 이 값을 포함해야 합니다.**

---

## 1. 핵심 개념

### OpenClaw이란?

OpenClaw은 AI Gateway 플랫폼으로, 다양한 AI 모델(Claude, GPT, DeepSeek 등)을 웹 UI를 통해 관리하고 사용할 수 있는 셀프호스팅 솔루션이다. Docker 이미지명은 `moltbot/moltbot:patched`이며 Docker Hub에서 배포된다.

> **⛔⛔⛔ 이미지 태그 절대 규칙: `moltbot/moltbot:latest`를 사용하면 안 된다! 반드시 `moltbot/moltbot:patched`를 사용해야 한다. ⛔⛔⛔**
>
> `latest` 태그 이미지에는 `memory-core` 플러그인 관련 **치명적 버그**가 있어 컨테이너가 크래시 루프에 빠진다.
> 에러 메시지: `plugins.slots.memory: plugin not found: memory-core`
> 이 버그는 `--allow-unconfigured` 플래그로도 회피되지 않으며, `moltbot doctor --fix`로도 수정되지 않는다.
> **유일한 해결책은 `patched` 태그 이미지를 사용하는 것이다.**

### 공식 문서

| 문서 | URL |
|------|-----|
| **Docker 설치 가이드** | https://docs.openclaw.ai/install/docker |

### 공식 Docker 설치 방법 (참고용)

공식 문서에 따르면 OpenClaw은 아래 3가지 방식으로 설치할 수 있다. 단, Dokploy 배포 시에는 이 방법을 직접 사용하지 않고, Docker Compose YAML을 Dokploy에 입력하는 방식을 사용한다.

#### 방법 1: 빠른 시작 스크립트 (로컬 개발용)

```bash
# 저장소 루트에서 실행
./docker-setup.sh
```

이 스크립트는 게이트웨이 이미지를 빌드하고, 온보딩 마법사를 실행하며, Docker Compose를 통해 게이트웨이를 시작한다.

#### 방법 2: 수동 실행 (로컬 개발용)

```bash
docker build -t openclaw:local -f Dockerfile .
docker compose run --rm openclaw-cli onboard
docker compose up -d openclaw-gateway
```

#### 공식 문서의 주요 환경 변수 (선택사항)

| 환경 변수 | 설명 |
|-----------|------|
| `OPENCLAW_DOCKER_APT_PACKAGES` | 빌드 중 추가 apt 패키지 설치 (예: `ffmpeg build-essential`) |
| `OPENCLAW_EXTRA_MOUNTS` | 호스트 디렉토리를 컨테이너에 마운트 (쉼표 구분) |
| `OPENCLAW_HOME_VOLUME` | `/home/node`를 명명된 볼륨으로 지속 (예: `openclaw_home`) |

#### 공식 문서 핵심 참고사항

- 대시보드 접속: `http://127.0.0.1:18789/`
- 설정 경로: `~/.openclaw/`, `~/.openclaw/workspace`
- 컨테이너는 비루트 `node` 사용자(uid 1000)로 실행됨
- 권한 오류 시: `sudo chown -R 1000:1000 /path/to/config`
- 자동으로 게이트웨이 토큰을 생성하고 `.env` 파일에 저장

### 핵심 정보

| 항목 | 값 |
|------|-----|
| **Docker 이미지** | `moltbot/moltbot:patched` (Docker Hub) - **`latest` 사용 금지!** |
| **패키지명** | moltbot (OpenClaw의 이전 버전명) |
| **기본 포트** | 18789 (Gateway), 18790 (Canvas) |
| **설정 디렉토리 (런타임)** | `/home/node/.clawdbot` (실제 런타임에 사용되는 경로) |
| **설정 디렉토리 (볼륨)** | `/home/node/.moltbot` (영구 볼륨 마운트 경로) |
| **워크스페이스** | `/home/node/clawd` |
| **템플릿 파일 경로** | `/app/docs/reference/templates/` (13개 .md 파일 필요) |
| **메인 설정 파일** | `/home/node/.clawdbot/moltbot.json` (런타임) |
| **API 키 파일** | `/home/node/.clawdbot/agents/main/agent/auth-profiles.json` (런타임) |

### 권장 사양

| 항목 | 최소 | 권장 |
|------|------|------|
| RAM | 1GB | 2GB |
| CPU | 1 Core | 2 Core |
| Storage | 5GB | 10GB |

---

## 2. 아키텍처 및 포트

### 트래픽 흐름

```
[사용자 브라우저]
    ↓ HTTPS (443)
[Traefik Reverse Proxy]
    ↓ HTTP (18789)
[Moltbot Gateway Container]
    ↓ API Call
[AI Provider (DeepSeek/OpenAI/Anthropic)]
```

### 포트 매핑

| 포트 | 용도 |
|------|------|
| 18789 | Gateway (WebSocket + HTTP) - **Traefik Container Port에 반드시 이 값 설정** |
| 18790 | Canvas |

> **⚠️ 핵심 주의사항**: Dokploy 도메인 설정 시 Container Port를 반드시 `18789`로 설정해야 한다. 기본값 3000이 아니다!

---

## 3. Docker Compose YAML

### 핵심 소스코드 - docker-compose.yml

Dokploy UI의 Compose 서비스 → General → Raw 탭에 입력하는 YAML:

```yaml
services:
  moltbot-gateway:
    image: moltbot/moltbot:patched  # ⛔ latest 사용 금지! memory-core 플러그인 버그로 크래시 루프 발생
    environment:
      HOME: /home/node
      TERM: xterm-256color
      CLAWDBOT_GATEWAY_TOKEN: YOUR_TOKEN_HERE
      DEEPSEEK_API_KEY: sk-YOUR_DEEPSEEK_API_KEY_HERE
    volumes:
      - moltbot-config:/home/node/.moltbot
      - moltbot-workspace:/home/node/clawd
    ports:
      - "18789"
      - "18790"
    init: true
    restart: unless-stopped
    command:
      - gateway
      - --bind
      - lan
      - --port
      - "18789"
      - --allow-unconfigured
      - --token
      - YOUR_TOKEN_HERE
    networks:
      - dokploy-network

volumes:
  moltbot-config:
  moltbot-workspace:

networks:
  dokploy-network:
    external: true
```

### YAML 설정 핵심 로직

| 설정 | 설명 | 왜 필요한가 |
|------|------|------------|
| `image: moltbot/moltbot:patched` | Docker Hub 패치 이미지 (**`latest` 사용 금지!**) | 필수. `latest`는 memory-core 버그로 크래시 |
| `--bind lan` | 모든 인터페이스(0.0.0.0)에서 수신 | Traefik 연결을 위해 필수 |
| `--port 18789` | Gateway 포트 지정 | 포트 일관성 유지 |
| `--allow-unconfigured` | 초기 설정 없이 시작 가능 | 첫 배포 시 필수 |
| `--token YOUR_TOKEN_HERE` | CLI 인자로 토큰 전달 | **환경변수만으로는 작동하지 않음** |
| `dokploy-network` | Traefik 네트워크 연결 | 도메인 라우팅을 위해 필수 |
| `moltbot-config` | 설정 파일 영구 볼륨 | 재배포 시 설정 보존 |
| `moltbot-workspace` | 워크스페이스 영구 볼륨 | 템플릿/대화 데이터 보존 |

### ⛔ command 설정 절대 규칙

이미지의 ENTRYPOINT가 이미 `node dist/index.js`를 실행하므로, command에 `node dist/index.js`를 포함하면 안 된다.

**올바른 command:**

```yaml
command:
  - gateway
  - --bind
  - lan
  - --port
  - "18789"
  - --allow-unconfigured
  - --token
  - YOUR_TOKEN_HERE
```

**잘못된 command (절대 금지):**

```yaml
command:
  - node
  - dist/index.js  # ❌ 중복! ENTRYPOINT에서 이미 실행됨
  - gateway
  - --bind
  - lan
```

### ⛔ 이미지 태그 절대 규칙

```yaml
# ✅ 올바른 이미지 (patched 태그 사용)
image: moltbot/moltbot:patched

# ❌ 잘못된 이미지 (latest 태그 - memory-core 버그로 크래시 루프 발생!)
image: moltbot/moltbot:latest
```

> **왜 `latest`를 사용하면 안 되는가?**
>
> `moltbot/moltbot:latest` 이미지에는 `memory-core` 플러그인이 기본 설정에 등록되어 있으나,
> 실제 플러그인 바이너리가 이미지에 포함되어 있지 않다. 이로 인해 컨테이너 시작 시
> `plugins.slots.memory: plugin not found: memory-core` 에러가 발생하며 크래시 루프에 빠진다.
> `--allow-unconfigured` 플래그로도 이 문제는 회피되지 않으며, `moltbot doctor --fix`로도 수정되지 않는다.
> **유일한 해결책은 `moltbot/moltbot:patched` 이미지를 사용하는 것이다.**

### ⛔ 환경변수 CLAWDBOT_PLUGINS 주의사항

```bash
# ❌ memory-core 포함 시 크래시 발생 (patched 이미지에서도 주의)
CLAWDBOT_PLUGINS=discord,memory-core

# ✅ memory-core 제거
CLAWDBOT_PLUGINS=discord

# ✅ 가장 안전: 환경변수 자체를 설정하지 않음
# (CLAWDBOT_PLUGINS 환경변수 삭제)
```

---

## 4. Gateway Token 설정

### 핵심 로직

Gateway Token은 **두 곳에 동시에** 설정해야 작동한다:

1. `environment.CLAWDBOT_GATEWAY_TOKEN` - 환경변수
2. `command`의 `--token` 옵션 - CLI 인자

> **⛔⛔⛔ 절대 규칙: 환경변수만으로는 작동하지 않는다! 반드시 `--token` CLI 옵션도 함께 설정해야 한다. ⛔⛔⛔**

### 토큰 생성 방법

```bash
# 32자 랜덤 토큰 생성
openssl rand -hex 16
# 예시 출력: 6d703cfb603473b871cfef846c536c67
```

### 접속 URL 형식

```
https://도메인/?token=GATEWAY_TOKEN
```

### 토큰 확인 방법 (서버에서)

```bash
# 컨테이너 이름 확인
docker ps --format '{{.Names}}' | grep moltbot

# Gateway Token 확인
docker exec <컨테이너이름> printenv CLAWDBOT_GATEWAY_TOKEN
```

---

## 5. Dokploy API를 통한 자동 설치

> **이 섹션은 Dokploy API를 사용하여 OpenClaw Compose 서비스를 프로그래밍 방식으로 생성, 설정, 배포하는 전체 과정을 다룬다.**

### 5.1 사전 준비

| # | 필요 정보 | 예시 | 확인 방법 |
|---|-----------|------|-----------|
| 1 | **Dokploy 서버 URL** | `http://167.88.45.173:3000` | Dokploy 대시보드 접속 URL |
| 2 | **Dokploy API 키** | `openclawcfYjyl...` | Dokploy → Settings → Profile → API/CLI |
| 3 | **프로젝트 ID** | `a6NDIzHNbE4Q7j4yByowW` | Dokploy 대시보드 URL에서 확인 |
| 4 | **환경 ID** | `ytwpt5REIUg70vv-iZCQU` | Dokploy 대시보드 URL에서 확인 |
| 5 | **SSH 접속 정보** | `root@167.88.45.173` | 서버 관리자에게 확인 |

#### 프로젝트 ID와 환경 ID 확인 방법

Dokploy 대시보드의 프로젝트 환경 URL에서 추출한다:

```
http://서버IP:3000/dashboard/project/{프로젝트ID}/environment/{환경ID}
```

예시:
```
http://167.88.45.173:3000/dashboard/project/a6NDIzHNbE4Q7j4yByowW/environment/ytwpt5REIUg70vv-iZCQU
                                           ^^^^^^^^^^^^^^^^^^^^^^^^^             ^^^^^^^^^^^^^^^^^^^^^^^^^
                                           프로젝트 ID                           환경 ID
```

### 5.2 단계 1: Gateway Token 생성

```bash
GATEWAY_TOKEN=$(openssl rand -hex 16)
echo "생성된 Gateway Token: $GATEWAY_TOKEN"
# 예시 출력: 6d703cfb603473b871cfef846c536c67
```

### 5.3 단계 2: Compose 서비스 생성 (compose.create)

```bash
# 변수 설정
DOKPLOY_URL="http://167.88.45.173:3000"
DOKPLOY_API_KEY="your-api-key-here"
PROJECT_ID="a6NDIzHNbE4Q7j4yByowW"
ENVIRONMENT_ID="ytwpt5REIUg70vv-iZCQU"
SERVICE_NAME="OpenClaw0211"

# Compose 서비스 생성
COMPOSE_RESPONSE=$(curl -s -X POST "$DOKPLOY_URL/api/compose.create" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $DOKPLOY_API_KEY" \
  -d "{
    \"name\": \"$SERVICE_NAME\",
    \"projectId\": \"$PROJECT_ID\",
    \"environmentId\": \"$ENVIRONMENT_ID\"
  }")

# composeId 추출
COMPOSE_ID=$(echo "$COMPOSE_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['composeId'])")
echo "생성된 Compose ID: $COMPOSE_ID"
```

**API 응답 예시:**

```json
{
  "composeId": "IIO0IPHSm1XVqDi8MyQ5_",
  "name": "OpenClaw0211",
  "appName": "compose-back-up-online-program-m32ael",
  "sourceType": "github",
  "composeType": "docker-compose",
  "composeStatus": "idle",
  "environmentId": "ytwpt5REIUg70vv-iZCQU"
}
```

**주요 필드 설명:**

| 필드 | 설명 |
|------|------|
| `composeId` | 이후 모든 API 호출에 사용하는 고유 식별자 |
| `appName` | Dokploy가 자동 생성하는 내부 앱 이름 (컨테이너 이름 접두사) |
| `composeStatus` | 현재 상태 (`idle`, `running`, `done`, `error`) |

### 5.4 단계 3: Docker Compose YAML 설정 (compose.update)

```bash
# Docker Compose YAML 준비
COMPOSE_YAML=$(cat <<YAMLEOF
services:
  moltbot-gateway:
    image: moltbot/moltbot:latest
    environment:
      HOME: /home/node
      TERM: xterm-256color
      CLAWDBOT_GATEWAY_TOKEN: $GATEWAY_TOKEN
    volumes:
      - moltbot-config:/home/node/.moltbot
      - moltbot-workspace:/home/node/clawd
    ports:
      - "18789"
      - "18790"
    init: true
    restart: unless-stopped
    command:
      - gateway
      - --bind
      - lan
      - --port
      - "18789"
      - --allow-unconfigured
      - --token
      - $GATEWAY_TOKEN
    networks:
      - dokploy-network

volumes:
  moltbot-config:
  moltbot-workspace:

networks:
  dokploy-network:
    external: true
YAMLEOF
)

# YAML을 JSON 문자열로 변환
COMPOSE_JSON=$(echo "$COMPOSE_YAML" | python3 -c "import sys, json; print(json.dumps(sys.stdin.read()))")

# Compose 서비스 업데이트 (sourceType을 "raw"로 설정하는 것이 핵심!)
curl -s -X POST "$DOKPLOY_URL/api/compose.update" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $DOKPLOY_API_KEY" \
  -d "{
    \"composeId\": \"$COMPOSE_ID\",
    \"composeFile\": $COMPOSE_JSON,
    \"sourceType\": \"raw\"
  }"
```

> **⚠️ 핵심 주의사항**: `sourceType`을 반드시 `"raw"`로 설정해야 한다. 기본값은 `"github"`인데, Raw 모드로 변경해야 직접 입력한 YAML이 적용된다.

### 5.5 단계 4: 배포 실행 (compose.deploy)

```bash
curl -s -X POST "$DOKPLOY_URL/api/compose.deploy" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $DOKPLOY_API_KEY" \
  -d "{
    \"composeId\": \"$COMPOSE_ID\"
  }"
# 응답: {"success":true,"message":"Deployment queued"}
```

### 5.6 단계 5: 배포 상태 확인 (compose.one)

```bash
# 15~20초 대기 후 상태 확인
sleep 20

curl -s "$DOKPLOY_URL/api/compose.one?composeId=$COMPOSE_ID" \
  -H "x-api-key: $DOKPLOY_API_KEY" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print('Compose Status:', d.get('composeStatus'))
print('Name:', d.get('name'))
for dep in d.get('deployments', []):
    print(f\"  Deployment: {dep['status']} ({dep['createdAt']})\")"
```

**정상 응답에서 확인해야 할 값:**

| 필드 | 기대값 |
|------|--------|
| `composeStatus` | `"done"` |
| `deployments[0].status` | `"done"` |

### 5.7 단계 6: SSH로 컨테이너 실행 확인

```bash
# 컨테이너 상태 확인 (SSH)
ssh root@167.88.45.173 "docker ps --format '{{.Names}}\t{{.Status}}\t{{.Ports}}' | grep moltbot"

# 예시 출력:
# compose-back-up-online-program-m32ael-moltbot-gateway-1  Up 47 seconds  0.0.0.0:58696->18789/tcp, 0.0.0.0:58697->18790/tcp
```

```bash
# 컨테이너 로그 확인 (SSH)
ssh root@167.88.45.173 "docker logs compose-back-up-online-program-m32ael-moltbot-gateway-1 --tail 30"
```

**정상 시작 로그 (반드시 아래 3줄이 모두 나와야 함):**

```
[gateway] agent model: anthropic/claude-opus-4-5
[gateway] listening on ws://0.0.0.0:18789 (PID 7)
[browser/service] Browser control service ready (profiles=2)
```

**무시해도 되는 경고 메시지:**

```
[gateway] [plugins] memory slot plugin not found or not marked as memory: memory-core
```

이 메시지는 이미지의 알려진 버그이며, `--allow-unconfigured` 플래그가 있으면 정상 작동한다.

### 5.7.1 ⛔ 볼륨 권한 수정 (필수!)

> **⛔⛔⛔ 첫 배포 후 반드시 볼륨 권한을 수정해야 한다! ⛔⛔⛔**
>
> Docker 명명된 볼륨(`moltbot-config`)이 처음 생성될 때 소유권이 `root:root`로 설정된다.
> 컨테이너는 `node` 사용자(uid 1000)로 실행되므로, `/home/node/.moltbot` 디렉토리에 쓰기 권한이 없다.
> 이로 인해 `devices`, `cron` 등 하위 디렉토리를 생성할 수 없어 **Device Pairing이 불가능**하다.

#### 증상

브라우저에서 접속 시 아래 에러가 표시된다:

```
disconnected (1000): no reason
```

컨테이너 로그에 아래 에러가 반복된다:

```
[gateway] parse/handle error: Error: EACCES: permission denied, mkdir '/home/node/.moltbot/devices'
[ws] ✗ parse-error error=Error: EACCES: permission denied, mkdir '/home/node/.moltbot/devices'
[ws] closed before connect ... code=1000 reason=n/a
```

> **주의**: 이 에러는 `pairing required` (1008)과 다르다!
> - `disconnected (1000): no reason` → 볼륨 권한 문제 (이 섹션의 해결 방법 적용)
> - `disconnected (1008): pairing required` → 정상적인 Device Pairing 필요 (Section 7 참조)

#### 해결 방법

```bash
# 컨테이너 내부에서 root 권한으로 소유권 변경
ssh root@서버IP "docker exec --user root $CONTAINER chown -R node:node /home/node/.moltbot"

# 컨테이너 재시작
ssh root@서버IP "docker restart $CONTAINER"
```

#### 스킬 워크플로우에서의 위치

**첫 배포 완료 직후 (5.7 이후), 도메인 추가 전 (6 이전)에 반드시 실행해야 한다.**

```bash
# 5.7 완료 후 즉시 실행
CONTAINER=$(ssh root@서버IP "docker ps --format '{{.Names}}' | grep moltbot | head -1")
ssh root@서버IP "docker exec --user root $CONTAINER chown -R node:node /home/node/.moltbot"
echo "볼륨 권한 수정 완료"
```

> **참고**: 이 작업은 첫 배포 시 한 번만 실행하면 된다. 재배포 시에는 볼륨이 이미 존재하므로 소유권이 유지된다.

### 5.8 전체 과정 요약 다이어그램

```
[0. 필수 사전 정보 수집]            → SSH, 프로젝트, 서비스명, Provider, API Key, 도메인 (Section 0)
        ↓
[1. openssl rand -hex 16]          → Gateway Token 생성
        ↓
[2. compose.create API]            → Compose 서비스 생성 (composeId 획득)
        ↓
[3. compose.update API]            → Docker Compose YAML 설정 (sourceType: "raw" 필수, API Key 환경변수 포함)
        ↓
[4. compose.deploy API]            → 첫 번째 배포 실행
        ↓
[5. compose.one API / SSH 확인]    → 배포 상태 확인 (composeStatus: "done")
        ↓
[5.1 볼륨 권한 수정 (docker exec)] → ⚠️ chown -R node:node /home/node/.moltbot (첫 배포 시 필수!)
        ↓
[6. 도메인 추가 (UI 또는 API)]     → 도메인 + HTTPS + Container Port 18789
        ↓
[7. compose.deploy API]            → ⚠️ 재배포 실행 (도메인 적용을 위해 필수!)
        ↓
[8. 템플릿 파일 생성 (docker exec)] → 13개 .md 파일을 /app/docs/reference/templates/ 에 생성
        ↓
[9. curl로 접속 테스트]             → https://도메인/?token=TOKEN
        ↓
[10. Device Pairing (SSH)]         → devices list → devices approve
        ↓
[11. moltbot.json 생성 (docker exec)] → ⚠️ plugins.slots.memory: "none" 필수! (Section 8.2)
        ↓
[12. Hot Reload 확인 (docker logs)] → agent model: deepseek/deepseek-chat 확인
        ↓
[13. 최종 테스트]                   → Chat에서 메시지 전송하여 AI 응답 확인
```

---

## 6. 도메인 및 HTTPS 설정

### Dokploy UI 도메인 설정

| 필드 | 값 |
|------|-----|
| **Host** | `claw.example.com` (본인 도메인) |
| **Container Port** | `18789` ⚠️ **반드시 18789!** (기본값 3000 아님) |
| **HTTPS** | ✅ 체크 |
| **Certificate** | `Let's Encrypt` |
| **Service Name** | `moltbot-gateway` (Docker Compose YAML의 서비스 이름과 동일해야 함) |

### DNS 설정 확인

```bash
dig +short claw.example.com
# 출력: 서버 IP 주소 (예: 167.88.45.173)
```

### 핵심 로직 - Traefik 라우팅

```
[Traefik] → Port 18789 → [Moltbot Container]
```

### ⛔⛔⛔ Compose 서비스 도메인 추가 후 반드시 재배포해야 한다!

> **이것은 Compose 서비스에서 가장 흔한 실수이다.**
>
> Application 서비스와 달리, **Compose 서비스는 도메인을 추가/변경한 후 반드시 재배포해야 Traefik 라벨이 적용된다.**
> 재배포 없이는 Traefik이 해당 도메인에 대한 라우팅 규칙을 모르기 때문에 접속이 불가능하다.

#### 증상

도메인을 추가하고 DNS도 정상인데 접속 시 다음과 같은 상태가 발생한다:

```bash
# curl 테스트 결과
curl -s -o /dev/null -w "HTTP Status: %{http_code}" https://도메인/
# HTTP Status: 000  (연결 자체가 안 됨)
# 또는 404 Not Found
```

#### 원인 분석 (디버깅 과정)

도메인 접속 불가 시 아래 순서대로 확인한다:

```bash
# 1단계: DNS 확인 - A 레코드가 서버 IP를 가리키는지
dig +short openclaw0211.vibers.kr
# 기대값: 167.88.45.173

# 2단계: 컨테이너 실행 상태 확인 (SSH)
ssh root@서버IP "docker ps --format '{{.Names}}\t{{.Status}}' | grep moltbot"
# 기대값: Up 상태

# 3단계: Dokploy 도메인 설정 확인 (API)
curl -s "$DOKPLOY_URL/api/compose.one?composeId=$COMPOSE_ID" \
  -H "x-api-key: $DOKPLOY_API_KEY" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for dom in d.get('domains', []):
    print(f\"Host: {dom.get('host')}\")
    print(f\"Port: {dom.get('port')}\")
    print(f\"HTTPS: {dom.get('https')}\")
    print(f\"Certificate: {dom.get('certificateType')}\")
    print(f\"Service Name: {dom.get('serviceName')}\")"

# 4단계: HTTPS/HTTP 모두 테스트
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" --max-time 10 -k "https://도메인/"
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" --max-time 10 "http://도메인/"

# 5단계: Traefik 로그에서 관련 에러 확인 (SSH)
ssh root@서버IP "docker logs dokploy-traefik --tail 50 2>&1 | grep -i '도메인명\|acme\|error'"
```

**만약 1~3단계가 모두 정상인데 4단계에서 접속 불가라면 → 재배포가 필요하다!**

#### 해결: 재배포 실행

```bash
# API로 재배포
curl -s -X POST "$DOKPLOY_URL/api/compose.deploy" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $DOKPLOY_API_KEY" \
  -d "{\"composeId\": \"$COMPOSE_ID\"}"

# 20초 대기 후 접속 테스트
sleep 20
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" --max-time 10 -k "https://도메인/"
# 기대값: HTTP Status: 200
```

#### 재배포 후 SSL 인증서 확인

```bash
# SSL 인증서 유효성 확인 (ssl_verify_result 가 0이면 정상)
curl -s -o /dev/null -w "HTTP Status: %{http_code}\nSSL Verify: %{ssl_verify_result}\n" \
  --max-time 10 "https://도메인/"
# 기대값:
# HTTP Status: 200
# SSL Verify: 0
```

---

## 7. Device Pairing (기기 승인)

### 핵심 개념

Moltbot은 보안을 위해 각 브라우저/기기마다 일회성 승인이 필요하다. 새 브라우저에서 처음 접속 시 화면에 아래 에러가 표시된다:

```
disconnected (1008): pairing required
```

> **⚠️ 중요: 이 에러는 웹 UI에서 해결할 수 없다!**
>
> Device Pairing은 반드시 **서버의 컨테이너 CLI**에서만 수행할 수 있다.
> 웹 UI에는 기기 승인 기능이 없으며, SSH로 서버에 접속하여 명령어를 실행해야 한다.

### 에러 발생 조건

| 상황 | Device Pairing 필요 여부 |
|------|--------------------------|
| 새 브라우저에서 처음 접속 | 필요 |
| 다른 컴퓨터에서 접속 | 필요 |
| 같은 브라우저 시크릿/프라이빗 모드 | 필요 |
| 브라우저 쿠키/데이터 삭제 후 접속 | 필요 |
| 이미 승인된 브라우저에서 재접속 | 불필요 |

### 기기 승인 워크플로우

#### 단계 1: SSH로 서버 접속

```bash
ssh root@서버IP
# 예: ssh root@167.88.45.173
```

또는 로컬에서 SSH를 통해 직접 명령어 실행:

```bash
ssh root@서버IP "docker exec 컨테이너이름 node dist/index.js devices list"
```

#### 단계 2: 컨테이너 이름 확인

```bash
CONTAINER=$(docker ps --format '{{.Names}}' | grep moltbot | head -1)
echo $CONTAINER
# 예시 출력: compose-back-up-online-program-m32ael-moltbot-gateway-1
```

> **팁**: 여러 OpenClaw 인스턴스가 실행 중인 경우, `docker ps`에서 원하는 컨테이너 이름을 직접 지정해야 한다.

#### 단계 3: 승인 대기 중인 기기 목록 확인

```bash
docker exec $CONTAINER node dist/index.js devices list
```

**출력 예시:**

```
Pending (1)
┌──────────────────────────────────────┬───────────────────────────────────┬──────────┬────────┬─────────┬────────┐
│ Request                              │ Device                            │ Role     │ IP     │ Age     │ Flags  │
├──────────────────────────────────────┼───────────────────────────────────┼──────────┼────────┼─────────┼────────┤
│ ca0023b6-7c22-4975-926a-8cb379f40aa8 │ 78ad1ffbe7c9a68e1de6220dc72dd1838 │ operator │        │ 39s ago │        │
│                                      │ 87d8c7664cde0c636a710472abda413   │          │        │         │        │
└──────────────────────────────────────┴───────────────────────────────────┴──────────┴────────┴─────────┴────────┘
Paired (1)
┌────────────────────────────────────────────┬────────────┬─────────────────────────────────┬────────────┬────────────┐
│ Device                                     │ Roles      │ Scopes                          │ Tokens     │ IP         │
├────────────────────────────────────────────┼────────────┼─────────────────────────────────┼────────────┼────────────┤
│ f2dff3ef991b5ebf4d52b3201ebb7438e6dce8891f │ operator   │ operator.admin, operator.       │ operator   │            │
│ 6c16b54deb3891842760b2                     │            │ approvals, operator.pairing     │            │            │
└────────────────────────────────────────────┴────────────┴─────────────────────────────────┴────────────┴────────────┘
```

**출력 테이블 설명:**

| 섹션 | 설명 |
|------|------|
| **Pending (N)** | 승인 대기 중인 기기 목록. `Request` 컬럼의 UUID가 승인에 필요한 ID |
| **Paired (N)** | 이미 승인된 기기 목록 |

| 컬럼 | 설명 |
|------|------|
| `Request` | 승인 요청 ID (UUID 형식) - **이 값을 approve 명령어에 사용** |
| `Device` | 기기 고유 식별자 (해시값) |
| `Role` | 기기 역할 (`operator`) |
| `IP` | 접속 IP 주소 |
| `Age` | 요청이 생성된 시간 (예: `39s ago`) |

#### 단계 4: 기기 승인

`Pending` 테이블의 `Request` 컬럼에 있는 UUID를 사용하여 승인한다:

```bash
docker exec $CONTAINER node dist/index.js devices approve ca0023b6-7c22-4975-926a-8cb379f40aa8
```

**성공 출력:**

```
Approved 78ad1ffbe7c9a68e1de6220dc72dd183887d8c7664cde0c636a710472abda413
```

#### 단계 5: 브라우저 새로고침

승인 후 브라우저에서 **페이지를 새로고침**하면 정상 접속된다.

### SSH를 통한 원격 Device Pairing (로컬에서 한 번에 실행)

서버에 직접 접속하지 않고 로컬에서 한 번에 실행하는 방법:

```bash
# 컨테이너 이름 (실제 이름으로 변경)
CONTAINER="compose-back-up-online-program-m32ael-moltbot-gateway-1"
SSH="root@167.88.45.173"

# 1. 대기 중인 기기 목록 확인
ssh $SSH "docker exec $CONTAINER node dist/index.js devices list"

# 2. Request ID를 확인 후 승인 (실제 ID로 변경)
ssh $SSH "docker exec $CONTAINER node dist/index.js devices approve REQUEST_ID_HERE"
```

### 전체 과정 요약

```
[브라우저에서 접속]
    ↓
[화면에 "disconnected (1008): pairing required" 표시]
    ↓
[SSH로 서버 접속]
    ↓
[docker exec ... devices list → Pending 목록에서 Request UUID 확인]
    ↓
[docker exec ... devices approve UUID]
    ↓
[브라우저 새로고침 → 정상 접속]
```

> **참고**: 다른 컴퓨터/브라우저에서 접속할 때마다 같은 과정을 반복해야 한다.
> 한 번 승인된 기기는 `Paired` 목록에 등록되며, 이후 재접속 시 추가 승인이 필요 없다.

---

## 8. API 키 및 모델 Provider 설정

### 8.1 지원 AI Provider

| Provider | API 키 형식 | 모델 ID 형식 | 비고 |
|----------|------------|-------------|------|
| DeepSeek | `sk-xxxxxxxx` | `deepseek/deepseek-chat` | OpenAI 프로토콜 호환 |
| Anthropic | `sk-ant-xxxxxxxx` | `anthropic/claude-opus-4-5` | 기본 모델 |
| OpenAI | `sk-xxxxxxxx` | `openai/gpt-4o` | |
| OpenRouter | `sk-or-xxxxxxxx` | (다양) | |

### 8.2 CLI(docker exec)로 moltbot.json 직접 생성 (권장)

> **⚠️ 핵심: Web UI의 Config → Save 기능은 `memory-core` 플러그인 버그로 인해 현재 작동하지 않음.**
> **`moltbot.json`을 직접 생성하되, 반드시 `plugins.slots.memory: "none"`을 포함해야 한다.**

#### 왜 `plugins.slots.memory: "none"`이 필수인가?

- 이미지의 기본 config에 `plugins.slots.memory: "memory-core"`가 설정되어 있음
- `memory-core` 플러그인이 현재 이미지에 포함되어 있지 않음
- moltbot.json이 존재하면 config validation 시 이 플러그인을 찾으려다 실패
- `"none"` 값으로 명시적 오버라이드하면 메모리 플러그인을 비활성화하여 validation 통과
- `{}`, `null`, `""` 등은 모두 실패함 — **반드시 `"none"` 문자열만 유효**

#### 단계 1: Docker Compose YAML에 API 키 환경변수 추가

Docker Compose YAML의 `environment` 섹션에 API 키를 환경변수로 추가한다:

```yaml
environment:
  HOME: /home/node
  TERM: xterm-256color
  CLAWDBOT_GATEWAY_TOKEN: YOUR_TOKEN_HERE
  DEEPSEEK_API_KEY: sk-YOUR_DEEPSEEK_API_KEY_HERE
```

> 환경변수로 API 키를 관리하면 moltbot.json에 키를 직접 기록하지 않고 `${DEEPSEEK_API_KEY}`로 참조할 수 있다.

#### 단계 2: moltbot.json 생성 (docker exec)

배포 후 컨테이너에 접속하여 moltbot.json을 생성한다:

```bash
CONTAINER=$(ssh root@서버IP "docker ps --format '{{.Names}}' | grep moltbot | head -1")

ssh root@서버IP "docker exec $CONTAINER node -e \"
const fs = require('fs');
const config = {
  plugins: { slots: { memory: 'none' } },
  messages: { ackReactionScope: 'group-mentions' },
  agents: {
    defaults: {
      maxConcurrent: 4,
      subagents: { maxConcurrent: 8 },
      compaction: { mode: 'safeguard' },
      model: { primary: 'deepseek/deepseek-chat' }
    }
  },
  models: {
    providers: {
      deepseek: {
        baseUrl: 'https://api.deepseek.com',
        apiKey: '\\\\\${DEEPSEEK_API_KEY}',
        api: 'openai-completions',
        models: [{
          id: 'deepseek-chat',
          name: 'DeepSeek Chat',
          contextWindow: 128000,
          maxTokens: 8192
        }]
      }
    }
  }
};
fs.writeFileSync('/home/node/.clawdbot/moltbot.json', JSON.stringify(config, null, 2));
console.log('moltbot.json 생성 완료');
\""
```

> **핵심**: `apiKey: "${DEEPSEEK_API_KEY}"`로 설정하면 Docker Compose의 환경변수를 참조한다.

#### 단계 3: Hot Reload 확인

moltbot.json을 생성하면 Gateway가 자동으로 감지하고 config를 재로드한다. 로그에서 확인:

```bash
ssh root@서버IP "docker logs $CONTAINER --tail 5"
# 기대 출력:
# [gateway] agent model: deepseek/deepseek-chat
# [gateway] listening on ws://0.0.0.0:18789 (PID 7)
# [browser/service] Browser control service ready (profiles=2)
```

#### 단계 4: Chat에서 테스트

```
https://도메인/chat?session=main&token=YOUR_TOKEN
```

메시지를 보내서 DeepSeek 모델이 정상 응답하는지 확인한다.

### 8.3 공식 문서 참조

| 문서 | URL |
|------|-----|
| Configuration 개요 | https://docs.openclaw.ai/gateway/configuration |
| Configuration Reference | https://docs.openclaw.ai/gateway/configuration-reference |
| Configuration Examples | https://docs.openclaw.ai/gateway/configuration-examples |
| Authentication | https://docs.openclaw.ai/gateway/authentication |

### 8.4 스킬에서 사용자에게 물어봐야 할 정보

> **배포 자동화 스킬은 컨테이너 설치 완료 후, 사용자에게 아래 정보를 확인해야 한다.**

```
배포가 완료되었습니다! AI Provider를 설정해야 합니다.

다음 정보를 알려주세요:
  1. AI Provider: (예: DeepSeek, Anthropic, OpenAI)
  2. API Key: (예: sk-xxxxxxxx)

스킬이 자동으로 다음을 수행합니다:
  1. Docker Compose YAML에 API 키 환경변수 추가
  2. moltbot.json 직접 생성 (plugins.slots.memory: "none" 포함)
  3. Hot Reload로 자동 적용 확인
  4. Chat 테스트
```

### ⚠️ moltbot.json 생성 시 필수 규칙

> **moltbot.json을 생성할 때 반드시 `plugins.slots.memory: "none"`을 포함해야 한다!**
>
> 이 필드가 없으면 기본값 `memory-core`가 적용되어 validation이 실패하고:
> - Hot Reload 시: `config reload skipped (invalid config)` 경고 후 이전 config 유지
> - Gateway 재시작 시: **컨테이너가 무한 재시작 루프에 빠짐**
> - Web UI Config → Save 시: `Error: invalid config` 에러
>
> `"none"` 값만이 유효하다. `null`, `""`, `{}` 등은 모두 실패한다.

---

## 9. 템플릿 파일 생성

### 핵심 개념

Moltbot은 `/app/docs/reference/templates/` 경로에 13개의 `.md` 템플릿 파일이 필요하다. 이 파일들이 없으면 Chat에서 에러가 발생한다.

> **⚠️ 경로 주의**: 템플릿 파일은 워크스페이스(`/home/node/clawd/`)가 아닌 **`/app/docs/reference/templates/`** 에 위치해야 한다.
> `/app/` 경로는 이미지 내부 경로이므로 볼륨에 저장되지 않으며, **컨테이너가 재생성될 때마다 다시 만들어야 한다.**

### 필수 템플릿 파일 목록 (13개)

| # | 파일 | 설명 |
|---|------|------|
| 1 | `AGENTS.md` | 에이전트 정의 |
| 2 | `SOUL.md` | AI 성격/페르소나 |
| 3 | `TOOLS.md` | 도구 정의 |
| 4 | `USER.md` | 사용자 정보 |
| 5 | `IDENTITY.md` | 신원 정보 |
| 6 | `BOOT.md` | 부팅 스크립트 |
| 7 | `BOOTSTRAP.md` | 초기화 스크립트 |
| 8 | `HEARTBEAT.md` | 하트비트 설정 |
| 9 | `HOOK.md` | 훅 설정 |
| 10 | `MEMORY.md` | 메모리 설정 |
| 11 | `SKILL.md` | 스킬 정의 |
| 12 | `DD.md` | 추가 설정 |
| 13 | `SOUL_EVIL.md` | 대체 페르소나 |

### 생성 방법: docker exec (권장)

배포 완료 후, 실행 중인 컨테이너에서 직접 생성한다:

```bash
# 컨테이너 이름 확인
CONTAINER=$(ssh root@서버IP "docker ps --format '{{.Names}}' | grep moltbot | head -1")

# 13개 템플릿 파일 일괄 생성 (SSH를 통해 실행)
ssh root@서버IP "docker exec $CONTAINER sh -c '
mkdir -p /app/docs/reference/templates
for f in AGENTS SOUL TOOLS USER IDENTITY BOOT BOOTSTRAP HEARTBEAT HOOK MEMORY SKILL DD SOUL_EVIL; do
  [ -f \"/app/docs/reference/templates/\$f.md\" ] || echo \"# \$f\" > \"/app/docs/reference/templates/\$f.md\"
done
echo \"생성 완료:\"
ls -la /app/docs/reference/templates/*.md
'"
```

### 생성 확인

```bash
# 파일 존재 여부 확인
ssh root@서버IP "docker exec $CONTAINER ls /app/docs/reference/templates/"
# 기대 출력: AGENTS.md  BOOT.md  BOOTSTRAP.md  DD.md  HEARTBEAT.md  HOOK.md
#           IDENTITY.md  MEMORY.md  SKILL.md  SOUL.md  SOUL_EVIL.md  TOOLS.md  USER.md
```

### ⚠️ 재배포 시 주의사항

`/app/docs/reference/templates/` 경로는 컨테이너 이미지 내부 경로이므로:
- **재배포(compose.deploy) 시 컨테이너가 재생성되면 템플릿 파일이 삭제된다**
- 재배포 후 반드시 위 docker exec 명령어를 다시 실행해야 한다
- entrypoint를 오버라이드하여 자동 생성하는 방법도 있으나, 이미지 업데이트 시 호환성 문제가 발생할 수 있어 **docker exec 방식을 권장**한다

---

## 10. 트러블슈팅

### 에러별 원인 및 해결

| 에러 | 원인 | 해결 |
|------|------|------|
| **도메인 접속 불가 (HTTP 000)** | Compose 서비스에서 도메인 추가 후 재배포를 하지 않음 | **재배포 실행** (`compose.deploy` API 또는 Dokploy UI에서 Deploy 클릭) |
| **404 Not Found** | Traefik이 컨테이너에 연결되지 않음 | `dokploy-network` 확인, 포트 `18789` 확인, 재배포 |
| **502 Bad Gateway** | 컨테이너 크래시 또는 포트 불일치 | `docker ps -a \| grep moltbot`, `docker logs` 확인 |
| **gateway token missing** | URL에 token 파라미터 없음 또는 `--token` CLI 옵션 누락 | `?token=YOUR_TOKEN` 추가, command에 `--token` 추가 |
| **pairing required** | 새 브라우저/기기에서 첫 접속 | `devices list` → `devices approve` |
| **Unknown model** | 모델 provider 미설정 | moltbot.json에 provider 설정 추가 |
| **No API key found** | auth-profiles.json에 API 키 없음 | auth-profiles.json 생성/수정 |
| **Missing workspace template** | 워크스페이스에 .md 파일 없음 | 템플릿 파일 일괄 생성 |
| **memory-core plugin not found** | **`latest` 이미지의 치명적 버그** | **반드시 `moltbot/moltbot:patched` 이미지로 변경** (아래 상세 참조) |
| **EACCES: permission denied, mkdir .moltbot/devices** | 볼륨 소유권이 root로 설정됨 (첫 배포 시 발생) | `docker exec --user root $CONTAINER chown -R node:node /home/node/.moltbot` + 컨테이너 재시작 |
| **disconnected (1000): no reason** | 볼륨 권한 문제로 devices 디렉토리 생성 불가 | 위 EACCES 해결 방법과 동일 (볼륨 권한 수정 후 재시작) |
| **[cron] failed to start: EACCES** | 볼륨 권한 문제로 cron 디렉토리 생성 불가 | 위 EACCES 해결 방법과 동일 |
| **컨테이너 재시작 루프** | 설정 파일 유효성 검사 실패 또는 `latest` 이미지 버그 | `moltbot.json` 확인, 이미지 태그 `patched`인지 확인 |

### memory-core 플러그인 크래시 루프 (치명적)

> **⛔ 이 문제는 매우 흔하게 발생하며, `--allow-unconfigured` 플래그나 `moltbot doctor --fix`로도 해결되지 않는다!**

**증상:**
- 컨테이너가 시작 직후 즉시 종료되며 재시작 루프에 빠짐
- `docker ps`에서 `Restarting (1) X seconds ago` 상태 반복
- 로그에 아래 에러 반복 출력:

```
Invalid config at /home/node/.moltbot/moltbot.json:
- plugins.slots.memory: plugin not found: memory-core
Config invalid
```

**근본 원인:**
- `moltbot/moltbot:latest` 이미지에 `memory-core` 플러그인이 기본 설정에 포함되어 있으나, 실제 플러그인 바이너리가 이미지에 없음
- 이 버그는 이미지 자체의 결함으로, 사용자 설정과 무관하게 발생
- `moltbot.json`에 `plugins` 관련 설정이 없어도 이미지 기본값에서 로드를 시도함
- 환경변수 `CLAWDBOT_PLUGINS`에 `memory-core`가 포함되어 있으면 문제가 더 악화됨

**해결 방법 (유일한 해결책):**

```bash
# 1단계: 이미지 태그 확인
docker inspect <컨테이너이름> --format '{{.Config.Image}}'
# 출력이 moltbot/moltbot:latest 이면 문제!

# 2단계: docker-compose.yml에서 이미지 변경
# image: moltbot/moltbot:latest   ← ❌ 크래시 루프 발생
# image: moltbot/moltbot:patched  ← ✅ 정상 작동

# 3단계: 환경변수에서 CLAWDBOT_PLUGINS 제거 (있는 경우)
# CLAWDBOT_PLUGINS=discord,memory-core  ← ❌ memory-core 제거 필요
# CLAWDBOT_PLUGINS=discord              ← ✅ 또는 환경변수 자체 삭제

# 4단계: 재배포
```

**Dokploy API를 통한 수정:**

```bash
# Compose YAML에서 이미지 변경 후 업데이트
curl -X POST "$DOKPLOY_URL/api/compose.update" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -d '{"composeId": "COMPOSE_ID", "composeFile": "수정된_YAML"}'

# 환경변수에서 CLAWDBOT_PLUGINS 제거 후 업데이트
curl -X POST "$DOKPLOY_URL/api/compose.update" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -d '{"composeId": "COMPOSE_ID", "env": "CLAWDBOT_PLUGINS 없는 환경변수"}'

# 재배포
curl -X POST "$DOKPLOY_URL/api/compose.deploy" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -d '{"composeId": "COMPOSE_ID"}'
```

**이미지 태그별 비교:**

| 태그 | memory-core 버그 | 상태 | 사용 여부 |
|------|-----------------|------|----------|
| `moltbot/moltbot:latest` | 있음 (크래시 루프) | 사용 금지 | ❌ |
| `moltbot/moltbot:patched` | 수정됨 (정상) | 권장 | ✅ |

### 도메인 접속 불가 디버깅 체크리스트

> Compose 서비스에서 도메인 접속이 안 될 때 아래 순서대로 확인한다.

```
[체크 1] DNS A 레코드가 서버 IP를 가리키는가?
    ↓ YES
[체크 2] 컨테이너가 실행 중인가? (docker ps)
    ↓ YES
[체크 3] Dokploy 도메인 설정이 올바른가? (Host, Port 18789, HTTPS, Service Name)
    ↓ YES
[체크 4] 도메인 추가 후 재배포를 했는가?
    ↓ NO → ⚠️ 재배포 실행! (가장 흔한 원인)
    ↓ YES
[체크 5] Traefik 로그에 에러가 있는가?
    ↓ 에러 있음 → 에러 메시지에 따라 대응
```

### Gateway Token 재시작 루프 디버깅

```bash
# 로그에서 아래 메시지가 반복되면:
# "Gateway auth is set to token, but no token is configured"
# → command에 --token 옵션을 추가해야 함

docker logs $CONTAINER --tail 50
```

### ⛔ moltbot.json 재시작 루프 (매우 흔한 문제)

> **이 문제는 CLI에서 moltbot.json을 직접 생성했을 때 발생한다.**

#### 증상

```
컨테이너가 무한 재시작됨:
docker ps 에서 "Restarting (1) X seconds ago" 반복

로그에 아래 에러가 반복됨:
Config invalid; plugins.slots.memory: plugin not found: memory-core
```

#### 원인

- `/home/node/.clawdbot/moltbot.json` 파일이 존재하면 Gateway가 **엄격한 설정 유효성 검사**를 수행한다
- 이미지에 내장된 `memory-core` 플러그인이 현재 버전에서 누락되어 있어 유효성 검사가 실패한다
- **빈 파일 `{}`도 동일한 문제를 발생시킨다** (파일 존재 자체가 엄격 모드를 트리거)
- moltbot.json이 없으면 memory-core는 단순 경고(`[plugins] memory slot plugin not found`)로만 출력되며 정상 작동한다

#### 해결 방법 A: moltbot.json에 `plugins.slots.memory: "none"` 추가 (권장)

```bash
CONTAINER=$(docker ps -a --format '{{.Names}}' | grep moltbot | head -1)

# moltbot.json에 plugins.slots.memory: "none" 추가
docker exec $CONTAINER node -e "
const fs = require('fs');
let config = {};
try { config = JSON.parse(fs.readFileSync('/home/node/.clawdbot/moltbot.json', 'utf8')); } catch(e) {}
if (!config.plugins) config.plugins = {};
if (!config.plugins.slots) config.plugins.slots = {};
config.plugins.slots.memory = 'none';
fs.writeFileSync('/home/node/.clawdbot/moltbot.json', JSON.stringify(config, null, 2));
console.log('Fixed: plugins.slots.memory set to none');
"

# Gateway가 hot reload로 자동 적용 (3초 대기)
sleep 3
docker logs $CONTAINER --tail 5
```

#### 해결 방법 B: moltbot.json 삭제 (기본값으로 복구)

```bash
CONTAINER=$(docker ps -a --format '{{.Names}}' | grep moltbot | head -1)

# moltbot.json 삭제 (런타임 + 볼륨)
docker exec $CONTAINER rm -f /home/node/.clawdbot/moltbot.json
CONFIG_VOL=$(docker volume ls --format '{{.Name}}' | grep moltbot-config)
docker run --rm -v $CONFIG_VOL:/data alpine rm -f /data/moltbot.json

docker restart $CONTAINER
sleep 5
docker logs $CONTAINER --tail 10
# 기대: [gateway] listening on ws://0.0.0.0:18789 (PID 7)
```

> 방법 B는 모든 커스텀 설정(모델/Provider)도 함께 삭제된다. 다시 Section 8.2 절차를 따라 재설정해야 한다.

#### 예방

- **moltbot.json 생성 시 반드시 `plugins.slots.memory: "none"` 포함**
- `"none"` 값만 유효함 — `null`, `""`, `{}`, `false` 등은 모두 validation 실패
- 소스 코드 확인: `/app/dist/config/schema.js`에 `'Select the active memory plugin by id, or "none" to disable memory plugins.'`로 정의됨

### 설정 파일 검증/복구

```bash
# 설정 파일 존재 여부 확인
docker exec $CONTAINER ls -la /home/node/.clawdbot/moltbot.json 2>/dev/null && echo "존재함 - 주의!" || echo "없음 - 정상"

# 볼륨의 설정 파일 확인
docker run --rm -v <config-volume>:/data alpine cat /data/moltbot.json 2>/dev/null || echo "없음"

# 잘못된 설정 삭제 (재시작 루프 복구)
docker run --rm -v <config-volume>:/data alpine rm -f /data/moltbot.json
```

---

## 11. 서버 SSH를 통한 전체 설정 스크립트

서버에서 한 번에 실행할 수 있는 통합 스크립트:

```bash
#!/bin/bash

# ===== 변수 설정 (반드시 실제 값으로 변경) =====
CONTAINER="myproject-moltbot-xxx-moltbot-gateway-1"

# 1. 템플릿 파일 생성 (/app/docs/reference/templates/ 경로)
echo "=== 1. 템플릿 파일 생성 ==="
docker exec $CONTAINER sh -c '
mkdir -p /app/docs/reference/templates
for f in AGENTS SOUL TOOLS USER IDENTITY BOOT BOOTSTRAP HEARTBEAT HOOK MEMORY SKILL DD SOUL_EVIL; do
  [ -f "/app/docs/reference/templates/$f.md" ] || echo "# $f" > "/app/docs/reference/templates/$f.md"
done
echo "생성 완료:"
ls /app/docs/reference/templates/*.md
'

# 2. 로그 확인
echo "=== 2. 로그 확인 ==="
docker logs $CONTAINER --tail 20

# ⛔ 주의: moltbot.json, auth-profiles.json은 CLI로 직접 생성하지 않는다!
# API 키와 모델 Provider 설정은 반드시 Web UI에서 수행해야 한다.
# Web UI: https://도메인/?token=TOKEN → Settings → Auth Profiles / Config

echo ""
echo "========================================="
echo "  템플릿 생성 완료!"
echo "  API 키 설정은 Web UI에서 진행하세요."
echo "  Web UI → Settings → Auth Profiles"
echo "========================================="
```

### 정상 시작 로그

```
[gateway] agent model: anthropic/claude-opus-4-5
[gateway] listening on ws://0.0.0.0:18789 (PID 7)
[browser/service] Browser control service ready (profiles=2)
```

> **참고**: 기본 모델은 `anthropic/claude-opus-4-5`이다. Web UI에서 Provider를 변경하면 로그에 해당 모델이 표시된다.

---

## 12. Dokploy API 자동화 전체 스크립트

> 로컬 머신에서 Dokploy API만으로 OpenClaw를 생성, 설정, 배포, 도메인 연결까지 자동화하는 스크립트이다.
> SSH 접속 없이 API만으로 배포하고, SSH는 배포 확인 및 후속 설정에만 사용한다.

```bash
#!/bin/bash
set -e

# =============================================
# 변수 설정 (반드시 실제 값으로 변경)
# =============================================
DOKPLOY_URL="http://167.88.45.173:3000"
DOKPLOY_API_KEY="your-api-key-here"
PROJECT_ID="a6NDIzHNbE4Q7j4yByowW"
ENVIRONMENT_ID="ytwpt5REIUg70vv-iZCQU"
SERVICE_NAME="OpenClaw0211"
DOMAIN="openclaw0211.vibers.kr"
SSH_CONNECTION="root@167.88.45.173"

# AI Provider 설정 (Section 0에서 수집한 정보)
AI_PROVIDER="deepseek"           # deepseek / anthropic / openai
AI_API_KEY="sk-your-api-key"     # Provider의 API Key
AI_MODEL="deepseek-chat"         # 모델 ID
AI_MODEL_FULL="deepseek/deepseek-chat"  # provider/model 형식
AI_BASE_URL="https://api.deepseek.com"  # Provider API base URL
AI_API_PROTOCOL="openai-completions"     # openai-completions / anthropic

# =============================================
# 1단계: Gateway Token 생성
# =============================================
echo "=== 1단계: Gateway Token 생성 ==="
GATEWAY_TOKEN=$(openssl rand -hex 16)
echo "Gateway Token: $GATEWAY_TOKEN"

# =============================================
# 2단계: Compose 서비스 생성
# =============================================
echo "=== 2단계: Compose 서비스 생성 ==="
COMPOSE_RESPONSE=$(curl -s -X POST "$DOKPLOY_URL/api/compose.create" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $DOKPLOY_API_KEY" \
  -d "{
    \"name\": \"$SERVICE_NAME\",
    \"projectId\": \"$PROJECT_ID\",
    \"environmentId\": \"$ENVIRONMENT_ID\"
  }")

COMPOSE_ID=$(echo "$COMPOSE_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['composeId'])")
echo "Compose ID: $COMPOSE_ID"

# =============================================
# 3단계: Docker Compose YAML 설정
# =============================================
echo "=== 3단계: Docker Compose YAML 설정 ==="
# API Key 환경변수 이름 결정 (Provider에 따라 다름)
API_KEY_ENV_NAME=$(echo "${AI_PROVIDER}_API_KEY" | tr '[:lower:]' '[:upper:]')

COMPOSE_YAML=$(cat <<YAMLEOF
services:
  moltbot-gateway:
    image: moltbot/moltbot:latest
    environment:
      HOME: /home/node
      TERM: xterm-256color
      CLAWDBOT_GATEWAY_TOKEN: $GATEWAY_TOKEN
      ${API_KEY_ENV_NAME}: $AI_API_KEY
    volumes:
      - moltbot-config:/home/node/.moltbot
      - moltbot-workspace:/home/node/clawd
    ports:
      - "18789"
      - "18790"
    init: true
    restart: unless-stopped
    command:
      - gateway
      - --bind
      - lan
      - --port
      - "18789"
      - --allow-unconfigured
      - --token
      - $GATEWAY_TOKEN
    networks:
      - dokploy-network

volumes:
  moltbot-config:
  moltbot-workspace:

networks:
  dokploy-network:
    external: true
YAMLEOF
)

COMPOSE_JSON=$(echo "$COMPOSE_YAML" | python3 -c "import sys, json; print(json.dumps(sys.stdin.read()))")

curl -s -X POST "$DOKPLOY_URL/api/compose.update" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $DOKPLOY_API_KEY" \
  -d "{
    \"composeId\": \"$COMPOSE_ID\",
    \"composeFile\": $COMPOSE_JSON,
    \"sourceType\": \"raw\"
  }" > /dev/null

echo "YAML 설정 완료"

# =============================================
# 4단계: 첫 번째 배포 실행
# =============================================
echo "=== 4단계: 첫 번째 배포 실행 ==="
curl -s -X POST "$DOKPLOY_URL/api/compose.deploy" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $DOKPLOY_API_KEY" \
  -d "{\"composeId\": \"$COMPOSE_ID\"}" > /dev/null

echo "배포 큐에 등록됨. 20초 대기..."
sleep 20

# 배포 상태 확인
STATUS=$(curl -s "$DOKPLOY_URL/api/compose.one?composeId=$COMPOSE_ID" \
  -H "x-api-key: $DOKPLOY_API_KEY" | python3 -c "import sys,json; print(json.load(sys.stdin)['composeStatus'])")
echo "배포 상태: $STATUS"

if [ "$STATUS" != "done" ]; then
  echo "배포가 아직 완료되지 않았습니다. 추가 대기가 필요할 수 있습니다."
fi

# =============================================
# 5단계: SSH로 컨테이너 확인
# =============================================
echo "=== 5단계: 컨테이너 실행 확인 ==="
ssh $SSH_CONNECTION "docker ps --format '{{.Names}}\t{{.Status}}' | grep moltbot"

# =============================================
# 5.1단계: ⛔ 볼륨 권한 수정 (필수!)
# Docker named volume은 root 소유로 생성되지만 컨테이너는 node 사용자로 실행됨
# 권한 수정 안 하면 EACCES 에러 + "disconnected (1000): no reason" 발생
# =============================================
echo "=== 5.1단계: 볼륨 권한 수정 (node 사용자로 변경) ==="
CONTAINER=$(ssh $SSH_CONNECTION "docker ps --format '{{.Names}}' | grep moltbot | head -1")
echo "컨테이너: $CONTAINER"

ssh $SSH_CONNECTION "docker exec --user root $CONTAINER chown -R node:node /home/node/.moltbot"
echo "볼륨 권한 수정 완료"

# 컨테이너 재시작 (권한 변경 적용)
ssh $SSH_CONNECTION "docker restart $CONTAINER"
echo "컨테이너 재시작 완료. 10초 대기..."
sleep 10

# =============================================
# 6단계: 도메인이 설정된 경우 재배포
# =============================================
if [ -n "$DOMAIN" ]; then
  echo "=== 6단계: 도메인 추가 후 재배포 ==="
  echo "Dokploy UI에서 도메인을 추가하세요:"
  echo "  Host: $DOMAIN"
  echo "  Container Port: 18789"
  echo "  HTTPS: 체크"
  echo "  Certificate: Let's Encrypt"
  echo "  Service Name: moltbot-gateway"
  echo ""
  read -p "도메인 추가 완료 후 Enter를 눌러 재배포하세요..."

  curl -s -X POST "$DOKPLOY_URL/api/compose.deploy" \
    -H "Content-Type: application/json" \
    -H "x-api-key: $DOKPLOY_API_KEY" \
    -d "{\"composeId\": \"$COMPOSE_ID\"}" > /dev/null

  echo "재배포 실행됨. 20초 대기..."
  sleep 20

  # 접속 테스트
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 -k "https://$DOMAIN/")
  echo "접속 테스트 결과: HTTP $HTTP_STATUS"
fi

# =============================================
# 7단계: 템플릿 파일 생성 (docker exec)
# =============================================
echo "=== 7단계: 템플릿 파일 생성 ==="
CONTAINER=$(ssh $SSH_CONNECTION "docker ps --format '{{.Names}}' | grep moltbot | head -1")
echo "컨테이너: $CONTAINER"

ssh $SSH_CONNECTION "docker exec $CONTAINER sh -c '
mkdir -p /app/docs/reference/templates
for f in AGENTS SOUL TOOLS USER IDENTITY BOOT BOOTSTRAP HEARTBEAT HOOK MEMORY SKILL DD SOUL_EVIL; do
  [ -f \"/app/docs/reference/templates/\$f.md\" ] || echo \"# \$f\" > \"/app/docs/reference/templates/\$f.md\"
done
echo \"템플릿 파일 생성 완료\"
ls /app/docs/reference/templates/*.md
'"

# =============================================
# 8단계: moltbot.json 생성 (⚠️ plugins.slots.memory: "none" 필수!)
# =============================================
echo "=== 8단계: moltbot.json 생성 (plugins.slots.memory: none 필수!) ==="

# API Key 환경변수 참조 문자열 생성
API_KEY_REF="\${${API_KEY_ENV_NAME}}"

ssh $SSH_CONNECTION "docker exec $CONTAINER node -e \"
const fs = require('fs');
const config = {
  plugins: { slots: { memory: 'none' } },
  messages: { ackReactionScope: 'group-mentions' },
  agents: {
    defaults: {
      maxConcurrent: 4,
      subagents: { maxConcurrent: 8 },
      compaction: { mode: 'safeguard' },
      model: { primary: '$AI_MODEL_FULL' }
    }
  },
  models: {
    providers: {
      '$AI_PROVIDER': {
        baseUrl: '$AI_BASE_URL',
        apiKey: '$API_KEY_REF',
        api: '$AI_API_PROTOCOL',
        models: [{
          id: '$AI_MODEL',
          name: '$AI_PROVIDER $AI_MODEL',
          contextWindow: 128000,
          maxTokens: 8192
        }]
      }
    }
  }
};
fs.writeFileSync('/home/node/.clawdbot/moltbot.json', JSON.stringify(config, null, 2));
console.log('moltbot.json 생성 완료 (plugins.slots.memory: none 포함)');
\""

# Hot Reload 확인 (3초 대기)
sleep 3
echo "=== Hot Reload 확인 ==="
ssh $SSH_CONNECTION "docker logs $CONTAINER --tail 5"

# =============================================
# 결과 출력
# =============================================
echo ""
echo "========================================="
echo "  OpenClaw 설치 완료!"
echo "========================================="
echo "  Compose ID:    $COMPOSE_ID"
echo "  Gateway Token: $GATEWAY_TOKEN"
echo "  AI Provider:   $AI_PROVIDER ($AI_MODEL_FULL)"
echo "  접속 URL:      https://$DOMAIN/?token=$GATEWAY_TOKEN"
echo ""
echo "  다음 단계 (수동):"
echo "  1. 브라우저에서 접속 → Device Pairing 승인"
echo "     ssh $SSH_CONNECTION \"docker exec $CONTAINER node dist/index.js devices list\""
echo "     ssh $SSH_CONNECTION \"docker exec $CONTAINER node dist/index.js devices approve REQUEST_ID\""
echo "  2. Chat에서 메시지 전송하여 최종 테스트"
echo "========================================="
```

---

## Dokploy 배포 워크플로우 요약

### 새 OpenClaw 배포 순서

| 단계 | 작업 | 방법 | 비고 |
|------|------|------|------|
| **0** | **⛔ 필수 사전 정보 수집** | **사용자에게 6가지 정보 요청** | **SSH, 프로젝트, 서비스명, Provider, API Key, 도메인 (Section 0)** |
| 1 | Gateway Token 생성 | `openssl rand -hex 16` | 32자 hex 문자열 |
| 2 | Compose 서비스 생성 | UI 또는 `compose.create` API | composeId 획득 |
| 3 | Docker Compose YAML 입력 | `compose.update` API | Token + **API Key 환경변수** 포함, sourceType: "raw" 필수 |
| 4 | 첫 번째 배포 실행 | `compose.deploy` API | 이미지 풀 + 컨테이너 생성 |
| 5 | 컨테이너 정상 확인 | SSH: `docker ps`, `docker logs` | 3줄 정상 로그 확인 |
| **5.1** | **⛔ 볼륨 권한 수정** | SSH: `docker exec --user root $CONTAINER chown -R node:node /home/node/.moltbot` + 재시작 | **첫 배포 후 필수! 안 하면 EACCES 에러** |
| 6 | 도메인 추가 | UI 또는 `domain.create` API | Host, Port **18789**, HTTPS, Let's Encrypt, Service: moltbot-gateway |
| 7 | **재배포 실행** | `compose.deploy` API | **⚠️ 도메인 추가 후 필수!** |
| 8 | **템플릿 파일 생성** | SSH: `docker exec` | 13개 .md 파일을 `/app/docs/reference/templates/`에 생성 |
| 9 | 접속 테스트 | `https://도메인/?token=TOKEN` | HTTP 200 + SSL 확인 |
| 10 | Device Pairing | SSH: `devices list` → `devices approve` | 첫 브라우저 접속 시 필수 |
| 11 | **moltbot.json 생성** | SSH: `docker exec` (Section 8.2) | **⚠️ `plugins.slots.memory: "none"` 필수! (Section 0 참조)** |
| 12 | **Hot Reload 확인** | SSH: `docker logs` | `agent model: deepseek/deepseek-chat` 확인 |
| 13 | 최종 테스트 | Chat에서 메시지 전송 | AI 응답 정상 확인 |

### 핵심 주의사항 요약

| # | 규칙 | 이유 |
|---|------|------|
| **0** | **⛔ 설치 전 6가지 정보 반드시 수집** | **정보 없이 시작하면 중간에 막혀서 처음부터 다시 해야 함 (Section 0)** |
| 1 | **Gateway Token은 environment + --token 두 곳에** | 환경변수만으로는 작동하지 않음 |
| 2 | **도메인 추가 후 반드시 재배포** | Compose 서비스는 재배포 없이 Traefik 라벨 미적용 |
| 3 | **Container Port는 18789** (3000 아님) | 기본값 3000 사용 시 접속 불가 |
| 4 | **템플릿 파일은 /app/docs/reference/templates/** | 워크스페이스(/home/node/clawd/)가 아님 |
| 5 | **⛔ moltbot.json에 `plugins.slots.memory: "none"` 필수** | **없으면 memory-core validation 실패 → 모든 설정 변경 불가, 재시작 루프 (Section 0 상세 설명)** |
| 6 | **API 키는 Docker Compose 환경변수 + moltbot.json** | Web UI Config Save는 memory-core 버그로 작동 안 함 |
| 7 | **재배포 시 템플릿 파일 재생성 필요** | /app/ 경로는 이미지 내부, 볼륨에 저장 안 됨 |
| 8 | **⛔ 첫 배포 후 볼륨 권한 수정 필수** | Docker named volume이 root 소유로 생성됨 → `chown -R node:node` 필요 |

### 사용된 Dokploy API 엔드포인트 요약

| API | 메서드 | 용도 |
|-----|--------|------|
| `/api/compose.create` | POST | Compose 서비스 생성 (name, projectId, environmentId 필수) |
| `/api/compose.update` | POST | YAML 설정 업데이트 (composeFile, sourceType: "raw" 필수) |
| `/api/compose.deploy` | POST | 배포/재배포 실행 (composeId 필수) |
| `/api/compose.delete` | POST | Compose 서비스 삭제 (composeId 필수) |
| `/api/compose.one?composeId=` | GET | 서비스 상태 조회 (도메인, 배포 이력 포함) |
| `/api/domain.create` | POST | 도메인 추가 (host, port, https, certificateType, serviceName, composeId 필수) |
