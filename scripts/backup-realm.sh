#!/bin/bash
# Keycloak Realm 설정 백업 스크립트
#
# 사용법: ./scripts/backup-realm.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="$PROJECT_DIR/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# 환경 변수 로드
if [ -f "$PROJECT_DIR/.env" ]; then
  export $(grep -v '^#' "$PROJECT_DIR/.env" | xargs)
fi

KEYCLOAK_URL=${KEYCLOAK_URL:-http://localhost:8180}
REALM=${REALM:-k-ecp}

mkdir -p "$BACKUP_DIR"

echo "=== K-ECP SSO Realm 백업 ==="
echo "Realm: $REALM"
echo "URL: $KEYCLOAK_URL"

# 관리자 토큰 획득
echo "관리자 토큰 획득 중..."
TOKEN=$(curl -s -X POST "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=${KEYCLOAK_ADMIN:-admin}" \
  -d "password=${KEYCLOAK_ADMIN_PASSWORD:-admin123}" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" | jq -r '.access_token')

if [ "$TOKEN" == "null" ] || [ -z "$TOKEN" ]; then
  echo "❌ 관리자 토큰 획득 실패"
  exit 1
fi

# Realm 내보내기
echo "Realm 설정 내보내기 중..."
BACKUP_FILE="$BACKUP_DIR/${REALM}_${TIMESTAMP}.json"

curl -s "$KEYCLOAK_URL/admin/realms/$REALM" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/json" \
  > "$BACKUP_FILE"

echo "✅ 백업 완료: $BACKUP_FILE"

# 최근 5개만 유지
echo "오래된 백업 정리 중..."
ls -t "$BACKUP_DIR"/${REALM}_*.json 2>/dev/null | tail -n +6 | xargs -r rm -f

echo "완료!"
