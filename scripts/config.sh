#!/bin/bash
# config.sh - Dokploy 배포 스크립트 공통 설정
#
# 이 파일은 모든 배포 스크립트에서 공유하는 설정 값을 정의합니다.
# 다른 스크립트에서 source 하여 사용합니다.
#
# 사용 방법:
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "$SCRIPT_DIR/config.sh"

# ==========================================
# Dokploy 서버 설정
# ==========================================

# ⚠️ 보안 주의: 아래 두 값은 파일에 저장하지 않습니다!
# 스크립트 실행 시 파라미터로 전달받습니다.
#
# --ssh-connection=root@1.2.3.4
# --dokploy-server-url=http://1.2.3.4:3000
#
# 예시:
#   ./scripts/traefik-setting.sh --ssh-connection=root@1.2.3.4 --dokploy-server-url=http://1.2.3.4:3000

# 파라미터 파싱 함수 (각 스크립트에서 호출)
parse_server_params() {
  for arg in "$@"; do
    case $arg in
      --ssh-connection=*)
        ROOT_SSH_CONNECTION="${arg#*=}"
        ;;
      --dokploy-server-url=*)
        DOKPLOY_SERVER_URL="${arg#*=}"
        ;;
    esac
  done

  # 필수 파라미터 검증
  if [ -z "$ROOT_SSH_CONNECTION" ]; then
    echo -e "${RED}오류: --ssh-connection 파라미터가 필요합니다${NC}"
    echo "사용법: $0 --ssh-connection=root@IP [--dokploy-server-url=http://IP:3000]"
    exit 1
  fi
}


# Dokploy 애플리케이션 ID
# 옵션: 필요한 경우에 사용자로 부터 입력 받도록 수정
DOKPLOY_APP_ID=""

# Dokploy API 키
# 옵션: 필요한 경우에 사용자로 부터 입력 받도록 수정
# 예: xxxxyyyzzzz...
DOKPLOY_API_KEY=""


# ==========================================
# 데이터베이스 설정
# ==========================================

# PostgreSQL 접속 정보
# 옵션: 필요한 경우에 사용자로 부터 입력 받도록 수정
# PosgreSQL 설정에 나와 있음
DB_URL="postgresql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}"

# ==========================================
# SSH 설정
# ==========================================


# ==========================================
# 사이트 설정
# ==========================================

# ==========================================
# 터미널 색상 정의
# ==========================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ==========================================
# 공통 함수
# ==========================================

# 배포 상태에 따른 이모지 반환
get_status_emoji() {
  case "$1" in
    "running") echo "🔵" ;;
    "done") echo "✅" ;;
    "error") echo "❌" ;;
    "cancelled") echo "⚠️" ;;
    "queued") echo "⏳" ;;
    *) echo "⚪" ;;
  esac
}

# 배포 상태에 따른 색상 반환
get_status_color() {
  case "$1" in
    "running") echo "$BLUE" ;;
    "done") echo "$GREEN" ;;
    "error") echo "$RED" ;;
    "cancelled") echo "$YELLOW" ;;
    *) echo "$NC" ;;
  esac
}

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
