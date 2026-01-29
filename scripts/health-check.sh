#!/bin/bash
# Keycloak 상태 확인 스크립트
#
# 사용법: ./scripts/health-check.sh

KEYCLOAK_URL=${KEYCLOAK_URL:-http://localhost:8180}

echo "=== K-ECP SSO 상태 확인 ==="
echo "URL: $KEYCLOAK_URL"
echo ""

# Health check
echo -n "Health: "
HEALTH=$(curl -s -o /dev/null -w "%{http_code}" "$KEYCLOAK_URL/health/ready")
if [ "$HEALTH" == "200" ]; then
  echo "✅ OK"
else
  echo "❌ FAIL (HTTP $HEALTH)"
  exit 1
fi

# Realm check
echo -n "k-ecp Realm: "
REALM=$(curl -s -o /dev/null -w "%{http_code}" "$KEYCLOAK_URL/realms/k-ecp")
if [ "$REALM" == "200" ]; then
  echo "✅ OK"
else
  echo "❌ Not found (HTTP $REALM)"
fi

# OIDC endpoints
echo -n "OIDC Discovery: "
OIDC=$(curl -s -o /dev/null -w "%{http_code}" "$KEYCLOAK_URL/realms/k-ecp/.well-known/openid-configuration")
if [ "$OIDC" == "200" ]; then
  echo "✅ OK"
else
  echo "❌ FAIL (HTTP $OIDC)"
fi

echo ""
echo "Admin Console: $KEYCLOAK_URL/admin"
echo "Account Console: $KEYCLOAK_URL/realms/k-ecp/account"
