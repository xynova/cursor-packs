# Go coding reference (cursor-packs)

Deep Go patterns and anti-patterns. Load from `golang-quality` when generating, reviewing, or refactoring `.go` files.

**Procedure / gates:** [SKILL.md](SKILL.md). Compact copy-paste patterns: [reference-patterns.md](reference-patterns.md).

Project architecture / logging / domain rules (if present) still apply and take precedence for local invariants.

---


# Go Coding Rules and Best Practices

**Rules vs skills:** This file states Go **invariants** (resource management, error handling, nil safety, formatting). For generation/completion workflow and Makefile gates, use `.cursor/skills/golang-quality/SKILL.md` (patterns in that skill's `reference.md`). For staged review (stage menu, detect vs consultant), use `.cursor/skills/review-code-staged/SKILL.md` .

## Table of Contents

### **Core Sections**
- [**Core Principles**](#-core-principles) (Line 9)
- [**Mandatory Code Generation Rules (Prevention-First)**](#️-mandatory-code-generation-rules-prevention-first) (Line 20)
  - Resource Management (MANDATORY) (Line 24)
  - Error Handling (MANDATORY) (Line 90)
  - Nil Safety (MANDATORY) (Line 252)
  - Context Propagation (MANDATORY) (Line 287)
  - Variable Usage Verification (MANDATORY) (Line 318)
  - Architecture Compliance (MANDATORY) (Line 360)
  - Performance Patterns (MANDATORY) (Line 397)
  - Logic Verification (MANDATORY) (Line 425)
- [**Code Formatting Requirements**](#-code-formatting-requirements) (Line 451)
- [**DRY (Don't Repeat Yourself) Principles**](#-dry-dont-repeat-yourself-principles) (Line 467)
- [**Type Safety & Interface Design**](#️-type-safety--interface-design) (Line 561)
  - Visibility Rules (Public vs Private) - MANDATORY
- [**Dependency Injection Patterns**](#️-dependency-injection-patterns) (Line 843)
- [**Architecture Patterns**](#️-architecture-patterns) (Line 926)
- [**Utility Functions & Helpers**](#-utility-functions--helpers) (Line 998)
- [**Import Organization**](#-import-organization) (Line 1034)
- [**Testing Integration**](#-testing-integration) (Line 1055)
- [**Mandatory Completion Checklist**](#️-mandatory-completion-checklist) (Line 1081)
- [**Mandatory Code Review Protocol**](#️-mandatory-code-review-protocol) (Line 1105)
- [**Mandatory Verification Protocol**](#️-mandatory-verification-protocol) (Line 1162)
- [**Task Completion Verification**](#-task-completion-verification) (Line 1242)
- [**Code Organization Best Practices**](#code-organization-best-practices) (Line 1271)
- [**Error Handling Patterns**](#error-handling-patterns) (Line 1364)
- [**Testing Best Practices**](#testing-best-practices) (Line 1393)
- [**Performance Considerations**](#performance-considerations) (Line 1423)
- [**Documentation Standards**](#documentation-standards) (Line 1457)
- [**Code Review Checklist**](#code-review-checklist) (Line 1480)
- [**Anti-Patterns to Avoid**](#anti-patterns-to-avoid) (Line 1499)
- [**Tools and Automation**](#tools-and-automation) (Line 1533)
- [**Summary**](#summary) (Line 1562)
- [**SOLID Principles**](#️-solid-principles) (Line 1574)


## 🎯 **CORE PRINCIPLES**
- **DRY (Don't Repeat Yourself)**: Eliminate code duplication through abstraction and reuse
- **Type Safety**: Full type safety with comprehensive type annotations and interfaces
- **Data Validation**: Use struct tags and validation for all data structures
- **Code Quality**: Format with gofmt, lint with golangci-lint, vet with go vet
- **Modern Go**: Use Go 1.21+ features and best practices
- **Dependency Injection**: Proper DI patterns for testability and maintainability
- **SOLID Principles**: Follow Single Responsibility, Open/Closed, Liskov Substitution, Interface Segregation, and Dependency Inversion principles


## 🛡️ **MANDATORY CODE GENERATION RULES (Prevention-First)**

> **For AI (Cursor)**: These rules are MANDATORY when generating code. They prevent bugs that code review would catch. Follow these patterns DURING code generation, not just during review.

### **🚨 CRITICAL: Resource Management (MANDATORY)**

#### **HTTP Response Bodies - ALWAYS CLOSE**
- **ALWAYS** close HTTP response bodies with `defer resp.Body.Close()` immediately after checking errors
- **NEVER** use `resp.Body` without defer
- **NEVER** return from function without closing response body
- **Pattern**:
```go
// ❌ FORBIDDEN: Response body not closed
resp, err := client.Do(req)
if err != nil {
    return err
}
json.NewDecoder(resp.Body).Decode(&result)  // ← Resource leak!

// ✅ MANDATORY: Always close with defer
resp, err := client.Do(req)
if err != nil {
    return err
}
defer resp.Body.Close()  // ← MUST be first after error check
json.NewDecoder(resp.Body).Decode(&result)
```

#### **Context Cancellation - ALWAYS DEFER**
- **ALWAYS** defer `cancel()` when creating context with `WithTimeout`, `WithCancel`, or `WithDeadline`
- **NEVER** create context without deferring cancellation
- **Pattern**:
```go
// ❌ FORBIDDEN: Context leak
ctx, cancel := context.WithTimeout(parentCtx, 5*time.Second)
client.SendMessage(ctx, ...)  // ← cancel() never called!

// ✅ MANDATORY: Always defer cancel
ctx, cancel := context.WithTimeout(parentCtx, 5*time.Second)
defer cancel()  // ← MUST defer immediately after creation
client.SendMessage(ctx, ...)
```

#### **Database Transactions - ALWAYS ROLLBACK**
- **ALWAYS** use `defer tx.Rollback(ctx)` after beginning a transaction
- **NEVER** begin transaction without defer rollback
- **Pattern**:
```go
// ❌ FORBIDDEN: Transaction leak
tx, err := db.Begin(ctx)
if err != nil {
    return err
}
// ... operations ...
return tx.Commit(ctx)  // ← If error before commit, transaction hangs!

// ✅ MANDATORY: Always defer rollback
tx, err := db.Begin(ctx)
if err != nil {
    return err
}
defer tx.Rollback(ctx)  // ← MUST defer immediately after begin
// ... operations ...
return tx.Commit(ctx)  // Commit cancels the defer rollback
```

#### **Files and Other Resources - ALWAYS CLOSE**
- **ALWAYS** use `defer file.Close()` for files, connections, and any Closeable resource
- **NEVER** return without closing resources

### **🚨 CRITICAL: Error Handling (MANDATORY)**

- **ALWAYS** wrap errors with `errors.NewDomainError()` - never return raw errors from external calls
- **NEVER** ignore errors with `_ =` - **THIS IS BAD PRACTICE AND CAUSES BUGS**
- **NEVER** log errors without returning them - logging is not error handling
- **NEVER** silently ignore errors in state persistence operations - this causes data inconsistency and infinite loops
- **ALWAYS** return errors when state persistence fails - even if the operation itself succeeded
- **ALWAYS** preserve underlying errors using `fmt.Errorf("message: %w", err)`
- **Pattern**:
```go
// ❌ FORBIDDEN: Raw error, ignored error, logged but not returned, silent state persistence failure
resp, err := client.doRequest(ctx, "GET", "/v1/agents", nil)
if err != nil {
    return err  // ← Missing domain context
}

_ = client.DeleteAgent(ctx, agentID)  // ← BAD PRACTICE: Silent failure!

if err := process(); err != nil {
    logger.Error(err)  // ← BAD PRACTICE: Caller doesn't know it failed!
}

// ❌ FORBIDDEN: Ignoring state persistence errors - causes infinite loops and version conflicts
if err := contextService.AddTranslationVersion(ctx, evalContext, version, translation, ...); err != nil {
    logger.Error(err)  // ← BAD PRACTICE: State is now inconsistent!
    // Don't fail the evaluation, just log the error  // ← WRONG!
}

// ❌ FORBIDDEN: Ignoring session refresh errors - causes stale state
updatedContext, err := contextService.GetEvaluationContext(ctx, sayingID)
if err == nil && updatedContext != nil {
    // Update session...
}
// Error silently ignored - BAD PRACTICE: Session state is stale!

// ✅ MANDATORY: Wrap with domain error, handle all errors, return state persistence failures
resp, err := client.doRequest(ctx, "GET", "/v1/agents", nil)
if err != nil {
    return errors.NewDomainError(
        errors.ErrExternalAPI,
        "Failed to list agents",
        err,
    )
}

if err := client.DeleteAgent(ctx, agentID); err != nil {
    return errors.NewDomainError(
        errors.ErrAgentDeletionFailed,
        fmt.Sprintf("Failed to delete agent %s", agentID),
        err,
    )
}

// ✅ MANDATORY: Return errors when state persistence fails
if err := contextService.AddTranslationVersion(ctx, evalContext, version, translation, ...); err != nil {
    logger.WithError(err).Error("Failed to persist evaluation results to shared context")
    return errors.NewDomainError(
        errors.ErrExternalAPI,
        "Evaluation succeeded but failed to persist results - context state is inconsistent",
        err,
    )
}

// ✅ MANDATORY: Return errors when session refresh fails
updatedContext, err := contextService.GetEvaluationContext(ctx, sayingID)
if err != nil {
    logger.WithError(err).Error("Failed to refresh session state - session may have stale data")
    return errors.NewDomainError(
        errors.ErrExternalAPI,
        "Failed to refresh session state - session state is stale and unreliable",
        err,
    )
}
if updatedContext == nil {
    return errors.NewDomainError(
        errors.ErrExternalAPI,
        "Session refresh returned nil - session state is unreliable",
        nil,
    )
}
// Update session with fresh data...
```

#### **🚨 CRITICAL: Never Ignore Errors - This Is Bad Practice**

**Rule**: **NEVER** ignore errors. Every error must be handled explicitly.

**Why This Matters**:
- **Ignored errors hide bugs** - Silent failures make debugging impossible
- **State inconsistency** - Ignoring persistence errors causes in-memory and persisted state to diverge
- **Infinite loops** - Stale state causes version conflicts and repeated operations
- **Data corruption** - Ignored errors can lead to inconsistent database state
- **Resource leaks** - Ignored cleanup errors cause resource exhaustion

**Common Anti-Patterns to Avoid**:
```go
// ❌ FORBIDDEN: Explicitly ignoring errors
_ = client.DeleteAgent(ctx, agentID)  // BAD PRACTICE!
_ = file.Close()  // BAD PRACTICE!
_ = tx.Commit(ctx)  // BAD PRACTICE!

// ❌ FORBIDDEN: Checking error but not handling it
err := process()
if err != nil {
    // Empty block - error ignored!  // BAD PRACTICE!
}

// ❌ FORBIDDEN: Logging but not returning
if err := saveState(); err != nil {
    logger.Error(err)  // BAD PRACTICE: Caller doesn't know it failed!
    // Continue as if nothing happened
}

// ❌ FORBIDDEN: Silent state persistence failures
if err := persistState(); err != nil {
    logger.Warn("Failed to persist state, continuing...")  // BAD PRACTICE!
    // State is now inconsistent - will cause bugs!
}

// ✅ MANDATORY: Always handle errors explicitly
if err := client.DeleteAgent(ctx, agentID); err != nil {
    return errors.NewDomainError(
        errors.ErrAgentDeletionFailed,
        fmt.Sprintf("Failed to delete agent %s", agentID),
        err,
    )
}

if err := file.Close(); err != nil {
    return fmt.Errorf("failed to close file: %w", err)
}

if err := tx.Commit(ctx); err != nil {
    return errors.NewDomainError(
        errors.ErrTransactionFailed,
        "Failed to commit transaction",
        err,
    )
}

// ✅ MANDATORY: Return errors from state persistence
if err := persistState(); err != nil {
    logger.WithError(err).Error("Failed to persist state - state is inconsistent")
    return errors.NewDomainError(
        errors.ErrStatePersistenceFailed,
        "Failed to persist state - state is now inconsistent",
        err,
    )
}
```

**Exception**: The ONLY acceptable place to ignore errors is in `defer` cleanup operations where the error cannot be meaningfully handled:
```go
// ✅ ACCEPTABLE: Defer cleanup where error cannot be handled
defer func() {
    if err := file.Close(); err != nil {
        // Log but cannot return from defer
        logger.WithError(err).Warn("Failed to close file in defer")
    }
}()
```

### **🚨 CRITICAL: Nil Safety (MANDATORY)**

- **ALWAYS** check pointers for nil before dereferencing
- **ALWAYS** validate dependencies are non-nil in constructors
- **NEVER** dereference without nil check
- **NEVER** pass nil where non-nil is expected
- **Pattern**:
```go
// ❌ FORBIDDEN: Nil pointer dereference
var config *Config
timeout := config.Timeout  // ← Panic: nil pointer dereference

func NewService(client ClientInterface) *Service {
    return &Service{client: client}  // ← No validation!
}

// ✅ MANDATORY: Always check nil, validate dependencies
func Process(config *Config) error {
    if config == nil {
        return errors.New("config cannot be nil")
    }
    timeout := config.Timeout  // Safe
}

func NewService(client ClientInterface, logger *Logger) *Service {
    if client == nil {
        panic("client cannot be nil")  // ← MUST validate
    }
    if logger == nil {
        panic("logger cannot be nil")
    }
    return &Service{client: client, logger: logger}
}
```

### **🚨 CRITICAL: Context Propagation (MANDATORY)**

- **ALWAYS** pass context through all function calls (never drop context)
- **NEVER** use `context.Background()` when request context is available
- **ALWAYS** check context cancellation before expensive operations
- **ALWAYS** propagate context from caller to callee
- **Pattern**:
```go
// ❌ FORBIDDEN: Context not propagated, background context used
func Process() error {
    client.SendMessage(context.Background(), agentID, msgs)  // ← Wrong!
}

func Process(ctx context.Context) error {
    // No cancellation check before expensive operation
    result := expensiveOperation()  // ← Wastes resources if cancelled
}

// ✅ MANDATORY: Propagate context, check cancellation
func Process(ctx context.Context) error {
    // Check cancellation before expensive operations
    select {
    case <-ctx.Done():
        return ctx.Err()
    default:
    }
    
    return client.SendMessage(ctx, agentID, msgs)  // ← Context propagated
}
```

### **🚨 CRITICAL: Variable Usage Verification (MANDATORY)**

- **ALWAYS** ensure every variable created is actually used
- **NEVER** create variables that are never referenced
- **NEVER** fetch data twice when once would suffice (batch vs individual operations)
- **Pattern Check**: After creating variable, trace its usage - if unused, either use it or remove it
```go
// ❌ FORBIDDEN: Variable created but unused, data fetched twice
agents, err := client.ListAgents(ctx)
if err != nil {
    return err
}
processItems(items)  // ← Doesn't use 'agents', uses undefined 'items'!

// Fetches same data twice
agents, _ := client.ListAgents(ctx)
for _, id := range agentIDs {
    agent, _ := client.GetAgent(ctx, id)  // ← Fetches again!
    process(agent)
}

// ✅ MANDATORY: Use variables, batch operations
agents, err := client.ListAgents(ctx)
if err != nil {
    return err
}
for _, agent := range agents {  // ← Uses 'agents'
    process(agent)
}

// Batch query instead of N+1
agents, _ := client.ListAgents(ctx)
agentMap := make(map[string]*Agent)
for _, agent := range agents {
    agentMap[agent.ID] = agent
}
for _, id := range agentIDs {
    agent := agentMap[id]  // ← Uses batch result
    process(agent)
}
```

### **🚨 CRITICAL: Architecture Compliance (MANDATORY)**

- **ALWAYS** follow CLI → Service → Client pattern
- **NEVER** make direct external API calls outside the dedicated client package (e.g. `internal/clients/<service>/`)
- **NEVER** put business logic in CLI commands
- **ALWAYS** use dependency injection, never direct instantiation
- **Pattern**:
```go
// ❌ FORBIDDEN: Direct API call, business logic in CLI, direct instantiation
func (c *Command) Execute() {
    resp, err := http.Post("http://external-service:8283/v1/agents", ...)  // ← Direct API!
    // ... complex business logic ...
}

func NewService() *Service {
    client := someapi.NewClient(...)  // ← Direct instantiation!
    return &Service{client: client}
}

// ✅ MANDATORY: Follow architecture, use DI
func (c *Command) Execute() error {
    return c.service.SetupAgents(ctx)  // ← Delegates to service
}

func (s *Service) SetupAgents(ctx context.Context) error {
    resource, err := s.apiClient.Create(ctx, config)  // ← Uses injected client
    // ... business logic ...
}

func NewService(apiClient SomeAPIClientInterface, logger *Logger) *Service {
    if apiClient == nil {
        panic("apiClient cannot be nil")
    }
    return &Service{apiClient: apiClient, logger: logger}  // ← Injected
}
```

### **🚨 CRITICAL: Performance Patterns (MANDATORY)**

- **ALWAYS** pass large structs by pointer, not by value
- **ALWAYS** pre-allocate slices when size is known
- **NEVER** fetch data twice when batch operation is available
- **Pattern**:
```go
// ❌ FORBIDDEN: Large struct by value, slice reallocation
func process(s Saying) {  // ← Should be *Saying
    // ...
}

var items []Item
for i := 0; i < 1000; i++ {
    items = append(items, Item{i})  // ← Multiple reallocations
}

// ✅ MANDATORY: Pointer for large structs, pre-allocate slices
func process(s *Saying) {  // ← Pointer
    // ...
}

items := make([]Item, 0, 1000)  // ← Pre-allocated capacity
for i := 0; i < 1000; i++ {
    items = append(items, Item{i})
}
```

### **🚨 CRITICAL: Logic Verification (MANDATORY)**

- **ALWAYS** check array/slice bounds before indexing
- **ALWAYS** check map existence before using value
- **ALWAYS** handle edge cases (empty slices, nil pointers, zero values)
- **Pattern**:
```go
// ❌ FORBIDDEN: Index out of bounds, map access without check
items[0] = value  // ← Panic if len(items) == 0

weight := weights[agentName]  // ← Returns 0 if not found, might be unintended

// ✅ MANDATORY: Check bounds, verify map existence
if len(items) == 0 {
    return errors.New("items cannot be empty")
}
items[0] = value

weight, exists := weights[agentName]
if !exists {
    return errors.New("weight not found for agent")
}
```


## 📝 **CODE FORMATTING REQUIREMENTS**

### **MANDATORY FORMATTING STEPS:**
1. **ALWAYS** run `gofmt -w .` before claiming work is complete
2. **ALWAYS** run `golangci-lint run` to check for style issues
3. **ALWAYS** run `go vet ./...` to verify code quality
4. **ALWAYS** run `go mod tidy` to clean dependencies
5. **NEVER** submit unformatted code
6. **NEVER** ignore linting warnings or errors

### **Formatting Tools:**
- **gofmt**: Code formatting (standard Go formatting)
- **golangci-lint**: Comprehensive linting with custom rules
- **go vet**: Built-in static analysis
- **goimports**: Import organization (handled by gofmt)

### **🚨 CRITICAL: Comment Formatting (MANDATORY)**
- **ALWAYS** end all comments with a period (`.`)
- **NEVER** write comments without ending punctuation
- **Rationale**: The `godot` linter enforces this rule. Missing periods cause lint failures and waste time fixing trivial issues
- **Pattern**:
```go
// ❌ FORBIDDEN: Comment without period
// Handle nullable fields
// Convert nullable strings to pointers
// Parse embedding if present

// ✅ MANDATORY: All comments end with period
// Handle nullable fields.
// Convert nullable strings to pointers.
// Parse embedding if present.
```

**Exception**: Multi-line comments where the period is part of the sentence structure are acceptable, but single-line comments MUST end with a period.

## 🔄 **DRY (DON'T REPEAT YOURSELF) PRINCIPLES**

### 1. Centralize Initialization Logic
- **Rule**: Never duplicate initialization code across multiple files
- **Example**: Config loading, logger setup, database connections
- **Implementation**: Create centralized initialization in `root.go` or dedicated init package
- **Anti-pattern**: Each command file loading config independently
- **Good pattern**: Single point of initialization with global access

```go
// ❌ BAD: Duplicated in every command
func runCommand(cmd *cobra.Command, args []string) {
    if err := godotenv.Load(); err != nil { /* ... */ }
    cfg, err := config.Load()
    if err != nil { /* ... */ }
    // ... rest of logic
}

// ✅ GOOD: Centralized initialization
var (
    Logger *logrus.Logger
    Config *config.Config
)

func initConfig() {
    godotenv.Load()
    cfg, err := config.Load()
    // ... handle errors and set globals
}

func runCommand(cmd *cobra.Command, args []string) {
    cfg := Config  // Already loaded!
    // ... rest of logic
}
```

### 2. Extract Common Patterns
- **Rule**: Identify repeated code patterns and extract them
- **Examples**: Error handling, logging patterns, validation logic
- **Implementation**: Create utility functions or helper packages

```go
// ❌ BAD: Repeated error handling
func runServer() {
    dbClient, err := database.NewClient(ctx, cfg.Database.URL, Logger)
    if err != nil {
        Logger.Fatalf("Failed to connect to database: %v", err)
    }
}

func runChat() {
    dbClient, err := database.NewClient(ctx, cfg.Database.URL, Logger)
    if err != nil {
        Logger.Fatalf("Failed to connect to database: %v", err)
    }
}

// ✅ GOOD: Extracted common pattern
func mustConnectDatabase(ctx context.Context, cfg *config.Config) *database.Client {
    dbClient, err := database.NewClient(ctx, cfg.Database.URL, Logger)
    if err != nil {
        Logger.Fatalf("Failed to connect to database: %v", err)
    }
    return dbClient
}

func runServer() {
    dbClient := mustConnectDatabase(ctx, cfg)
}

func runChat() {
    dbClient := mustConnectDatabase(ctx, cfg)
}
```

### 3. Avoid Import Duplication
- **Rule**: Remove unused imports immediately after refactoring
- **Implementation**: Use `goimports` or IDE auto-formatting
- **Check**: Run `go mod tidy` regularly

```go
// ❌ BAD: Unused imports after refactoring
import (
    "github.com/example/app/internal/config"  // unused
    "github.com/example/app/internal/database"
    "github.com/joho/godotenv"  // unused
)

// ✅ GOOD: Clean imports
import (
    "github.com/example/app/internal/database"
)
```

## 🏷️ **TYPE SAFETY & INTERFACE DESIGN**

### **Type Safety Requirements:**
- **ALWAYS** use explicit types for function parameters and return values
- **ALWAYS** define interfaces for external dependencies
- **ALWAYS** use struct tags for validation and serialization
- **ALWAYS** use generics for reusable code patterns
- **ALWAYS** use context.Context for cancellation and timeouts
- **NEVER** use `interface{}` without explicit justification
- **NEVER** ignore type safety warnings

### **🚨 CRITICAL: Visibility Rules (Public vs Private) - MANDATORY**

**Principle:** Export only what is essential (public API interfaces, constructors, shared domain models, client interfaces for DI). Keep implementation structs, internal interfaces, internal helpers, and session/state private.

**When writing code:** Before exporting a symbol, check: used outside this package? part of public API? constructor or interface for DI? If not, keep it unexported.

**Audit or fix existing code:** Use the **review-member-visibility** skill (`.cursor/skills/review-member-visibility/SKILL.md`) for the full decision tree, checklist, and procedure. Invoke via the review-member-visibility command or by asking to "review visibility" and specifying a target path.

### **Interface Design Examples:**
```go
// ✅ GOOD: Well-defined interfaces
type DatabaseClient interface {
    Connect(ctx context.Context, url string) error
    Query(ctx context.Context, sql string, args ...interface{}) ([]Row, error)
    Close() error
}

type Logger interface {
    Debug(msg string, fields ...Field)
    Info(msg string, fields ...Field)
    Warn(msg string, fields ...Field)
    Error(msg string, fields ...Field)
    Fatal(msg string, fields ...Field)
}

// ✅ GOOD: Generic types for reusability
type Cache[T any] interface {
    Get(key string) (T, bool)
    Set(key string, value T) error
    Delete(key string) error
}

// ✅ GOOD: Struct with validation tags
type Config struct {
    DatabaseURL string `validate:"required,url" json:"database_url"`
    LogLevel    string `validate:"required,oneof=debug info warn error" json:"log_level"`
    Timeout     int    `validate:"min=1,max=300" json:"timeout"`
}
```

### **Context Usage Patterns:**
```go
// ✅ GOOD: Proper context usage
func (s *Service) ProcessData(ctx context.Context, data []byte) error {
    // Check for cancellation
    select {
    case <-ctx.Done():
        return ctx.Err()
    default:
    }
    
    // Use context for timeouts
    ctx, cancel := context.WithTimeout(ctx, 30*time.Second)
    defer cancel()
    
    return s.processWithTimeout(ctx, data)
}
```

## 🏗️ **DEPENDENCY INJECTION PATTERNS**

### **DI Architecture Overview:**
Go applications should use **constructor injection** and **interface-based DI**:
- **Constructor Injection**: Pass dependencies through constructors
- **Interface Segregation**: Use small, focused interfaces
- **Service Locator**: Global service registry for cross-cutting concerns
- **Factory Pattern**: Create services with proper dependencies

### **Constructor Injection Pattern:**
```go
// ✅ GOOD: Constructor injection with interfaces
type Service struct {
    db     DatabaseClient
    logger Logger
    cache  Cache[string]
}

func NewService(db DatabaseClient, logger Logger, cache Cache[string]) *Service {
    return &Service{
        db:     db,
        logger: logger,
        cache:  cache,
    }
}

// ✅ GOOD: Service factory pattern
type ServiceFactory struct {
    dbClient DatabaseClient
    logger   Logger
}

func (f *ServiceFactory) CreateUserService() *UserService {
    return NewUserService(f.dbClient, f.logger)
}

func (f *ServiceFactory) CreateOrderService() *OrderService {
    return NewOrderService(f.dbClient, f.logger)
}
```

### **Global Service Registry:**
```go
// ✅ GOOD: Global service registry for cross-cutting concerns
var (
    Logger *logrus.Logger
    Config *config.Config
    DBClient DatabaseClient
)

func InitServices() error {
    // Initialize logger
    Logger = observability.InitLoggerFromConfig(Config.Logging, "")
    
    // Initialize database
    var err error
    DBClient, err = database.NewClient(context.Background(), Config.Database.URL, Logger)
    if err != nil {
        return fmt.Errorf("failed to initialize database: %w", err)
    }
    
    return nil
}
```

### **DI Anti-Patterns to Avoid:**
```go
// ❌ BAD: Direct instantiation in business logic
func (s *Service) ProcessOrder() error {
    db := database.NewClient() // Bypasses DI
    logger := logrus.New()      // Bypasses DI
    // ...
}

// ❌ BAD: Global state without initialization
var globalDB *sql.DB // Should be injected

// ❌ BAD: Service locator abuse
func GetService[T any]() T {
    return serviceLocator.Get[T]() // Too generic, hard to test
}
```

## 🏛️ **ARCHITECTURE PATTERNS**

### **Error Handling Standards:**
```go
// ✅ GOOD: Custom error types with context
type ServiceError struct {
    Type    string
    Message string
    Cause   error
    Context map[string]interface{}
}

func (e *ServiceError) Error() string {
    return fmt.Sprintf("%s: %s", e.Type, e.Message)
}

func (e *ServiceError) Unwrap() error {
    return e.Cause
}

// ✅ GOOD: Error handling with structured logging
func (s *Service) ProcessData(ctx context.Context, data []byte) error {
    if err := s.validateData(data); err != nil {
        s.logger.WithFields(logrus.Fields{
            "error": err.Error(),
            "data_size": len(data),
        }).Error("Data validation failed")
        return &ServiceError{
            Type:    "ValidationError",
            Message: "Invalid data provided",
            Cause:   err,
            Context: map[string]interface{}{
                "data_size": len(data),
            },
        }
    }
    return nil
}
```

### **Resource Management:**
```go
// ✅ GOOD: Proper resource management with defer
func (s *Service) ProcessFile(filePath string) error {
    file, err := os.Open(filePath)
    if err != nil {
        return fmt.Errorf("failed to open file: %w", err)
    }
    defer file.Close()
    
    // Process file...
    return nil
}

// ✅ GOOD: Context-based cancellation
func (s *Service) LongRunningTask(ctx context.Context) error {
    ticker := time.NewTicker(1 * time.Second)
    defer ticker.Stop()
    
    for {
        select {
        case <-ctx.Done():
            return ctx.Err()
        case <-ticker.C:
            if err := s.doWork(); err != nil {
                return err
            }
        }
    }
}
```

## 🔧 **UTILITY FUNCTIONS & HELPERS**

### **Common Patterns:**
```go
// ✅ GOOD: Reusable utility functions
func Must[T any](value T, err error) T {
    if err != nil {
        panic(fmt.Sprintf("must not fail: %v", err))
    }
    return value
}

func SafeDivide(a, b float64) (float64, error) {
    if b == 0 {
        return 0, fmt.Errorf("division by zero")
    }
    return a / b, nil
}

func Retry(ctx context.Context, fn func() error, maxRetries int) error {
    for i := 0; i < maxRetries; i++ {
        if err := fn(); err == nil {
            return nil
        }
        
        select {
        case <-ctx.Done():
            return ctx.Err()
        case <-time.After(time.Duration(i+1) * time.Second):
            continue
        }
    }
    return fmt.Errorf("max retries exceeded")
}
```

## 📦 **IMPORT ORGANIZATION**

### **Import Standards:**
```go
// ✅ GOOD: Organized imports
import (
    // Standard library imports
    "context"
    "fmt"
    "time"
    
    // Third-party imports
    "github.com/sirupsen/logrus"
    "github.com/spf13/cobra"
    
    // Local imports
    "github.com/example/app/internal/config"
    "github.com/example/app/internal/observability"
)
```

## 🧪 **TESTING INTEGRATION**

### **Testable Code Patterns:**
```go
// ✅ GOOD: Dependency injection for testability
type Service struct {
    db     DatabaseClient
    logger Logger
}

func NewService(db DatabaseClient, logger Logger) *Service {
    return &Service{db: db, logger: logger}
}

// ✅ GOOD: Test with mocks
func TestService_ProcessData(t *testing.T) {
    mockDB := &MockDatabaseClient{}
    mockLogger := &MockLogger{}
    
    service := NewService(mockDB, mockLogger)
    
    err := service.ProcessData(context.Background(), []byte("test"))
    assert.NoError(t, err)
}
```

## 🚨 **MANDATORY COMPLETION CHECKLIST**

### **Before claiming work is complete:**
- [ ] **Code is formatted**: `gofmt -w .` has been run
- [ ] **Linting passes**: `golangci-lint run` shows no errors
- [ ] **Vet passes**: `go vet ./...` shows no errors
- [ ] **Dependencies cleaned**: `go mod tidy` has been run
- [ ] **All functions have proper error handling**
- [ ] **No errors are ignored** - all errors are explicitly handled or returned (NEVER use `_ =` to ignore errors)
- [ ] **State persistence errors are returned** - never silently ignored (prevents infinite loops and version conflicts)
- [ ] **All structs use validation tags where appropriate**
- [ ] **No code duplication exists**
- [ ] **Error handling is comprehensive** - no silent failures
- [ ] **Logging is structured and meaningful**
- [ ] **Documentation strings are present**
- [ ] **Tests pass**: `go test ./...` succeeds
- [ ] **DI compliance**: All services use dependency injection
- [ ] **No direct instantiation**: No `logrus.New()`, `database.NewClient()` outside DI
- [ ] **Interface usage**: All external dependencies use interfaces
- [ ] **Context usage**: All long-running operations use context.Context
- [ ] **Visibility compliance**: Only essential symbols are exported; use review-member-visibility skill to audit/fix
- [ ] **No internal details exported**: All internal structs, interfaces, and methods are private
- [ ] **Code review completed**: Systematic review performed using `.cursor/skills/review-code-staged/SKILL.md` checklist

## 🔍 **MANDATORY CODE REVIEW PROTOCOL**

### **CRITICAL: After ANY code generation, you MUST perform systematic code review:**

Before claiming completion, you MUST:

#### **1. Read Code Review Protocol**
- [ ] **Read `.cursor/skills/review-code-staged/SKILL.md`** - Review the complete checklist
- [ ] **Understand all review steps** - Know what to check for

#### **2. Execution Flow Tracing** ⚡
- [ ] **Entry Point Analysis**: Identify entry point(s), map call chain, verify architecture pattern
- [ ] **Data Flow Tracking**: Trace every variable - created, modified, consumed (or BUG!)
- [ ] **Function Call Verification**: Parameters match signatures, return values handled, context propagated
- [ ] **Control Flow Verification**: Code executes in expected order, error paths handled, resources cleaned

#### **3. Resource Management Review** 💾
- [ ] **HTTP Response Bodies**: All `resp.Body.Close()` deferred immediately after error check
- [ ] **Context Cancellation**: All `context.WithTimeout/WithCancel` have `defer cancel()`
- [ ] **Transactions**: All `tx.Begin()` have `defer tx.Rollback(ctx)`
- [ ] **Files/Resources**: All closeable resources use `defer close()`

#### **4. Error Handling Review** 🛡️
- [ ] **Error Wrapping**: All errors wrapped with `errors.NewDomainError()`, never raw errors
- [ ] **Error Handling**: No ignored errors (`_ =`), no logged-but-not-returned errors
- [ ] **State Persistence Errors**: All state persistence errors are returned, never silently ignored
- [ ] **Session Refresh Errors**: All session/context refresh errors are returned, never silently ignored
- [ ] **Resource Cleanup**: Resources cleaned up even on errors (defer statements)
- [ ] **No Silent Failures**: No errors are ignored that could cause state inconsistency or infinite loops

#### **5. Logic Verification** 🧠
- [ ] **Nil Safety**: Pointers checked for nil before dereferencing
- [ ] **Bounds Checking**: Array/slice bounds checked before indexing
- [ ] **Map Access**: Map existence checked before using value
- [ ] **Edge Cases**: Empty slices, nil pointers, zero values handled

#### **6. Performance Analysis** ⚡
- [ ] **Variable Usage**: Every variable created is actually used
- [ ] **Duplicate Fetches**: No data fetched twice when once would suffice
- [ ] **Large Structs**: Passed by pointer, not by value
- [ ] **Slice Pre-allocation**: Pre-allocate when size is known

#### **7. Architecture Compliance** 🏗️
- [ ] **Client isolation**: All external API calls through dedicated client packages (e.g. `internal/clients/<service>/`)
- [ ] **Service Layer**: Business logic in services, not CLI commands
- [ ] **Dependency Injection**: All dependencies injected, no direct instantiation
- [ ] **Domain Models**: Domain models in `internal/database/models.go`, DTOs with clients

#### **8. Report Findings**
- [ ] **List all issues found** (bugs, inefficiencies, improvements)
- [ ] **Fix critical issues** before claiming completion
- [ ] **Document non-critical issues** for future improvement

**Note**: Finding bugs during review is GOOD - it means you're thorough. Fix them before claiming completion.


## 🔍 **MANDATORY VERIFICATION PROTOCOL**

### **CRITICAL: Before claiming ANY task is complete, you MUST:**

#### **1. Deep Search Verification**
- [ ] **Perform comprehensive codebase search** to verify the task was actually completed
- [ ] **Search for all related patterns** to ensure nothing was missed
- [ ] **Verify no old implementations remain** that contradict the new changes
- [ ] **Confirm all references were updated** to use the new implementation
- [ ] **Check for any remaining dead code** or unused imports

#### **2. Dead Code Removal**
- [ ] **Identify and remove all dead code** left behind after refactoring
- [ ] **Remove unused imports** and dependencies
- [ ] **Delete obsolete files** that are no longer needed
- [ ] **Clean up service registry** references to removed services
- [ ] **Verify no broken references** remain in the codebase

#### **3. Build Verification**
- [ ] **Run `gofmt -w .`** to ensure code formatting is correct
- [ ] **Run `golangci-lint run`** to check for style issues
- [ ] **Run `go vet ./...`** to verify code quality
- [ ] **Run `go test ./...`** to ensure all tests pass
- [ ] **Run `go mod tidy`** to clean dependencies
- [ ] **Test the actual functionality** to ensure it works as expected

### **🔍 Deep Search Requirements:**

#### **For Refactoring Tasks:**
```bash
# Search for old patterns that should be replaced
grep -r "old_pattern" internal/
# Search for new patterns to verify implementation
grep -r "new_pattern" internal/
# Search for any remaining references to old code
grep -r "old_struct_name" internal/
```

#### **For Dead Code Detection:**
```bash
# Search for unused imports
grep -r "import.*unused_package" internal/
# Search for unused functions
grep -r "func.*unused_function" internal/
# Search for files that are imported but never used
find internal/ -name "*.go" -exec grep -l "import.*filename" {} \;
```

#### **For Build Verification:**
```bash
# Format and lint
gofmt -w . && golangci-lint run && go vet ./...
# Run tests
go test ./...
# Clean dependencies
go mod tidy
# Test functionality
go run ./cmd --help
```

### **🚨 ANTI-CHEATING PROTOCOLS**

> **Note**: For global code quality and anti-cheating rules that apply to all code, see `always-rules-2-quality.mdc`. This section focuses on verification protocols specific to Go code completion.

#### **What Constitutes Incomplete Work:**
- [ ] **Claiming completion without deep search verification**
- [ ] **Leaving dead code behind after refactoring**
- [ ] **Not building and testing the final result**
- [ ] **Missing references to old implementations**
- [ ] **Broken imports or dependencies**
- [ ] **Failing tests or build errors**

#### **Quality Gates:**
- [ ] **Zero dead code** - All obsolete code must be removed
- [ ] **Zero broken references** - All imports and dependencies must work
- [ ] **Zero build errors** - Application must build and run successfully
- [ ] **Zero test failures** - All tests must pass
- [ ] **Complete verification** - Deep search must confirm task completion

### **📋 Verification Checklist Template:**

```markdown
## ✅ TASK COMPLETION VERIFICATION

### **Deep Search Results:**
- [ ] Searched for old patterns: `grep -r "old_pattern" internal/` → No results found
- [ ] Searched for new patterns: `grep -r "new_pattern" internal/` → X results found
- [ ] Verified no old references: `grep -r "old_struct" internal/` → No results found
- [ ] Confirmed new implementation: `grep -r "new_struct" internal/` → X results found

### **Dead Code Removal:**
- [ ] Removed unused files: `deleted_file.go` (X lines)
- [ ] Removed unused imports: X imports cleaned up
- [ ] Removed unused functions: X functions removed
- [ ] Cleaned up references: X references updated

### **Build Verification:**
- [ ] `gofmt -w .` → ✅ Passed
- [ ] `golangci-lint run` → ✅ Passed  
- [ ] `go vet ./...` → ✅ Passed
- [ ] `go test ./...` → ✅ Passed
- [ ] `go mod tidy` → ✅ Passed
- [ ] `go run ./cmd --help` → ✅ Passed

### **Final Status:**
- [ ] **Task 100% complete** with full verification
- [ ] **No dead code remaining**
- [ ] **All builds and tests passing**
- [ ] **Functionality verified working**
```

## Code Organization Best Practices

### 1. Package Structure
```
internal/
├── cli/           # CLI commands and root logic
├── config/        # Configuration management
├── database/      # Database layer
├── observability/ # Logging, metrics, tracing
├── services/      # Business logic services
└── models/        # Data models and DTOs
```

### 2. Global Variables Pattern
- **Rule**: Use global variables for cross-cutting concerns only
- **Examples**: Logger, Config, Database connections
- **Implementation**: Declare in `root.go` or dedicated package
- **Naming**: Use PascalCase for exported globals

```go
// ✅ GOOD: Global variables for cross-cutting concerns
var (
    Logger *logrus.Logger
    Config *config.Config
    DBClient *database.Client
)
```

### 3. Initialization Flow
- **Rule**: Single point of initialization for global dependencies
- **Order**: Environment → Config → Logger → Database → Services
- **Error Handling**: Fail fast with clear error messages

```go
func initConfig() {
    // 1. Load environment variables
    if err := godotenv.Load(); err != nil {
        // Continue without .env file
    }

    // 2. Load configuration
    cfg, err := config.Load()
    if err != nil {
        Logger = observability.InitDefaultLogger()
        Logger.Warnf("Failed to load configuration: %v", err)
        Config = &config.Config{}
        return
    }

    // 3. Initialize logger with config
    Config = cfg
    Logger = observability.InitLoggerFromConfig(cfg.Logging, logLevel)
}
```

### 4. Command Structure
- **Rule**: Commands should be thin, focused on business logic
- **Dependencies**: Use global variables for cross-cutting concerns
- **Error Handling**: Delegate to centralized error handling

```go
// ✅ GOOD: Thin command function
func runServer(cmd *cobra.Command, args []string) {
    // Config already loaded in root.go
    cfg := Config

    Logger.WithFields(map[string]interface{}{
        "environment": cfg.App.Environment,
        "log_level":   logLevel,
    }).Info("Starting LinkedIn Content Generator")

    // Business logic here...
}
```

### 5. Import Organization
- **Rule**: Group imports by type with blank lines
- **Order**: Standard library → Third-party → Internal packages

```go
import (
    "context"
    "fmt"
    "os"

    "github.com/sirupsen/logrus"
    "github.com/spf13/cobra"

    "github.com/example/app/internal/config"
    "github.com/example/app/internal/observability"
)
```

## Error Handling Patterns

### 1. Centralized Error Handling
- **Rule**: Use consistent error handling patterns
- **Implementation**: Create error handling utilities

```go
// ✅ GOOD: Centralized error handling
func mustLoadConfig() *config.Config {
    cfg, err := config.Load()
    if err != nil {
        Logger.Fatalf("Failed to load configuration: %v", err)
    }
    return cfg
}
```

### 2. Logging Patterns
- **Rule**: Use structured logging consistently
- **Implementation**: Centralized logger with context

```go
// ✅ GOOD: Structured logging
Logger.WithFields(map[string]interface{}{
    "action":  action,
    "version": version,
}).Info("Starting database migration")
```

### 3. Log Level Conventions (MANDATORY)
- **Info** = **Application flow**: User-facing or operational milestones. Use for outcomes and high-level steps you want in normal logs (e.g. "Saying created successfully", "Processing X for next saying", "workflow completed", "Listing sayings", "Migrations applied", "Received shutdown signal").
- **Debug** = **Internal/diagnostic**: Wiring, per-request steps, internal state transitions. Use for anything that would clutter production logs or is only needed when troubleshooting (e.g. "Module setup: LLM set", "Processing saying for translation with streaming", "X version saved to database", refinement stopping reasons, research/search steps, human-review flow steps).
- **Rule**: At default (Info) level, logs should read as application flow; turn on Debug when you need implementation detail.

## Testing Best Practices

### 1. Test Organization
- **Rule**: Mirror package structure in tests
- **Naming**: Use descriptive test names

```go
func TestInitConfig_LoadsConfigSuccessfully(t *testing.T) {
    // Test implementation
}

func TestInitConfig_HandlesConfigLoadError(t *testing.T) {
    // Test implementation
}
```

### 2. Test Utilities
- **Rule**: Create test utilities for common patterns
- **Implementation**: Test helpers for setup/teardown

```go
func setupTestConfig(t *testing.T) *config.Config {
    // Test setup logic
}

func teardownTestConfig(t *testing.T) {
    // Test cleanup logic
}
```

## Performance Considerations

### 1. Lazy Initialization
- **Rule**: Initialize expensive resources only when needed
- **Implementation**: Use sync.Once for singleton patterns

```go
var (
    dbClient *database.Client
    dbOnce   sync.Once
)

func GetDBClient() *database.Client {
    dbOnce.Do(func() {
        dbClient = mustConnectDatabase(context.Background(), Config)
    })
    return dbClient
}
```

### 2. Resource Management
- **Rule**: Always close resources in defer statements
- **Implementation**: Use context for cancellation

```go
func runCommand(cmd *cobra.Command, args []string) {
    ctx, cancel := context.WithCancel(context.Background())
    defer cancel()

    dbClient := mustConnectDatabase(ctx, Config)
    defer dbClient.Close()
}
```

## Documentation Standards

### 1. Package Documentation
- **Rule**: Every package should have a package comment
- **Format**: Start with package name

```go
// Package cli provides command-line interface functionality
// for the LinkedIn Content Generator application.
package cli
```

### 2. Function Documentation
- **Rule**: Export functions should have documentation
- **Format**: Start with function name

```go
// InitLoggerFromConfig creates a logger from config with optional level override
func InitLoggerFromConfig(loggingConfig config.LoggingConfig, levelOverride string) *logrus.Logger {
    // Implementation
}
```

### 3. Comment Formatting (MANDATORY)
- **Rule**: **ALL comments MUST end with a period (`.`)**
- **Reference**: See [**CRITICAL: Comment Formatting (MANDATORY)**](#-critical-comment-formatting-mandatory) in Code Formatting Requirements (Line 506) for complete details, rationale, and examples.
- **Quick Summary**: The `godot` linter enforces this rule. Missing periods cause lint failures and waste time fixing trivial issues.

## Code Review Checklist

### Before Committing
- [ ] No duplicated initialization code
- [ ] Unused imports removed
- [ ] Global variables properly scoped
- [ ] Error handling consistent
- [ ] Logging structured and meaningful
- [ ] Tests cover new functionality
- [ ] Documentation updated

### Refactoring Guidelines
- [ ] Identify repeated patterns
- [ ] Extract common functionality
- [ ] Update all affected files
- [ ] Remove unused code
- [ ] Test thoroughly
- [ ] Update documentation

## Anti-Patterns to Avoid

### 1. Initialization Duplication
```go
// ❌ BAD: Each command loads config independently
func runServer() { config.Load() }
func runChat() { config.Load() }
func runProcess() { config.Load() }
```

### 2. Global Variable Abuse
```go
// ❌ BAD: Too many global variables
var (
    Logger *logrus.Logger
    Config *config.Config
    DBClient *database.Client
    HTTPClient *http.Client
    CacheClient *cache.Client
    // ... many more
)
```

### 3. Import Pollution
```go
// ❌ BAD: Unused imports
import (
    "fmt"           // unused
    "os"            // unused
    "strings"        // unused
    "github.com/joho/godotenv"  // unused
)
```

## Tools and Automation

### 1. Code Formatting
```bash
# Use goimports for import organization
goimports -w .

# Use gofmt for code formatting
gofmt -w .
```

### 2. Linting
```bash
# Use golangci-lint for comprehensive linting
golangci-lint run

# Use go vet for basic checks
go vet ./...
```

### 3. Testing
```bash
# Run tests with coverage
go test -cover ./...

# Run tests with race detection
go test -race ./...
```

## Summary

These rules ensure:
- **DRY compliance**: No code duplication
- **Clean architecture**: Proper separation of concerns
- **Maintainability**: Easy to modify and extend
- **Testability**: Clear interfaces and dependencies
- **Performance**: Efficient resource usage
- **Documentation**: Clear and comprehensive

Follow these patterns consistently across the codebase for a maintainable and scalable Go application.

## 🏗️ **SOLID PRINCIPLES**

### **1. Single Responsibility Principle (SRP)**

**Rule**: Each class/struct should have only one reason to change
**Go Implementation**: Each struct should have a single, well-defined purpose

```go
// ❌ BAD: Multiple responsibilities
type UserService struct {
    db *sql.DB
}

func (s *UserService) CreateUser(user *User) error { /* ... */ }
func (s *UserService) SendEmail(user *User, message string) error { /* ... */ }
func (s *UserService) GenerateReport(user *User) error { /* ... */ }

// ✅ GOOD: Single responsibility
type UserRepository struct {
    db *sql.DB
}

func (r *UserRepository) Create(user *User) error { /* ... */ }
func (r *UserRepository) GetByID(id string) (*User, error) { /* ... */ }

type EmailService struct {
    smtpClient *smtp.Client
}

func (s *EmailService) Send(user *User, message string) error { /* ... */ }

type ReportService struct {
    userRepo *UserRepository
}

func (s *ReportService) Generate(user *User) error { /* ... */ }
```

### **2. Open/Closed Principle (OCP)**

**Rule**: Software entities should be open for extension, closed for modification
**Go Implementation**: Use interfaces and composition for extensibility

```go
// ❌ BAD: Modifying existing code for new features
type PaymentProcessor struct {
    paymentType string
}

func (p *PaymentProcessor) Process(amount float64) error {
    switch p.paymentType {
    case "credit":
        return p.processCreditCard(amount)
    case "paypal":
        return p.processPayPal(amount)
    case "stripe": // Adding new payment method requires modification
        return p.processStripe(amount)
    }
    return fmt.Errorf("unsupported payment type")
}

// ✅ GOOD: Open for extension, closed for modification
type PaymentProcessor interface {
    Process(amount float64) error
}

type CreditCardProcessor struct{}
func (p *CreditCardProcessor) Process(amount float64) error { /* ... */ }

type PayPalProcessor struct{}
func (p *PayPalProcessor) Process(amount float64) error { /* ... */ }

type StripeProcessor struct{} // New processor without modifying existing code
func (p *StripeProcessor) Process(amount float64) error { /* ... */ }
```

### **3. Liskov Substitution Principle (LSP)**

**Rule**: Objects of a superclass should be replaceable with objects of a subclass
**Go Implementation**: Interface implementations must be fully substitutable

```go
// ❌ BAD: Violates LSP - Square changes Rectangle behavior
type Rectangle struct {
    Width, Height float64
}

func (r *Rectangle) SetWidth(w float64) {
    r.Width = w
}

func (r *Rectangle) SetHeight(h float64) {
    r.Height = h
}

type Square struct {
    Rectangle
}

func (s *Square) SetWidth(w float64) {
    s.Width = w
    s.Height = w // Violates Rectangle contract
}

// ✅ GOOD: Proper interface design
type Shape interface {
    Area() float64
    Perimeter() float64
}

type Rectangle struct {
    Width, Height float64
}

func (r Rectangle) Area() float64 {
    return r.Width * r.Height
}

func (r Rectangle) Perimeter() float64 {
    return 2 * (r.Width + r.Height)
}

type Square struct {
    Side float64
}

func (s Square) Area() float64 {
    return s.Side * s.Side
}

func (s Square) Perimeter() float64 {
    return 4 * s.Side
}
```

### **4. Interface Segregation Principle (ISP)**

**Rule**: Clients should not be forced to depend on interfaces they don't use
**Go Implementation**: Create focused, small interfaces instead of large ones

```go
// ❌ BAD: God Interface - violates ISP
type Repository interface {
    // Saying operations
    CreateSaying(ctx context.Context, saying *Saying) error
    GetSayingByID(ctx context.Context, id uuid.UUID) (*Saying, error)
    UpdateSaying(ctx context.Context, saying *Saying) error
    DeleteSaying(ctx context.Context, id uuid.UUID) error
    
    // Translation operations
    CreateTranslation(ctx context.Context, translation *Translation) error
    GetTranslationByID(ctx context.Context, id uuid.UUID) (*Translation, error)
    UpdateTranslation(ctx context.Context, translation *Translation) error
    DeleteTranslation(ctx context.Context, id uuid.UUID) error
    
    // Evaluation operations
    CreateEvaluation(ctx context.Context, evaluation *Evaluation) error
    GetEvaluationByID(ctx context.Context, id uuid.UUID) (*Evaluation, error)
    UpdateEvaluation(ctx context.Context, evaluation *Evaluation) error
    DeleteEvaluation(ctx context.Context, id uuid.UUID) error
    
    // 20+ more methods...
}

// ✅ GOOD: Segregated interfaces - clients only depend on what they need
type SayingRepository interface {
    Create(ctx context.Context, saying *Saying) error
    GetByID(ctx context.Context, id uuid.UUID) (*Saying, error)
    Update(ctx context.Context, saying *Saying) error
    Delete(ctx context.Context, id uuid.UUID) error
}

type TranslationRepository interface {
    Create(ctx context.Context, translation *Translation) error
    GetByID(ctx context.Context, id uuid.UUID) (*Translation, error)
    Update(ctx context.Context, translation *Translation) error
    Delete(ctx context.Context, id uuid.UUID) error
}

type EvaluationRepository interface {
    Create(ctx context.Context, evaluation *Evaluation) error
    GetByID(ctx context.Context, id uuid.UUID) (*Evaluation, error)
    Update(ctx context.Context, evaluation *Evaluation) error
    Delete(ctx context.Context, id uuid.UUID) error
}

// Services only depend on what they actually use
type TranslationService struct {
    sayings      SayingRepository      // Only saying operations
    translations TranslationRepository // Only translation operations
}
```

### **5. Dependency Inversion Principle (DIP)**

**Rule**: Depend on abstractions, not concretions
**Go Implementation**: Use interfaces for dependencies, inject them via constructors

```go
// ❌ BAD: Depends on concrete implementations
type UserService struct {
    db     *sql.DB
    logger *logrus.Logger
    cache  *redis.Client
}

func NewUserService() *UserService {
    return &UserService{
        db:     sql.Open("postgres", "..."), // Hard-coded dependency
        logger: logrus.New(),                // Hard-coded dependency
        cache:  redis.NewClient(...),        // Hard-coded dependency
    }
}

// ✅ GOOD: Depends on abstractions
type DatabaseClient interface {
    Query(ctx context.Context, sql string, args ...interface{}) ([]Row, error)
    Exec(ctx context.Context, sql string, args ...interface{}) error
}

type Logger interface {
    Info(msg string, fields ...Field)
    Error(msg string, fields ...Field)
}

type Cache interface {
    Get(key string) (string, bool)
    Set(key string, value string) error
}

type UserService struct {
    db     DatabaseClient
    logger Logger
    cache  Cache
}

func NewUserService(db DatabaseClient, logger Logger, cache Cache) *UserService {
    return &UserService{
        db:     db,     // Injected dependency
        logger: logger, // Injected dependency
        cache:  cache,  // Injected dependency
    }
}
```

### **SOLID Principles Anti-Patterns to Avoid**

#### **God Interface Anti-Pattern**
```go
// ❌ BAD: One interface doing everything
type Repository interface {
    // 25+ methods covering all entities
    CreateSaying(...)
    GetSayingByID(...)
    UpdateSaying(...)
    DeleteSaying(...)
    CreateTranslation(...)
    GetTranslationByID(...)
    // ... 20+ more methods
}

// ✅ GOOD: Focused interfaces
type SayingRepository interface {
    Create(ctx context.Context, saying *Saying) error
    GetByID(ctx context.Context, id uuid.UUID) (*Saying, error)
    Update(ctx context.Context, saying *Saying) error
    Delete(ctx context.Context, id uuid.UUID) error
}
```

#### **Fat Service Anti-Pattern**
```go
// ❌ BAD: Service doing too much
type UserService struct {
    db *sql.DB
}

func (s *UserService) CreateUser(user *User) error { /* ... */ }
func (s *UserService) SendWelcomeEmail(user *User) error { /* ... */ }
func (s *UserService) GenerateUserReport(user *User) error { /* ... */ }
func (s *UserService) ProcessPayment(user *User, amount float64) error { /* ... */ }

// ✅ GOOD: Single responsibility services
type UserService struct {
    repo UserRepository
}

func (s *UserService) CreateUser(user *User) error { /* ... */ }

type EmailService struct {
    smtp SMTPClient
}

func (s *EmailService) SendWelcomeEmail(user *User) error { /* ... */ }

type ReportService struct {
    userRepo UserRepository
}

func (s *ReportService) GenerateUserReport(user *User) error { /* ... */ }
```

### **SOLID Principles Checklist**

Before committing code, verify:
- [ ] **SRP**: Each struct has a single, well-defined responsibility
- [ ] **OCP**: New features added through extension, not modification
- [ ] **LSP**: Interface implementations are fully substitutable
- [ ] **ISP**: Interfaces are focused and small (5-6 methods max)
- [ ] **DIP**: Dependencies are injected via interfaces, not concrete types
- [ ] **No God Interfaces**: No single interface with 10+ methods
- [ ] **No Fat Services**: Services have single, clear responsibility
- [ ] **Interface Segregation**: Clients only depend on what they use
