# Large-Scale App Architecture

> **Flutter + Go Echo | Modular Monolith + Clean Architecture**
> Version 1.0.0 — April 2026

---

## 1. Project Overview

Large-scale betting/gaming platform (1xbet-scale) အတွက် architecture document ဖြစ်ပါသည်။
Flutter ကို cross-platform mobile (Android + iOS)၊ Go Echo ကို backend အဖြစ် သုံးသည်။

| Component | Technology | Purpose |
|-----------|-----------|---------|
| Mobile App | Flutter (Dart) | Android + iOS client |
| State Management | Riverpod 2.x + Code Gen | Reactive state, DI |
| Navigation | GoRouter | Declarative routing |
| Backend | Go + Echo v4 | REST API + WebSocket |
| Architecture | Modular Monolith + Clean Architecture | Scalable structure |
| Database | PostgreSQL | Primary data store |
| Cache | Redis | Sessions, odds, rate limiting |
| Event Bus | Internal (Kafka-ready) | Async module communication |
| Auth | JWT + Refresh Token | Stateless authentication |
| Real-time | WebSocket (Go) | Live odds streaming |

---

## 2. Architecture Overview

### 2.1 Why Modular Monolith + Clean Architecture?

နှစ်ခုသည် complementary pattern များဖြစ်ပြီး တပြိုင်နက် အသုံးပြုသည်။

| Pattern | Type | Purpose |
|---------|------|---------|
| Modular Monolith | Deployment & Structure Strategy | Module များ (user, betting, payment) ကို single binary ထဲ independent ခွဲထားသည် |
| Clean Architecture | Code Organization Pattern | Module တစ်ခုချင်းစီထဲမှာ domain / usecase / infrastructure layer ခွဲသည် |

```
Modular Monolith
┌─────────────────────────────────────┐
│  ┌──────────┐      ┌──────────┐    │
│  │  User    │      │ Betting  │    │
│  │ Module   │      │ Module   │    │
│  │──────────│      │──────────│    │
│  │ domain   │      │ domain   │    │  ← Clean Architecture
│  │ usecase  │      │ usecase  │    │    တစ်ခုချင်းစီထဲမှာ
│  │ infra    │      │ infra    │    │
│  └──────────┘      └──────────┘    │
│           Single Binary            │
└─────────────────────────────────────┘
```

### 2.2 Migration Path

| Phase | Structure | When |
|-------|-----------|------|
| Phase 1 (Now) | Modular Monolith — single binary, PostgreSQL schemas separated | MVP to early production |
| Phase 2 (Growth) | Extract Odds Service, Notification Service | Specific modules hit bottlenecks |
| Phase 3 (Scale) | Full Microservices — gRPC, Kafka, K8s | Enterprise scale |

---

## 3. Backend Architecture (Go + Echo)

### 3.1 Technology Stack

| Layer | Technology |
|-------|-----------|
| HTTP Framework | Echo v4 |
| ORM | GORM + sqlc |
| Database | PostgreSQL (schema-per-module) |
| Cache | Redis (go-redis) |
| Auth | JWT (golang-jwt) + bcrypt |
| Validation | go-playground/validator |
| Config | Viper |
| Migration | golang-migrate |
| Logger | Zap (uber-go/zap) |
| Testing | testify + gomock |

### 3.2 Folder Structure

```
backend/
├── cmd/
│   └── server/
│       └── main.go                 # Entry point
│
├── internal/
│   ├── modules/
│   │   ├── user/
│   │   │   ├── domain/
│   │   │   │   ├── entity.go       # Pure Go structs
│   │   │   │   └── repository.go   # Interface
│   │   │   ├── usecase/
│   │   │   │   └── user_usecase.go
│   │   │   ├── repository/
│   │   │   │   └── postgres_repo.go # Implementation
│   │   │   └── handler/
│   │   │       └── user_handler.go  # Echo handler
│   │   ├── betting/                 # Same structure
│   │   ├── payment/                 # Same structure
│   │   ├── odds/                    # Same structure
│   │   └── notification/            # Same structure
│   │
│   ├── shared/
│   │   ├── middleware/              # Auth, rate limit, logging
│   │   ├── database/               # DB connection pool
│   │   ├── cache/                  # Redis client
│   │   ├── event/                  # Internal event bus
│   │   └── errors/                 # Shared error types
│   │
│   └── app/
│       └── router.go               # Route registration
│
├── pkg/                            # Reusable (future microservices)
│   ├── jwt/
│   ├── logger/
│   └── config/
│
├── migrations/                     # golang-migrate SQL files
└── go.mod
```

### 3.3 Clean Architecture Flow (per module)

```
Echo Handler (HTTP layer)
  └── UseCase (business logic)
        └── Repository Interface (domain — no framework dependency)
              └── Repository Implementation (infrastructure)
                    └── PostgreSQL / Redis
```

### 3.4 Module Communication Rule

Modules တစ်ခုနဲ့တစ်ခု directly import မလုပ်ရ။ Interface သို့မဟုတ် internal event bus မှတဆင့်သာ communicate လုပ်ရမည်။

```go
// ❌ BAD — tight coupling
import "myapp/internal/modules/user"

func (b *BettingUseCase) PlaceBet() {
    u := user.GetUser(id) // direct dependency
}

// ✅ GOOD — interface dependency
type UserProvider interface {
    GetUser(ctx context.Context, id string) (*UserInfo, error)
}

func (b *BettingUseCase) PlaceBet() {
    u := b.userProvider.GetUser(id) // interface only
}
```

### 3.5 Database Strategy (Schema-per-Module)

```sql
-- Each module owns its schema
CREATE SCHEMA users;
CREATE SCHEMA betting;
CREATE SCHEMA payments;
CREATE SCHEMA odds;

-- Tables are namespaced
CREATE TABLE users.accounts (...);
CREATE TABLE betting.bets (...);
CREATE TABLE payments.transactions (...);
```

> Module ကို Microservice အဖြစ် extract လုပ်တဲ့အခါ schema သည် separate database ဖြစ်သွားသည် — data migration မလိုဘဲ။

### 3.6 Security Requirements

| Requirement | Implementation |
|-------------|---------------|
| Authentication | JWT Access Token (15min) + Refresh Token (7 days) |
| Session invalidation | Redis-based token blacklist |
| Rate limiting | Per-user + per-IP via Redis middleware |
| Password hashing | bcrypt (cost factor 12) |
| Financial transactions | Idempotency key on all payment endpoints |
| Request integrity | HMAC request signing for sensitive operations |
| Fraud detection | Middleware layer with rule-based scoring |

---

## 4. Frontend Architecture (Flutter)

### 4.1 Technology Stack

| Layer | Technology |
|-------|-----------|
| State Management | Riverpod 2.x (with code generation) |
| Architecture | Clean Architecture (per feature) |
| Navigation | GoRouter |
| HTTP Client | Dio + Retrofit |
| WebSocket | web_socket_channel |
| Local Storage | Hive / Isar |
| Serialization | Freezed + json_serializable |
| Testing | flutter_test + mocktail |

### 4.2 Folder Structure

```
lib/
├── core/
│   ├── constants/
│   ├── errors/               # Failures, Exceptions
│   ├── network/
│   │   ├── dio_client.dart   # Dio + interceptors
│   │   └── websocket.dart    # WS client
│   ├── router/               # GoRouter setup
│   ├── theme/
│   └── utils/
│
├── features/
│   └── auth/
│       ├── data/
│       │   ├── datasources/  # Remote & Local
│       │   ├── models/       # DTOs (Freezed)
│       │   └── repositories/ # Implementation
│       ├── domain/
│       │   ├── entities/     # Pure Dart classes
│       │   ├── repositories/ # Abstract interface
│       │   └── usecases/
│       └── presentation/
│           ├── providers/    # Riverpod notifiers
│           ├── screens/
│           └── widgets/
│   ├── betting/              # Same structure
│   ├── odds/                 # Same structure
│   └── payment/              # Same structure
│
└── main.dart
```

### 4.3 Data Flow

```
Widget (ConsumerWidget)
  └── watches Riverpod Provider
        └── calls UseCase
              └── Repository Interface (domain)
                    └── Repository Implementation (data)
                          └── DataSource (Remote: Dio / Local: Hive)
```

### 4.4 Riverpod Pattern

#### Provider Definition

```dart
@riverpod
class AuthNotifier extends _$AuthNotifier {
  @override
  AsyncValue<User?> build() => const AsyncData(null);

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    final result = await ref
        .read(loginUseCaseProvider)
        .call(LoginParams(email: email, password: password));
    state = result.fold(
      (failure) => AsyncError(failure, StackTrace.current),
      (user) => AsyncData(user),
    );
  }
}
```

#### UI Consumption

```dart
class LoginScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    return authState.when(
      data: (user) => user != null ? const HomeScreen() : const LoginForm(),
      loading: () => const CircularProgressIndicator(),
      error: (e, _) => ErrorWidget(e.toString()),
    );
  }
}
```

### 4.5 Real-time Odds (WebSocket)

```dart
final channel = WebSocketChannel.connect(
  Uri.parse('wss://api.yourapp.com/ws/odds'),
);

StreamBuilder(
  stream: channel.stream,
  builder: (context, snapshot) {
    if (!snapshot.hasData) return const LoadingWidget();
    final odds = OddsModel.fromJson(jsonDecode(snapshot.data as String));
    return OddsWidget(odds: odds);
  },
)
```

---

## 5. API Design Contract

### 5.1 REST Conventions

| Rule | Example |
|------|---------|
| Resource naming (plural nouns) | `GET /api/v1/users` |
| Versioning in URL | `/api/v1/...`, `/api/v2/...` |
| HTTP verbs | GET=read, POST=create, PUT=replace, PATCH=update, DELETE=remove |
| Auth header | `Authorization: Bearer <access_token>` |
| Pagination | `?page=1&limit=20` with `meta: { total, page, lastPage }` |

### 5.2 Standard Response Format

```json
// Success
{
  "success": true,
  "data": { },
  "meta": { "total": 100, "page": 1, "lastPage": 5 }
}

// Error
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Email is required",
    "details": { "field": "email" }
  }
}
```

### 5.3 WebSocket Message Format

```json
{
  "type": "ODDS_UPDATE",
  "payload": {
    "matchId": "123",
    "homeOdds": 1.85,
    "awayOdds": 2.10,
    "drawOdds": 3.40,
    "timestamp": "2026-04-13T10:00:00Z"
  }
}
```

---

## 6. Coding Standards

### 6.1 Go (Backend)

| Rule | Detail |
|------|--------|
| Naming | Structs: `PascalCase` \| functions: `camelCase` \| constants: `SCREAMING_SNAKE_CASE` |
| Error handling | Always wrap: `fmt.Errorf("usecase.Login: %w", err)` |
| Context | `context.Context` ကို service/repo methods အားလုံး၏ first argument အဖြစ် pass လုပ်ရမည် |
| Interface size | Small interfaces (1-3 methods) — prefer many small over one large |
| Tests | Usecase layer တွင် minimum 80% coverage။ Table-driven tests သုံးရမည် |

### 6.2 Dart / Flutter (Frontend)

| Rule | Detail |
|------|--------|
| Naming | Classes: `PascalCase` \| variables/functions: `camelCase` \| files: `snake_case` |
| Immutability | Data models နှင့် entities အားလုံးတွင် Freezed သုံးရမည် |
| Providers | Feature တစ်ခုလျှင် Notifier တစ်ခု။ `@riverpod` annotation သုံးရမည် |
| Async context | `await` ပြီးနောက် `context` သုံးမည်ဆိုလျှင် `mounted` စစ်ရမည် |
| Widget size | Widget တစ်ခု 100 lines ကျော်ပါက sub-widget ခွဲထုတ်ရမည် |
| Tests | UseCase အားလုံး unit test လုပ်ရမည်။ Critical screens တွင် widget test လုပ်ရမည် |

---

## 7. Deployment Strategy

### 7.1 Phase 1 — Docker Compose (Current)

```yaml
# docker-compose.yml
services:
  backend:
    build: .
    ports:
      - "8080:8080"
    depends_on:
      - postgres
      - redis

  postgres:
    image: postgres:15
    environment:
      POSTGRES_DB: appdb
      POSTGRES_USER: user
      POSTGRES_PASSWORD: password

  redis:
    image: redis:7-alpine
```

### 7.2 Phase 3 — Kubernetes (Future)

```
Kubernetes Cluster
├── Ingress (Nginx)
├── API Gateway Pod (Go/Echo)
├── User Service Pod
├── Betting Service Pod
├── Odds Service Pod        ← high-frequency, scale independently
├── Payment Service Pod
├── Notification Service Pod
├── PostgreSQL (RDS/Cloud SQL)
├── Redis Cluster
└── Kafka Cluster

CDN:        Cloudflare
Monitoring: Prometheus + Grafana
Logging:    ELK Stack
```

---

## 8. Getting Started

### 8.1 Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| Go | 1.22+ | Backend language |
| Flutter | 3.19+ | Mobile framework |
| Docker | Latest | Local development |
| PostgreSQL | 15+ | Database |
| Redis | 7+ | Cache |
| golang-migrate | Latest | DB migrations |

### 8.2 Backend Setup

```bash
# Clone repository
git clone https://github.com/your-org/your-app-backend.git
cd your-app-backend

# Copy environment variables
cp .env.example .env

# Start dependencies
docker-compose up -d postgres redis

# Run migrations
make migrate-up

# Start server
go run cmd/server/main.go

# Server runs on http://localhost:8080
```

### 8.3 Flutter Setup

```bash
# Get dependencies
flutter pub get

# Generate code (Riverpod + Freezed)
dart run build_runner build --delete-conflicting-outputs

# Run on Android
flutter run -d android

# Run on iOS
flutter run -d ios
```

### 8.4 Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `DATABASE_URL` | PostgreSQL connection string | `postgres://user:pass@localhost:5432/appdb` |
| `REDIS_URL` | Redis connection string | `redis://localhost:6379` |
| `JWT_SECRET` | JWT signing secret (min 32 chars) | `your-super-secret-key` |
| `JWT_EXPIRY` | Access token expiry | `15m` |
| `REFRESH_EXPIRY` | Refresh token expiry | `168h` |
| `PORT` | Server port | `8080` |
| `ENV` | Environment | `development` \| `production` |

---

*End of Document — Version 1.0.0*
