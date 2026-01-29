# K-ECP SSO 하이브리드 인증 시스템 설계

> 작성일: 2026-01-29  
> 버전: 1.0

## 1. 개요

K-ECP SSO 시스템에서 Keycloak의 테마 커스터마이징 한계를 극복하고, 더 유연한 사용자 경험을 제공하기 위한 하이브리드 인증 시스템 설계 문서입니다.

### 1.1 목표

- **로그인**: Keycloak 리다이렉트 방식 유지 (보안상 안전)
- **회원가입**: 커스텀 UI + Backend API + Keycloak Admin API
- **비밀번호 찾기**: 커스텀 UI + SMS 인증 + Keycloak Admin API
- **2FA**: TOTP와 SMS 중 사용자 선택 가능

### 1.2 대상 서비스

| 서비스 | Client ID | 설명 |
|--------|-----------|------|
| KustHub | k-ecp-support | 고객센터 (React SPA) |
| Kohub | k-ecp-kohub | 운영 플랫폼 (React SPA) |
| user-console | k-ecp-main | 메인 포털 (Spring Boot) |
| marketplace | k-ecp-marketplace | 마켓플레이스 (Flask) |

---

## 2. 전체 아키텍처

```mermaid
flowchart TB
    subgraph Frontend["Frontend (React)"]
        LoginPage["로그인 페이지"]
        RegisterPage["회원가입 페이지"]
        ForgotPwPage["비밀번호 찾기"]
        Settings2FA["2FA 설정"]
    end

    subgraph Backend["Backend (Spring Boot)"]
        AuthAPI["인증 API"]
        SmsService["SMS 서비스"]
        KeycloakClient["Keycloak Admin Client"]
    end

    subgraph Keycloak["Keycloak SSO"]
        KC_Login["로그인 처리"]
        KC_2FA["2FA 검증"]
        KC_Admin["Admin API"]
    end

    subgraph External["외부 시스템"]
        SmsServer["SMS 서버"]
        Redis["Redis (인증코드 저장)"]
    end

    LoginPage -->|리다이렉트| KC_Login
    KC_Login -->|2FA 필요시| KC_2FA
    KC_2FA -->|완료| Frontend

    RegisterPage -->|API 호출| AuthAPI
    ForgotPwPage -->|API 호출| AuthAPI
    Settings2FA -->|API 호출| AuthAPI

    AuthAPI --> SmsService
    AuthAPI --> KeycloakClient
    SmsService --> SmsServer
    SmsService --> Redis
    KeycloakClient --> KC_Admin

    style Frontend fill:#e3f2fd,stroke:#1976d2
    style Backend fill:#e8f5e9,stroke:#388e3c
    style Keycloak fill:#fff3e0,stroke:#f57c00
    style External fill:#f3e5f5,stroke:#7b1fa2
```

---

## 3. 인증 플로우

### 3.1 로그인 플로우

Keycloak 리다이렉트 방식을 유지하여 보안을 확보합니다.

```mermaid
sequenceDiagram
    autonumber
    participant User as 👤 사용자
    participant App as 📱 KustHub
    participant KC as 🔐 Keycloak

    User->>App: 서비스 접속
    App->>KC: 로그인 리다이렉트
    KC-->>User: 로그인 폼 표시
    User->>KC: ID/Password 입력
    
    alt 2FA 활성화
        KC-->>User: 2FA 입력 요청 (TOTP/SMS)
        User->>KC: 인증 코드 입력
    end
    
    KC-->>App: Authorization Code
    App->>KC: Token 교환
    KC-->>App: Access Token + Refresh Token
    App-->>User: 서비스 제공
```

### 3.2 회원가입 플로우

커스텀 UI와 Backend API를 통해 회원가입을 처리합니다.

```mermaid
sequenceDiagram
    autonumber
    participant User as 👤 사용자
    participant App as 📱 Frontend
    participant API as 🖥️ Backend API
    participant SMS as 📲 SMS 서버
    participant Redis as 💾 Redis
    participant KC as 🔐 Keycloak

    User->>App: 회원가입 페이지 접속
    App-->>User: 회원가입 폼 표시
    User->>App: 정보 입력 (이름, 이메일, 휴대폰, 비밀번호)
    
    App->>API: POST /api/auth/send-sms
    API->>Redis: 인증코드 저장 (5분 TTL)
    API->>SMS: 인증번호 발송 요청
    SMS-->>User: SMS 수신
    API-->>App: 발송 완료
    
    User->>App: 인증번호 입력
    App->>API: POST /api/auth/verify-sms
    API->>Redis: 인증코드 검증
    API-->>App: 검증 성공
    
    App->>API: POST /api/auth/register
    API->>KC: Keycloak Admin API - 사용자 생성
    KC-->>API: 생성 완료
    API-->>App: 회원가입 완료
    
    App-->>User: 로그인 페이지로 이동
```

### 3.3 비밀번호 찾기 플로우

SMS 인증을 통해 비밀번호를 재설정합니다.

```mermaid
sequenceDiagram
    autonumber
    participant User as 👤 사용자
    participant App as 📱 Frontend
    participant API as 🖥️ Backend API
    participant SMS as 📲 SMS 서버
    participant Redis as 💾 Redis
    participant KC as 🔐 Keycloak

    User->>App: 비밀번호 찾기 페이지 접속
    User->>App: 휴대폰 번호 입력
    
    App->>API: POST /api/auth/send-sms (type: reset)
    API->>KC: 휴대폰 번호로 사용자 조회
    KC-->>API: 사용자 정보
    API->>Redis: 인증코드 저장 (5분 TTL)
    API->>SMS: 인증번호 발송 요청
    SMS-->>User: SMS 수신
    API-->>App: 발송 완료
    
    User->>App: 인증번호 입력
    App->>API: POST /api/auth/verify-sms
    API->>Redis: 인증코드 검증
    API-->>App: 검증 성공 + Reset Token
    
    User->>App: 새 비밀번호 입력
    App->>API: POST /api/auth/reset-password
    API->>KC: Keycloak Admin API - 비밀번호 변경
    KC-->>API: 변경 완료
    API-->>App: 재설정 완료
    
    App-->>User: 로그인 페이지로 이동
```

---

## 4. 2FA (Two-Factor Authentication)

### 4.1 지원 방식

| 방식 | 설명 | 구현 |
|------|------|------|
| **TOTP** | Google/Microsoft Authenticator 앱 | Keycloak 내장 |
| **SMS** | 문자 메시지로 인증 코드 | Keycloak SPI + SMS 서버 |

### 4.2 2FA 설정 플로우

```mermaid
flowchart TD
    A[사용자 2FA 설정 페이지] --> B{2FA 방식 선택}
    
    B -->|TOTP| C[QR 코드 표시]
    C --> D[Authenticator 앱 등록]
    D --> E[TOTP 코드 입력 검증]
    E --> F[TOTP 2FA 활성화]
    
    B -->|SMS| G[휴대폰 번호 확인]
    G --> H[SMS 인증번호 발송]
    H --> I[인증번호 입력 검증]
    I --> J[SMS 2FA 활성화]
    
    F --> K[2FA 설정 완료]
    J --> K
    
    style A fill:#e3f2fd
    style K fill:#c8e6c9
```

### 4.3 Keycloak SMS SPI 구현

SMS 2FA를 위해 Keycloak SPI (Service Provider Interface)를 구현합니다.

```mermaid
classDiagram
    class SmsAuthenticator {
        +authenticate(context)
        +action(context)
        +requiresUser() boolean
        +configuredFor() boolean
    }
    
    class SmsAuthenticatorFactory {
        +create(session) Authenticator
        +getId() String
        +getConfigProperties() List
    }
    
    class SmsService {
        +sendSms(phoneNumber, message)
        +generateCode() String
        +verifyCode(phoneNumber, code) boolean
    }
    
    SmsAuthenticatorFactory --> SmsAuthenticator
    SmsAuthenticator --> SmsService
```

---

## 5. Backend API 설계

### 5.1 API 엔드포인트

| Method | Endpoint | 설명 |
|--------|----------|------|
| POST | `/api/auth/register` | 회원가입 |
| POST | `/api/auth/send-sms` | SMS 인증번호 발송 |
| POST | `/api/auth/verify-sms` | SMS 인증번호 검증 |
| POST | `/api/auth/reset-password` | 비밀번호 재설정 |
| GET | `/api/auth/2fa/status` | 2FA 설정 상태 조회 |
| POST | `/api/auth/2fa/totp/setup` | TOTP 설정 |
| POST | `/api/auth/2fa/sms/setup` | SMS 2FA 설정 |
| DELETE | `/api/auth/2fa/disable` | 2FA 비활성화 |

### 5.2 API 상세 스펙

#### 5.2.1 회원가입

```
POST /api/auth/register
Content-Type: application/json

Request:
{
  "email": "user@example.com",
  "name": "홍길동",
  "phoneNumber": "010-1234-5678",
  "password": "SecurePassword123!",
  "smsVerificationToken": "abc123..."
}

Response (201 Created):
{
  "success": true,
  "message": "회원가입이 완료되었습니다.",
  "userId": "uuid-1234-5678"
}

Response (400 Bad Request):
{
  "success": false,
  "error": "DUPLICATE_EMAIL",
  "message": "이미 등록된 이메일입니다."
}
```

#### 5.2.2 SMS 인증번호 발송

```
POST /api/auth/send-sms
Content-Type: application/json

Request:
{
  "phoneNumber": "010-1234-5678",
  "type": "register" | "reset" | "2fa"
}

Response (200 OK):
{
  "success": true,
  "message": "인증번호가 발송되었습니다.",
  "expiresIn": 300
}
```

#### 5.2.3 SMS 인증번호 검증

```
POST /api/auth/verify-sms
Content-Type: application/json

Request:
{
  "phoneNumber": "010-1234-5678",
  "code": "123456"
}

Response (200 OK):
{
  "success": true,
  "verificationToken": "jwt-token-for-next-step"
}

Response (400 Bad Request):
{
  "success": false,
  "error": "INVALID_CODE",
  "message": "인증번호가 올바르지 않습니다."
}
```

#### 5.2.4 비밀번호 재설정

```
POST /api/auth/reset-password
Content-Type: application/json

Request:
{
  "verificationToken": "jwt-token",
  "newPassword": "NewSecurePassword123!"
}

Response (200 OK):
{
  "success": true,
  "message": "비밀번호가 변경되었습니다."
}
```

---

## 6. Frontend 페이지

### 6.1 페이지 구조

```
/auth
├── /login          → Keycloak 리다이렉트
├── /register       → 커스텀 회원가입
├── /forgot-password → 커스텀 비밀번호 찾기
├── /callback       → Keycloak 콜백
└── /settings
    └── /2fa        → 2FA 설정
```

### 6.2 UI 컴포넌트

```mermaid
graph TD
    subgraph RegisterPage["회원가입 페이지"]
        R1[이름 입력]
        R2[이메일 입력]
        R3[휴대폰 번호]
        R4[인증번호 발송]
        R5[인증번호 입력]
        R6[비밀번호 입력]
        R7[비밀번호 확인]
        R8[가입하기 버튼]
    end
    
    subgraph ForgotPage["비밀번호 찾기"]
        F1[휴대폰 번호 입력]
        F2[인증번호 발송]
        F3[인증번호 입력]
        F4[새 비밀번호 입력]
        F5[비밀번호 확인]
        F6[변경하기 버튼]
    end
    
    subgraph TwoFAPage["2FA 설정"]
        T1[현재 2FA 상태]
        T2[TOTP 설정]
        T3[SMS 설정]
        T4[2FA 비활성화]
    end
```

---

## 7. 데이터 모델

### 7.1 Redis 저장 구조

```
# SMS 인증코드
sms:verify:{phoneNumber} = {
  code: "123456",
  type: "register|reset|2fa",
  attempts: 0,
  createdAt: timestamp
}
TTL: 300초 (5분)

# 인증 완료 토큰
sms:token:{phoneNumber} = {
  token: "jwt-token",
  type: "register|reset",
  userId: "uuid" (비밀번호 찾기 시)
}
TTL: 600초 (10분)
```

### 7.2 Keycloak 사용자 속성

| 속성 | 설명 |
|------|------|
| `phoneNumber` | 휴대폰 번호 |
| `phoneVerified` | 휴대폰 인증 여부 |
| `twoFactorMethod` | 2FA 방식 (totp/sms/none) |

---

## 8. 보안 고려사항

### 8.1 SMS 인증 보안

| 항목 | 대책 |
|------|------|
| 브루트포스 방지 | 5회 실패 시 30분 차단 |
| 재발송 제한 | 60초 간격 제한 |
| 인증코드 유효시간 | 5분 |
| 인증코드 길이 | 6자리 숫자 |

### 8.2 비밀번호 정책

| 항목 | 요구사항 |
|------|----------|
| 최소 길이 | 8자 이상 |
| 복잡성 | 영문, 숫자, 특수문자 포함 |
| 이전 비밀번호 | 최근 3개 재사용 불가 |

### 8.3 토큰 보안

- SMS 검증 토큰: JWT, 10분 유효
- 단일 사용: 사용 후 즉시 무효화

---

## 9. 구현 순서

```mermaid
gantt
    title K-ECP 하이브리드 인증 시스템 구현 계획
    dateFormat  YYYY-MM-DD
    
    section Backend
    Keycloak Admin Client 설정     :b1, 2026-01-30, 1d
    SMS 서비스 연동                :b2, after b1, 2d
    인증 API 구현                  :b3, after b2, 3d
    
    section Frontend
    회원가입 페이지                :f1, after b3, 2d
    비밀번호 찾기 페이지           :f2, after f1, 2d
    2FA 설정 페이지               :f3, after f2, 2d
    
    section Keycloak
    SMS SPI 개발                  :k1, after b2, 3d
    2FA 플로우 설정               :k2, after k1, 1d
    
    section 테스트
    통합 테스트                   :t1, after f3, 2d
    보안 테스트                   :t2, after t1, 1d
```

---

## 10. 참고 자료

- [Keycloak Admin REST API](https://www.keycloak.org/docs-api/24.0/rest-api/)
- [Keycloak SPI 개발 가이드](https://www.keycloak.org/docs/latest/server_development/)
- [OIDC Authorization Code Flow](https://openid.net/specs/openid-connect-core-1_0.html)

---

## Appendix A: SMS 서버 연동 스펙

SMS 서버 API 스펙은 기존 시스템의 문서를 참조하여 별도 작성 예정.

```
# 예상 인터페이스
POST /sms/send
{
  "phoneNumber": "010-1234-5678",
  "message": "[K-ECP] 인증번호: 123456"
}
```

---

## Appendix B: 환경 변수

```bash
# Backend
KEYCLOAK_URL=http://localhost:8180
KEYCLOAK_REALM=k-ecp
KEYCLOAK_CLIENT_ID=k-ecp-admin
KEYCLOAK_CLIENT_SECRET=your-secret

# SMS Server
SMS_SERVER_URL=https://sms.example.com
SMS_API_KEY=your-api-key

# Redis
REDIS_HOST=localhost
REDIS_PORT=6379
```
