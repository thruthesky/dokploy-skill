# Dokploy 애플리케이션 관리 가이드

## 목차

1. [개요](#개요)
2. [기본 관리 기능](#기본-관리-기능)
3. [고급 설정](#고급-설정)
4. [리소스 관리](#리소스-관리)
5. [스토리지 (볼륨/마운트)](#스토리지-볼륨마운트)
6. [키보드 단축키](#키보드-단축키)

---

## 개요

Dokploy의 애플리케이션은 단일 서비스/컨테이너로 취급되어 각 앱을 독립적인 워크스페이스에서 관리할 수 있습니다.

---

## 기본 관리 기능

### General (일반)

- 코드 소스 구성 (GitHub, Git, Docker)
- 빌드 방식 설정 (Nixpacks, Dockerfile 등)
- 배포, 업데이트, 삭제, 중단 작업

### Environment (환경변수)

```bash
# 단일 변수
DATABASE_URL=postgres://user:pass@host:5432/db

# 여러 줄 변수 (큰따옴표로 감싸기)
PRIVATE_KEY="-----BEGIN RSA PRIVATE KEY-----
MIIEowIBAAKCAQEA...
-----END RSA PRIVATE KEY-----"
```

### Monitoring (모니터링)

4개 그래프 표시:
- 메모리 사용량
- CPU 사용량
- 디스크 사용량
- 네트워크 트래픽

**참고:** 현재 페이지를 볼 때만 실시간 업데이트됩니다.

### Logs (로그)

실행 중인 애플리케이션의 로그와 에러 정보를 확인합니다.

### Deployments (배포)

- 최근 10개 배포 기록 조회
- 대기 중인 배포 취소 가능
- GitHub, Gitea, GitLab, Bitbucket, DockerHub 웹훅 지원

### Domains (도메인)

- 커스텀 도메인 할당
- `traefik.me`를 통한 무료 도메인 생성

---

## 고급 설정

### Run Command (실행 명령어)

컨테이너 내에서 커스텀 셸 명령을 실행합니다.

```bash
# 디버깅 예시
ls -la /app
cat /app/config.json
```

### Cluster Settings (클러스터 설정)

| 설정 | 설명 |
|------|------|
| Replicas | 실행할 인스턴스 개수 |
| Registry | 이미지를 가져올 Docker 레지스트리 |

**중요:** 설정 변경 후 반드시 'Redeploy' 클릭

### Swarm 설정

#### Health Check (헬스 체크)

```yaml
# 예시 설정
Test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
Interval: 30s
Timeout: 10s
Retries: 3
Start Period: 40s
```

#### Restart Policy (재시작 정책)

| 옵션 | 설명 |
|------|------|
| Condition | 재시작 발동 조건 (on-failure, any, none) |
| Delay | 재시작 간 시간 간격 |
| Max Attempts | 최대 시도 횟수 |
| Window | 정책 평가 시간 윈도우 |

#### Update Settings (업데이트 설정)

| 옵션 | 설명 |
|------|------|
| Parallelism | 동시 업데이트 컨테이너 수 |
| Delay | 업데이트 간 지연 시간 |
| Failure Action | 실패 시 조치 (pause, continue, rollback) |
| Monitor | 업데이트 후 모니터링 기간 |

#### Rollback Config (롤백 설정)

업데이트 실패 시 자동 롤백:
- Parallelism: 롤백 병렬 처리 수
- Delay: 롤백 간 지연
- Max Failure Ratio: 허용 최대 실패 비율

### Mode (모드)

| 모드 | 설명 |
|------|------|
| Replicated | 지정된 수만큼 복제 |
| Global | 모든 노드에서 실행 |
| Replicated Job | 일회성 작업 복제 실행 |

### Network (네트워크)

- 네트워크 이름 및 별칭 설정
- 드라이버 옵션 (MTU 크기 등)

### Labels (라벨)

서비스 식별 및 정렬을 위한 키-값 메타데이터:

```yaml
labels:
  environment: production
  team: backend
  version: "1.2.3"
```

---

## 빌드 서버

외부 빌드 서버를 사용하여 빌드 프로세스를 분리할 수 있습니다.

**장점:**
- 배포 서버와 분리된 강력한 빌드 자원 활용
- 한 번 빌드하여 여러 서버에 배포
- 프로덕션 환경과 격리

**제한사항:** 현재 애플리케이션만 지원 (Docker Compose 미지원)

---

## 리소스 관리

### 메모리 설정

| 설정 | 설명 | 예시 |
|------|------|------|
| Memory Limit | 최대 메모리 사용량 | `256MB`, `1GB`, `2GB` |
| Memory Reservation | 최소 보장 메모리 | `128MB`, `512MB` |

### CPU 설정

| 설정 | 설명 | 예시 |
|------|------|------|
| CPU Limit | 최대 코어 수 | `2`, `0.5`, `1.5` |
| CPU Reservation | 최소 예약 코어 수 | `0.25`, `1` |

**규칙:** 예약값은 반드시 제한값 이하여야 합니다.

```yaml
# 올바른 설정
resources:
  limits:
    cpus: "2"
    memory: "1GB"
  reservations:
    cpus: "0.5"
    memory: "256MB"
```

---

## 스토리지 (볼륨/마운트)

### 마운트 타입

| 타입 | 설명 | 사용 시나리오 |
|------|------|-------------|
| **Bind Mount** | 호스트 경로 → 컨테이너 매핑 | 로컬 파일 직접 접근 |
| **Volume Mount** | Docker 관리 볼륨 사용 | 데이터 지속성, 백업 |
| **File Mount** | 특정 파일 마운트 | 설정 파일 주입 |

### Bind Mount 예시

```yaml
# 호스트의 /data/uploads를 컨테이너의 /app/uploads에 마운트
mounts:
  - type: bind
    source: /data/uploads
    target: /app/uploads
```

### Volume Mount 예시

```yaml
# Docker 명명 볼륨 사용
volumes:
  app-data:
    driver: local

services:
  app:
    volumes:
      - app-data:/app/data
```

### File Mount 예시

```yaml
# 설정 파일 마운트
mounts:
  - type: file
    source: ../files/config.json
    target: /app/config.json
```

---

## 추가 설정

### Redirects (리다이렉트)

정규식 기반 URL 리다이렉션으로 SEO 최적화:

```
# www → non-www 리다이렉트
^https://www\.example\.com(.*)$ → https://example.com$1
```

### Security (보안)

기본 인증으로 애플리케이션 접근 제한:

```
Username: admin
Password: ********
```

### Ports (포트)

호스트 포트를 컨테이너 내부 포트에 매핑:

```yaml
ports:
  - "8080:3000"   # 호스트 8080 → 컨테이너 3000
  - "443:443"    # HTTPS
```

### Traefik

HTTP 트래픽 동적 관리:
- 로드 밸런싱
- SSL 종료
- 도메인 기반 라우팅

---

## 키보드 단축키

`g` 키를 접두사로 사용:

| 단축키 | 이동 위치 |
|--------|----------|
| `g` + `e` | Environment (환경변수) |
| `g` + `d` | Deployments (배포) |
| `g` + `l` | Logs (로그) |
| `g` + `m` | Monitoring (모니터링) |
| `g` + `a` | Advanced (고급 설정) |
