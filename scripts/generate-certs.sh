#!/bin/bash
# SSL 인증서 생성 스크립트 (개발/테스트용)
#
# 사용법: ./scripts/generate-certs.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CERT_DIR="$PROJECT_DIR/keycloak/certs"

# 디렉토리 생성
mkdir -p "$CERT_DIR"

cd "$CERT_DIR"

echo "=== K-ECP SSO 자체 서명 인증서 생성 ==="

# 개인키 생성
openssl genrsa -out server.key.pem 2048

# 인증서 생성 (1년 유효)
openssl req -new -x509 \
  -key server.key.pem \
  -out server.crt.pem \
  -days 365 \
  -subj "/CN=localhost/O=K-ECP/C=KR"

echo "✅ 인증서 생성 완료"
echo "   - 개인키: $CERT_DIR/server.key.pem"
echo "   - 인증서: $CERT_DIR/server.crt.pem"
echo ""
echo "⚠️  이 인증서는 개발/테스트 용도입니다."
echo "   운영 환경에서는 공인 인증서를 사용하세요."
