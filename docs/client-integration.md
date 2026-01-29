# K-ECP SSO 클라이언트 연동 가이드

K-ECP SSO(Keycloak)를 각 서비스에서 사용하기 위한 연동 가이드입니다.

## 개요

```mermaid
flowchart TB
    subgraph Keycloak["🔐 Keycloak Server"]
        subgraph Realm["Realm: k-ecp"]
            C1["k-ecp-main<br/>🔒 Confidential"]
            C2["k-ecp-marketplace<br/>🔒 Confidential"]
            C3["k-ecp-support<br/>🔓 Public (PKCE)"]
            C4["k-ecp-kohub<br/>🔓 Public (PKCE)"]
        end
    end
    
    subgraph Apps["Applications"]
        A1["🏢 user-console<br/>(Spring Boot)"]
        A2["🛒 marketplace<br/>(Flask)"]
        A3["📞 KustHub<br/>(React SPA)"]
        A4["⚙️ Kohub<br/>(React SPA)"]
    end
    
    C1 <--> A1
    C2 <--> A2
    C3 <--> A3
    C4 <--> A4
    
    style Keycloak fill:#fff3e0,stroke:#f57c00
    style Realm fill:#e8f5e9,stroke:#388e3c
    style Apps fill:#e3f2fd,stroke:#1976d2
```

## 공통 정보

| 항목 | 개발 환경 | 운영 환경 |
|------|-----------|-----------|
| Keycloak URL | http://localhost:8180 | https://auth.kecp.kdn.com |
| Realm | k-ecp | k-ecp |
| OIDC Discovery | /realms/k-ecp/.well-known/openid-configuration | 동일 |

---

## 1. Spring Boot 연동 (user-console)

### 연동 구조

```mermaid
flowchart LR
    subgraph Spring["Spring Boot"]
        SC["Security Config"]
        OC["OAuth2 Client"]
        AC["Admin Client"]
    end
    
    subgraph KC["Keycloak"]
        Auth["Authorization"]
        Admin["Admin API"]
    end
    
    OC -->|로그인| Auth
    AC -->|사용자 동기화| Admin
    
    style Spring fill:#e8f5e9,stroke:#388e3c
    style KC fill:#fff3e0,stroke:#f57c00
```

### 1.1 의존성 추가

```xml
<!-- pom.xml -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-oauth2-client</artifactId>
</dependency>
<dependency>
    <groupId>org.keycloak</groupId>
    <artifactId>keycloak-admin-client</artifactId>
    <version>24.0.0</version>
</dependency>
```

### 1.2 application.yml

```yaml
spring:
  security:
    oauth2:
      client:
        registration:
          keycloak:
            client-id: k-ecp-main
            client-secret: ${KEYCLOAK_CLIENT_SECRET}
            authorization-grant-type: authorization_code
            scope: openid, profile, email
        provider:
          keycloak:
            issuer-uri: ${KEYCLOAK_URL:http://localhost:8180}/realms/k-ecp
```

---

## 2. Flask 연동 (marketplace)

### 연동 구조

```mermaid
flowchart LR
    subgraph Flask["Flask App"]
        AB["Authlib"]
        Session["Session"]
    end
    
    subgraph KC["Keycloak"]
        Auth["Authorization"]
    end
    
    AB -->|OAuth2| Auth
    Auth -->|Token| Session
    
    style Flask fill:#e3f2fd,stroke:#1976d2
    style KC fill:#fff3e0,stroke:#f57c00
```

### 2.1 의존성

```
Authlib>=1.3.0
httpx>=0.27.0
```

### 2.2 설정

```python
# config.py
KEYCLOAK_URL = os.environ.get('KEYCLOAK_URL', 'http://localhost:8180')
KEYCLOAK_REALM = 'k-ecp'
KEYCLOAK_CLIENT_ID = 'k-ecp-marketplace'
KEYCLOAK_CLIENT_SECRET = os.environ.get('KEYCLOAK_CLIENT_SECRET', '')
OAUTH2_METADATA_URL = f"{KEYCLOAK_URL}/realms/{KEYCLOAK_REALM}/.well-known/openid-configuration"
```

### 2.3 OAuth 초기화

```python
from authlib.integrations.flask_client import OAuth

oauth = OAuth()
oauth.register(
    name='keycloak',
    client_id=app.config['KEYCLOAK_CLIENT_ID'],
    client_secret=app.config['KEYCLOAK_CLIENT_SECRET'],
    server_metadata_url=app.config['OAUTH2_METADATA_URL'],
    client_kwargs={'scope': 'openid email profile'}
)
```

---

## 3. React SPA 연동 (KustHub, Kohub)

### 연동 구조

```mermaid
flowchart LR
    subgraph React["React SPA"]
        OIDC["react-oidc-context"]
        Auth["AuthContext"]
        API["API Client"]
    end
    
    subgraph KC["Keycloak"]
        Login["Login Page"]
        Token["Token Endpoint"]
    end
    
    subgraph Backend["Backend API"]
        RS["Resource Server"]
    end
    
    OIDC -->|PKCE Flow| Login
    Login -->|Access Token| Auth
    Auth -->|Bearer Token| API
    API -->|JWT| RS
    
    style React fill:#61dafb,stroke:#21232a
    style KC fill:#fff3e0,stroke:#f57c00
    style Backend fill:#e8f5e9,stroke:#388e3c
```

### 3.1 의존성

```bash
npm install oidc-client-ts react-oidc-context
```

### 3.2 환경 변수

```bash
# .env
VITE_KEYCLOAK_URL=http://localhost:8180
VITE_KEYCLOAK_REALM=k-ecp
VITE_KEYCLOAK_CLIENT_ID=k-ecp-support  # 또는 k-ecp-kohub
```

### 3.3 OIDC Provider 설정

```javascript
// src/auth/oidcConfig.js
export const oidcConfig = {
  authority: `${import.meta.env.VITE_KEYCLOAK_URL}/realms/${import.meta.env.VITE_KEYCLOAK_REALM}`,
  client_id: import.meta.env.VITE_KEYCLOAK_CLIENT_ID,
  redirect_uri: `${window.location.origin}/callback`,
  post_logout_redirect_uri: window.location.origin,
  response_type: 'code',
  scope: 'openid profile email',
  automaticSilentRenew: true,
  loadUserInfo: true,
};
```

### 3.4 main.jsx

```javascript
import { AuthProvider } from 'react-oidc-context';
import { oidcConfig } from './auth/oidcConfig';

ReactDOM.createRoot(document.getElementById('root')).render(
  <AuthProvider {...oidcConfig}>
    <App />
  </AuthProvider>
);
```

---

## 4. Backend Resource Server (JWT 검증)

### JWT 검증 흐름

```mermaid
sequenceDiagram
    participant Client as 📱 Client
    participant API as 🖥️ API Server
    participant KC as 🔐 Keycloak
    
    Client->>API: API 요청 + Bearer Token
    API->>KC: JWKS 조회 (캐싱)
    KC-->>API: 공개키
    API->>API: JWT 서명 검증
    API->>API: Claims 추출 (roles)
    API-->>Client: 응답
```

### 4.1 Spring Boot

```yaml
# application.yml
spring:
  security:
    oauth2:
      resourceserver:
        jwt:
          issuer-uri: ${KEYCLOAK_URL:http://localhost:8180}/realms/k-ecp
          jwk-set-uri: ${KEYCLOAK_URL:http://localhost:8180}/realms/k-ecp/protocol/openid-connect/certs
```

---

## 5. 역할(Role) 매핑

```mermaid
flowchart TB
    subgraph KC["Keycloak Roles"]
        R1["admin"]
        R2["operator"]
        R3["partner"]
        R4["member"]
    end
    
    subgraph Apps["Application Permissions"]
        P1["시스템 관리<br/>모든 권한"]
        P2["운영 권한<br/>서비스 관리"]
        P3["파트너 권한<br/>제한된 관리"]
        P4["일반 권한<br/>기본 사용"]
    end
    
    R1 --> P1
    R2 --> P2
    R3 --> P3
    R4 --> P4
    
    style KC fill:#fff3e0,stroke:#f57c00
    style Apps fill:#e3f2fd,stroke:#1976d2
```

| Keycloak Role | 설명 | 대상 서비스 |
|---------------|------|-------------|
| admin | 시스템 관리자 | 모든 서비스 |
| operator | 운영자 | user-console, KustHub, Kohub |
| partner | 파트너사 | marketplace |
| member | 일반 회원 | 모든 서비스 |

---

## 6. 문제 해결

### 일반적인 오류와 해결 방법

```mermaid
flowchart TD
    E1["CORS 오류"] --> S1["Keycloak Client의<br/>Web Origins 확인"]
    E2["redirect_uri 오류"] --> S2["Valid redirect URIs에<br/>콜백 URL 추가"]
    E3["토큰 검증 실패"] --> S3["issuer-uri 설정 확인<br/>시계 동기화 (NTP)"]
    E4["역할 인식 안됨"] --> S4["realm_access.roles<br/>클레임 확인"]
    
    style E1 fill:#ffcdd2,stroke:#c62828
    style E2 fill:#ffcdd2,stroke:#c62828
    style E3 fill:#ffcdd2,stroke:#c62828
    style E4 fill:#ffcdd2,stroke:#c62828
    style S1 fill:#c8e6c9,stroke:#2e7d32
    style S2 fill:#c8e6c9,stroke:#2e7d32
    style S3 fill:#c8e6c9,stroke:#2e7d32
    style S4 fill:#c8e6c9,stroke:#2e7d32
```

### CORS 오류
- Keycloak Admin Console → Clients → Web Origins 확인

### redirect_uri 오류
- Valid redirect URIs에 정확한 콜백 URL 추가

### 토큰 검증 실패
- issuer-uri 설정 확인
- 시계 동기화 확인 (NTP)
