#!/bin/bash
# swagger.sh - Dokploy API (Swagger) 확인 스크립트
#
# 이 스크립트는 Dokploy 서버의 API를 테스트하고 확인합니다.
# Swagger UI는 브라우저에서 로그인 후 접근 가능합니다.
#
# 사용법:
#   ./scripts/swagger.sh --server-url=http://IP:3000 --api-key=YOUR_API_KEY
#
# 예시:
#   ./scripts/swagger.sh --server-url=http://209.97.169.136:3000 --api-key=xxxxx

# ==========================================
# 터미널 색상 정의
# ==========================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ==========================================
# 파라미터 파싱
# ==========================================
DOKPLOY_SERVER_URL=""
DOKPLOY_API_KEY=""

for arg in "$@"; do
  case $arg in
    --server-url=*)
      DOKPLOY_SERVER_URL="${arg#*=}"
      ;;
    --api-key=*)
      DOKPLOY_API_KEY="${arg#*=}"
      ;;
    --help|-h)
      echo "사용법: $0 --server-url=URL --api-key=KEY"
      echo ""
      echo "옵션:"
      echo "  --server-url=URL   Dokploy 서버 URL (예: http://IP:3000)"
      echo "  --api-key=KEY      Dokploy API 키"
      echo "  --help, -h         도움말 표시"
      echo ""
      echo "예시:"
      echo "  $0 --server-url=http://209.97.169.136:3000 --api-key=xxxxx"
      exit 0
      ;;
  esac
done

# ==========================================
# 필수 파라미터 검증
# ==========================================
if [ -z "$DOKPLOY_SERVER_URL" ]; then
  echo -e "${RED}오류: --server-url 파라미터가 필요합니다${NC}"
  echo "사용법: $0 --server-url=URL --api-key=KEY"
  exit 1
fi

if [ -z "$DOKPLOY_API_KEY" ]; then
  echo -e "${RED}오류: --api-key 파라미터가 필요합니다${NC}"
  echo "사용법: $0 --server-url=URL --api-key=KEY"
  exit 1
fi

# ==========================================
# API 호출 함수
# ==========================================
call_api() {
  local endpoint="$1"
  local method="${2:-GET}"
  local data="$3"

  if [ "$method" == "GET" ]; then
    curl -s -X "$method" \
      "${DOKPLOY_SERVER_URL}/api${endpoint}" \
      -H 'accept: application/json' \
      -H "x-api-key: ${DOKPLOY_API_KEY}"
  else
    curl -s -X "$method" \
      "${DOKPLOY_SERVER_URL}/api${endpoint}" \
      -H 'Content-Type: application/json' \
      -H 'accept: application/json' \
      -H "x-api-key: ${DOKPLOY_API_KEY}" \
      -d "$data"
  fi
}

# ==========================================
# 메인 실행
# ==========================================
echo -e "${CYAN}======================================${NC}"
echo -e "${CYAN}  Dokploy API (Swagger) 확인 스크립트${NC}"
echo -e "${CYAN}======================================${NC}"
echo ""
echo -e "${BLUE}서버 URL:${NC} $DOKPLOY_SERVER_URL"
echo -e "${BLUE}Swagger UI:${NC} ${DOKPLOY_SERVER_URL}/swagger (브라우저에서 로그인 필요)"
echo ""

# API 연결 테스트
echo -e "${YELLOW}[1/4] API 연결 테스트 중...${NC}"
response=$(call_api "/project.all")
if echo "$response" | grep -q "projectId\|^\[\]"; then
  echo -e "${GREEN}✅ API 연결 성공${NC}"
else
  echo -e "${RED}❌ API 연결 실패${NC}"
  echo "응답: $response"
  exit 1
fi
echo ""

# 프로젝트 목록 조회
echo -e "${YELLOW}[2/4] 프로젝트 목록 조회...${NC}"
projects=$(call_api "/project.all" | jq -r '.[] | "\(.name) (ID: \(.projectId))"' 2>/dev/null)
if [ -n "$projects" ]; then
  echo -e "${GREEN}프로젝트 목록:${NC}"
  echo "$projects" | while read -r line; do
    echo "  - $line"
  done
else
  echo -e "${YELLOW}프로젝트가 없습니다.${NC}"
fi
echo ""

# 주요 API 엔드포인트 목록
echo -e "${YELLOW}[3/4] 사용 가능한 주요 API 엔드포인트:${NC}"
echo ""
echo -e "${CYAN}📁 프로젝트 (Project)${NC}"
echo "  GET  /api/project.all          - 모든 프로젝트 조회"
echo "  POST /api/project.create       - 프로젝트 생성"
echo "  POST /api/project.remove       - 프로젝트 삭제"
echo ""
echo -e "${CYAN}📦 애플리케이션 (Application)${NC}"
echo "  POST /api/application.create   - 애플리케이션 생성"
echo "  POST /api/application.start    - 애플리케이션 시작"
echo "  POST /api/application.stop     - 애플리케이션 중지"
echo "  POST /api/application.redeploy - 애플리케이션 재배포"
echo "  POST /api/application.saveEnvironment - 환경 변수 저장"
echo ""
echo -e "${CYAN}🗄️ 데이터베이스 (Database)${NC}"
echo "  POST /api/postgres.create      - PostgreSQL 생성"
echo "  POST /api/mysql.create         - MySQL 생성"
echo "  POST /api/mongo.create         - MongoDB 생성"
echo "  POST /api/redis.create         - Redis 생성"
echo ""
echo -e "${CYAN}🌐 도메인 (Domain)${NC}"
echo "  POST /api/domain.create        - 도메인 생성"
echo ""
echo -e "${CYAN}🚀 배포 (Deployment)${NC}"
echo "  GET  /api/deployment.all       - 배포 목록 조회"
echo ""

# 상세 정보 출력 (선택적)
echo -e "${YELLOW}[4/4] 전체 프로젝트 데이터 (JSON):${NC}"
echo ""
call_api "/project.all" | jq '.' 2>/dev/null || call_api "/project.all"
echo ""

echo -e "${CYAN}======================================${NC}"
echo -e "${GREEN}✅ Swagger 확인 완료${NC}"
echo ""
echo -e "${BLUE}💡 팁:${NC}"
echo "  - Swagger UI는 브라우저에서 ${DOKPLOY_SERVER_URL}/swagger 로 접근"
echo "  - Dokploy에 로그인 후 API 테스트 가능"
echo "  - API 문서: https://docs.dokploy.com/docs/api"
echo -e "${CYAN}======================================${NC}"
