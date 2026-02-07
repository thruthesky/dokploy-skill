# OpenClaw (Moltbot) Dokploy 배포 레퍼런스

## 목차

1. [핵심 개념](#1-핵심-개념)
2. [아키텍처 및 포트](#2-아키텍처-및-포트)
3. [Docker Compose YAML](#3-docker-compose-yaml)
4. [Gateway Token 설정](#4-gateway-token-설정)
5. [도메인 및 HTTPS 설정](#5-도메인-및-https-설정)
6. [Device Pairing (기기 승인)](#6-device-pairing-기기-승인)
7. [API 키 및 모델 Provider 설정](#7-api-키-및-모델-provider-설정)
8. [템플릿 파일 생성](#8-템플릿-파일-생성)
9. [트러블슈팅](#9-트러블슈팅)
10. [전체 설정 스크립트](#10-전체-설정-스크립트)

---

## 1. 핵심 개념

### OpenClaw이란?

OpenClaw은 AI Gateway 플랫폼으로, 다양한 AI 모델(Claude, GPT, DeepSeek 등)을 웹 UI를 통해 관리하고 사용할 수 있는 셀프호스팅 솔루션이다. Docker 이미지명은 `moltbot/moltbot:latest`이며 Docker Hub에서 배포된다.

### 핵심 정보

| 항목 | 값 |
|------|-----|
| **Docker 이미지** | `moltbot/moltbot:latest` (Docker Hub) |
| **패키지명** | moltbot (OpenClaw의 이전 버전명) |
| **기본 포트** | 18789 (Gateway), 18790 (Canvas) |
| **설정 디렉토리** | `/home/node/.moltbot` |
| **워크스페이스** | `/home/node/clawd` |
| **메인 설정 파일** | `/home/node/.moltbot/moltbot.json` |
| **API 키 파일** | `/home/node/.moltbot/agents/main/agent/auth-profiles.json` |

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
    image: moltbot/moltbot:latest
    environment:
      HOME: /home/node
      TERM: xterm-256color
      CLAWDBOT_GATEWAY_TOKEN: YOUR_TOKEN_HERE
      OPENROUTER_API_KEY: ${OPENROUTER_API_KEY}
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
| `image: moltbot/moltbot:latest` | Docker Hub 공식 이미지 | 필수 |
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
# 예시 출력: 2atffjjnrmogozfqmv0ds2nyxwgzoq2q
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

## 5. 도메인 및 HTTPS 설정

### Dokploy UI 도메인 설정

| 필드 | 값 |
|------|-----|
| **Host** | `claw.example.com` (본인 도메인) |
| **Container Port** | `18789` ⚠️ **반드시 18789!** (기본값 3000 아님) |
| **HTTPS** | ✅ 체크 |
| **Certificate** | `Let's Encrypt` |

### DNS 설정 확인

```bash
dig +short claw.example.com
# 출력: 서버 IP 주소
```

### 핵심 로직 - Traefik 라우팅

```
[Traefik] → Port 18789 → [Moltbot Container]
```

---

## 6. Device Pairing (기기 승인)

### 핵심 개념

Moltbot은 보안을 위해 각 브라우저/기기마다 일회성 승인이 필요하다. 새 브라우저에서 처음 접속 시 `disconnected (1008): unauthorized: pairing required` 에러가 표시된다.

### 기기 승인 워크플로우

```bash
# 1. 컨테이너 이름 확인
CONTAINER=$(docker ps --format '{{.Names}}' | grep moltbot | head -1)

# 2. 승인 대기 중인 기기 목록 확인
docker exec $CONTAINER node dist/index.js devices list

# 출력 예시:
# Pending approval:
#   Request ID: abc123def456
#   Platform: MacIntel
#   Client: moltbot-control-ui webchat

# 3. 기기 승인
docker exec $CONTAINER node dist/index.js devices approve abc123def456
```

> **참고**: 다른 컴퓨터/브라우저에서 접속할 때마다 같은 과정을 반복해야 한다.

---

## 7. API 키 및 모델 Provider 설정

### 7.1 지원 AI Provider

| Provider | API 키 형식 | 모델 ID 형식 |
|----------|------------|-------------|
| DeepSeek | `sk-xxxxxxxx` | `deepseek/deepseek-chat` |
| Anthropic | `sk-ant-xxxxxxxx` | `anthropic/claude-opus-4-5` |
| OpenAI | `sk-xxxxxxxx` | `openai/gpt-4o` |
| OpenRouter | `sk-or-xxxxxxxx` | (다양) |

### 7.2 API 키 설정 - auth-profiles.json

**파일 경로**: `/home/node/.moltbot/agents/main/agent/auth-profiles.json`

```bash
CONTAINER=$(docker ps --format '{{.Names}}' | grep moltbot | head -1)

# DeepSeek API 키 설정
docker exec $CONTAINER bash -c 'mkdir -p /home/node/.moltbot/agents/main/agent && cat > /home/node/.moltbot/agents/main/agent/auth-profiles.json << EOF
{
  "version": 1,
  "profiles": {
    "deepseek:default": {
      "type": "api_key",
      "provider": "deepseek",
      "key": "sk-여기에-API-키-입력"
    }
  }
}
EOF'
```

### 핵심 소스코드 - Provider별 auth-profiles.json

**DeepSeek:**

```json
{
  "version": 1,
  "profiles": {
    "deepseek:default": {
      "type": "api_key",
      "provider": "deepseek",
      "key": "sk-여기에-API-키-입력"
    }
  }
}
```

**Anthropic:**

```json
{
  "version": 1,
  "profiles": {
    "anthropic:default": {
      "type": "api_key",
      "provider": "anthropic",
      "key": "sk-ant-여기에-API-키-입력"
    }
  }
}
```

**OpenAI:**

```json
{
  "version": 1,
  "profiles": {
    "openai:default": {
      "type": "api_key",
      "provider": "openai",
      "key": "sk-여기에-API-키-입력"
    }
  }
}
```

### 7.3 모델 Provider 설정 - moltbot.json

**파일 경로**: `/home/node/.moltbot/moltbot.json`

기본 모델은 `anthropic/claude-opus-4-5`이다. DeepSeek 등 다른 모델을 사용하려면 provider 설정이 필요하다.

### 방법 1: Web UI에서 설정 (권장)

1. `https://도메인/?token=YOUR_TOKEN` 접속
2. 좌측 메뉴 → **Settings** → **Config**
3. JSON 편집 모드에서 아래 내용 추가:

```json
{
  "models": {
    "providers": {
      "deepseek": {
        "baseUrl": "https://api.deepseek.com",
        "api": "openai-completions",
        "models": [
          {
            "id": "deepseek-chat",
            "name": "DeepSeek Chat",
            "contextWindow": 64000
          }
        ]
      }
    }
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "deepseek/deepseek-chat"
      }
    }
  }
}
```

### 방법 2: CLI에서 moltbot.json 직접 설정

```bash
# 볼륨 이름 확인
docker volume ls | grep moltbot
# 예시: myproject-moltbot-abc123_moltbot-config

# moltbot.json 생성 (DeepSeek 예시)
docker run --rm -v <볼륨이름>:/data alpine sh -c 'cat > /data/moltbot.json << EOF
{
  "gateway": {
    "trustedProxies": [
      "10.0.0.0/8",
      "172.16.0.0/12"
    ]
  },
  "models": {
    "providers": {
      "deepseek": {
        "baseUrl": "https://api.deepseek.com",
        "api": "openai-completions",
        "models": [
          {
            "id": "deepseek-chat",
            "name": "DeepSeek Chat",
            "contextWindow": 64000
          }
        ]
      }
    }
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "deepseek/deepseek-chat"
      }
    }
  }
}
EOF'
```

### 설정 후 확인

```bash
docker restart $CONTAINER
# 로그에서 확인:
# [gateway] agent model: deepseek/deepseek-chat
```

---

## 8. 템플릿 파일 생성

### 핵심 개념

Moltbot은 워크스페이스(`/home/node/clawd/`)에 특정 `.md` 템플릿 파일이 필요하다. 없으면 Chat에서 에러가 발생한다.

### 필수 템플릿 파일 목록

| 파일 | 설명 |
|------|------|
| `AGENTS.md` | 에이전트 정의 |
| `SOUL.md` | AI 성격/페르소나 |
| `TOOLS.md` | 도구 정의 |
| `USER.md` | 사용자 정보 |
| `IDENTITY.md` | 신원 정보 |
| `BOOT.md` | 부팅 스크립트 |
| `BOOTSTRAP.md` | 초기화 스크립트 |
| `HEARTBEAT.md` | 하트비트 설정 |
| `HOOK.md` | 훅 설정 |
| `MEMORY.md` | 메모리 설정 |
| `SKILL.md` | 스킬 정의 |
| `DD.md` | 추가 설정 |
| `SOUL_EVIL.md` | 대체 페르소나 |

### 일괄 생성 스크립트

```bash
WORKSPACE_VOL="myproject-moltbot-abc123_moltbot-workspace"

docker run --rm -v $WORKSPACE_VOL:/data alpine sh -c '
for file in AGENTS.md SOUL.md TOOLS.md USER.md IDENTITY.md BOOT.md BOOTSTRAP.md HEARTBEAT.md HOOK.md MEMORY.md SKILL.md DD.md SOUL_EVIL.md; do
  touch /data/$file
done
ls -la /data/*.md
'
```

### AGENTS.md 기본 내용 (선택)

```bash
docker run --rm -v $WORKSPACE_VOL:/data alpine sh -c 'cat > /data/AGENTS.md << EOF
# Agents Configuration

## Main Agent
- Name: Assistant
- Role: General purpose AI assistant

EOF'
```

---

## 9. 트러블슈팅

### 에러별 원인 및 해결

| 에러 | 원인 | 해결 |
|------|------|------|
| **404 Not Found** | Traefik이 컨테이너에 연결되지 않음 | `dokploy-network` 확인, 포트 `18789` 확인, 재배포 |
| **502 Bad Gateway** | 컨테이너 크래시 또는 포트 불일치 | `docker ps -a \| grep moltbot`, `docker logs` 확인 |
| **gateway token missing** | URL에 token 파라미터 없음 또는 `--token` CLI 옵션 누락 | `?token=YOUR_TOKEN` 추가, command에 `--token` 추가 |
| **pairing required** | 새 브라우저/기기에서 첫 접속 | `devices list` → `devices approve` |
| **Unknown model** | 모델 provider 미설정 | moltbot.json에 provider 설정 추가 |
| **No API key found** | auth-profiles.json에 API 키 없음 | auth-profiles.json 생성/수정 |
| **Missing workspace template** | 워크스페이스에 .md 파일 없음 | 템플릿 파일 일괄 생성 |
| **memory-core plugin not found** | 이미지의 알려진 버그 | `--allow-unconfigured` 플래그 확인 (있으면 무시됨) |
| **컨테이너 재시작 루프** | 설정 파일 유효성 검사 실패 | `moltbot.json` 확인 또는 삭제 후 재시작 |

### Gateway Token 재시작 루프 디버깅

```bash
# 로그에서 아래 메시지가 반복되면:
# "Gateway auth is set to token, but no token is configured"
# → command에 --token 옵션을 추가해야 함

docker logs $CONTAINER --tail 50
```

### 설정 파일 검증/복구

```bash
# 설정 파일 확인
docker run --rm -v <config-volume>:/data alpine cat /data/moltbot.json

# 잘못된 설정 삭제
docker run --rm -v <config-volume>:/data alpine rm /data/moltbot.json
```

---

## 10. 전체 설정 스크립트

서버에서 한 번에 실행할 수 있는 통합 스크립트:

```bash
#!/bin/bash

# ===== 변수 설정 (반드시 실제 값으로 변경) =====
CONTAINER="myproject-moltbot-xxx-moltbot-gateway-1"
CONFIG_VOL="myproject-moltbot-xxx_moltbot-config"
WORKSPACE_VOL="myproject-moltbot-xxx_moltbot-workspace"
DEEPSEEK_API_KEY="sk-your-api-key-here"

# 1. 템플릿 파일 생성
docker run --rm -v $WORKSPACE_VOL:/data alpine sh -c '
for file in AGENTS.md SOUL.md TOOLS.md USER.md IDENTITY.md BOOT.md BOOTSTRAP.md HEARTBEAT.md HOOK.md MEMORY.md SKILL.md DD.md SOUL_EVIL.md; do
  touch /data/$file
done
'

# 2. moltbot.json 설정
docker run --rm -v $CONFIG_VOL:/data alpine sh -c "cat > /data/moltbot.json << 'EOF'
{
  \"gateway\": {
    \"trustedProxies\": [\"10.0.0.0/8\", \"172.16.0.0/12\"]
  },
  \"models\": {
    \"providers\": {
      \"deepseek\": {
        \"baseUrl\": \"https://api.deepseek.com\",
        \"api\": \"openai-completions\",
        \"models\": [{\"id\": \"deepseek-chat\", \"name\": \"DeepSeek Chat\", \"contextWindow\": 64000}]
      }
    }
  },
  \"agents\": {
    \"defaults\": {
      \"model\": {\"primary\": \"deepseek/deepseek-chat\"}
    }
  }
}
EOF"

# 3. auth-profiles.json 설정
docker run --rm -v $CONFIG_VOL:/data alpine sh -c "mkdir -p /data/agents/main/agent && cat > /data/agents/main/agent/auth-profiles.json << 'EOF'
{
  \"version\": 1,
  \"profiles\": {
    \"deepseek:default\": {
      \"type\": \"api_key\",
      \"provider\": \"deepseek\",
      \"key\": \"$DEEPSEEK_API_KEY\"
    }
  }
}
EOF"

# 4. 권한 설정 (node 사용자: UID 1000)
docker run --rm -v $CONFIG_VOL:/data alpine chown -R 1000:1000 /data
docker run --rm -v $WORKSPACE_VOL:/data alpine chown -R 1000:1000 /data

# 5. 컨테이너 재시작
docker restart $CONTAINER

# 6. 로그 확인
sleep 5
docker logs $CONTAINER --tail 20
```

### 정상 시작 로그

```
[gateway] agent model: deepseek/deepseek-chat
[gateway] listening on ws://0.0.0.0:18789 (PID 7)
[browser/service] Browser control service ready (profiles=2)
```

---

## Dokploy 배포 워크플로우 요약

### 새 OpenClaw 배포 순서

1. Dokploy에서 프로젝트 생성 → Compose 서비스 추가
2. Docker Compose YAML 입력 (Gateway Token 두 곳 설정)
3. 환경변수 설정 (`CLAWDBOT_GATEWAY_TOKEN`)
4. 도메인 추가 (Container Port: **18789**)
5. HTTPS 활성화 (Let's Encrypt)
6. 첫 배포 실행
7. `https://도메인/?token=YOUR_TOKEN` 으로 접속 테스트
8. Device Pairing 승인
9. API 키 설정 (Web UI 또는 CLI)
10. 모델 Provider 설정 (필요 시)
11. 템플릿 파일 생성 (필요 시)
12. 최종 테스트 (Chat에서 메시지 전송)
