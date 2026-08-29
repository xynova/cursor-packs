---
name: review-code-smells
description: >-
  Systematic code-smell and maintainability review for Go (duplication, complexity,
  style, resource management, tooling). Use when the user asks to find code smells,
  technical debt, maintainability issues, or run a smells review.
disable-model-invocation: true
---

# Review code smells

Explicit-invocation review protocol (former slash command). Ask for the **target** (path, package, or current changes) before starting.

**Related:** `.cursor/skills/review-code-staged/SKILL.md` (staged quality), `.cursor/skills/golang-quality/SKILL.md`, `.cursor/skills/review-member-visibility/SKILL.md`. Project architecture review (if present): `pipelines-x-review-architecture` or equivalent overlay.

---


> **For AI (Cursor)**: Use this protocol to systematically identify code smells, technical debt, and maintainability issues in the codebase.

## 🎯 **PRIMARY GOAL: Improve Code Quality and Maintainability**

**Reward System**: Identifying code smells is crucial for long-term project health. You are helping to prevent future bugs and make the code easier to understand and modify.

---

## 📑 **TABLE OF CONTENTS**

### **Main Analysis Steps**
- [**STEP 1: Duplication Analysis**](#step-1-duplication-analysis)
- [**STEP 2: Complexity Analysis**](#step-2-complexity-analysis)
- [**STEP 3: Maintainability Review**](#step-3-maintainability-review)
- [**STEP 4: Code Style & Conventions**](#step-4-code-style--conventions)
- [**STEP 5: Go-Specific Patterns**](#step-5-go-specific-patterns)
- [**STEP 6: Architecture Violations**](#step-6-architecture-violations)
- [**STEP 7: Resource Management**](#step-7-resource-management)
- [**STEP 8: Tooling Integration**](#step-8-tooling-integration)

### **Additional Sections**
- [**Prioritization Guide**](#prioritization-guide)
- [**Report Format**](#report-format)
- [**Quick Reference Checklist**](#quick-reference-checklist)

---

## ✅ **MANDATORY ANALYSIS STEPS**

### **STEP 1: Duplication Analysis** 👯

**Objective**: Identify repeated code blocks that should be refactored.

- [ ] **Copy-Paste Coding**: Look for blocks of code that are identical or nearly identical across different functions or files.
- [ ] **Structural Duplication**: Identify similar logic structures (e.g., initialization sequences, error handling patterns) that differ only by variable names or types.
- [ ] **Magic Strings/Numbers**: Check for repeated string literals or numeric constants that should be defined as constants.
- [ ] **Data Clumps**: Groups of data that always travel together (e.g., `(x, y)` coordinates, `(host, port)` pairs) should be extracted into structs.

**Example (Go)**:
```go
// BAD: Repeated initialization logic
func initA() {
    if config == nil { return error }
    setup(config)
    // ... 10 lines of setup
}

func initB() {
    if config == nil { return error }
    setup(config)
    // ... same 10 lines of setup
}

// GOOD: Shared helper function
func initCommon(cfg *Config) {
    if cfg == nil { return error }
    setup(cfg)
    // ...
}

// BAD: Data clump
func connect(host string, port int, timeout time.Duration) { /* ... */ }
func disconnect(host string, port int) { /* ... */ }

// GOOD: Extract to struct
type ConnectionConfig struct {
    Host    string
    Port    int
    Timeout time.Duration
}
```

### **STEP 2: Complexity Analysis** 🤯

**Objective**: Find code that is difficult to understand or test.

- [ ] **Long Functions**: Identify functions longer than 50-100 lines. Can they be broken down?
- [ ] **Deep Nesting**: Look for excessive indentation (e.g., more than 3-4 levels). Can early returns or extraction help?
- [ ] **Cyclomatic Complexity**: Check for functions with too many branches (`if`, `for`, `switch`). Aim for complexity < 10.
- [ ] **Mixed Responsibilities**: Does a single function or struct do too many unrelated things? (Single Responsibility Principle violation).
- [ ] **Long Parameter Lists**: Functions with more than 4-5 parameters should use structs or options pattern.
- [ ] **Feature Envy**: Methods that use more of another object than their own (indicates misplaced logic).

**Example (Go)**:
```go
// BAD: Deep nesting
func process() {
    if a {
        if b {
            for c := range items {
                if c.isValid() {
                    // ... logic
                }
            }
        }
    }
}

// GOOD: Early returns and extraction
func process() {
    if !a || !b {
        return
    }
    for c := range items {
        processItem(c)
    }
}

// BAD: Long parameter list
func createUser(name, email, phone, address, city, country string, age int) error { /* ... */ }

// GOOD: Use struct
type UserData struct {
    Name    string
    Email   string
    Phone   string
    Address string
    City    string
    Country string
    Age     int
}
func createUser(data UserData) error { /* ... */ }
```

### **STEP 3: Maintainability Review** 🛠️

**Objective**: Ensure the code is easy to change and extend.

- [ ] **Hardcoded Values**: Are configuration values (URLs, timeouts, limits) hardcoded instead of using config files or constants?
- [ ] **Tight Coupling**: Are components overly dependent on concrete implementations rather than interfaces?
- [ ] **God Objects/Interfaces**: Are there structs or interfaces with too many methods or fields? (Aim for < 10 methods per interface)
- [ ] **Dead Code**: Is there commented-out code or unused functions/variables?
- [ ] **TODOs**: Are there `TODO` or `FIXME` comments that have been ignored for a long time?
- [ ] **Speculative Generality**: Code written for future use that never comes (YAGNI violation).
- [ ] **Inappropriate Intimacy**: Packages/structs that know too much about each other's internals.
- [ ] **Primitive Obsession**: Using primitives (string, int) instead of small objects for domain concepts.

**Example (Go)**:
```go
// BAD: Primitive obsession
func validateEmail(email string) bool { /* ... */ }
func sendEmail(to string, subject string, body string) error { /* ... */ }

// GOOD: Domain types
type Email string
func (e Email) Validate() bool { /* ... */ }
func sendEmail(to Email, subject string, body string) error { /* ... */ }

// BAD: God interface
type Service interface {
    CreateUser() error
    UpdateUser() error
    DeleteUser() error
    GetUser() error
    ListUsers() error
    CreateOrder() error
    UpdateOrder() error
    DeleteOrder() error
    GetOrder() error
    ListOrders() error
    // ... 20 more methods
}

// GOOD: Segregated interfaces
type UserService interface {
    CreateUser() error
    UpdateUser() error
    DeleteUser() error
    GetUser() error
    ListUsers() error
}
type OrderService interface {
    CreateOrder() error
    UpdateOrder() error
    DeleteOrder() error
    GetOrder() error
    ListOrders() error
}
```

### **STEP 4: Code Style & Conventions** 🎨

**Objective**: Verify adherence to Go idioms and project standards.

- [ ] **Error Handling**: Is error handling consistent? Are errors wrapped with context using `fmt.Errorf("%w", err)`?
- [ ] **Naming**: Do variable and function names clearly convey intent? Are they consistent with Go conventions?
- [ ] **Comments**: Are complex logic sections explained? Are public APIs documented? Do comments explain "why" not "what"?
- [ ] **Project Structure**: Does the code follow the project's directory structure and architecture patterns?
- [ ] **Package Naming**: Are packages named with singular nouns? No generic names like `common`, `utils`, `shared`.
- [ ] **Export Rules**: Are only essential symbols exported? No internal implementation details exposed.

**Example (Go)**:
```go
// BAD: Comment explains "what" (obvious from code)
// Loop through items and process them
for _, item := range items {
    process(item)
}

// GOOD: Comment explains "why"
// Process items in reverse order to maintain dependency order
for i := len(items) - 1; i >= 0; i-- {
    process(items[i])
}

// BAD: Generic package name
package utils

// GOOD: Specific package name
package validation
```

### **STEP 5: Go-Specific Patterns** 🐹

**Objective**: Identify Go-specific code smells and anti-patterns.

- [ ] **Missing context.Context**: Functions that perform I/O or long-running operations should accept `context.Context` as first parameter.
- [ ] **Panic Usage**: Are panics used for error handling instead of returning errors? (Panics should only be for unrecoverable errors)
- [ ] **Interface Pollution**: Too many small interfaces that aren't actually needed (prefer concrete types when interfaces aren't necessary).
- [ ] **Package-Level State**: Global variables or package-level state that makes testing difficult.
- [ ] **Improper Goroutine Usage**: Goroutines without proper cancellation, error handling, or cleanup.
- [ ] **Channel Misuse**: Unbuffered channels when buffered are needed, or vice versa. Missing channel cleanup.
- [ ] **Missing Defer**: Resource cleanup (file closes, mutex unlocks) not using `defer`.
- [ ] **Variable Shadowing with Named Returns**: When using named return values `(err error)` with `defer`, ensure error assignments use `err =` not `err :=` to avoid shadowing the named return. This is critical for defer functions that need to see the final error value (e.g., `defer observability.EndSpanWithStatus(otelSpan, err)`).
- [ ] **Slice/Map Bounds**: Direct indexing without bounds checking.

**Example (Go)**:
```go
// BAD: Missing context
func fetchData(url string) ([]byte, error) { /* ... */ }

// GOOD: Context-aware
func fetchData(ctx context.Context, url string) ([]byte, error) { /* ... */ }

// BAD: Panic for error handling
func divide(a, b int) int {
    if b == 0 {
        panic("division by zero")
    }
    return a / b
}

// GOOD: Return error
func divide(a, b int) (int, error) {
    if b == 0 {
        return 0, fmt.Errorf("division by zero")
    }
    return a / b, nil
}

// BAD: Missing defer
func processFile(filename string) error {
    f, err := os.Open(filename)
    if err != nil {
        return err
    }
    // ... use file ...
    f.Close() // What if there's an error before this?
    return nil
}

// GOOD: Use defer
func processFile(filename string) error {
    f, err := os.Open(filename)
    if err != nil {
        return err
    }
    defer f.Close() // Always closes, even on error
    // ... use file ...
    return nil
}

// BAD: Variable shadowing with named return
func processCommand(cmd *cobra.Command, args []string) (err error) {
    defer observability.EndSpanWithStatus(otelSpan, err) // Will see nil, not the actual error!
    
    // ❌ WRONG: Creates new local 'err' that shadows named return
    if err := service.Process(ctx); err != nil {
        return fmt.Errorf("failed: %w", err)
    }
    return nil
}

// GOOD: Assign to named return value
func processCommand(cmd *cobra.Command, args []string) (err error) {
    defer observability.EndSpanWithStatus(otelSpan, err) // Will see the actual error
    
    // ✅ CORRECT: Assigns to named return 'err'
    if err = service.Process(ctx); err != nil {
        return fmt.Errorf("failed: %w", err)
    }
    return nil
}

// BAD: Variable shadowing with multiple assignments
func parseAndProcess(sayingID string) (err error) {
    defer observability.EndSpanWithStatus(otelSpan, err)
    
    // ❌ WRONG: Creates new local 'err' that shadows named return
    id, err := uuid.Parse(sayingID)
    if err != nil {
        return fmt.Errorf("invalid ID: %w", err)
    }
    
    // ❌ WRONG: Also shadows named return
    if err := service.Process(id); err != nil {
        return fmt.Errorf("failed: %w", err)
    }
    return nil
}

// GOOD: Explicit variable declaration, then assignment
func parseAndProcess(sayingID string) (err error) {
    defer observability.EndSpanWithStatus(otelSpan, err)
    
    // ✅ CORRECT: Declare id separately, assign to named return
    var id uuid.UUID
    id, err = uuid.Parse(sayingID)
    if err != nil {
        return fmt.Errorf("invalid ID: %w", err)
    }
    
    // ✅ CORRECT: Assign to named return
    if err = service.Process(id); err != nil {
        return fmt.Errorf("failed: %w", err)
    }
    return nil
}

// BAD: No bounds check
func getFirst(items []Item) Item {
    return items[0] // Panic if empty
}

// GOOD: Bounds check
func getFirst(items []Item) (Item, error) {
    if len(items) == 0 {
        return Item{}, fmt.Errorf("items cannot be empty")
    }
    return items[0], nil
}
```

### **STEP 6: Architecture Violations** 🏗️

**Objective**: Check for violations of project-specific architectural rules.

- [ ] **Shared vs Pipeline Dependency (No Nested Imports)**: Do top-level shared packages (`internal/dspy/`, `internal/evaluation/`) import pipeline packages (`internal/pipelines/*`)? (CRITICAL: Shared code must NOT import nested pipeline code; pipelines depend on shared code and inject behavior. See architecture review §1.4.)
- [ ] **Direct DSPy Module Access**: Are services directly accessing `*dspy.ModuleRegistry` or calling `module.Process()` instead of using `GeneratorClient`/`EvaluationClient`?
- [ ] **Business Logic in CLI**: Is complex business logic embedded in CLI command handlers instead of services?
- [ ] **Direct Service Instantiation**: Are services/clients instantiated directly instead of using DI container?
- [ ] **Wrong Layer Dependencies**: Do CLI commands depend on repositories directly? (Should depend on services)
- [ ] **Missing Interfaces**: Are services using concrete types instead of interfaces for dependencies?
- [ ] **Domain Model Confusion**: Are infrastructure DTOs mixed with domain models (Saying, Translation, Evaluation)?
- [ ] **Logging Violations**: Are `fmt.Println()`, `fmt.Printf()`, or direct `logrus` calls used instead of `internal/observability/Logger`?
- [ ] **Configuration Violations**: Are config values hardcoded instead of using `internal/config/`?
- [ ] **Error Handling Violations**: Are errors returned without wrapping or domain-specific error types?
- [ ] **Visibility Violations**: Are internal implementation details (structs, methods) exported unnecessarily?
- [ ] **Leaky Abstractions**: Are services aware of DSPy-specific types (`*modules.Predict`, `map[string]interface{}` inputs) instead of domain types?
- [ ] **Fallback Logic for Database Queries**: Is there fallback logic for database queries within transactions? (CRITICAL: Must fail fast and rollback)
- [ ] **Fallback Logic for Structured Output Parsing**: Is there fallback logic to manually parse XML or check nested response fields when XML interceptors are enabled? (CRITICAL: Must fail fast, fields should be at top level)
- [ ] **LLM Calls Inside Transactions**: Are LLM calls or external API calls made inside database transactions? (CRITICAL: Causes blocking and performance issues)

**Example (Go)**:
```go
// BAD: Direct DSPy module access in service
func (s *Service) GenerateTranslation(ctx context.Context, text string) error {
    module, err := s.dspyRegistry.GetGeneratorModule("translation") // ❌ Wrong - exposes DSPy internals
    outputs, err := module.Process(ctx, map[string]interface{}{"text": text}) // ❌ Wrong layer
    // ...
}

// GOOD: Use DSPy client
func (s *Service) GenerateTranslation(ctx context.Context, input TranslationInput) error {
    output, err := s.generatorClient.GenerateTranslation(ctx, input) // ✅ Correct layer
    // ...
}

// BAD: Business logic in CLI
func (c *Command) Run(cmd *cobra.Command, args []string) {
    // ❌ Complex business logic here
    sayings := fetchSayings()
    for _, saying := range sayings {
        // ... complex processing ...
    }
}

// GOOD: Thin CLI wrapper
func (c *Command) RunE(cmd *cobra.Command, args []string) error {
    return c.service.ProcessNextSaying(cmd.Context()) // ✅ Delegate to service
}

// BAD: Direct instantiation
func NewService() *Service {
    registry := dspy.NewModuleRegistry(...) // ❌ Bypasses DI
    return &Service{registry: registry}
}

// GOOD: Dependency injection
func NewService(
    generatorClient *dspyClient.GeneratorClient,
    evaluationClient *dspyClient.EvaluationClient,
    logger *observability.Logger,
) ServiceInterface {
    return &Service{
        generatorClient: generatorClient,
        evaluationClient: evaluationClient,
        logger: logger,
    } // ✅ Injected
}

// BAD: Wrong logging
func process() {
    fmt.Println("Processing...") // ❌ Wrong
    logrus.Info("Processing...") // ❌ Wrong
}

// GOOD: Use project logger
func (s *Service) process() {
    s.logger.Info("Processing...") // ✅ Correct
}

// BAD: Leaky abstraction - service knows about DSPy internals
func (s *Service) evaluate(ctx context.Context, content string) error {
    workflow, _ := s.dspyRegistry.GetTranslationWorkflow() // ❌ Direct DSPy access
    result, err := workflow.Evaluate(ctx, content, map[string]interface{}{...}) // ❌ DSPy-specific
    // ...
}

// GOOD: Domain-oriented abstraction
func (s *Service) evaluate(ctx context.Context, content string, evalContext EvaluationContext) error {
    result, err := s.evaluationClient.EvaluateTranslation(ctx, content, evalContext) // ✅ Domain types
    // ...
}

// BAD: Fallback logic for database queries within transactions
func (s *Service) ProcessSaying(ctx context.Context, sayingID uuid.UUID) error {
    return s.transactionManager.WithTransaction(ctx, func(tx database.Transaction) error {
        // ❌ WRONG: Fallback logic hides errors and causes data inconsistency
        evaluations, err := tx.GetEvaluationsByContentID(ctx, contentID)
        if err == nil && len(evaluations) > 0 {
            // Use evaluations
        }
        // ❌ Problem: If query fails, we continue with incomplete data
        // ❌ Problem: Transaction state may be corrupted
        return nil
    })
}

// GOOD: Fail fast on database query errors
func (s *Service) ProcessSaying(ctx context.Context, sayingID uuid.UUID) error {
    return s.transactionManager.WithTransaction(ctx, func(tx database.Transaction) error {
        // ✅ CORRECT: Return error immediately, transaction will rollback
        evaluations, err := tx.GetEvaluationsByContentID(ctx, contentID)
        if err != nil {
            return errors.NewDomainError(errors.ErrEvaluationQueryFailed, "Failed to query evaluations", err)
        }
        // Use evaluations
        return nil
    })
}

// BAD: Fallback logic for structured output parsing
func extractStringField(outputs map[string]interface{}, fieldName string) (string, bool) {
    // Try top-level first
    if value, ok := outputs[fieldName]; ok {
        return value.(string), true
    }
    // ❌ WRONG: Fallback to check nested response fields
    if responseField, hasResponse := outputs["response"]; hasResponse {
        if responseMap, isMap := responseField.(map[string]interface{}); isMap {
            if nestedValue, hasNestedField := responseMap[fieldName]; hasNestedField {
                // ❌ WRONG: Fallback logic hides configuration issues
                return nestedValue.(string), true
            }
        }
    }
    return "", false
}

// GOOD: Fail fast - expect fields at top level when XML interceptors are enabled
func extractStringField(outputs map[string]interface{}, fieldName string) (string, bool) {
    // ✅ CORRECT: Expect fields at top level when XML interceptors are enabled
    if value, ok := outputs[fieldName]; ok {
        if str, isString := value.(string); isString && str != "" {
            return str, true
        }
    }
    // ✅ Fail fast if field is missing - don't try alternatives
    return "", false
}

// BAD: LLM calls inside database transactions - CRITICAL PERFORMANCE ISSUE
func (s *HumanReviewService) ReviewHumanAlignment(ctx context.Context, evaluationID uuid.UUID, humanAgrees bool) error {
    return s.transactionManager.WithTransaction(ctx, func(db database.Transaction) error {
        evaluation, err := s.reviewRepo.GetByID(ctx, db, evaluationID)
        if err != nil {
            return err
        }
        
        // Update human alignment
        evaluation.HumanAlignmentAgrees = &humanAgrees
        
        // ❌ WRONG: LLM calls inside transaction - blocks database connection
        // Each LLM call can take 2-5 seconds, and we're doing this for multiple criteria!
        criterionDescriptions := GetCriterionDescriptions(getCriterionIDsFromEvaluation(evaluation))
        for i := range evaluation.CriterionEvaluations {
            if err := s.ProposeCriterionScoreWithAlignment(
                ctx,
                evaluation.PipelineHistory,
                criterionDescriptions[i],
                &evaluation.CriterionEvaluations[i],
                humanAgrees,
                humanComment,
            ); err != nil {
                return err
            }
            // ❌ Problem: Database connection held during each slow LLM API call
            // ❌ Problem: If there are 5 criteria, connection held for 10-25 seconds total!
            // ❌ Problem: Blocks other operations from using that connection
            // ❌ Problem: Can cause connection pool exhaustion under load
        }
        
        return s.reviewRepo.Update(ctx, db, evaluation)
    })
}

// GOOD: LLM calls outside transaction, only DB write in transaction
func (s *HumanReviewService) ReviewHumanAlignment(ctx context.Context, evaluationID uuid.UUID, humanAgrees bool) error {
    // Read evaluation outside transaction (uses connection pool, fast)
    evaluation, err := s.reviewRepo.GetByID(ctx, nil, evaluationID)
    if err != nil {
        return err
    }
    
    // Update human alignment (in memory)
    evaluation.HumanAlignmentAgrees = &humanAgrees
    
    // ✅ CORRECT: Do LLM calls OUTSIDE transaction (can take seconds, doesn't block DB)
    criterionDescriptions := GetCriterionDescriptions(getCriterionIDsFromEvaluation(evaluation))
    for i := range evaluation.CriterionEvaluations {
        if err := s.ProposeCriterionScoreWithAlignment(
            ctx,
            evaluation.PipelineHistory,
            criterionDescriptions[i],
            &evaluation.CriterionEvaluations[i],
            humanAgrees,
            humanComment,
        ); err != nil {
            return err
        }
        // ✅ LLM calls happen outside transaction - doesn't block database
    }
    
    // ✅ CORRECT: Only wrap DB write in transaction (fast operation, minimal blocking)
    return s.transactionManager.WithTransaction(ctx, func(db database.Transaction) error {
        // Re-read to prevent race conditions
        currentEvaluation, err := s.reviewRepo.GetByID(ctx, db, evaluationID)
        if err != nil {
            return err
        }
        // Apply updates and save
        currentEvaluation.HumanAlignmentAgrees = evaluation.HumanAlignmentAgrees
        currentEvaluation.CriterionEvaluations = evaluation.CriterionEvaluations
        return s.reviewRepo.Update(ctx, db, currentEvaluation)
    })
}
    // ✅ CORRECT: Fail fast if field is missing - don't try alternatives
    return "", false
}
```

### **STEP 7: Resource Management** 💾

**Objective**: Identify resource leaks and improper resource handling.

- [ ] **File Handles**: Are files opened but not closed? Use `defer file.Close()`.
- [ ] **Database Connections**: Are database connections properly closed? Are connection pools configured correctly?
- [ ] **HTTP Clients**: Are HTTP clients reused? Are timeouts configured?
- [ ] **Goroutine Leaks**: Are goroutines started without proper cancellation or cleanup?
- [ ] **Context Cancellation**: Are long-running operations respecting context cancellation?
- [ ] **Memory Leaks**: Are large data structures held in memory unnecessarily?
- [ ] **Mutex Locks**: Are mutexes properly unlocked? Use `defer mu.Unlock()`.

**Example (Go)**:
```go
// BAD: Goroutine leak
func processItems(items []Item) {
    for _, item := range items {
        go func(i Item) {
            process(i) // No way to cancel or wait
        }(item)
    }
}

// GOOD: Proper goroutine management
func processItems(ctx context.Context, items []Item) error {
    var wg sync.WaitGroup
    errCh := make(chan error, len(items))
    
    for _, item := range items {
        wg.Add(1)
        go func(i Item) {
            defer wg.Done()
            if err := process(ctx, i); err != nil {
                errCh <- err
            }
        }(item)
    }
    
    wg.Wait()
    close(errCh)
    // Check for errors...
    return nil
}

// BAD: Missing context cancellation
func longRunningOperation() error {
    for {
        // No way to cancel
        doWork()
    }
}

// GOOD: Context-aware
func longRunningOperation(ctx context.Context) error {
    for {
        select {
        case <-ctx.Done():
            return ctx.Err()
        default:
            doWork()
        }
    }
}
```

### **STEP 8: Tooling Integration** 🔧

**Objective**: Leverage automated tools to detect code smells.

**Run these commands and review their output:**

- [ ] **golangci-lint**: Run `make lint` or `golangci-lint run` to detect common issues
- [ ] **go vet**: Run `go vet ./...` for static analysis
- [ ] **go fmt**: Run `gofmt -d .` to check formatting issues
- [ ] **unused**: Check for unused code with `golangci-lint run --enable=unused`
- [ ] **gocyclo**: Check cyclomatic complexity (if available)
- [ ] **dupl**: Check for code duplication (if available)

**Common golangci-lint checks to review:**
- `errcheck`: Unchecked errors
- `gosec`: Security issues
- `goconst`: Repeated strings that should be constants
- `gocritic`: Performance and style issues
- `govet`: Go vet checks
- `ineffassign`: Ineffective assignments
- `staticcheck`: Static analysis checks
- `unused`: Unused code
- `varcheck`: Unused variables

**Example**:
```bash
# Run comprehensive linting
make lint

# Check for specific issues
golangci-lint run --enable=errcheck,unused,goconst

# Check formatting
gofmt -d .
```

---

## 📊 **PRIORITIZATION GUIDE**

When multiple code smells are found, prioritize fixes using this order:

### **🔴 High Priority (Fix Immediately)**
1. **Architecture Violations**: Direct DSPy module access, business logic in wrong layers, leaky abstractions
2. **Fallback Logic Violations**: Fallback logic for database queries in transactions, fallback logic for structured output parsing (CRITICAL: Must fail fast)
3. **Resource Leaks**: File handles, goroutines, database connections
4. **Security Issues**: Unchecked errors, missing validation, injection risks
5. **Critical Bugs**: Panic risks, nil pointer dereferences, data races

### **🟡 Medium Priority (Fix Soon)**
1. **Complexity Issues**: Long functions, deep nesting, high cyclomatic complexity
2. **Duplication**: Copy-paste code that's actively maintained
3. **Error Handling**: Missing error wrapping, inconsistent error patterns
4. **Go-Specific Issues**: Missing context, improper panic usage, variable shadowing with named returns (can cause incorrect span status in observability)

### **🟢 Low Priority (Fix When Convenient)**
1. **Code Style**: Naming inconsistencies, missing comments
2. **Dead Code**: Unused functions, commented code
3. **TODOs**: Old TODO comments
4. **Minor Duplication**: Small repeated patterns that aren't causing issues

---

## 📋 **REPORT FORMAT**

When reporting code smells, use the following format:

```markdown
## [Category] Description
**Location**: `file/path:line_number`
**Severity**: High/Medium/Low
**Priority**: 🔴 High / 🟡 Medium / 🟢 Low

[Description of the issue]

**Current Code**:
```startLine:endLine:file/path
// problematic code here
```

**Recommendation**:
```go
// improved code here
```

**Rationale**: [Why this change improves the code]

**Related Issues**: [Link to other related smells or architectural violations]
```

**Example Report**:
```markdown
## [Architecture Violation] Direct DSPy Module Access in Service Layer
**Location**: `internal/services/translation/service.go:295`
**Severity**: High
**Priority**: 🔴 High

The service is directly accessing DSPy's ModuleRegistry and calling module.Process() instead of using the GeneratorClient. This violates the architectural principle of client isolation and creates leaky abstractions.

**Current Code**:
```295:312:internal/services/translation/service.go
func (s *Service) generateTranslation(ctx context.Context, text string) error {
    module, err := s.dspyRegistry.GetGeneratorModule("translation")
    if err != nil {
        return err
    }
    outputs, err := module.Process(ctx, map[string]interface{}{
        "original_text": text,
    })
    translation := outputs["translation"].(string)
    // ...
}
```

**Recommendation**:
```go
func (s *Service) generateTranslation(ctx context.Context, input TranslationInput) error {
    output, err := s.generatorClient.GenerateTranslation(ctx, dspyClient.TranslationInput{
        OriginalText:     input.OriginalText,
        PreviousFeedback: input.PreviousFeedback,
        Version:         input.Version,
    })
    if err != nil {
        return err
    }
    // Use output.LiteralTranslation and output.SemanticTranslation
    // ...
}
```

**Rationale**: All DSPy interactions must go through `internal/clients/dspy/` clients (GeneratorClient, EvaluationClient) to maintain proper separation of concerns, enable testing, and hide DSPy implementation details from services.

**Related Issues**: See architecture rules Section 6.1 (Direct API Interaction) and leaky abstractions documentation.
```

---

## ✅ **QUICK REFERENCE CHECKLIST**

Use this checklist when reviewing code:

### **Duplication**
- [ ] No identical code blocks across files
- [ ] No structural duplication (similar patterns)
- [ ] No magic strings/numbers (use constants)
- [ ] No data clumps (extract to structs)

### **Complexity**
- [ ] Functions < 100 lines
- [ ] Nesting depth < 4 levels
- [ ] Cyclomatic complexity < 10
- [ ] Single responsibility per function/struct
- [ ] Parameter lists < 5 parameters

### **Maintainability**
- [ ] No hardcoded configuration values
- [ ] Dependencies on interfaces, not concretions
- [ ] No god objects/interfaces (> 10 methods)
- [ ] No dead code or long-ignored TODOs
- [ ] No speculative generality

### **Go-Specific**
- [ ] I/O functions accept `context.Context`
- [ ] No panics for error handling
- [ ] No interface pollution
- [ ] No package-level state
- [ ] Proper goroutine/channel usage
- [ ] Resource cleanup with `defer`
- [ ] No variable shadowing with named returns (use `err =` not `err :=` when defer needs to see error)
- [ ] Bounds checking for slices/maps

### **Architecture**
- [ ] No direct DSPy module access (use GeneratorClient/EvaluationClient)
- [ ] No business logic in CLI commands
- [ ] No direct service instantiation (use DI)
- [ ] Correct layer dependencies
- [ ] Domain models separate from DTOs
- [ ] Using `internal/observability/Logger` (not fmt/logrus)
- [ ] Using `internal/config/` for configuration
- [ ] Proper error wrapping
- [ ] Minimal exports (only public API)
- [ ] No leaky abstractions (services don't know DSPy internals)
- [ ] No fallback logic for database queries in transactions
- [ ] No fallback logic for structured output parsing (XML interceptors handle it)
- [ ] No LLM/external API calls inside database transactions (causes blocking and performance issues)

### **Resources**
- [ ] Files closed with `defer`
- [ ] Database connections properly managed
- [ ] Transactions are short (no LLM/external API calls inside)
- [ ] HTTP clients reused with timeouts
- [ ] Goroutines have cancellation/cleanup
- [ ] Context cancellation respected
- [ ] Mutexes unlocked with `defer`

### **Tooling**
- [ ] `golangci-lint run` passes
- [ ] `go vet ./...` passes
- [ ] `gofmt -d .` shows no changes
- [ ] No unused code warnings

---

## 🎯 **USAGE WORKFLOW**

1. **Run automated tools first**: `make lint`, `go vet ./...`, `gofmt -d .`
2. **Review tool output**: Address all errors and warnings
3. **Manual review**: Go through each analysis step systematically
4. **Prioritize findings**: Use the prioritization guide
5. **Create reports**: Use the report format for each finding
6. **Track fixes**: Document which smells were fixed and why

---

**Remember**: Code smells are indicators, not absolute rules. Use judgment to determine if a "smell" is actually a problem in your specific context. However, architecture violations and resource leaks should always be fixed immediately.
