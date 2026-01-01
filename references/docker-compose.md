# Dokploy Docker Compose 관리 가이드

## 목차

1. [센터 프로젝트 Docker 설정](#센터-프로젝트-docker-설정)
2. [개요](#개요)
3. [Compose 서비스 생성](#compose-서비스-생성)
4. [Compose 파일 작성 규칙](#compose-파일-작성-규칙)
5. [볼륨 마운트](#볼륨-마운트)
6. [네트워크 설정](#네트워크-설정)
7. [환경 변수](#환경-변수)
8. [도메인 설정](#도메인-설정)
9. [문제 해결](#문제-해결)

---

## 센터 프로젝트 Docker 설정

> **중요**: 센터 프로젝트는 Dokploy 배포 시 **docker-compose.yml을 사용하지 않습니다**. Dockerfile만 사용합니다.

### 로컬 개발용 docker-compose.yml

로컬 개발 환경에서만 사용하는 docker-compose.yml 설정:

```yaml
# docker-compose.yml (로컬 개발 전용)
services:
  center:
    build:
      context: .
      dockerfile: etc/docker/Dockerfile
    ports:
      - "8080:80"
    volumes:
      - .:/www          # 소스 코드 실시간 반영
      - ./uploads:/uploads  # 업로드 파일 영구 저장
```

**실행 방법:**
```bash
docker compose up
```

**접속 URL:**
- 로컬 개발: `http://127.0.0.1:8080`
- Browser-Sync: `http://localhost:3000` (`npm run dev` 실행 시)

### Dokploy 배포용 Dockerfile

```dockerfile
# etc/docker/Dockerfile
FROM php:8.4-fpm

# PHP PDO 드라이버(PostgreSQL) + nginx + GD 라이브러리 + APCu 설치
RUN apt-get update \
  && apt-get install -y nginx libpq-dev \
  libpng-dev libjpeg-dev libwebp-dev libfreetype6-dev \
  && docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
  && docker-php-ext-install pdo pdo_pgsql gd \
  && pecl install apcu \
  && docker-php-ext-enable apcu \
  && rm -rf /var/lib/apt/lists/*

# uploads 폴더 생성 및 권한 설정
RUN mkdir -p /uploads && chmod 777 /uploads

# PHP 설정 파일 복사 (업로드 사이즈 50M 등)
COPY etc/php/php.ini /usr/local/etc/php/php.ini

# 작업 디렉토리 및 소스 코드 복사
WORKDIR /www
COPY . /www

# nginx 설정 반영
COPY etc/nginx/nginx.conf /etc/nginx/nginx.conf
COPY etc/nginx/conf.d/center.conf /etc/nginx/conf.d/center.conf

# PHP-FPM + Nginx 같이 실행
EXPOSE 80
CMD php-fpm -D && nginx -g "daemon off;"
```

### 로컬 vs Dokploy 배포 차이점

| 항목 | 로컬 개발 | Dokploy 배포 |
|------|----------|-------------|
| **소스 코드** | 볼륨 마운트 (실시간 반영) | COPY로 이미지에 포함 |
| **포트** | 8080:80 | 80 (Traefik이 라우팅) |
| **docker-compose.yml** | 사용 | 사용 안함 |
| **Dockerfile** | 사용 | 사용 |

---

## 개요

Docker Compose를 사용하면 멀티 컨테이너 환경을 손쉽게 배포할 수 있습니다.

**Applications vs Docker Compose:**

| 특성 | Applications | Docker Compose |
|------|-------------|----------------|
| 컨테이너 수 | 단일 | 멀티 |
| 설정 방식 | UI 기반 | YAML 파일 |
| 도메인 적용 | 자동 | 재배포 필요 |
| 복잡한 구성 | 제한적 | 유연함 |

---

## Compose 서비스 생성

### UI를 통한 생성

1. **Dokploy 대시보드** 접속
2. **프로젝트** 선택
3. **Create Service** → **Compose** 선택
4. 이름 입력
5. **Create** 클릭
6. **General** 탭에서 Compose 파일 작성
7. **Deploy** 클릭

### Git 연동

1. **Source** 섹션에서 Git Provider 선택
2. 리포지토리 URL 입력
3. 브랜치 선택
4. Compose 파일 경로 지정 (기본: `docker-compose.yml`)

---

## Compose 파일 작성 규칙

### 기본 구조

```yaml
version: "3.8"

services:
  app:
    image: node:20-alpine
    ports:
      - 3000  # 내부 포트만 지정 (호스트 포트 제외)
    environment:
      - NODE_ENV=production
    volumes:
      - app-data:/app/data

  db:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: mydb
      POSTGRES_USER: admin
      POSTGRES_PASSWORD: password
    volumes:
      - db-data:/var/lib/postgresql/data

volumes:
  app-data:
  db-data:
```

### 필수 규칙

#### 1. 포트 노출 방식

```yaml
# 올바른 방식 (호스트 포트 없이)
ports:
  - 3000
  - 80

# 잘못된 방식 (호스트 포트 포함 - Traefik 충돌 가능)
ports:
  - "8080:3000"
```

#### 2. 볼륨 경로

```yaml
# 올바른 방식 (상대 경로 + files 폴더)
volumes:
  - "../files/data:/app/data"

# 잘못된 방식 (절대 경로)
volumes:
  - "/host/path:/container/path"
```

#### 3. 네트워크 (선택사항)

Dokploy가 자동으로 네트워크를 구성하므로, 특별한 경우가 아니면 생략합니다.

---

## 볼륨 마운트

### 명명 볼륨 (Named Volume) - 권장

```yaml
services:
  app:
    volumes:
      - app-data:/app/data

volumes:
  app-data:  # 정의 필수
```

**장점:**
- Docker가 자동 관리
- 백업 기능 지원
- 데이터 지속성 보장

### 바인드 마운트 (Bind Mount)

```yaml
services:
  app:
    volumes:
      - "../files/uploads:/app/uploads"
```

**구조:**
```
/application-name
  /code       # Git 소스 코드
  /files      # 바인드 마운트 파일
```

### 볼륨명 확인

Compose에서 생성된 볼륨은 `{앱이름}_{볼륨명}` 형식입니다:

```bash
# 볼륨 목록 확인
ssh root@$SERVER_IP "docker volume ls | grep 앱이름"

# 예시: n8n-compose_n8n_data
```

---

## 네트워크 설정

### 서비스 간 통신

같은 Compose 파일 내 서비스는 서비스 이름으로 통신합니다:

```yaml
services:
  app:
    environment:
      DATABASE_URL: postgres://admin:password@db:5432/mydb

  db:
    image: postgres:15
```

### 외부 네트워크 연결

다른 Dokploy 서비스와 연결이 필요한 경우:

```yaml
services:
  app:
    networks:
      - default
      - dokploy-network

networks:
  dokploy-network:
    external: true
```

---

## 환경 변수

### 인라인 방식

```yaml
services:
  app:
    environment:
      - NODE_ENV=production
      - DATABASE_URL=postgres://user:pass@db:5432/mydb
```

### Dokploy 환경 변수 탭

Compose 파일과 별도로 Dokploy UI의 **Environment** 탭에서 설정 가능합니다.

**우선순위:** Dokploy Environment > Compose 파일

### 민감 정보 처리

```yaml
# Compose 파일에서 변수 참조
services:
  app:
    environment:
      - API_KEY=${API_KEY}
```

Dokploy Environment 탭에서 `API_KEY=실제값` 설정

---

## 도메인 설정

### Traefik 라벨 방식

```yaml
services:
  app:
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.myapp.rule=Host(`myapp.example.com`)"
      - "traefik.http.routers.myapp.entrypoints=websecure"
      - "traefik.http.routers.myapp.tls.certresolver=letsencrypt"
      - "traefik.http.services.myapp.loadbalancer.server.port=3000"
```

### Dokploy UI 방식

1. Compose 서비스 선택
2. **Domains** 탭 클릭
3. 도메인 추가
4. **Deploy** 클릭 (중요: 재배포 필수)

**주의:** Compose에서 도메인 변경 후 반드시 재배포해야 적용됩니다.

---

## 문제 해결

### 도메인 접속 안 됨 (404)

**원인:** Compose는 Traefik 라벨을 사용하므로 도메인 변경 후 재배포 필요

**해결:**
```bash
# 재배포
curl -X POST "http://$SERVER_IP:3000/api/compose.redeploy" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -d '{"composeId": "COMPOSE_ID"}'
```

### 볼륨 데이터 손실

**원인:**
- `docker-compose down -v` 실행
- AutoDeploy가 볼륨을 초기화

**해결:**
- 바인드 마운트(`../files/`)로 중요 데이터 이동
- 명명 볼륨 백업 설정

### 서비스 간 연결 실패

**확인 사항:**
1. 서비스 이름이 올바른지
2. 네트워크가 같은지
3. 포트가 올바른지

```bash
# 네트워크 확인
ssh root@$SERVER_IP "docker network ls"

# 컨테이너 네트워크 확인
ssh root@$SERVER_IP "docker inspect CONTAINER_ID | grep -A 20 'Networks'"
```

### 로그 확인

```bash
# Compose 서비스 로그
ssh root@$SERVER_IP "docker compose -f /path/to/compose.yml logs -f"

# 특정 서비스 로그
ssh root@$SERVER_IP "docker service logs SERVICE_NAME --tail 100"
```

---

## 예제 Compose 파일

### WordPress + MySQL

```yaml
version: "3.8"

services:
  wordpress:
    image: wordpress:latest
    ports:
      - 80
    environment:
      WORDPRESS_DB_HOST: db
      WORDPRESS_DB_USER: wordpress
      WORDPRESS_DB_PASSWORD: wordpress
      WORDPRESS_DB_NAME: wordpress
    volumes:
      - wp-content:/var/www/html/wp-content

  db:
    image: mysql:8.0
    environment:
      MYSQL_DATABASE: wordpress
      MYSQL_USER: wordpress
      MYSQL_PASSWORD: wordpress
      MYSQL_ROOT_PASSWORD: rootpassword
    volumes:
      - db-data:/var/lib/mysql

volumes:
  wp-content:
  db-data:
```

### Next.js + PostgreSQL + Redis

```yaml
version: "3.8"

services:
  app:
    build: .
    ports:
      - 3000
    environment:
      DATABASE_URL: postgres://admin:password@db:5432/mydb
      REDIS_URL: redis://redis:6379
    depends_on:
      - db
      - redis

  db:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: mydb
      POSTGRES_USER: admin
      POSTGRES_PASSWORD: password
    volumes:
      - db-data:/var/lib/postgresql/data

  redis:
    image: redis:alpine
    volumes:
      - redis-data:/data

volumes:
  db-data:
  redis-data:
```

---

## 체크리스트

### 배포 전

- [ ] 포트 노출 방식 확인 (호스트 포트 제외)
- [ ] 볼륨 경로 확인 (상대 경로 사용)
- [ ] 환경 변수 설정 완료
- [ ] 민감 정보 분리

### 배포 후

- [ ] 서비스 상태 확인
- [ ] 로그 확인
- [ ] 도메인 접속 테스트
- [ ] 볼륨 데이터 확인
