# Go Patterns (This Repo)

Load from `golang-quality` when generating, reviewing, or refactoring `.go` files.

Invariants: `.cursor/rules/rules-for-golang-coding.mdc`, `.cursor/rules/always-rules-2-architecture.mdc`.

---

## Resource management

### HTTP response body

```go
resp, err := client.Do(req)
if err != nil {
    return fmt.Errorf("request failed: %w", err)
}
defer resp.Body.Close()

var result MyResponse
if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
    return fmt.Errorf("failed to decode response: %w", err)
}
```

- MUST call `defer resp.Body.Close()` on the line immediately after the error check.
- NEVER read `resp.Body` without a preceding defer close.

### Context with timeout

```go
ctx, cancel := context.WithTimeout(parentCtx, 5*time.Second)
defer cancel()

if err := client.SendMessage(ctx, agentID, msgs); err != nil {
    return fmt.Errorf("failed to send message: %w", err)
}
```

- MUST defer `cancel()` immediately after `WithTimeout` / `WithCancel` / `WithDeadline`.

### Database transaction

```go
tx, err := db.Begin(ctx)
if err != nil {
    return fmt.Errorf("failed to begin transaction: %w", err)
}
defer tx.Rollback(ctx) // no-op if Commit succeeds

if err := tx.Commit(ctx); err != nil {
    return fmt.Errorf("failed to commit transaction: %w", err)
}
```

- MUST defer `tx.Rollback(ctx)` immediately after `Begin`.
- NEVER begin a transaction without a deferred rollback.

### File resource

```go
file, err := os.Open(filePath)
if err != nil {
    return fmt.Errorf("failed to open file: %w", err)
}
defer file.Close()
```

---

## Error handling

### Wrap with operation context

```go
resp, err := client.doRequest(ctx, "GET", "/v1/agents", nil)
if err != nil {
    return fmt.Errorf("failed to list agents: %w", err)
}
```

Services SHOULD use domain errors when the package already does:

```go
if err != nil {
    return errors.NewDomainError(errors.ErrEvaluationFailed, "Failed to list agents", err)
}
```

- MUST wrap — NEVER return `err` bare from an external call.
- Message MUST name the operation that failed.

### Persistence errors MUST be returned

```go
if err := contextService.AddTranslationVersion(ctx, evalContext, version, translation); err != nil {
    logger.WithError(err).Error("Failed to persist evaluation results to shared context.")
    return fmt.Errorf("evaluation succeeded but failed to persist results: %w", err)
}
```

- MUST return the error — NEVER log-only when persistence fails.
- Continuing after a persistence failure causes state inconsistency and infinite loops.

### Log-only only inside defer

```go
defer func() {
    if err := file.Close(); err != nil {
        logger.WithError(err).Warn("Failed to close file in defer.")
    }
}()
```

Logging MUST use injected `*observability.Logger`. NEVER `fmt.Print*` or `logrus.New()` for logs.

---

## Nil safety

### Constructor nil guards

```go
func NewService(client ClientInterface, logger *observability.Logger) *Service {
    if client == nil {
        panic("client cannot be nil")
    }
    if logger == nil {
        panic("logger cannot be nil")
    }
    return &Service{client: client, logger: logger}
}
```

- MUST panic on nil for every required dependency in the constructor.

### Nil check at public API boundaries

```go
func Process(config *Config) error {
    if config == nil {
        return fmt.Errorf("config cannot be nil")
    }
    timeout := config.Timeout
    _ = timeout
    return nil
}
```

- Return an error (not panic) for nil inputs at public API boundaries.

---

## Context

### Check cancellation before expensive work

```go
func Process(ctx context.Context) error {
    select {
    case <-ctx.Done():
        return ctx.Err()
    default:
    }
    return client.SendMessage(ctx, agentID, msgs)
}
```

- MUST propagate `ctx` to all callees — NEVER substitute `context.Background()`.

### Long-running loop

```go
func (s *Service) LongRunningTask(ctx context.Context) error {
    ticker := time.NewTicker(1 * time.Second)
    defer ticker.Stop()

    for {
        select {
        case <-ctx.Done():
            return ctx.Err()
        case <-ticker.C:
            if err := s.doWork(ctx); err != nil {
                return fmt.Errorf("work iteration failed: %w", err)
            }
        }
    }
}
```

---

## Dependency injection

Primary pattern: constructor injection. Wire from `internal/container` (or the pipeline container). NEVER instantiate clients or loggers inside business logic.

```go
type Service struct {
    db     DatabaseClient
    logger *observability.Logger
}

func NewService(db DatabaseClient, logger *observability.Logger) *Service {
    if db == nil {
        panic("db cannot be nil")
    }
    if logger == nil {
        panic("logger cannot be nil")
    }
    return &Service{db: db, logger: logger}
}
```

- MUST inject ALL dependencies via constructor.
- MUST use interfaces for external dependencies (HTTP, DB, APIs).
- Concrete types are acceptable for a single stable adapter (see architecture DI notes).

PROHIBITED:

```go
func (s *Service) ProcessOrder() error {
    db := database.NewClient() // bypasses DI
    log := observability.NewLogger("info") // bypasses DI
}
```

---

## Architecture (CLI → Service → Client)

```go
// CLI — delegates only.
func (c *Command) Execute(ctx context.Context) error {
    return c.service.SetupAgents(ctx)
}

// Service — business logic, injected client.
func (s *Service) SetupAgents(ctx context.Context) error {
    resource, err := s.apiClient.Create(ctx, config)
    if err != nil {
        return fmt.Errorf("failed to create agent resource: %w", err)
    }
    return nil
}

// Client — HTTP only, internal/clients/<service>/.
func (c *APIClient) Create(ctx context.Context, cfg AgentConfig) (*Resource, error) {
    req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+"/v1/agents", body)
    if err != nil {
        return nil, fmt.Errorf("failed to build create request: %w", err)
    }
    resp, err := c.httpClient.Do(req)
    if err != nil {
        return nil, fmt.Errorf("create agent request failed: %w", err)
    }
    defer resp.Body.Close()
    return decode(resp)
}
```

- CLI MUST only call service methods.
- Services MUST NOT call `http` directly.
- HTTP MUST live in `internal/clients/<service>/` (or a pipeline HTTP client package).

---

## Interface segregation (ISP)

```go
type SayingRepository interface {
    Create(ctx context.Context, s *Saying) error
    GetByID(ctx context.Context, id uuid.UUID) (*Saying, error)
    Update(ctx context.Context, s *Saying) error
    Delete(ctx context.Context, id uuid.UUID) error
}

type TranslationRepository interface {
    Create(ctx context.Context, t *Translation) error
    GetByID(ctx context.Context, id uuid.UUID) (*Translation, error)
    Update(ctx context.Context, t *Translation) error
    Delete(ctx context.Context, id uuid.UUID) error
}

type TranslationService struct {
    sayings      SayingRepository
    translations TranslationRepository
}
```

- Maximum 5–6 methods per interface.
- Services MUST declare only the interfaces they use.
- Prefer generics over `any` / `interface{}` when a type parameter fits:

```go
type Cache[T any] interface {
    Get(key string) (T, bool)
    Set(key string, value T) error
    Delete(key string) error
}
```

---

## Testing

```go
func TestService_ProcessData(t *testing.T) {
    mockDB := &MockDatabaseClient{
        QueryFn: func(ctx context.Context, sql string, args ...any) ([]Row, error) {
            return []Row{{Data: "test"}}, nil
        },
    }
    logger := observability.NewLogger("debug")
    svc := NewService(mockDB, logger)

    err := svc.ProcessData(context.Background(), []byte("test"))
    if err != nil {
        t.Fatalf("unexpected error: %v", err)
    }
}
```

- MUST mock external dependencies. NEVER hit real APIs or DBs in unit tests.
- Test names: `Test<Type>_<Method>_<Scenario>`.

```go
func setupTestDB(t *testing.T) DatabaseClient {
    t.Helper()
    db, err := database.NewTestClient(context.Background())
    if err != nil {
        t.Fatalf("failed to set up test database: %v", err)
    }
    t.Cleanup(func() { db.Close() })
    return db
}
```

- MUST call `t.Helper()` in test helpers.
- MUST use `t.Cleanup` instead of `defer` for teardown in helpers.

---

## Performance

### Pre-allocate slices

```go
items := make([]Item, 0, len(input))
for _, v := range input {
    items = append(items, Item{Value: v})
}
```

### Batch instead of N+1

```go
agents, err := client.ListAgents(ctx)
if err != nil {
    return fmt.Errorf("failed to list agents: %w", err)
}
agentMap := make(map[string]*Agent, len(agents))
for _, a := range agents {
    agentMap[a.ID] = a
}
```

PROHIBITED: one `GetByID` per ID in a loop when a list/batch exists.

### Large structs by pointer

Pass and return structs with 3+ fields as pointers.

---

## Import organization

```go
import (
    "context"
    "fmt"
    "time"

    "github.com/google/uuid"
    "github.com/spf13/cobra"

    "github.com/xynova/content-pipelines/internal/config"
    "github.com/xynova/content-pipelines/internal/observability"
)
```

- Group: stdlib → third-party → internal, blank lines between groups.
- `make format` runs gofumpt + goimports.
