#!/bin/bash
# traefik-setting.sh - Traefik 정적 설정 확인 스크립트
#
# 사용법:
#   ./traefik-setting.sh --ssh-connection=root@1.2.3.4 [--dokploy-server-url=http://1.2.3.4:3000]
#
# 이 스크립트는 Dokploy 서버의 Traefik 정적 설정(traefik.yml)을 확인합니다.

# 스크립트 디렉토리 설정 및 config.sh 로드
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# 파라미터 파싱
parse_server_params "$@"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Dokploy Traefik 정적 설정 확인${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${GREEN}서버:${NC} $ROOT_SSH_CONNECTION"
[ -n "$DOKPLOY_SERVER_URL" ] && echo -e "${GREEN}Dokploy URL:${NC} $DOKPLOY_SERVER_URL"
echo ""

# Traefik 정적 설정 파일 경로
TRAEFIK_CONFIG="/etc/dokploy/traefik/traefik.yml"

echo -e "${YELLOW}[1/3] Traefik 정적 설정 (traefik.yml)${NC}"
echo "----------------------------------------"
ssh "$ROOT_SSH_CONNECTION" "cat $TRAEFIK_CONFIG 2>/dev/null || echo '파일을 찾을 수 없습니다: $TRAEFIK_CONFIG'"
echo ""

echo -e "${YELLOW}[2/3] Traefik 동적 설정 파일 목록${NC}"
echo "----------------------------------------"
ssh "$ROOT_SSH_CONNECTION" "ls -la /etc/dokploy/traefik/dynamic/ 2>/dev/null || echo '디렉토리를 찾을 수 없습니다'"
echo ""

echo -e "${YELLOW}[3/3] Traefik 컨테이너 상태${NC}"
echo "----------------------------------------"
ssh "$ROOT_SSH_CONNECTION" "docker ps --filter 'name=traefik' --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}설정 확인 완료${NC}"
echo -e "${GREEN}========================================${NC}"
