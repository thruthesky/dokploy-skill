# Dokploy 데이터베이스 관리 가이드

## 목차

1. [센터 프로젝트 데이터베이스 설정](#센터-프로젝트-데이터베이스-설정)
2. [지원 데이터베이스](#지원-데이터베이스)
3. [데이터베이스 생성](#데이터베이스-생성)
4. [연결 정보 확인](#연결-정보-확인)
5. [백업 및 복원](#백업-및-복원)
6. [모니터링](#모니터링)
7. [문제 해결](#문제-해결)

---

## 센터 프로젝트 데이터베이스 설정

> **참고**: 센터 프로젝트의 데이터베이스 설정은 `.claude/skills/center-skill/scripts/config.sh`에 정의되어 있습니다.

### PostgreSQL 접속 정보

| 항목 | 값 |
|------|-----|
| **호스트** | `209.97.169.136` |
| **포트** | `5433` |
| **사용자** | `center` |
| **데이터베이스** | `center` |

### 데이터베이스 쿼리 실행

센터 프로젝트에서는 `db-query.sh` 스크립트를 통해 데이터베이스 쿼리를 실행합니다:

```bash
# 테이블 목록 조회
./.claude/skills/center-skill/scripts/db-query.sh "\dt"

# 테이블 스키마 확인
./.claude/skills/center-skill/scripts/db-query.sh "\d users"

# SELECT 쿼리 실행
./.claude/skills/center-skill/scripts/db-query.sh "SELECT * FROM users LIMIT 10"

# 데이터 조작
./.claude/skills/center-skill/scripts/db-query.sh "INSERT INTO ..."
./.claude/skills/center-skill/scripts/db-query.sh "UPDATE ... SET ..."
./.claude/skills/center-skill/scripts/db-query.sh "DELETE FROM ..."
```

### 연결 문자열

```bash
# config.sh에 정의된 연결 URL
DB_URL="postgresql://center:***@209.97.169.136:5433/center"
```

### PHP에서 PDO 연결

센터 프로젝트의 Dockerfile에서 PostgreSQL PDO 드라이버를 설치합니다:

```dockerfile
RUN docker-php-ext-install pdo pdo_pgsql
```

---

## 지원 데이터베이스

| 데이터베이스 | 설명 |
|-------------|------|
| **PostgreSQL** | 관계형 DB, 대부분의 앱에 권장 |
| **MySQL** | 관계형 DB, WordPress 등에 사용 |
| **MariaDB** | MySQL 호환, 오픈소스 |
| **MongoDB** | NoSQL 문서 DB |
| **Redis** | 인메모리 캐시/세션 저장소 |

---

## 데이터베이스 생성

### UI를 통한 생성

1. **Dokploy 대시보드** 접속
2. **프로젝트** 선택
3. **Create Service** → **Database** 선택
4. 데이터베이스 타입 선택
5. 필요한 정보 입력 (이름, 사용자, 비밀번호)
6. **Create** 클릭

### API를 통한 생성

#### PostgreSQL

```bash
curl -X POST "http://$SERVER_IP:3000/api/postgres.create" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -d '{
    "name": "my-postgres",
    "projectId": "PROJECT_ID",
    "databaseName": "mydb",
    "databaseUser": "admin",
    "databasePassword": "secure-password"
  }'
```

#### MySQL

```bash
curl -X POST "http://$SERVER_IP:3000/api/mysql.create" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -d '{
    "name": "my-mysql",
    "projectId": "PROJECT_ID",
    "databaseName": "mydb",
    "databaseRootPassword": "root-password",
    "databaseUser": "admin",
    "databasePassword": "secure-password"
  }'
```

#### MongoDB

```bash
curl -X POST "http://$SERVER_IP:3000/api/mongo.create" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -d '{
    "name": "my-mongo",
    "projectId": "PROJECT_ID",
    "databaseUser": "admin",
    "databasePassword": "secure-password"
  }'
```

#### Redis

```bash
curl -X POST "http://$SERVER_IP:3000/api/redis.create" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -d '{
    "name": "my-redis",
    "projectId": "PROJECT_ID"
  }'
```

---

## 연결 정보 확인

### 내부 연결 (같은 Dokploy 내 앱)

Docker 네트워크 내에서 서비스 이름으로 연결합니다:

```bash
# PostgreSQL
DATABASE_URL=postgres://user:password@service-name:5432/dbname

# MySQL
DATABASE_URL=mysql://user:password@service-name:3306/dbname

# MongoDB
MONGODB_URI=mongodb://user:password@service-name:27017/dbname

# Redis
REDIS_URL=redis://service-name:6379
```

### 외부 연결

포트를 외부에 노출해야 합니다:

1. **데이터베이스 서비스** 선택
2. **Advanced** → **Ports** 설정
3. 호스트 포트 매핑 (예: `5432:5432`)

```bash
# 외부에서 연결
psql -h SERVER_IP -p 5432 -U admin -d mydb
```

### 연결 문자열 확인

```bash
# SSH로 서버 접속 후 환경 변수 확인
ssh root@$SERVER_IP "docker inspect SERVICE_NAME | grep -A 20 'Env'"
```

---

## 백업 및 복원

### PostgreSQL 백업

```bash
# SSH로 서버 접속 후 실행
ssh root@$SERVER_IP

# 컨테이너 ID 확인
docker ps | grep postgres

# pg_dump로 백업
docker exec CONTAINER_ID pg_dump -U admin mydb > backup.sql

# 로컬로 다운로드
scp root@$SERVER_IP:~/backup.sql ./backup.sql
```

### PostgreSQL 복원

```bash
# 백업 파일 업로드
scp ./backup.sql root@$SERVER_IP:~/backup.sql

# 복원 실행
ssh root@$SERVER_IP "docker exec -i CONTAINER_ID psql -U admin mydb < ~/backup.sql"
```

### MySQL 백업

```bash
# mysqldump로 백업
ssh root@$SERVER_IP "docker exec CONTAINER_ID mysqldump -u admin -pPASSWORD mydb > backup.sql"
```

### MySQL 복원

```bash
ssh root@$SERVER_IP "docker exec -i CONTAINER_ID mysql -u admin -pPASSWORD mydb < ~/backup.sql"
```

### MongoDB 백업

```bash
# mongodump로 백업
ssh root@$SERVER_IP "docker exec CONTAINER_ID mongodump --out /backup"

# 로컬로 복사
ssh root@$SERVER_IP "docker cp CONTAINER_ID:/backup ./mongodb-backup"
```

### Redis 백업

```bash
# RDB 스냅샷 생성
ssh root@$SERVER_IP "docker exec CONTAINER_ID redis-cli BGSAVE"

# dump.rdb 파일 복사
ssh root@$SERVER_IP "docker cp CONTAINER_ID:/data/dump.rdb ./redis-backup.rdb"
```

---

## 모니터링

### 컨테이너 리소스 확인

```bash
# CPU/메모리 사용량
ssh root@$SERVER_IP "docker stats --no-stream | grep postgres"
```

### 데이터베이스 상태 확인

#### PostgreSQL

```bash
ssh root@$SERVER_IP "docker exec CONTAINER_ID psql -U admin -c 'SELECT pg_database_size(current_database());'"
```

#### MySQL

```bash
ssh root@$SERVER_IP "docker exec CONTAINER_ID mysql -u admin -pPASSWORD -e 'SHOW STATUS;'"
```

### 로그 확인

```bash
# 데이터베이스 서비스 로그
ssh root@$SERVER_IP "docker service logs DB_SERVICE_NAME --tail 100"
```

---

## 문제 해결

### 연결 오류

| 오류 | 원인 | 해결 |
|------|------|------|
| `Connection refused` | 포트 미개방 또는 서비스 중단 | 포트 설정 확인, 서비스 재시작 |
| `Authentication failed` | 잘못된 자격 증명 | 사용자명/비밀번호 확인 |
| `Database does not exist` | DB 미생성 | 데이터베이스 생성 |

### 서비스 재시작

```bash
# 데이터베이스 서비스 재시작
ssh root@$SERVER_IP "docker service update --force DB_SERVICE_NAME"
```

### 디스크 공간 부족

```bash
# 디스크 사용량 확인
ssh root@$SERVER_IP "df -h"

# 오래된 Docker 이미지 정리
ssh root@$SERVER_IP "docker image prune -a"
```

---

## 환경 변수 설정 예시

애플리케이션에서 데이터베이스 연결 시 사용하는 환경 변수:

```bash
# PostgreSQL
DATABASE_URL=postgres://admin:password@my-postgres:5432/mydb

# MySQL
DATABASE_URL=mysql://admin:password@my-mysql:3306/mydb

# MongoDB
MONGODB_URI=mongodb://admin:password@my-mongo:27017/mydb?authSource=admin

# Redis
REDIS_URL=redis://my-redis:6379
```

---

## 체크리스트

### 데이터베이스 생성

- [ ] 프로젝트 선택
- [ ] 데이터베이스 타입 선택
- [ ] 사용자명/비밀번호 설정
- [ ] 생성 완료 확인

### 백업 설정

- [ ] 백업 스크립트 작성
- [ ] Cron 스케줄 설정
- [ ] 백업 저장 위치 확인
- [ ] 복원 테스트 완료
