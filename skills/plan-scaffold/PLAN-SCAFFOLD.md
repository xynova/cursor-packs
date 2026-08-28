# Plan Scaffold – Meta-Framework for Creating Implementation Plans

**Purpose**: Standard template and checkpoints for creating thorough, executable plans that don't miss critical wiring/glue steps.

---

## Quick Start

1. Copy this file to `.cursor/plans/<feature-name>-plan.md`
2. Fill in each section using the prompts
3. Use the **Glue Analysis Checklist** to catch wiring issues
4. Review with the **Plan Quality Gates** before implementation

---

## Plan Structure (Standard Sections)

### 1. Overview & Context

**Template:**
```markdown
# [Feature Name] Implementation Plan

## What we're building
- [One-sentence description]
- [Key user-facing capabilities]

## Why (business value)
- [Problem this solves]
- [Impact on users/pipeline]

## Reference implementation
- **Pattern source**: [e.g. "sayings pipeline: internal/pipelines/sayings/container.go lines 331-883"]
- **Similar feature**: [e.g. "Translation generation service with refinement loop"]
- **Key differences**: [What's different from the reference]
```

---

### 2. Architectural Analysis (The "Glue")

**This section prevents wiring failures. Answer every question explicitly.**

#### 2.1 Does this feature use a registry pattern?

- [ ] **Yes** → Fill in registry details below
- [ ] **No** → Skip to 2.2

**If yes:**
- **Registry type**: [e.g. DSPy ModuleRegistry, ServiceRegistry, ToolRegistry]
- **What gets registered**: [e.g. "Generators for youtube_topic, youtube_chapters, youtube_speakers"]
- **Where registration happens**: [e.g. "YouTube container, in initializeYouTubeStructuralModules()"]
- **When registration happens**: [e.g. "During NewContainer(), before creating StructuralGeneratorClient"]
- **Reference code**: [e.g. "sayings/container.go:465-520 (initializeSayingsGenerators)"]

**Registry checklist:**
- [ ] Where does `Register[Thing](key, value)` get called?
- [ ] Where does `Get[Thing](key)` get called? (must be after Register)
- [ ] Is there an init function that populates the registry?
- [ ] Is that init function called in the container before clients are created?

#### 2.2 Does this feature use dependency injection?

- [ ] **Yes** → Fill in DI details below
- [ ] **No** → Skip to 2.3

**If yes:**
- **What gets injected**: [List all dependencies: repos, clients, services]
- **Injected where**: [e.g. "StructuralService constructor"]
- **Injected from**: [e.g. "YouTube container NewContainer()"]
- **DI pattern**: [e.g. "Constructor injection via NewService(logger, repo, client, ...)"]

**DI checklist:**
- [ ] Are all dependencies created in the container before injection?
- [ ] Are constructors validating non-nil dependencies?
- [ ] Is the container passing the right implementations (not just nil)?

#### 2.3 Does this feature use factories?

- [ ] **Yes** → Fill in factory details below
- [ ] **No** → Skip to 2.4

**If yes:**
- **Factory type**: [e.g. GeneratorFactory, EvaluatorFactory]
- **What it creates**: [e.g. "ChainOfThought modules configured with provider and interceptors"]
- **Where factory is used**: [e.g. "initializeYouTubeStructuralModules calls factory.CreateGenerator()"]
- **Factory source**: [e.g. "shared.GetGeneratorFactory() - created in SharedContainer"]

**Factory checklist:**
- [ ] Is the factory created before use?
- [ ] Does the container have access to the factory (via shared or local)?
- [ ] Are factory outputs registered somewhere (if using registry pattern)?

#### 2.4 Configuration dependencies

**Config keys this feature needs:**
- [ ] `job_configs.[key]` entries: [List all, e.g. "youtube_topic, youtube_chapters, youtube_speakers"]
- [ ] `ai_providers.[name]` entries: [List all providers needed]
- [ ] Other config: [e.g. "services.max_versions, dspy.timeout"]

**Config resolution:**
- **Where config is read**: [e.g. "YouTube container calls cfg.GetGeneratorProvider('youtube_chapters')"]
- **Fallback behavior**: [What happens if config missing? Error or skip?]

#### 2.5 Database initialization order

**Does this feature require migrations?**
- [ ] **Yes** → Fill in migration details below
- [ ] **No** → Skip to 2.6

**If yes:**
- **Migration number**: [e.g. "000006"]
- **Tables created/modified**: [List all]
- **Migration must run before**: [e.g. "Before running analyze commands"]
- **How user applies migration**: [e.g. "pipelines youtube migrate up"]

#### 2.6 CLI wiring

**CLI commands this feature adds:**
- [ ] Command: [e.g. "pipelines youtube analyze chapters <video_uuid>"]
  - **Registered where**: [e.g. "internal/cli/pipelines/youtube/register.go"]
  - **Container dependency**: [e.g. "Needs youtubeContainer.StructuralService"]
  - **Nil handling**: [What happens if container/service is nil?]

---

### 3. Data Flow Diagram

**Trace the end-to-end path with actual types and method calls:**

```
CLI Command
  ↓ [what method?]
Service
  ↓ [what method? what does it call?]
Client
  ↓ [registry.Get[Thing]? API call?]
Registry/External System
  ↓
Repository
  ↓
Database Table
```

**Example (filled in):**
```
`pipelines youtube analyze chapters <video_uuid>`
  ↓ analyze.go: runAnalyzeWithComponents(cmd, logger, c, ["chapters"])
c.StructuralService.AnalyzeStructure(ctx, videoID, force, nil, ["chapters"])
  ↓ service.go: runChaptersStep(ctx, video, transcript, result, eventChan)
generatorClient.RunChapterGenerator(ctx, input, eventChan)
  ↓ structural_generator_client.go: registry.GetGenerator(JobChapters)
  ↓ Returns ChainOfThought module (registered in initializeYouTubeStructuralModules)
module.Process(ctx, inputs) → LLM call
  ↓
evaluationClient.EvaluateChapters(ctx, genInput, genOutput, eventChan)
  ↓ evaluation_client.go: registry.GetWorkflow(JobChapters)
  ↓ Returns ParallelEvaluationWorkflow (registered in initializeYouTubeStructuralModules)
workflow.EvaluateStream(ctx, inputs, eventChan) → returns score + feedback
  ↓
videoChaptersRepo.Create(ctx, db, videoChapters) in transaction
  ↓
INSERT INTO youtube.video_chapters (version, chapters JSONB, score, feedback, status)
```

**Checkpoint**: Does every step exist and connect to the next?

---

### 4. The Glue Analysis (Critical - Answer Every Question)

#### 4.1 Initialization sequence

**In what order do things get created?**

Example:
```
1. SharedContainer (creates registry, factories, transaction manager)
2. Sayings container (registers sayings generators/workflows, creates sayings services)
3. YouTube container → THIS IS WHERE YOUTUBE MODULES MUST BE REGISTERED
   a. Get registry from shared (already populated with sayings stuff)
   b. Register YouTube generators and workflows (initializeYouTubeStructuralModules)
   c. Create YouTube clients that use the registry (StructuralGeneratorClient)
   d. Create YouTube services that use the clients
```

**Questions:**
- [ ] What creates the thing that gets registered? [e.g. "generatorFactory.CreateGenerator()"]
- [ ] Where does registration happen? [File and function name]
- [ ] When does registration happen? [Relative to what other init steps]
- [ ] What depends on registration being complete? [e.g. "StructuralGeneratorClient.RunChapterGenerator calls GetGenerator"]

#### 4.2 Registry/Factory population

**For each registry this feature uses:**

| Registry | What gets registered | Registration function | Called from | Before creating |
|----------|---------------------|----------------------|-------------|-----------------|
| DSPy ModuleRegistry | youtube_topic, youtube_chapters, youtube_speakers generators | `initializeYouTubeStructuralModules()` | YouTube container `NewContainer()` | StructuralGeneratorClient |
| DSPy ModuleRegistry | youtube_topic, youtube_chapters workflows | Same function | Same | StructuralEvaluationClient |

**Checkpoint questions:**
- [ ] Is every `Get[Thing](key)` call preceded by a `Register[Thing](key, value)` call?
- [ ] Does the container initialization sequence ensure registration happens first?
- [ ] If registration fails, does the container handle it gracefully (nil service, warning)?

#### 4.3 Client creation dependencies

**For each client created:**

| Client | What it needs | Where it gets it | Registered by |
|--------|---------------|------------------|---------------|
| StructuralGeneratorClient | Registry with youtube_* generators | `registry.GetGenerator(job)` | `initializeYouTubeStructuralModules` |
| StructuralEvaluationClient | Registry with youtube_* workflows | `registry.GetWorkflow(job)` | Same function |

**Checkpoint**: Can each client be created and used after the container init completes?

#### 4.4 Service creation dependencies

**For the main service (e.g. StructuralService):**

| Dependency | Type | Created where | Injected via |
|------------|------|---------------|--------------|
| logger | `*observability.Logger` | shared.GetLogger() | Constructor param |
| transactionManager | `TransactionManager` | shared.GetTransactionManager() | Constructor param |
| videoTopicRepo | `VideoTopicRepository` | `NewVideoTopicRepository(dbPool, "youtube")` | Constructor param |
| generatorClient | `*StructuralGeneratorClient` | `NewStructuralGeneratorClient(registry, logger)` | Constructor param |

**Checkpoint**: Are all dependencies created before `NewService()` is called?

#### 4.5 "Can I run a command?" test

**For the main user-facing command:**

1. Start with CLI: `pipelines youtube analyze chapters <video_uuid>`
2. Trace backward to find every prerequisite:
   - [ ] YouTube container must exist (created in root.go)
   - [ ] YouTube container init must succeed (no errors)
   - [ ] `c.StructuralService` must be non-nil
   - [ ] StructuralService needs generatorClient non-nil
   - [ ] generatorClient needs registry with youtube_chapters registered
   - [ ] **Therefore**: YouTube container must call `initializeYouTubeStructuralModules` before creating generatorClient

**Checkpoint**: Starting from the CLI command, can you trace backward to a specific init function that makes it work?

---

### 5. Implementation Phases (Standard Checklist)

Use this order to avoid blocked work:

#### Phase A: Schema & Config
- [ ] Add config keys to `config.yaml` (job_configs, ai_providers)
- [ ] Add or update migration (create tables, indexes)
- [ ] Add or update domain models (structs in database/models.go)
- [ ] **Checkpoint**: Run migration; verify tables exist

#### Phase B: Data Access
- [ ] Create repositories (one per table)
- [ ] Implement interface methods (Create, GetByID, List, Update, etc.)
- [ ] Write repository tests (mock DB, verify queries)
- [ ] **Checkpoint**: Repository tests pass

#### Phase C: Module Definitions (if using DSPy)
- [ ] Define signatures (inputs, outputs)
- [ ] Write system prompts
- [ ] Implement `CreateModule()` functions
- [ ] Define evaluator prompts (feedback + score)
- [ ] **Checkpoint**: Modules can be instantiated (unit test CreateModule)

#### Phase D: Registration & Clients (THE GLUE)
- [ ] **Write registration function**: `initialize[Pipeline][Feature]Modules(ctx, shared, registry)`
  - [ ] For each generator: `cfg.GetGeneratorProvider(job)` → `factory.CreateGenerator()` → `registry.RegisterGenerator(job, gen)`
  - [ ] For each workflow: build evaluator + consolidator → `RegisterEvaluators/Consolidator/Workflow(job, ...)`
- [ ] **Call registration in container**: In `NewContainer()`, before creating clients:
  ```go
  if shared.GetDSPyRegistry() != nil {
      initCtx := context.Background()
      if err := initialize[Pipeline][Feature]Modules(initCtx, shared, registry); err != nil {
          logger.WithError(err).Warn("Failed to register - feature disabled")
      } else {
          // Now create clients that use the registry
      }
  }
  ```
- [ ] **Create clients** (after registration): Pass registry to client constructors
- [ ] **Checkpoint**: Start app, verify logs show "registered [thing]" or no "not found" errors

#### Phase E: Services
- [ ] Implement business logic service
- [ ] Inject all dependencies (repos, clients, transaction manager)
- [ ] Write service tests (mock clients and repos)
- [ ] **Checkpoint**: Service tests pass

#### Phase F: CLI
- [ ] Create command functions (thin wrappers)
- [ ] Wire commands in container (inject service)
- [ ] Register commands with root
- [ ] **Checkpoint**: `bin/pipelines [command] --help` works

#### Phase G: End-to-End Verification
- [ ] Run full command flow (CLI → service → repo → DB)
- [ ] Verify data persists correctly
- [ ] Check logs for "not found" or "nil" errors
- [ ] **Checkpoint**: Feature works end-to-end

---

## Plan Review Checklist (Use Before Implementation)

### Completeness
- [ ] Every phase has concrete tasks (not just "implement X")
- [ ] Reference implementation is cited with file:lines
- [ ] Data flow diagram traces CLI → DB with actual method names

### The Glue (Critical)
- [ ] **Registry population**: If using registry, there's an explicit "register in container" task in Phase D
- [ ] **Init order**: Registration happens before client creation (shown in container wiring)
- [ ] **DI validation**: All constructor dependencies are created in the container before NewService
- [ ] **Config resolution**: All `Get[Thing]Provider(job)` calls use correct job keys that exist in config.yaml

### Error Handling
- [ ] What happens if registry is nil? (Service disabled or error?)
- [ ] What happens if config provider missing? (Fail or skip with warning?)
- [ ] What happens if migration not run? (Clear error message?)

### Testing
- [ ] Each phase has a checkpoint (how do we know it works?)
- [ ] Tests don't require external services (mocks for unit tests)

---

## Glue Analysis Template (Use for Every Plan)

Copy this section into every plan and fill it in:

```markdown
## Wiring & Registration Analysis

### Does this feature use a registry/factory pattern?
**Answer**: [Yes/No - if yes, continue]

### Registry details
- **Registry type**: [e.g. DSPy ModuleRegistry, shared instance from SharedContainer]
- **What gets registered**: 
  - [Item 1, e.g. "Generator for youtube_topic"]
  - [Item 2, e.g. "Workflow for youtube_chapters"]
- **Registration function**: `[functionName]` in `[file.go]`
- **Pattern source**: [e.g. "sayings/container.go:465-520 (initializeSayingsGenerators)"]

### Registration sequence (critical)
1. **When**: [e.g. "During YouTube container NewContainer(), after getting shared.GetDSPyRegistry()"]
2. **Where**: [e.g. "Call initializeYouTubeStructuralModules(ctx, shared, registry)"]
3. **Before**: [e.g. "Before creating StructuralGeneratorClient(registry, logger)"]
4. **Error handling**: [e.g. "If registration fails, log warning and set structuralService = nil"]

### What depends on registration
- [e.g. "StructuralGeneratorClient.RunChapterGenerator() calls registry.GetGenerator('youtube_chapters')"]
- [e.g. "Must fail with clear error if generator not registered"]

### Container init pseudocode
```go
func NewContainer(shared *SharedContainer) (*Container, error) {
    // 1. Create repositories (no dependencies)
    videoRepo := NewVideoRepository(...)
    
    // 2. If using registry pattern:
    registry := shared.GetDSPyRegistry()
    if registry != nil {
        // 2a. REGISTER MODULES FIRST
        if err := initializeModules(ctx, shared, registry); err != nil {
            logger.Warn("Registration failed - feature disabled")
        } else {
            // 2b. NOW create clients that use registry
            generatorClient := NewGeneratorClient(registry, logger)
            
            // 2c. NOW create services that use clients
            service := NewService(logger, videoRepo, generatorClient, ...)
        }
    }
    
    return &Container{...}, nil
}
```

### Verification questions (must answer YES to all)
- [ ] Can I trace `Get[Thing](key)` back to `Register[Thing](key, value)`?
- [ ] Does registration happen in the container, before clients are created?
- [ ] Is there a clear init function (like sayings initializeSayingsGenerators)?
- [ ] If I grep for "Register[Thing]", do I find it being called for this feature?
```

---

## Standard Phases (Detailed)

### Phase A: Schema & Config

**Goal**: Database and configuration foundation in place.

**Tasks**:
- [ ] Update `config.yaml`:
  - [ ] Add `job_configs.[job_name].modules.generator.provider: "[provider_name]"`
  - [ ] Add `job_configs.[job_name].modules.evaluator.provider: "[provider_name]"` (if needed)
  - [ ] Verify `ai_providers.[provider_name]` exists with correct schema and model
- [ ] Create migration `migrations/[pipeline]/[number]_[name].up.sql`:
  - [ ] Create tables with proper columns, constraints, indexes
  - [ ] Add down migration for rollback
- [ ] Add domain models in `internal/pipelines/[pipeline]/database/models.go`:
  - [ ] Struct definitions with json/db tags
  - [ ] Validation logic if needed

**Checkpoint**: 
```bash
# Apply migration
bin/pipelines [pipeline] migrate up

# Verify tables exist
psql $DATABASE_URL -c "\dt [schema].*"
```

**Reference**: sayings migration 000001 + models.go for Translation/Explanation pattern.

---

### Phase B: Repositories

**Goal**: Data access layer complete and tested.

**Tasks**:
- [ ] Create repository file `internal/pipelines/[pipeline]/database/[entity]_repository.go`
- [ ] Define interface (Create, GetByID, List, Update, etc.)
- [ ] Implement methods using `sharedDatabase.GetExecutor(db, r.pool)` pattern
- [ ] Handle JSONB marshaling/unmarshaling if needed
- [ ] Validate domain constraints before persisting
- [ ] Return domain errors (not raw pgx errors)
- [ ] Write repository tests (use testutil for DB access if integration tests)

**Checkpoint**: 
```bash
# Run repository tests
go test ./internal/pipelines/[pipeline]/database/... -v
```

**Reference**: VideoChaptersRepository for JSONB + validation pattern.

---

### Phase C: Module Definitions (DSPy/External Clients)

**Goal**: Module signatures, prompts, and `CreateModule` functions ready.

**Tasks**:
- [ ] Create `internal/pipelines/[pipeline]/clients/[feature]_modules.go`
- [ ] Define generator signatures (inputs, outputs)
- [ ] Write system prompts (clear instructions for LLM)
- [ ] Implement `CreateModule()` functions (returns `*modules.ChainOfThought`)
- [ ] Define evaluator signatures and prompts (feedback + score)
- [ ] If using external APIs: create client interface and HTTP implementation

**Checkpoint**: 
```go
// Unit test that CreateModule works
func TestGeneratorConfig_CreateModule(t *testing.T) {
    module, err := TopicGeneratorConfig.CreateModule()
    assert.NoError(t, err)
    assert.NotNil(t, module)
}
```

**Reference**: sayings/clients/translation_modules.go for TranslationGenerator pattern.

---

### Phase D: Registration & Clients (THE CRITICAL GLUE)

**Goal**: Registry populated; clients created and ready to use.

**Tasks (do in this exact order)**:

1. **Write registration function** (in container.go, at the end):
   ```go
   func initialize[Pipeline][Feature]Modules(
       ctx context.Context,
       shared *SharedContainer,
       registry *dspyRegistry.ModuleRegistry,
   ) error {
       cfg := shared.GetConfig()
       generatorFactory := shared.GetGeneratorFactory()
       
       // Register generators
       for _, job := range []string{"job1", "job2"} {
           provider, err := cfg.GetGeneratorProvider(job)
           if err != nil {
               logger.Warn("Provider not configured - skipping")
               continue
           }
           gen, err := generatorFactory.CreateGenerator(ctx, provider, Config.CreateModule, "label", nil)
           if err != nil { return err }
           registry.RegisterGenerator(job, gen)
       }
       
       // Register evaluators and workflows (if needed)
       evaluatorFactory := shared.GetEvaluatorFactory()
       // ... similar pattern: create evaluator modules, register
       
       return nil
   }
   ```

2. **Call registration in container**:
   ```go
   func NewContainer(shared *SharedContainer) (*Container, error) {
       // ... create repos first ...
       
       if shared.GetDSPyRegistry() != nil {
           registry := shared.GetDSPyRegistry()
           initCtx := context.Background()
           
           // CRITICAL: Register before creating clients
           if err := initialize[Pipeline][Feature]Modules(initCtx, shared, registry); err != nil {
               logger.WithError(err).Warn("Registration failed - feature disabled")
               // Set clients/service to nil
           } else {
               // NOW create clients that use registry
               generatorClient := NewGeneratorClient(registry, logger)
               service := NewService(logger, repo, generatorClient, ...)
           }
       }
   }
   ```

3. **Create clients** (pass registry that's now populated):
   - [ ] Client constructors receive registry as parameter
   - [ ] Client methods call `registry.Get[Thing](key)` and handle not-found errors

**Checkpoint**:
```bash
# Build and check for registration
make build

# Look for registration logs
bin/pipelines [command] 2>&1 | grep -i "register\|initialized"

# Verify no "not found" errors
bin/pipelines [command] 2>&1 | grep -i "not found"
```

**Reference**: 
- `sayings/container.go:331-350` (initializeSayingsDSPyModules → initializeSayingsGenerators)
- `sayings/container.go:465-520` (initializeSayingsGenerators implementation)

---

### Phase E: Services

**Goal**: Business logic implemented and tested.

**Tasks**:
- [ ] Create service file `internal/pipelines/[pipeline]/services/[feature]/service.go`
- [ ] Implement service interface with business methods
- [ ] Use transaction manager for multi-step operations
- [ ] Inject all dependencies via constructor (validate non-nil)
- [ ] Return domain errors (wrapped with context)
- [ ] Write service tests (mock all dependencies)

**Checkpoint**: 
```bash
go test ./internal/pipelines/[pipeline]/services/[feature]/... -v
```

**Reference**: sayings/services/translation for refinement loop pattern.

---

### Phase F: CLI

**Goal**: User can run commands.

**Tasks**:
- [ ] Create CLI file `internal/cli/pipelines/[pipeline]/[feature].go`
- [ ] Implement command functions (use `RunE`, not `Run`)
- [ ] Wire to container: `NewCommand(logger, container)` gets service from container
- [ ] Register command in `[pipeline]_group.go`: `cmd.AddCommand(NewFeatureCommand(...))`
- [ ] Handle nil service gracefully (clear error message)

**Checkpoint**:
```bash
bin/pipelines [pipeline] [command] --help
# Should show help without errors

bin/pipelines [pipeline] [command] [args]
# Should execute (or fail with clear error if deps missing)
```

**Reference**: internal/cli/pipelines/youtube/analyze.go for thin command pattern.

---

## Pre-Implementation Review (Do This Before Coding)

Go through this checklist with another person or AI:

### Glue Review
1. **Show me the registration function**: Where is it? What does it register?
2. **Show me where it's called**: In which container, at what point in NewContainer()?
3. **Show me what depends on it**: Which clients call Get[Thing] that need the registration?
4. **Trace backward from CLI**: Start with command, go backward to registration—are all links present?

### Completeness Review
5. **Config keys match constants**: Do config.yaml job keys match the constants used in code?
6. **Migration order**: If multiple migrations, are they numbered correctly?
7. **Error handling**: What happens if optional dependencies are missing?

### Pattern Consistency Review
8. **Matches reference**: Is the structure parallel to the reference implementation?
9. **No new patterns**: Are we reusing existing patterns, or inventing new ones?
10. **Same file structure**: Do we have the same file layout (container, services, clients, database)?

---

## Post-Implementation Verification (Do This After Coding)

### Build & Test
```bash
make build                          # Must pass
go test ./internal/pipelines/[pipeline]/... -v  # All tests pass
```

### Connectivity Test
```bash
# Does the command work?
bin/pipelines [pipeline] [command] [args]

# Check logs for errors
tail -f logs/app.log | grep -i "error\|not found\|nil"

# Verify DB changes
psql $DATABASE_URL -c "SELECT * FROM [schema].[table] LIMIT 5;"
```

### Glue Verification
```bash
# Grep for registration calls
rg "Register(Generator|Workflow|Evaluators)" internal/pipelines/[pipeline]/

# Should find registration calls in container or init function

# Grep for Get[Thing] calls  
rg "Get(Generator|Workflow|Evaluators)" internal/pipelines/[pipeline]/

# Should find usage in clients; verify those clients are created after registration
```

---

## Common Glue Failures (Watch For These)

### 1. **Registry Never Populated**
- **Symptom**: "generator for task 'X' not found"
- **Cause**: Clients call `registry.GetGenerator(job)` but nothing called `RegisterGenerator(job, ...)`
- **Fix**: Add registration function in container, call before creating clients

### 2. **Registration After Usage**
- **Symptom**: Intermittent "not found" or nil errors
- **Cause**: Clients created before registration runs (race condition or wrong order)
- **Fix**: Ensure registration is synchronous and happens first in NewContainer

### 3. **Config Key Mismatch**
- **Symptom**: "provider 'X' not found" or "job 'Y' not found"
- **Cause**: Code uses `"youtube_chapters"` but config has `"chapters"` (or vice versa)
- **Fix**: Grep for all job key usage; verify matches config.yaml exactly

### 4. **Factory Not Available**
- **Symptom**: "factory is nil" or panic in registration
- **Cause**: SharedContainer doesn't have factory, or YouTube container doesn't get it from shared
- **Fix**: Verify SharedContainer creates factory; verify YouTube container calls shared.GetFactory()

### 5. **Wrong Dependency Type**
- **Symptom**: Type assertion failed, interface not implemented
- **Cause**: Container injects concrete type but service expects interface (or vice versa)
- **Fix**: Match types exactly; use interfaces where mocking is needed

---

## Example: Filled-In Glue Analysis (YouTube Structural)

### Does this feature use a registry/factory pattern?
**Answer**: Yes - uses shared DSPy ModuleRegistry and GeneratorFactory/EvaluatorFactory.

### Registry details
- **Registry type**: DSPy ModuleRegistry (shared instance from SharedContainer)
- **What gets registered**: 
  - Generators for: `youtube_topic`, `youtube_chapters`, `youtube_speakers`
  - Workflows for: `youtube_topic`, `youtube_chapters` (speakers has no evaluation)
- **Registration function**: `initializeYouTubeStructuralModules(ctx, shared, registry)` in `youtube/container.go`
- **Pattern source**: `sayings/container.go:465-520` (initializeSayingsGenerators) and `:524-882` (initializeSayingsEvaluatorsAndWorkflows)

### Registration sequence
1. **When**: During YouTube container `NewContainer()`, after `registry := shared.GetDSPyRegistry()` (line 118)
2. **Where**: Call `initializeYouTubeStructuralModules(initCtx, shared, registry)` before creating clients
3. **Before**: Before `NewStructuralGeneratorClient(registry, logger)` and `NewStructuralEvaluationClient(registry)`
4. **Error handling**: If registration fails, log warning and set `structuralService = nil` (feature disabled)

### What depends on registration
- `StructuralGeneratorClient.RunChapterGenerator()` calls `registry.GetGenerator('youtube_chapters')` → returns "not found" if not registered
- `StructuralEvaluationClient.EvaluateChapters()` calls `registry.GetWorkflow('youtube_chapters')` → same
- **Critical**: Clients are unusable without registration; service will fail on first analyze command

### Container init pseudocode
```go
func NewContainer(shared *SharedContainer) (*Container, error) {
    // 1. Create repos (no deps)
    videoTopicRepo := NewVideoTopicRepository(dbPool, "youtube")
    
    // 2. Register modules (THE GLUE)
    var structuralService *Service
    if shared.GetDSPyRegistry() != nil {
        registry := shared.GetDSPyRegistry()
        initCtx := context.Background()
        
        // CRITICAL: Registration must happen here
        if err := initializeYouTubeStructuralModules(initCtx, shared, registry); err != nil {
            logger.Warn("Registration failed")
        } else {
            // NOW create clients (they use registry)
            genClient := NewStructuralGeneratorClient(registry, logger)
            evalClient := NewStructuralEvaluationClient(registry)
            structuralService = NewService(logger, ..., genClient, evalClient, ...)
        }
    }
    
    return &Container{StructuralService: structuralService, ...}, nil
}
```

### Verification
- [x] Grep finds `RegisterGenerator("youtube_chapters", ...)` in container.go
- [x] Grep finds `GetGenerator("youtube_chapters")` in structural_generator_client.go
- [x] Registration happens before client creation (init function called first)
- [x] If registration fails, service is nil (graceful degradation)

---

## Usage: How to Create a Plan

1. **Copy this file** to `.cursor/plans/[feature-name]-plan.md`
2. **Fill in Overview & Context**: What/why/reference
3. **Complete Architectural Analysis (section 2)**: Answer every glue question
4. **Draw data flow**: CLI → service → client → registry → repo → DB
5. **Fill in Glue Analysis Template**: Registration sequence and verification
6. **Create phase checklists**: Copy standard phases, add feature-specific tasks
7. **Review with Plan Review Checklist**: Verify glue, completeness, error handling
8. **Get feedback**: Ask AI to review using this scaffold

---

## For AI: Plan Review Protocol

When reviewing a plan (user asks "review this plan"), use this protocol:

### Step 1: Glue Analysis (mandatory)
Ask these questions explicitly:
1. "Does this feature use a registry or factory pattern?"
2. "If yes, where does registration happen? Show me the function name and file."
3. "When is registration called relative to client creation?"
4. "What calls Get[Thing] that depends on Register[Thing] being done first?"
5. "Is there a checklist item that says 'call registration in container'?"

### Step 2: Trace Backward from CLI
1. Start with the main user command (e.g. `analyze chapters`)
2. Trace to service method
3. Trace to client method
4. Trace to registry Get call
5. Ask: "Where does the thing being Get'd get Register'd?"
6. Verify: Registration is in the container, before client creation

### Step 3: Pattern Match
1. Find reference implementation (e.g. sayings)
2. List the key glue steps from reference (e.g. "initializeSayingsGenerators at line X")
3. Check: Does the plan have equivalent steps for the new feature?
4. Flag: Any missing registration/initialization steps

### Step 4: Report
- "Glue analysis: [OK / MISSING X]"
- If missing: "The plan doesn't show where [thing] gets registered. Add explicit task: 'In [Pipeline] container, call initialize[Feature]Modules before creating clients.'"

---

## Summary

**Key insight**: Most implementation failures are glue failures—not business logic bugs.

**The scaffold forces**:
1. **Explicit glue analysis** before writing code (section 2)
2. **Registration as a first-class phase** (Phase D)
3. **Verification questions** that trace Get back to Register
4. **Reference to working code** (file:lines, not just "like sayings")

**For every new plan, fill in the "Wiring & Registration Analysis" section first. If you can't answer those questions, the plan is incomplete.**
