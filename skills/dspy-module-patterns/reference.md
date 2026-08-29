# DSPy-Go reference (cursor-packs)

Deep dspy-go module, optimizer, interceptor, and workflow patterns. Load from `dspy-module-patterns` (and related dspy/strop skills) when needed.

**Procedure:** [SKILL.md](SKILL.md). XML parser: `dspy-xml-structured-output`. Prompts: `dspy-prompt-engineering` + [its reference](../dspy-prompt-engineering/reference.md). Debugging: `dspy-go-debugging`. Pipeline layout: `strop-pipeline-pattern`.

Project overlays (if any) use a consumer prefix such as `pipelines-x-*`.

---


# DSPy-Go Development Rules

**Rules vs skills:** This file states DSPy **invariants and patterns** for this codebase. Task-specific checklists live in **project skills** (see **Rules vs project skills** in `always-rules-2-architecture.mdc`). Pack: XML structured output — `.cursor/skills/dspy-xml-structured-output/SKILL.md`; pipeline layout — `.cursor/skills/strop-pipeline-pattern/SKILL.md`; orchestration — `.cursor/skills/strop-orchestration/SKILL.md`; debugging — `.cursor/skills/dspy-go-debugging/SKILL.md`; module wiring — `.cursor/skills/dspy-module-patterns/SKILL.md`; prompts — `.cursor/skills/dspy-prompt-engineering/SKILL.md`. Overlays: content-pipelines job conventions — ``.cursor/skills/strop-pipeline-pattern/SKILL.md` (plus project `pipelines-x-*` overlay if present)`; phased PostGenerator — `project `pipelines-x-*` XML overlay if present`.

## Table of Contents

### [Core Architecture Understanding](#core-architecture-understanding) (Line 73)
- [1. DSPy-Go is a Native Go Framework](#1-dspy-go-is-a-native-go-framework) (Line 75)
- [2. Module-Based Architecture](#2-module-based-architecture) (Line 82)
- [3. Signature Patterns](#3-signature-patterns) (Line 102)
- [4. LLM Configuration Patterns](#4-llm-configuration-patterns) (Line 132)
  - [Default LLM Configuration](#default-llm-configuration) (Line 134)
  - [Provider-Specific LLM Configuration](#provider-specific-llm-configuration) (Line 147)

### [Modules and Programs](#modules-and-programs) (Line 176)
- [5. Module Types and Usage](#5-module-types-and-usage) (Line 178)
  - [Predict Module](#predict-module) (Line 180)
  - [ChainOfThought Module](#chainofthought-module) (Line 195)
  - [ReAct Module](#react-module) (Line 214)
  - [Refine Module](#refine-module) (Line 239)
  - [Parallel Module](#parallel-module) (Line 265)
  - [MultiChainComparison Module](#multichaincomparison-module) (Line 290)
- [6. Program Patterns](#6-program-patterns) (Line 308)

### [Optimizers](#optimizers) (Line 345)
- [7. Optimizer Patterns](#7-optimizer-patterns) (Line 347)
  - [BootstrapFewShot](#bootstrapfewshot) (Line 351)
  - [MIPRO (Multi-step Interactive Prompt Optimization)](#mipro-multi-step-interactive-prompt-optimization) (Line 365)
  - [SIMBA (Stochastic Introspective Mini-Batch Ascent)](#simba-stochastic-introspective-mini-batch-ascent) (Line 379)
  - [GEPA (Generative Evolutionary Prompt Adaptation)](#gepa-generative-evolutionary-prompt-adaptation) (Line 397)
  - [COPRO (Collaborative Prompt Optimization)](#copro-collaborative-prompt-optimization) (Line 418)

### [Tools and Integration](#tools-and-integration) (Line 428)
- [8. Tool Integration Patterns](#8-tool-integration-patterns) (Line 430)
  - [Basic Tool Registry](#basic-tool-registry) (Line 432)
  - [Smart Tool Registry](#smart-tool-registry) (Line 446)
  - [Custom Tools](#custom-tools) (Line 467)
  - [Tool Chaining](#tool-chaining) (Line 489)
  - [Dependency Resolution](#dependency-resolution) (Line 507)
  - [Parallel Tool Execution](#parallel-tool-execution) (Line 529)
  - [Tool Composition](#tool-composition) (Line 541)
- [9. MCP (Model Context Protocol) Integration](#9-mcp-model-context-protocol-integration) (Line 575)

### [Multimodal Processing](#multimodal-processing) (Line 594)
- [10. Multimodal Processing Patterns](#10-multimodal-processing-patterns) (Line 596)
  - [Image Analysis](#image-analysis) (Line 598)
  - [Streaming Multimodal](#streaming-multimodal) (Line 625)

### [Workflows and Memory](#workflows-and-memory) (Line 644)
- [11. Workflow Patterns](#11-workflow-patterns) (Line 646)
  - [Chain Workflow](#chain-workflow) (Line 648)
  - [Orchestrator](#orchestrator) (Line 673)
- [12. Memory Patterns](#12-memory-patterns) (Line 690)
  - [Buffer Memory](#buffer-memory) (Line 692)
  - [SQLite Memory](#sqlite-memory) (Line 701)

### [Advanced Features](#advanced-features) (Line 710)
- [13. Streaming Support](#13-streaming-support) (Line 712)
- [14. Dataset Management](#14-dataset-management) (Line 728)
- [15. Error Handling Patterns](#15-error-handling-patterns) (Line 743)
- [16. Tracing and Logging](#16-tracing-and-logging) (Line 763)
- [17. Interceptor Patterns](#17-interceptor-patterns) (Line 786)
  - [Module Interceptors](#module-interceptors) (Line 788)
  - [Output validation and retry](#output-validation-and-retry)
  - [XML Interceptor](#xml-interceptor) (Line 810)

### [Best Practices and Testing](#best-practices-and-testing) (Line 825)
- [18. Best Practices](#18-best-practices) (Line 827)
  - [Configuration Management](#configuration-management) (Line 829)
  - [Module Design](#module-design) (Line 835)
  - [Performance](#performance) (Line 841)
  - [Error Handling](#error-handling) (Line 847)
- [19. Common Anti-Patterns to Avoid](#19-common-anti-patterns-to-avoid) (Line 853)
  - [❌ DON'T](#-dont) (Line 855)
  - [✅ DO](#-do) (Line 874)
- [20. Testing Patterns](#20-testing-patterns) (Line 900)
  - [Unit Testing with Mocks](#unit-testing-with-mocks) (Line 902)
  - [Integration Testing](#integration-testing) (Line 916)

### [Summary](#summary) (Line 932)
- [21. Key Takeaways](#21-key-takeaways) (Line 934)
- [Major Features](#major-features) (Line 951)
  - [✅ Module System](#-module-system) (Line 953)
  - [✅ Optimizers](#-optimizers) (Line 961)
  - [✅ Tool Integration](#-tool-integration) (Line 968)
  - [✅ Multimodal Support](#-multimodal-support) (Line 976)
  - [✅ Workflow Patterns](#-workflow-patterns) (Line 982)
  - [✅ Advanced Features](#-advanced-features) (Line 987)


## Core Architecture Understanding

### 1. DSPy-Go is a Native Go Framework
- **NEVER** assume DSPy-Go requires external services or containers
- **ALWAYS** use DSPy-Go as a library imported directly into your Go application
- DSPy-Go runs entirely within your Go process - no separate services needed
- All modules, optimizers, and tools execute in-process
- LLM providers are configured as clients, not separate services

### 2. Module-Based Architecture
DSPy-Go is built around composable modules that process inputs and produce outputs:

```go
// CORRECT: Modules are the core building blocks
signature := core.NewSignature(
    []core.InputField{{Field: core.NewField("question")}},
    []core.OutputField{{Field: core.NewField("answer")}},
)
module := modules.NewPredict(signature)
result, err := module.Process(ctx, map[string]interface{}{
    "question": "What is 2+2?",
})
```

**NEVER**:
- Try to directly call LLMs without using modules
- Bypass the module interface for LLM interactions
- Create modules without proper signatures

### 3. Signature Patterns

Signatures define the contract for module inputs and outputs:

```go
// Basic signature
signature := core.NewSignature(
    []core.InputField{
        {Field: core.NewField("question", core.WithDescription("Question to answer"))},
    },
    []core.OutputField{
        {Field: core.NewField("answer", core.WithDescription("Answer to the question"))},
    },
)

// Signature with instruction
signature = signature.WithInstruction("Answer questions concisely and accurately.")

// Multimodal signature
signature := core.NewSignature(
    []core.InputField{
        {Field: core.NewImageField("image", core.WithDescription("The image to analyze"))},
        {Field: core.NewTextField("question", core.WithDescription("Question about the image"))},
    },
    []core.OutputField{
        {Field: core.NewTextField("answer", core.WithDescription("Analysis result"))},
    },
)
```

### 4. LLM Configuration Patterns

#### Default LLM Configuration
```go
// Configure default LLM for all modules
llms.EnsureFactory()
err := core.ConfigureDefaultLLM("your-api-key", core.ModelAnthropicSonnet)
if err != nil {
    log.Fatalf("Failed to configure LLM: %v", err)
}

// All modules will use the default LLM
module := modules.NewPredict(signature)
```

#### Provider-Specific LLM Configuration
```go
// Anthropic Claude
llm, err := llms.NewAnthropicLLM("api-key", core.ModelAnthropicSonnet)

// Google Gemini (with multimodal support)
llm, err := llms.NewGeminiLLM("api-key", core.ModelGoogleGeminiPro)

// OpenAI
llm, err := llms.NewOpenAI(core.ModelOpenAIGPT4, "api-key")

// OpenAI-compatible (LiteLLM, LocalAI, etc.)
llm, err := llms.NewOpenAILLM(core.ModelOpenAIGPT4,
    llms.WithAPIKey("api-key"),
    llms.WithOpenAIBaseURL("http://localhost:4000"),
    llms.WithOpenAITimeout(60*time.Second))

// Ollama (local)
llm, err := llms.NewOllamaLLM(core.ModelOllamaLlama3_8B)

// LlamaCPP (local)
llm, err := llms.NewLlamacppLLM("http://localhost:8080")

// Set as default or use with specific module
core.SetDefaultLLM(llm)
// OR
module.SetLLM(llm)
```

## Modules and Programs

### 5. Module Types and Usage

#### Predict Module
The simplest module for direct LLM predictions:

```go
signature := core.NewSignature(
    []core.InputField{{Field: core.NewField("document")}},
    []core.OutputField{{Field: core.NewField("summary")}},
)

predict := modules.NewPredict(signature)
result, err := predict.Process(ctx, map[string]interface{}{
    "document": "Long document text...",
})
```

#### ChainOfThought Module
Implements step-by-step reasoning:

```go
signature := core.NewSignature(
    []core.InputField{{Field: core.NewField("question")}},
    []core.OutputField{
        {Field: core.NewField("rationale")},
        {Field: core.NewField("answer")},
    },
)

cot := modules.NewChainOfThought(signature)
result, err := cot.Process(ctx, map[string]interface{}{
    "question": "Solve 25 × 16 step by step.",
})
// result contains both "rationale" and "answer"
```

#### ReAct Module
Implements Reasoning and Acting with tool integration:

```go
// Create tools
calculator := tools.NewCalculatorTool()
searchTool := tools.NewSearchTool()

// Create tool registry
registry := tools.NewInMemoryToolRegistry()
registry.Register(calculator)
registry.Register(searchTool)

// Create ReAct module
signature := core.NewSignature(
    []core.InputField{{Field: core.NewField("question")}},
    []core.OutputField{{Field: core.NewField("answer")}},
)

react := modules.NewReAct(signature, registry, 5) // 5 max iterations
result, err := react.Process(ctx, map[string]interface{}{
    "question": "What is the population of France divided by 1000?",
})
```

#### Refine Module
Improves prediction quality through multiple attempts:

```go
// Define reward function
rewardFn := func(inputs, outputs map[string]interface{}) float64 {
    answer := outputs["answer"].(string)
    // Custom evaluation logic
    return math.Min(1.0, float64(len(answer))/100.0)
}

// Create Refine module
refine := modules.NewRefine(
    modules.NewPredict(signature),
    modules.RefineConfig{
        N:         5,       // Number of refinement attempts
        RewardFn:  rewardFn,
        Threshold: 0.8,     // Stop early if threshold reached
    },
)

result, err := refine.Process(ctx, map[string]interface{}{
    "question": "Explain quantum computing in detail.",
})
```

#### Parallel Module
Enables concurrent execution for batch processing:

```go
baseModule := modules.NewPredict(signature)

parallel := modules.NewParallel(baseModule,
    modules.WithMaxWorkers(4),              // 4 concurrent workers
    modules.WithReturnFailures(true),        // Include failed results
    modules.WithStopOnFirstError(false),     // Continue on errors
)

batchInputs := []map[string]interface{}{
    {"question": "What is 2+2?"},
    {"question": "What is 3+3?"},
    {"question": "What is 4+4?"},
}

result, err := parallel.Process(ctx, map[string]interface{}{
    "batch_inputs": batchInputs,
})

results := result["results"].([]map[string]interface{})
```

#### MultiChainComparison Module
Compares multiple reasoning attempts:

```go
multiChain := modules.NewMultiChainComparison(signature, 3, 0.7)

completions := []map[string]interface{}{
    {"rationale": "focus on cost reduction", "solution": "Implement automation"},
    {"reasoning": "prioritize customer satisfaction", "solution": "Improve service"},
    {"rationale": "balance objectives", "solution": "Gradual optimization"},
}

result, err := multiChain.Process(ctx, map[string]interface{}{
    "problem": "How should we address declining performance?",
    "completions": completions,
})
```

### 6. Program Patterns

Programs combine modules into executable workflows:

```go
// Create modules
retriever := modules.NewPredict(retrieverSignature)
generator := modules.NewPredict(generatorSignature)

// Create program
program := core.NewProgram(
    map[string]core.Module{
        "retriever": retriever,
        "generator": generator,
    },
    func(ctx context.Context, inputs map[string]interface{}) (map[string]interface{}, error) {
        // First retrieve documents
        retrieverResult, err := retriever.Process(ctx, inputs)
        if err != nil {
            return nil, err
        }

        // Then generate answer
        generatorInputs := map[string]interface{}{
            "question": inputs["question"],
            "documents": retrieverResult["documents"],
        }
        return generator.Process(ctx, generatorInputs)
    },
)

// Execute program
result, err := program.Execute(ctx, map[string]interface{}{
    "question": "What is machine learning?",
})
```

## Optimizers

### 7. Optimizer Patterns

Optimizers improve module performance by automatically tuning prompts and parameters.

#### BootstrapFewShot
Automatically selects high-quality examples:

```go
// Create metric function
metric := func(example, prediction map[string]interface{}, ctx context.Context) bool {
    return example["answer"] == prediction["answer"]
}

// Create optimizer
optimizer := optimizers.NewBootstrapFewShot(metric, 10) // Max 10 examples

// Optimize module
optimizedProgram, err := optimizer.Compile(ctx, program, dataset, metric)
```

#### MIPRO (Multi-step Interactive Prompt Optimization)
Advanced optimizer using TPE search:

```go
mipro := optimizers.NewMIPRO(
    metricFunc,
    optimizers.WithMode(optimizers.LightMode),      // Fast optimization
    optimizers.WithNumTrials(10),                   // Number of trials
    optimizers.WithTPEGamma(0.25),                  // TPE exploration
)

optimizedProgram, err := mipro.Compile(ctx, program, dataset, nil)
```

#### SIMBA (Stochastic Introspective Mini-Batch Ascent)
Introspective learning optimizer:

```go
simba := optimizers.NewSIMBA(
    optimizers.WithSIMBABatchSize(8),
    optimizers.WithSIMBAMaxSteps(12),
    optimizers.WithSIMBANumCandidates(6),
    optimizers.WithSamplingTemperature(0.2),
)

optimizedProgram, err := simba.Compile(ctx, program, dataset, metricFunc)

// Access introspective insights
state := simba.GetState()
fmt.Printf("Completed in %d steps with score %.3f\n", state.CurrentStep, state.BestScore)
```

#### GEPA (Generative Evolutionary Prompt Adaptation)
Multi-objective evolutionary optimizer:

```go
config := &optimizers.GEPAConfig{
    PopulationSize:    20,
    MaxGenerations:    10,
    SelectionStrategy: "adaptive_pareto",
    MutationRate:      0.3,
    CrossoverRate:     0.7,
    ReflectionFreq:    2,
}

gepa, err := optimizers.NewGEPA(config)
optimizedProgram, err := gepa.Compile(ctx, program, dataset, metricFunc)

// Access optimization results
state := gepa.GetOptimizationState()
archive := state.GetParetoArchive()
```

#### COPRO (Collaborative Prompt Optimization)
Collaborative optimizer for multi-module programs:

```go
copro := optimizers.NewCopro(dataset, metrics.NewRougeMetric("answer"))
optimizedModule, err := copro.Optimize(ctx, originalModule)
```

## Tools and Integration

### 8. Tool Integration Patterns

#### Basic Tool Registry
```go
// Create registry
registry := tools.NewInMemoryToolRegistry()

// Register tools
registry.Register(calculatorTool)
registry.Register(searchTool)

// Get tool
tool, err := registry.Get("calculator")
result, err := tool.Execute(ctx, params)
```

#### Smart Tool Registry
Intelligent tool selection with Bayesian inference:

```go
config := &tools.SmartToolRegistryConfig{
    AutoDiscoveryEnabled:       true,  // Auto-discover from MCP servers
    PerformanceTrackingEnabled: true,  // Track performance metrics
    FallbackEnabled:           true,   // Intelligent fallback
}

registry := tools.NewSmartToolRegistry(config)
registry.Register(mySearchTool)
registry.Register(myAnalysisTool)

// Intelligent tool selection
tool, err := registry.SelectBest(ctx, "find user information")

// Execute with tracking
result, err := registry.ExecuteWithTracking(ctx, tool.Name(), params)
```

#### Custom Tools
```go
type WeatherTool struct{}

func (t *WeatherTool) Name() string {
    return "weather"
}

func (t *WeatherTool) Description() string {
    return "Get the current weather for a location"
}

func (t *WeatherTool) Execute(ctx context.Context, params map[string]interface{}) (interface{}, error) {
    location := params["location"].(string)
    // Fetch weather data
    return weatherData, nil
}

// Register custom tool
registry.Register(&WeatherTool{})
```

#### Tool Chaining
Sequential tool execution with data transformation:

```go
pipeline, err := tools.NewPipelineBuilder("data_processing", registry).
    Step("data_extractor").
    StepWithTransformer("data_validator", tools.TransformExtractField("result")).
    ConditionalStep("data_enricher",
        tools.ConditionExists("validation_result"),
        tools.ConditionEquals("status", "validated")).
    StepWithRetries("data_transformer", 3).
    FailFast().
    EnableCaching().
    Build()

result, err := pipeline.Execute(ctx, input)
```

#### Dependency Resolution
Automatic execution planning with parallel optimization:

```go
graph := tools.NewDependencyGraph()
graph.AddNode(&tools.DependencyNode{
    ToolName:     "data_extractor",
    Dependencies: []string{},
    Outputs:      []string{"raw_data"},
})

graph.AddNode(&tools.DependencyNode{
    ToolName:     "data_validator",
    Dependencies: []string{"data_extractor"},
    Inputs:       []string{"raw_data"},
    Outputs:      []string{"validated_data"},
})

depPipeline, err := tools.NewDependencyPipeline("smart_pipeline", registry, graph, options)
result, err := depPipeline.ExecuteWithDependencies(ctx, input)
```

#### Parallel Tool Execution
```go
executor := tools.NewParallelExecutor(registry, 4) // 4 workers

tasks := []*tools.ParallelTask{
    {ID: "task1", ToolName: "analyzer", Input: data1, Priority: 1},
    {ID: "task2", ToolName: "processor", Input: data2, Priority: 2},
}

results, err := executor.ExecuteParallel(ctx, tasks, &tools.PriorityScheduler{})
```

#### Tool Composition
Create reusable composite tools:

```go
type CompositeTool struct {
    name     string
    pipeline *tools.ToolPipeline
}

func NewCompositeTool(name string, registry core.ToolRegistry,
    builder func(*tools.PipelineBuilder) *tools.PipelineBuilder) (*CompositeTool, error) {
    
    pipeline, err := builder(tools.NewPipelineBuilder(name+"_pipeline", registry)).Build()
    if err != nil {
        return nil, err
    }
    
    return &CompositeTool{name: name, pipeline: pipeline}, nil
}

// Create composite tool
textProcessor, err := NewCompositeTool("text_processor", registry,
    func(builder *tools.PipelineBuilder) *tools.PipelineBuilder {
        return builder.
            Step("text_uppercase").
            Step("text_reverse").
            Step("text_length")
    })

// Register and use
registry.Register(textProcessor)
result, err := textProcessor.Execute(ctx, input)
```

### 9. MCP (Model Context Protocol) Integration

```go
import (
    "github.com/XiaoConstantine/dspy-go/pkg/tools"
    "github.com/XiaoConstantine/mcp-go/pkg/client"
)

// Connect to MCP server
mcpClient, err := client.NewStdioClient("path/to/mcp-server")

// Register MCP tools
registry := tools.NewInMemoryToolRegistry()
err = tools.RegisterMCPTools(registry, mcpClient)

// Use with ReAct
react := modules.NewReAct(signature, registry, 5)
```

## Multimodal Processing

### 10. Multimodal Processing Patterns

#### Image Analysis
```go
// Create Gemini LLM (supports multimodal)
llm, err := llms.NewGeminiLLM(os.Getenv("GEMINI_API_KEY"), core.ModelGoogleGeminiFlash)

// Multimodal signature
signature := core.NewSignature(
    []core.InputField{
        {Field: core.NewImageField("image", core.WithDescription("The image to analyze"))},
        {Field: core.NewTextField("question", core.WithDescription("Question about the image"))},
    },
    []core.OutputField{
        {Field: core.NewTextField("answer", core.WithDescription("Analysis result"))},
    },
).WithInstruction("Analyze the provided image and answer the given question.")

predictor := modules.NewPredict(signature)
predictor.SetLLM(llm)

// Load image
imageData, err := os.ReadFile("path/to/image.jpg")

// Execute
result, err := predictor.Process(ctx, map[string]interface{}{
    "image":    core.NewImageBlock(imageData, "image/jpeg"),
    "question": "What objects can you see in this image?",
})
```

#### Streaming Multimodal
```go
content := []core.ContentBlock{
    core.NewTextBlock("Please describe this image in detail:"),
    core.NewImageBlock(imageData, "image/jpeg"),
}

streamResp, err := llm.StreamGenerateWithContent(ctx, content)
for chunk := range streamResp.ChunkChannel {
    if chunk.Error != nil {
        log.Printf("Streaming error: %v", chunk.Error)
        break
    }
    fmt.Print(chunk.Content)
}
```

## Workflows and Memory

### 11. Workflow Patterns

#### Chain Workflow
Sequential execution of steps:

```go
workflow := workflows.NewChainWorkflow(store)

workflow.AddStep(&workflows.Step{
    ID: "step1",
    Module: modules.NewPredict(signature1),
})

workflow.AddStep(&workflows.Step{
    ID: "step2",
    Module: modules.NewPredict(signature2),
    RetryConfig: &workflows.RetryConfig{
        MaxAttempts: 3,
        BackoffMultiplier: 2.0,
        InitialBackoff: time.Second,
    },
    Condition: func(state map[string]interface{}) bool {
        return someCondition(state)
    },
})

result, err := workflow.Execute(ctx, inputs)
```

#### Orchestrator
Flexible task decomposition:

```go
orchestrator := agents.NewOrchestrator()

researchTask := agents.NewTask("research", researchModule)
summarizeTask := agents.NewTask("summarize", summarizeModule)

orchestrator.AddTask(researchTask)
orchestrator.AddTask(summarizeTask)

result, err := orchestrator.Execute(ctx, map[string]interface{}{
    "topic": "Climate change impacts",
})
```

### 12. Memory Patterns

#### Buffer Memory
```go
memory := memory.NewBufferMemory(10) // Keep last 10 exchanges
memory.Add(ctx, "user", "Hello, how can you help me?")
memory.Add(ctx, "assistant", "I can answer questions and help with tasks.")

history, err := memory.Get(ctx)
```

#### SQLite Memory
```go
memory := memory.NewSQLiteMemory("conversations.db")
memory.Add(ctx, "user", "Hello")
history, err := memory.Get(ctx)
```

## Advanced Features

### 13. Streaming Support

```go
// Create streaming handler
handler := func(chunk core.StreamChunk) error {
    fmt.Print(chunk.Content)
    return nil
}

// Enable streaming on module
module.SetStreamingHandler(handler)

// Or use with options
result, err := module.Process(ctx, inputs,
    core.WithStreamHandler(handler),
)
```

### 14. Dataset Management

```go
import "github.com/XiaoConstantine/dspy-go/pkg/datasets"

// Automatically download and get path
gsm8kPath, err := datasets.EnsureDataset("gsm8k")

// Load dataset
gsm8kDataset, err := datasets.LoadGSM8K(gsm8kPath)

// Use with optimizer
optimizer := optimizers.NewBootstrapFewShot(gsm8kDataset, metricFunc)
```

### 15. Error Handling Patterns

```go
result, err := module.Process(ctx, inputs)
if err != nil {
    var dspyErr *errors.DSPyError
    if errors.As(err, &dspyErr) {
        switch dspyErr.Code {
        case errors.InvalidInput:
            // Handle invalid input
        case errors.ResourceNotFound:
            // Handle missing resource
        case errors.LLMError:
            // Handle LLM API error
        }
    }
    return fmt.Errorf("module processing failed: %w", err)
}
```

### 16. Tracing and Logging

```go
// Enable execution state tracking
ctx = core.WithExecutionState(context.Background())

// Configure logging
logger := logging.NewLogger(logging.Config{
    Severity: logging.DEBUG,
    Outputs:  []logging.Output{logging.NewConsoleOutput(true)},
})
logging.SetLogger(logger)

// After execution, inspect trace
executionState := core.GetExecutionState(ctx)
steps := executionState.GetSteps("moduleId")
for _, step := range steps {
    fmt.Printf("Step: %s, Duration: %s\n", step.Name, step.Duration)
    fmt.Printf("Prompt: %s\n", step.Prompt)
    fmt.Printf("Response: %s\n", step.Response)
}
```

### 17. Interceptor Patterns

#### Module Interceptors
```go
// Create interceptor
interceptor := func(ctx context.Context, inputs map[string]interface{}, 
    info core.ModuleInfo, next core.ModuleHandler, opts ...core.Option) (map[string]interface{}, error) {
    
    // Pre-processing
    logger.Info("Before module execution")
    
    // Call next handler
    result, err := next(ctx, inputs, opts...)
    
    // Post-processing
    logger.Info("After module execution")
    
    return result, err
}

// Set interceptors on module
module.SetInterceptors([]core.ModuleInterceptor{interceptor})
```

#### Output validation and retry

- **Do not** inject placeholder or synthetic text into module outputs (for example filling empty evaluator `feedback`) to satisfy mandatory-field validation. That hides contract violations and can pollute `consolidated_feedback` / `previous_feedback` on the next refinement round.
- **Do** let `strop/dspy/validation.ValidationInterceptor` return an error when mandatory fields are missing or empty (`ValidateMandatoryFields`, including empty `feedback` on `* - Feedback Analysis` modules). The error propagates to **`RetryModuleInterceptor`** configured in `strop/dspy/factory/interceptor_setup.go` (`AddInterceptors`), which re-runs the module call within its retry budget. Product validators in `internal/dspy/validation/` (PostGenerator, section isolation) register on top of this.
- **Semantics:** Empty `feedback` is not "all criteria met"; it is invalid evaluator output. After retries are exhausted, the run should fail clearly rather than continue with fabricated checklist text.

#### XML Interceptor for Structured Output

**CRITICAL**: Structured output parsing **REQUIRES** XML interceptors to be configured. Without interceptors, LLM responses containing XML will be returned as raw strings in a `response` field, requiring manual parsing.

**How XML Interceptors Work:**
1. **XMLFormatModuleInterceptor**: Injects XML formatting instructions into prompts, guiding the LLM to produce structured XML output
2. **XMLParseModuleInterceptor**: Parses XML responses and extracts fields directly into the outputs map according to the module's signature

**Enabling on Predict Modules:**
```go
import "github.com/XiaoConstantine/dspy-go/pkg/interceptors"

// Basic configuration
xmlConfig := interceptors.DefaultXMLConfig()
predict := modules.NewPredict(signature).WithXMLOutput(xmlConfig)

// Custom configuration
customConfig := interceptors.DefaultXMLConfig().
    WithStrictParsing(true).           // Require all fields
    WithFallback(false).               // Don't fallback to text parsing
    WithValidation(true).               // Validate XML syntax
    WithMaxDepth(10).                   // Limit nesting depth
    WithMaxSize(1024*1024).            // 1MB size limit
    WithTimeout(30*time.Second).       // Parse timeout
    WithPreserveWhitespace(false)      // Trim whitespace

predict.WithXMLOutput(customConfig)
```

**Enabling on ChainOfThought Modules:**
Since `ChainOfThought` wraps a `Predict` module internally, access the underlying `Predict` module:

```go
// Create ChainOfThought module
cot := modules.NewChainOfThought(signature)

// Enable XML output on the underlying Predict module
xmlConfig := interceptors.DefaultXMLConfig()
cot.Predict.WithXMLOutput(xmlConfig)

// Now XML responses will be automatically parsed
result, err := cot.Process(ctx, inputs)
// result["literal_translation"] will be directly available (not wrapped in XML string)
```

**Configuration Presets:**
```go
// Default: Balanced settings for general use
xmlConfig := interceptors.DefaultXMLConfig()

// Strict: Strict parsing, no fallback, all fields required
xmlConfig := interceptors.StrictXMLConfig()

// Flexible: Allows missing fields, has fallback to text parsing
xmlConfig := interceptors.FlexibleXMLConfig()

// Performant: Optimized for speed, minimal validation
xmlConfig := interceptors.PerformantXMLConfig()

// Secure: Enhanced security restrictions, strict size limits
xmlConfig := interceptors.SecureXMLConfig()
```

**What Happens Without XML Interceptors:**
```go
// Without XML interceptors enabled
module := modules.NewChainOfThought(signature)
result, err := module.Process(ctx, inputs)

// Result will contain raw XML string:
// result["response"] = "<response><literal_translation>...</literal_translation>...</response>"
// You must manually parse XML to extract fields
```

**What Happens With XML Interceptors:**
```go
// With XML interceptors enabled
module := modules.NewChainOfThought(signature)
module.Predict.WithXMLOutput(interceptors.DefaultXMLConfig())
result, err := module.Process(ctx, inputs)

// Result will contain parsed fields directly:
// result["literal_translation"] = "..."
// result["semantic_translation"] = "..."
// result["detected_language"] = "Spanish"
// result["proverb_meaning"] = "..."
// Fields are automatically extracted from XML structure
```

**Example: Generator Module Configuration**
```go
// In module initialization code
func initializeGenerator(moduleFactory func() (*modules.ChainOfThought, error)) (*modules.ChainOfThought, error) {
    module, err := moduleFactory()
    if err != nil {
        return nil, err
    }
    
    // Enable XML output parsing for structured responses
    xmlConfig := interceptors.DefaultXMLConfig()
    module.Predict.WithXMLOutput(xmlConfig)
    
    // Set LLM and other configuration
    module.SetLLM(llmInstance)
    
    return module, nil
}
```

**Best Practices:**
- **ALWAYS** enable XML interceptors on generator modules that require structured output
- **USE** `DefaultXMLConfig()` for most cases, or `StrictXMLConfig()` for production
- **ENABLE** strict parsing in production for data quality assurance
- **CONFIGURE** appropriate size limits to prevent memory issues
- **REMEMBER** that XML interceptors work automatically - no manual XML parsing needed in your code
- **NEVER** implement fallback logic to manually parse XML or check nested response fields
- **ALWAYS** expect fields at the top level of outputs map when XML interceptors are enabled
- **FAIL FAST** if required fields are missing - don't try alternative parsing strategies

## Best Practices and Testing

### 18. Best Practices

#### Configuration Management
- **ALWAYS** use environment variables for API keys
- **ALWAYS** set appropriate timeouts for LLM requests
- **ALWAYS** handle errors gracefully
- **NEVER** hardcode sensitive information

#### Module Design
- **ALWAYS** define clear signatures with descriptions
- **ALWAYS** validate inputs match signature
- **CONSIDER** using typed signatures for type safety
- **AVOID** modules with too many inputs/outputs
- **ALWAYS** enable XML interceptors on modules that require structured output parsing
- **NEVER** manually parse XML responses - use XML interceptors instead
- **NEVER** implement fallback logic to check nested response fields or manually parse XML
- **ALWAYS** expect structured output fields at the top level when XML interceptors are enabled
- **FAIL FAST** if required fields are missing - don't implement alternative parsing strategies

#### Performance
- **USE** Parallel module for batch processing
- **IMPLEMENT** proper retry logic for transient failures
- **MONITOR** token usage and API rate limits
- **CACHE** results when appropriate

#### Error Handling
- **ALWAYS** wrap errors with context
- **ALWAYS** check for nil before using results
- **USE** structured error types from errors package
- **PROVIDE** meaningful error messages

### 19. Common Anti-Patterns to Avoid

#### ❌ DON'T
```go
// Don't bypass modules for LLM calls
llm.Generate(ctx, "prompt") // WRONG - use modules instead

// Don't create modules without signatures
module := &MyModule{} // WRONG - must have signature

// Don't hardcode API keys
llm := llms.NewAnthropicLLM("hardcoded-key", ...) // WRONG

// Don't ignore errors
result, _ := module.Process(ctx, inputs) // WRONG

// Don't use modules without setting LLM
module := modules.NewPredict(signature)
result, err := module.Process(ctx, inputs) // May fail if no default LLM

// Don't expect structured output without XML interceptors
module := modules.NewChainOfThought(signature)
result, err := module.Process(ctx, inputs)
literal := result["literal_translation"] // WRONG - will be nil, XML is in result["response"] as string

// Don't implement fallback logic for parsing structured output
if value, ok := outputs["field"]; ok {
    // use value
} else if response, hasResponse := outputs["response"]; hasResponse {
    // WRONG - don't check nested response fields, XML interceptors should handle this
    if responseMap, isMap := response.(map[string]interface{}); isMap {
        value = responseMap["field"] // WRONG - fallback logic
    }
}
```

#### ✅ DO
```go
// Always use modules for LLM interactions
module := modules.NewPredict(signature)
result, err := module.Process(ctx, inputs)

// Always define signatures
signature := core.NewSignature(inputs, outputs)
module := modules.NewPredict(signature)

// Always use environment variables or config
apiKey := os.Getenv("ANTHROPIC_API_KEY")
llm, err := llms.NewAnthropicLLM(apiKey, core.ModelAnthropicSonnet)

// Always handle errors
result, err := module.Process(ctx, inputs)
if err != nil {
    return fmt.Errorf("processing failed: %w", err)
}

// Always configure LLM
core.SetDefaultLLM(llm)
// OR
module.SetLLM(llm)

// Always enable XML interceptors for structured output
module := modules.NewChainOfThought(signature)
module.Predict.WithXMLOutput(interceptors.DefaultXMLConfig())
result, err := module.Process(ctx, inputs)
literal := result["literal_translation"] // CORRECT - automatically parsed from XML

// Always expect fields at top level when XML interceptors are enabled
if value, ok := outputs["field"]; ok {
    // CORRECT - field is at top level, XML interceptor parsed it
    useValue(value)
} else {
    // CORRECT - fail fast if field is missing
    return fmt.Errorf("required field 'field' is missing")
}
```

### 20. Testing Patterns

#### Unit Testing with Mocks
```go
type MockLLM struct{}

func (m *MockLLM) Generate(ctx context.Context, prompt string, opts ...core.GenerateOption) (*core.LLMResponse, error) {
    return &core.LLMResponse{Content: "Mock response"}, nil
}

// Use mock in tests
mockLLM := &MockLLM{}
module.SetLLM(mockLLM)
result, err := module.Process(ctx, inputs)
```

#### Integration Testing
```go
func TestModuleIntegration(t *testing.T) {
    // Use real LLM with test API key
    llm, err := llms.NewAnthropicLLM(testAPIKey, core.ModelAnthropicSonnet)
    require.NoError(t, err)
    
    module := modules.NewPredict(signature)
    module.SetLLM(llm)
    
    result, err := module.Process(ctx, testInputs)
    assert.NoError(t, err)
    assert.NotNil(t, result)
}
```

## Summary

### 21. Key Takeaways

1. **DSPy-Go is a native Go library** - no external services required
2. **Modules are the core abstraction** - always use modules for LLM interactions
3. **Signatures define contracts** - always define clear input/output signatures
4. **LLMs are configured as clients** - set default or per-module LLMs
5. **Optimizers improve performance** - use optimizers to tune prompts automatically
6. **Tools extend capabilities** - use tool registries for ReAct and custom workflows
7. **Programs compose modules** - build complex workflows with programs
8. **Handle errors properly** - use structured error types and context
9. **Enable tracing for debugging** - use execution state for observability
10. **Test with mocks and integration** - mock LLMs for unit tests, use real LLMs for integration

## Major Features

### ✅ Module System
- **Predict**: Basic prediction module
- **ChainOfThought**: Step-by-step reasoning
- **ReAct**: Reasoning and Acting with tools
- **Refine**: Quality improvement through multiple attempts
- **Parallel**: Concurrent batch processing
- **MultiChainComparison**: Multi-perspective reasoning

### ✅ Optimizers
- **BootstrapFewShot**: Automatic example selection
- **MIPRO**: Multi-step interactive prompt optimization
- **SIMBA**: Stochastic introspective learning
- **GEPA**: Multi-objective evolutionary optimization
- **COPRO**: Collaborative prompt optimization

### ✅ Tool Integration
- **Basic Registry**: Simple tool registration and execution
- **Smart Registry**: Bayesian tool selection with performance tracking
- **Tool Chaining**: Sequential execution with data transformation
- **Dependency Resolution**: Automatic execution planning
- **Parallel Execution**: High-performance concurrent tool execution
- **Tool Composition**: Reusable composite tools

### ✅ Multimodal Support
- **Image Analysis**: Analyze and describe images
- **Vision Q&A**: Ask questions about visual content
- **Multimodal Chat**: Interactive conversations with images
- **Streaming Multimodal**: Real-time multimodal processing

### ✅ Workflow Patterns
- **Chain Workflow**: Sequential step execution
- **Orchestrator**: Flexible task decomposition
- **Memory**: Conversation history management

### ✅ Advanced Features
- **Streaming**: Incremental output processing
- **Tracing**: Detailed execution tracking
- **Interceptors**: Pre/post-processing hooks
- **XML Output**: Structured XML responses
- **Dataset Management**: Built-in dataset support

Remember: You're building **native Go applications** that use DSPy-Go as a library, not managing external services.
