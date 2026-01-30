# K-ECP SSO

K-ECP 생태계 통합 인증 시스템 (Keycloak 기반)

## 개요

K-ECP 서비스들(user-console, marketplace, KustHub, Kohub)에서 단일 로그인(SSO)을 제공하는 인증 시스템입니다.

```mermaid
flowchart TB
    subgraph SSO["🔐 K-ECP SSO (Keycloak)"]
        KC["Keycloak<br/>:8180"]
    end
    
    subgraph Services["K-ECP 서비스"]
        UC["🏢 user-console<br/>(Spring)<br/>:8080"]
        MP["🛒 marketplace<br/>(Flask)<br/>:5000"]
        KH["📞 KustHub<br/>(React)<br/>:3001"]
        KO["⚙️ Kohub<br/>(React)<br/>:3002"]
        FT["🔮 Future<br/>Services"]
    end
    
    KC --> UC
    KC --> MP
    KC --> KH
    KC --> KO
    KC -.-> FT
    
    style SSO fill:#fff3e0,stroke:#f57c00
    style Services fill:#e3f2fd,stroke:#1976d2
```

## 인증 흐름 (Authorization Code Flow + PKCE)

```mermaid
sequenceDiagram
    autonumber
    participant User as 👤 사용자
    participant App as 📱 앱 (SPA/Server)
    participant KC as 🔐 Keycloak
    
    User->>App: 서비스 접속
    App-->>User: 로그인 필요
    User->>KC: Keycloak 로그인 페이지
    KC-->>User: 로그인 폼
    User->>KC: ID/Password 입력
    KC-->>User: Authorization Code
    User->>App: Code 전달
    App->>KC: Token 교환 (code + PKCE)
    KC-->>App: Access Token + Refresh Token
    App-->>User: 서비스 제공
    
    Note over User,KC: 이후 API 호출 시 Access Token 사용
```

## 기술 스택

| 구성요소 | 기술 | 버전 |
|----------|------|------|
| 인증 서버 | Keycloak | 24.0 |
| 데이터베이스 | PostgreSQL | 15 |
| 컨테이너 | Podman/Docker Compose | - |

## 빠른 시작

### 1. 환경 변수 설정

```bash
cp .env.example .env
# .env 파일 편집
```

### 2. 서비스 시작

```bash
# 개발 환경
podman-compose up -d

# 또는 docker-compose
docker-compose up -d
```

### 3. 접속

- **Admin Console**: http://localhost:8180/admin
  - ID: admin / PW: admin123 (기본값)
- **k-ecp Realm**: http://localhost:8180/realms/k-ecp

### 4. 상태 확인

```bash
./scripts/health-check.sh
```

## Realm 구성

```mermaid
flowchart TB
    subgraph Realm["🏰 Realm: k-ecp"]
        subgraph Clients["📱 Clients"]
            C1["k-ecp-main<br/>Confidential"]
            C2["k-ecp-marketplace<br/>Confidential"]
            C3["k-ecp-support<br/>Public + PKCE"]
            C4["k-ecp-kohub<br/>Public + PKCE"]
        end
        
        subgraph Roles["🎭 Realm Roles"]
            R1["admin"]
            R2["operator"]
            R3["partner"]
            R4["member"]
        end
        
        subgraph Groups["👥 Groups"]
            G1["K-ECP Admins"]
            G2["Operators"]
            G3["Partners"]
            G4["Members"]
        end
    end
    
    style Realm fill:#e8f5e9,stroke:#388e3c
    style Clients fill:#e3f2fd,stroke:#1976d2
    style Roles fill:#fff3e0,stroke:#f57c00
    style Groups fill:#f3e5f5,stroke:#7b1fa2
```

## 등록된 클라이언트

| Client ID | 서비스 | 유형 | 포트 | 비고 |
|-----------|--------|------|------|------|
| k-ecp-main | user-console | Confidential | 8080 | |
| k-ecp-marketplace | marketplace | Confidential | 5000 | |
| k-ecp-support | KustHub | Public (PKCE) | 4000 | 프론트엔드 SSO 로그인 |
| kusthub-frontend | KustHub | Public + Direct Access | 4000 | 비밀번호 검증용 |
| k-ecp-kohub | Kohub | Public (PKCE) | 3002 | |

> **Note**: `kusthub-frontend` 클라이언트는 프로필 관리에서 비밀번호 재확인 시 Direct Access Grants를 사용합니다.

## Realm 역할

| 역할 | 설명 | 권한 |
|------|------|------|
| admin | 시스템 관리자 | 시스템 전반 설정 및 모니터링 |
| operator | 운영자 (접수자) | 요청 분류 및 담당자 지정 |
| partner | 파트너 (담당자) | 요청 처리 및 결과 입력 |
| customer_admin | 고객 관리자 | 고객사 사용자 관리, 요청 모니터링 |
| member | 일반 회원 (고객) | 요청 생성/조회, 공지 열람 |

## User Profile 속성

KustHub 고객정보 관리를 위해 추가된 사용자 정의 속성:

| 속성 | 설명 | 필수 |
|------|------|------|
| phoneNumber | 휴대폰 번호 | 선택 |
| company | 회사/기관 | 선택 |
| department | 부서 | 선택 |
| position | 직위 | 선택 |
| receiveSms | SMS 수신 동의 | 선택 |
| receiveEmail | 이메일 수신 동의 | 선택 |

> **설정 방법**: Keycloak Admin Console → Realm Settings → User Profile에서 속성을 추가합니다.

## 테스트 계정

| 이메일 | 비밀번호 | 역할 |
|--------|----------|------|
| testadmin@kecp.kdn.com | test1234 | admin |
| testuser@kecp.kdn.com | test1234 | member |

## 디렉토리 구조

```
kecp-sso/
├── compose.yml              # 개발 환경
├── compose.prod.yml         # 운영 환경
├── .env.example             # 환경 변수 템플릿
├── keycloak/
│   ├── import/
│   │   └── k-ecp-realm.json # Realm 초기 설정
│   ├── themes/kecp/         # 커스텀 테마 (옵션)
│   └── certs/               # SSL 인증서 (운영용)
├── scripts/
│   ├── generate-certs.sh    # 인증서 생성
│   ├── backup-realm.sh      # Realm 백업
│   └── health-check.sh      # 상태 확인
└── docs/
    └── client-integration.md # 클라이언트 연동 가이드
```

## 운영 환경 배포

```mermaid
flowchart LR
    subgraph Dev["개발 환경"]
        D1["compose.yml"]
        D2["HTTP :8180"]
    end
    
    subgraph Prod["운영 환경"]
        P1["compose.prod.yml"]
        P2["HTTPS :8443"]
        P3["SSL 인증서"]
    end
    
    Dev -->|배포| Prod
    
    style Dev fill:#e3f2fd,stroke:#1976d2
    style Prod fill:#e8f5e9,stroke:#388e3c
```

```bash
# 1. SSL 인증서 준비
./scripts/generate-certs.sh  # 또는 공인 인증서 복사

# 2. 환경 변수 설정
cp .env.example .env
# 보안 비밀번호로 변경

# 3. 운영 모드로 시작
podman-compose -f compose.prod.yml up -d
```

## 연동 가이드

각 서비스에서 SSO를 연동하는 방법은 [클라이언트 연동 가이드](docs/client-integration.md)를 참조하세요.

## 문서

- [클라이언트 연동 가이드](docs/client-integration.md)
- [Keycloak 공식 문서](https://www.keycloak.org/documentation)

## License

Internal Use Only - K-ECP Team
