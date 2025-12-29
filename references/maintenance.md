# Dokploy 서버 유지보수 가이드

## 목차

1. [정기 점검 항목](#정기-점검-항목)
2. [Dokploy 업데이트](#dokploy-업데이트)
3. [Docker 관리](#docker-관리)
4. [디스크 관리](#디스크-관리)
5. [보안 점검](#보안-점검)
6. [백업 전략](#백업-전략)
7. [모니터링](#모니터링)

---

## 정기 점검 항목

### 일일 점검

```bash
# 서버 상태 확인
ssh root@$SERVER_IP "uptime && df -h && free -h"

# Dokploy 필수 서비스 상태
ssh root@$SERVER_IP "docker ps | grep -E 'dokploy|postgres|redis|traefik'"

# 최근 오류 로그
ssh root@$SERVER_IP "docker service logs dokploy --since 24h 2>&1 | grep -i error | tail -20"
```

### 주간 점검

```bash
# 디스크 사용량 상세
ssh root@$SERVER_IP "du -sh /var/lib/docker/*"

# 미사용 Docker 리소스
ssh root@$SERVER_IP "docker system df"

# SSL 인증서 만료 확인
echo | openssl s_client -connect example.com:443 -servername example.com 2>/dev/null | openssl x509 -noout -dates
```

---

## Dokploy 업데이트

### 현재 버전 확인

```bash
# Dokploy 버전 확인
ssh root@$SERVER_IP "docker inspect dokploy | grep -i version"

# 또는 UI에서 Settings → About 확인
```

### 업데이트 방법

#### 방법 1: UI를 통한 업데이트 (권장)

1. Dokploy 대시보드 접속
2. **Settings** → **Server** 이동
3. **Update** 버튼 클릭
4. 업데이트 완료 대기

#### 방법 2: CLI를 통한 업데이트

```bash
# 서버 접속
ssh root@$SERVER_IP

# Dokploy 업데이트 스크립트 실행
curl -sSL https://dokploy.com/install.sh | sh

# 또는 수동 업데이트
docker pull dokploy/dokploy:latest
docker service update --image dokploy/dokploy:latest dokploy
```

### 업데이트 전 주의사항

- [ ] 현재 배포 중인 작업이 없는지 확인
- [ ] 중요 데이터 백업 완료
- [ ] 업데이트 노트 확인 (Breaking Changes)
- [ ] 다운타임 공지 (필요 시)

### 업데이트 후 확인

```bash
# 서비스 상태 확인
ssh root@$SERVER_IP "docker service ls"

# Dokploy UI 접속 테스트
curl -sI http://$SERVER_IP:3000 | head -5
```

---

## Docker 관리

### Docker 버전 확인

```bash
ssh root@$SERVER_IP "docker version"
```

### Docker 업데이트

```bash
# Ubuntu/Debian
ssh root@$SERVER_IP "apt update && apt upgrade docker-ce docker-ce-cli containerd.io -y"

# CentOS/RHEL
ssh root@$SERVER_IP "yum update docker-ce docker-ce-cli containerd.io -y"
```

### Swarm 상태 확인

```bash
# Swarm 노드 상태
ssh root@$SERVER_IP "docker node ls"

# Swarm 서비스 상태
ssh root@$SERVER_IP "docker service ls"
```

### 서비스 재시작

```bash
# 특정 서비스 재시작
ssh root@$SERVER_IP "docker service update --force SERVICE_NAME"

# Dokploy 전체 재시작
ssh root@$SERVER_IP "docker service update --force dokploy"

# Traefik 재시작
ssh root@$SERVER_IP "docker restart dokploy-traefik"
```

---

## 디스크 관리

### 사용량 확인

```bash
# 전체 디스크 사용량
ssh root@$SERVER_IP "df -h"

# Docker 관련 사용량
ssh root@$SERVER_IP "docker system df -v"

# 볼륨별 사용량
ssh root@$SERVER_IP "du -sh /var/lib/docker/volumes/*"
```

### 정리 작업

```bash
# 미사용 이미지 삭제
ssh root@$SERVER_IP "docker image prune -a -f"

# 미사용 컨테이너 삭제
ssh root@$SERVER_IP "docker container prune -f"

# 미사용 볼륨 삭제 (주의: 데이터 손실 가능)
ssh root@$SERVER_IP "docker volume prune -f"

# 전체 정리 (이미지, 컨테이너, 네트워크)
ssh root@$SERVER_IP "docker system prune -a -f"
```

### 로그 관리

```bash
# Docker 로그 크기 확인
ssh root@$SERVER_IP "du -sh /var/lib/docker/containers/*/*-json.log"

# 로그 로테이션 설정 (/etc/docker/daemon.json)
ssh root@$SERVER_IP 'cat > /etc/docker/daemon.json << EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF'

# Docker 재시작 (설정 적용)
ssh root@$SERVER_IP "systemctl restart docker"
```

---

## 보안 점검

### SSH 보안

```bash
# 로그인 시도 확인
ssh root@$SERVER_IP "grep 'Failed password' /var/log/auth.log | tail -20"

# SSH 키 확인
ssh root@$SERVER_IP "cat ~/.ssh/authorized_keys"
```

### 방화벽 설정

```bash
# UFW 상태 확인 (Ubuntu)
ssh root@$SERVER_IP "ufw status verbose"

# 필수 포트만 개방
ssh root@$SERVER_IP "ufw allow 22/tcp"   # SSH
ssh root@$SERVER_IP "ufw allow 80/tcp"   # HTTP
ssh root@$SERVER_IP "ufw allow 443/tcp"  # HTTPS
ssh root@$SERVER_IP "ufw allow 3000/tcp" # Dokploy (필요시)
```

### 시스템 업데이트

```bash
# Ubuntu/Debian
ssh root@$SERVER_IP "apt update && apt upgrade -y"

# 보안 업데이트만
ssh root@$SERVER_IP "apt update && apt upgrade -y --only-upgrade"
```

### 취약점 점검

```bash
# 컨테이너 이미지 스캔 (trivy 사용)
ssh root@$SERVER_IP "docker run --rm aquasec/trivy image dokploy/dokploy:latest"
```

---

## 백업 전략

### 백업 대상

| 대상 | 중요도 | 방법 |
|------|--------|------|
| **데이터베이스** | 높음 | pg_dump, mysqldump |
| **볼륨 데이터** | 높음 | Dokploy 볼륨 백업 |
| **Dokploy 설정** | 중간 | DB 백업에 포함 |
| **Traefik 설정** | 낮음 | /etc/dokploy/traefik 복사 |

### Dokploy 데이터베이스 백업

```bash
# Dokploy PostgreSQL 백업
ssh root@$SERVER_IP "docker exec \$(docker ps -qf 'name=dokploy-postgres') pg_dumpall -U postgres > /root/dokploy-backup-\$(date +%Y%m%d).sql"

# 로컬로 다운로드
scp root@$SERVER_IP:/root/dokploy-backup-*.sql ./
```

### 자동 백업 스크립트

```bash
#!/bin/bash
# /root/backup.sh

DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/root/backups"

mkdir -p $BACKUP_DIR

# Dokploy DB 백업
docker exec $(docker ps -qf 'name=dokploy-postgres') pg_dumpall -U postgres > $BACKUP_DIR/dokploy-$DATE.sql

# Traefik 설정 백업
tar -czf $BACKUP_DIR/traefik-$DATE.tar.gz /etc/dokploy/traefik

# 7일 이상 된 백업 삭제
find $BACKUP_DIR -type f -mtime +7 -delete

echo "Backup completed: $DATE"
```

Cron 설정:
```bash
# 매일 새벽 3시에 백업
0 3 * * * /root/backup.sh >> /var/log/backup.log 2>&1
```

---

## 모니터링

### 리소스 모니터링

```bash
# 실시간 리소스 사용량
ssh root@$SERVER_IP "docker stats --no-stream"

# 특정 서비스 모니터링
ssh root@$SERVER_IP "docker stats --no-stream \$(docker ps -qf 'name=dokploy')"
```

### 알림 설정

Dokploy UI → Settings → Notifications에서 설정:

- **Slack**: 웹훅 URL 입력
- **Discord**: 웹훅 URL 입력
- **Email**: SMTP 설정

### 헬스 체크

```bash
# Dokploy API 헬스 체크
curl -s http://$SERVER_IP:3000/api/health

# 모든 서비스 헬스 체크
ssh root@$SERVER_IP "docker service ls --format '{{.Name}}: {{.Replicas}}'"
```

### 외부 모니터링 도구 연동

- **UptimeRobot**: HTTP(S) 모니터링
- **Prometheus + Grafana**: 메트릭 수집/시각화
- **Netdata**: 실시간 시스템 모니터링

---

## 긴급 상황 대응

### Dokploy 접속 불가

```bash
# 1. 서버 접속 확인
ssh root@$SERVER_IP "echo 'OK'"

# 2. Docker 상태 확인
ssh root@$SERVER_IP "systemctl status docker"

# 3. 필수 서비스 확인
ssh root@$SERVER_IP "docker ps"

# 4. 디스크 공간 확인
ssh root@$SERVER_IP "df -h"

# 5. 서비스 재시작
ssh root@$SERVER_IP "docker service scale dokploy=0 && docker service scale dokploy=1"
```

### 데이터베이스 복구

```bash
# PostgreSQL 복구 모드 확인
ssh root@$SERVER_IP "docker logs \$(docker ps -qf 'name=dokploy-postgres') | tail -50"

# 서비스 재시작
ssh root@$SERVER_IP "docker service update --force dokploy-postgres"
```

### 롤백

```bash
# 이전 버전으로 롤백
ssh root@$SERVER_IP "docker service update --rollback dokploy"
```

---

## 체크리스트

### 월간 유지보수

- [ ] Dokploy 업데이트 확인
- [ ] 시스템 패키지 업데이트
- [ ] 디스크 정리
- [ ] 백업 복원 테스트
- [ ] SSL 인증서 만료 확인
- [ ] 보안 로그 검토

### 긴급 연락처

- Dokploy GitHub Issues: https://github.com/Dokploy/dokploy/issues
- Dokploy Discord: https://discord.gg/dokploy
