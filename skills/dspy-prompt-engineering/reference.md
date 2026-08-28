# DSPy prompt engineering reference (cursor-packs)

Bias mitigation, CoT, signature templates, and longer prompt guidance. Load from `dspy-prompt-engineering` when writing or revising module prompts.

**Compact contract:** [SKILL.md](SKILL.md). XML alignment: `dspy-xml-structured-output`.

Product-specific prompt invariants stay in the consumer under a project prefix such as `pipelines-x-*`.

---


# DSPy Prompt Engineering and LLM Guidelines

This document outlines best practices for crafting effective system prompts for DSPy modules, designing DSPy signatures, managing LLM cognitive biases, and optimizing module behavior through prompt engineering and DSPy optimization techniques.

## Table of Contents

### 📚 Foundation & Theory
- [1. Understanding LLM Cognitive Biases](#1-understanding-llm-cognitive-biases) (Line 68)
  - [Common LLM Biases and Weaknesses](#common-llm-biases-and-weaknesses) (Line 70)

### 🎯 DSPy Core Concepts
- [2. System Prompt Best Practices for DSPy](#2-system-prompt-best-practices-for-dspy) (Line 84)
  - [DSPy Signature and Instruction Pattern](#dspy-signature-and-instruction-pattern) (Line 86)
  - [Clear Role Definition](#clear-role-definition) (Line 121)
  - [Field Descriptions in Signatures](#field-descriptions-in-signatures) (Line 136)
  - [Bias Mitigation Strategies](#bias-mitigation-strategies) (Line 152)
  - [Chain-of-Thought Prompting](#chain-of-thought-prompting) (Line 167)

### 📋 Templates & Examples
- [3. DSPy Signature and Prompt Templates](#3-dspy-signature-and-prompt-templates) (Line 189)
  - [Evaluation Module Template](#evaluation-module-template) (Line 191)
  - [Generation Module Template](#generation-module-template) (Line 242)
  - [Analysis Module Template](#analysis-module-template) (Line 290)
  - [Multi-Step Workflow Template](#multi-step-workflow-template) (Line 330)

### ⚙️ Advanced Techniques
- [4. Advanced DSPy Techniques](#4-advanced-dspy-techniques) (Line 366)
  - [Using ChainOfThought Module](#using-chainofthought-module) (Line 368)
  - [Multi-Step Reasoning in Instructions](#multi-step-reasoning-in-instructions) (Line 385)
  - [Error Prevention in Instructions](#error-prevention-in-instructions) (Line 421)
  - [Context Awareness](#context-awareness) (Line 436)
  - [DSPy Optimization Strategies](#dspy-optimization-strategies) (Line 451)
  - [Performance Optimization in Instructions](#performance-optimization-in-instructions) (Line 476)
  - [Field-Level Guidance](#field-level-guidance) (Line 489)

### 🧪 Testing & Validation
- [5. DSPy Module Testing and Validation](#5-dspy-module-testing-and-validation) (Line 505)
  - [Module Testing Framework](#module-testing-framework) (Line 507)
  - [Evaluation Metrics](#evaluation-metrics) (Line 556)
  - [Bias Detection in Prompts](#bias-detection-in-prompts) (Line 586)
  - [Module Performance Testing](#module-performance-testing) (Line 634)
  - [Signature Validation](#signature-validation) (Line 680)

### ✅ Best Practices & Guidelines
- [6. DSPy Prompt Engineering Best Practices](#6-dspy-prompt-engineering-best-practices) (Line 732)
  - [Signature Design Principles](#signature-design-principles) (Line 734)
  - [DSPy Optimization Best Practices](#dspy-optimization-best-practices) (Line 760)
  - [Testing and Validation](#testing-and-validation) (Line 779)
  - [Common Pitfalls to Avoid](#common-pitfalls-to-avoid) (Line 794)

### 🔗 Integration & Workflows
- [7. DSPy Integration Patterns](#7-dspy-integration-patterns) (Line 827)
  - [Module Composition](#module-composition) (Line 829)
  - [Using DSPy Optimizers](#using-dspy-optimizers) (Line 868)
  - [Context Passing Between Modules](#context-passing-between-modules) (Line 903)
  - [Error Handling in Modules](#error-handling-in-modules) (Line 942)
  - [Module Reusability](#module-reusability) (Line 975)

### 📝 Summary
- [Key Takeaways](#key-takeaways) (Line 1015)

## 1. Understanding LLM Cognitive Biases

### Common LLM Biases and Weaknesses

**Bias Towards AI-Generated Content**: LLMs may favor AI-generated content over human inputs, potentially leading to implicit discrimination against human-generated information.

**Susceptibility to Training Data Biases**: Reflects biases present in training data, affecting reasoning and decision-making processes.

**Lack of Semantic Grounding**: May produce plausible but incorrect outputs due to insufficient understanding of context or meaning.

**Confirmation Bias**: Tendency to seek information that confirms existing beliefs rather than exploring alternatives.

**Anchoring Bias**: Over-reliance on first information encountered, potentially limiting exploration of other options.

**Availability Heuristic**: Overweighting easily accessible information while undervaluing less accessible but potentially more relevant data.

## 2. System Prompt Best Practices for DSPy

### DSPy Signature and Instruction Pattern

In DSPy, system prompts are attached to signatures using `.WithInstruction()`. The signature defines the structured input/output, while the instruction provides the role and behavior guidance.

```go
import (
    "github.com/XiaoConstantine/dspy-go/pkg/core"
    "github.com/XiaoConstantine/dspy-go/pkg/modules"
)

// Step 1: Define the signature with input/output fields
signature := core.NewSignature(
    []core.InputField{
        {Field: core.NewField("content", core.WithDescription("Content to evaluate"))},
        {Field: core.NewField("context", core.WithDescription("Evaluation context"))},
    },
    []core.OutputField{
        {Field: core.NewField("score", core.WithDescription("Score from 0.0 to 10.0"))},
        {Field: core.NewField("feedback", core.WithDescription("Detailed feedback"))},
    },
)

// Step 2: Attach system prompt as instruction
systemPrompt := `You are a specialized evaluator with expertise in content analysis.
Your primary role is to:
- Analyze content critically and objectively
- Provide accurate, well-structured evaluations
- Acknowledge limitations and uncertainties`

signature = signature.WithInstruction(systemPrompt)

// Step 3: Create Predict module from signature
predict := modules.NewPredict(signature)
```

### Clear Role Definition

```go
// Define the module's role and capabilities clearly in the instruction
systemPrompt := `You are a specialized research assistant with access to advanced tools.
Your primary role is to:
- Conduct thorough research using available tools
- Analyze information critically and objectively
- Provide accurate, well-sourced responses
- Acknowledge limitations and uncertainties`

// Attach to signature
signature = signature.WithInstruction(systemPrompt)
```

### Field Descriptions in Signatures

Field descriptions in signatures guide the LLM on what each field represents. They work together with system prompts:

```go
signature := core.NewSignature(
    []core.InputField{
        {Field: core.NewField("original_text", core.WithDescription("Original Spanish text to translate"))},
        {Field: core.NewField("previous_feedback", core.WithDescription("Optional feedback from previous version for iterative improvement"))},
    },
    []core.OutputField{
        {Field: core.NewField("translation", core.WithDescription("English translation that preserves cultural meaning and nuance"))},
    },
)
```

### Bias Mitigation Strategies

```go
// Include bias mitigation in system prompts
systemPrompt := `BIAS MITIGATION REQUIREMENTS:
- Always consider multiple perspectives when analyzing information
- Explicitly state when information comes from AI vs human sources
- Question assumptions and seek contradictory evidence
- Use chain-of-thought reasoning to make your process transparent
- Flag potential biases in your analysis
- Admit uncertainty when information is incomplete`

signature = signature.WithInstruction(systemPrompt)
```

### Chain-of-Thought Prompting

DSPy provides built-in ChainOfThought modules, but you can also encourage reasoning in your instructions:

```go
// Encourage transparent reasoning in instruction
systemPrompt := `REASONING PROCESS:
Before providing your answer, you must:
1. THINK: Analyze the problem and available information
2. PLAN: Outline your approach step-by-step
3. EXECUTE: Process the information systematically
4. VERIFY: Check results for accuracy and bias
5. REFLECT: Consider what could have been done better

Always show your reasoning process in your response.`

signature = signature.WithInstruction(systemPrompt)

// Alternatively, use DSPy's ChainOfThought module
chainOfThought := modules.NewChainOfThought(signature)
```

### Objective recitation before execution (generators — mandatory)

**Problem:** Models often plan *where* content goes (scene allocation, field order) without restating *voice* and *success criteria*. That produces smooth, correct-structure prose that fails the job (e.g. CEO-manual fairness copy instead of street wisdom).

**Rule:** For every **ChainOfThought generator** built via `dspy.CreateGeneratorModule` / `GeneratorConfig`, the model must open `<rationale>` with **three labeled lines** before any other output field:

1. **VOICE:** Who you are on this job (from `Persona` + OBJECTIVES).
2. **MUST:** Non-negotiable outcome for this pass.
3. **ANTI_PATTERN:** Main failure mode to refuse (e.g. HR brochure, inventing facts, asset-meta lesson).

Then continue with job-specific planning (action-chain bullets, structured labels, `phase_plan`). If reader-facing prose drifts from VOICE/MUST, **revise prose** — do not weaken rationale to match weak prose.

**Where it is enforced in code (single source of truth):**

| Layer | Location |
|-------|----------|
| Global prompt block | `strop/dspy/signature_helpers.go` → `SharedInstructions.GeneratorObjectiveRecitation` (appended in `CreateGeneratorModule`) |
| Rationale field descriptions | `strop/dspy/constants.go` → `rationaleActionChainRules`, `RationaleDescriptionWithContext` |
| Default persona | `strop/dspy/persona.go` → `DefaultGeneratorPersona` |

**Job-specific longer plans:** Some jobs extend rationale after the three objective lines (e.g. sayings post skim: **12 lines** = VOICE/MUST/ANTI_PATTERN + nine scene-allocation labels in `postStructuredRationaleRules`). Do not duplicate the global block in `{job}_modules.go`; use `RationaleDescriptionWithExtra` only for emit-order or length exceptions.

**Do not** paste long rationale instructions into every `{job}_modules.go` — see `.cursor/skills/strop-pipeline-pattern/SKILL.md` §6 and `.cursor/skills/dspy-prompt-engineering/SKILL.md`.

```go
// Rationale field on generator signatures — use centralized helper
{Field: newOutputField(FieldRationale, core.WithDescription(
    dspy.RationaleDescriptionWithContext("Quote extraction for this chapter"),
))}

// Module-specific emit-order only — not a second copy of VOICE/MUST/ANTI_PATTERN
dspy.RationaleDescriptionWithExtra("Chapter boundaries", "Emit rationale only after </chapters>.")
```

**Evaluators:** Chained evaluators use action-chain rationale for scoring reasoning; they do **not** get `GeneratorObjectiveRecitation` (evaluators are not created via `CreateGeneratorModule`).

## 3. DSPy Signature and Prompt Templates

### Evaluation Module Template

This template shows how to create an evaluation module with a structured signature and role-specific prompt:

```go
// Define evaluation signature
func NewTextEvaluationSignature() core.Signature {
    return core.NewSignature(
        []core.InputField{
            {Field: core.NewField("content", core.WithDescription("Content to evaluate"))},
            {Field: core.NewField("context", core.WithDescription("Evaluation context (original text, saying ID, etc.)"))},
        },
        []core.OutputField{
            {Field: core.NewField("score", core.WithDescription("Score from 0.0 to 10.0"))},
            {Field: core.NewField("style", core.WithDescription("Style descriptor (e.g., formal/professional, spiritual/metaphorical)"))},
            {Field: core.NewField("feedback", core.WithDescription("Detailed feedback"))},
        },
    )
}

// Create evaluation module with role-specific prompt
func CreateTextEvaluationModule(roleName, systemPrompt string) (*modules.Predict, error) {
    signature := NewTextEvaluationSignature()
    signature = signature.WithInstruction(systemPrompt)
    predict := modules.NewPredict(signature)
    predict.WithName(roleName)
    return predict, nil
}

// Example: LinkedIn Professional Evaluator
linkedInPrompt := `You are a LinkedIn Professional Evaluator specializing in business content and professional communication.

Your expertise includes:
- LinkedIn platform best practices and audience expectations
- Professional tone and business communication standards
- Industry-specific terminology and conventions
- Professional networking and career development content
- Business impact and strategic value assessment

When evaluating translations, focus on:
1. Professional appropriateness for LinkedIn's business audience
2. Tone and language that resonates with professionals
3. Clarity and conciseness suitable for busy professionals
4. Business relevance and strategic value
5. Professional credibility and authority

Provide scores from 0.0 to 10.0, style analysis, and detailed feedback that helps improve professional impact.`

module, _ := CreateTextEvaluationModule("LinkedInProfessional", linkedInPrompt)
```

### Generation Module Template

This template shows how to create a generation module (e.g., translation, explanation):

```go
// Define translation generation signature
func NewTranslationGenerationSignature() core.Signature {
    return core.NewSignature(
        []core.InputField{
            {Field: core.NewField("original_text", core.WithDescription("Original Spanish text to translate"))},
            {Field: core.NewField("previous_feedback", core.WithDescription("Optional feedback from previous version"))},
            {Field: core.NewField("version", core.WithDescription("Version number for this translation"))},
        },
        []core.OutputField{
            {Field: core.NewField("translation", core.WithDescription("English translation of the Spanish text"))},
        },
    )
}

// Create translation module
func CreateTranslationModule(systemPrompt string) (*modules.Predict, error) {
    signature := NewTranslationGenerationSignature()
    signature = signature.WithInstruction(systemPrompt)
    predict := modules.NewPredict(signature)
    predict.WithName("TranslationGenerator")
    return predict, nil
}

// Example: Translation system prompt
translationPrompt := `You are a professional translator specializing in Spanish to English translation.

TRANSLATION PRINCIPLES:
1. Preserve the original meaning and cultural context
2. Maintain the tone and style of the original text
3. Ensure natural, fluent English that reads well
4. Consider cultural nuances and idiomatic expressions
5. Provide translations suitable for professional audiences

When translating:
- Focus on meaning preservation over literal translation
- Adapt cultural references appropriately
- Maintain the original's emotional tone
- Ensure clarity and readability in English
- Consider the target audience (LinkedIn professionals)`

module, _ := CreateTranslationModule(translationPrompt)
```

### Analysis Module Template

For analytical tasks with structured reasoning:

```go
// Analysis signature with multiple output fields
analysisSignature := core.NewSignature(
    []core.InputField{
        {Field: core.NewField("data", core.WithDescription("Data to analyze"))},
        {Field: core.NewField("question", core.WithDescription("Analysis question or objective"))},
    },
    []core.OutputField{
        {Field: core.NewField("analysis", core.WithDescription("Detailed analysis"))},
        {Field: core.NewField("confidence", core.WithDescription("Confidence level (0.0 to 1.0)"))},
        {Field: core.NewField("limitations", core.WithDescription("Acknowledged limitations and uncertainties"))},
    },
)

analysisPrompt := `You are an analytical assistant specializing in data interpretation.

ANALYSIS FRAMEWORK:
1. UNDERSTAND: What is the question or problem?
2. GATHER: What data and information is available?
3. ANALYZE: Apply appropriate analytical methods
4. SYNTHESIZE: Combine insights from multiple sources
5. CONCLUDE: Present findings with confidence levels

CRITICAL THINKING REQUIREMENTS:
- Question assumptions and initial hypotheses
- Look for contradictory evidence
- Consider alternative explanations
- Assess the quality and reliability of data
- Use statistical thinking when appropriate

Always acknowledge limitations and uncertainties in your analysis.`

analysisSignature = analysisSignature.WithInstruction(analysisPrompt)
analysisModule := modules.NewChainOfThought(analysisSignature) // Use ChainOfThought for reasoning
```

### Multi-Step Workflow Template

For complex workflows that require multiple steps:

```go
// Step 1: Research signature
researchSignature := core.NewSignature(
    []core.InputField{
        {Field: core.NewField("topic", core.WithDescription("Topic to research"))},
    },
    []core.OutputField{
        {Field: core.NewField("findings", core.WithDescription("Research findings"))},
        {Field: core.NewField("sources", core.WithDescription("Information sources"))},
    },
)

researchPrompt := `You are a research assistant. Conduct thorough research, cite sources, and acknowledge limitations.`
researchModule := modules.NewPredict(researchSignature.WithInstruction(researchPrompt))

// Step 2: Analysis signature (uses research output)
analysisSignature := core.NewSignature(
    []core.InputField{
        {Field: core.NewField("findings", core.WithDescription("Research findings from previous step"))},
    },
    []core.OutputField{
        {Field: core.NewField("synthesis", core.WithDescription("Synthesized analysis"))},
    },
)

analysisPrompt := `You are an analyst. Synthesize research findings into coherent insights.`
analysisModule := modules.NewChainOfThought(analysisSignature.WithInstruction(analysisPrompt))

// Combine in a workflow (pseudocode)
// workflow := researchModule -> analysisModule
```

## 4. Advanced DSPy Techniques

### Using ChainOfThought Module

DSPy provides built-in ChainOfThought modules for explicit reasoning:

```go
// Standard Predict module
signature := core.NewSignature(inputs, outputs)
signature = signature.WithInstruction(systemPrompt)
predict := modules.NewPredict(signature)

// ChainOfThought module (encourages step-by-step reasoning)
chainOfThought := modules.NewChainOfThought(signature)

// ChainOfThought automatically adds reasoning steps to the prompt
// The LLM will show its thinking process before providing the answer
```

### Multi-Step Reasoning in Instructions

You can also encourage reasoning explicitly in your instructions:

```go
systemPrompt := `REASONING PROTOCOL:
For every task, follow this process:

STEP 1: UNDERSTANDING
- What exactly is being asked?
- What context is provided?
- What constraints exist?

STEP 2: PLANNING
- What approach should I take?
- What information do I need?
- What could go wrong?

STEP 3: EXECUTION
- Process the information systematically
- Monitor for errors or biases
- Adjust approach if needed

STEP 4: VERIFICATION
- Check results for accuracy
- Look for missing information
- Consider alternative interpretations

STEP 5: COMMUNICATION
- Present findings clearly
- Acknowledge limitations
- Suggest next steps`

signature = signature.WithInstruction(systemPrompt)
```

### Error Prevention in Instructions

```go
systemPrompt := `ERROR PREVENTION CHECKLIST:
Before finalizing any response:
✓ Are my conclusions supported by the data?
✓ Have I considered alternative explanations?
✓ Am I making any unwarranted assumptions?
✓ Have I acknowledged limitations and uncertainties?
✓ Is my reasoning transparent and logical?
✓ Have I validated the output format matches the signature?`

signature = signature.WithInstruction(systemPrompt)
```

### Context Awareness

```go
systemPrompt := `CONTEXT AWARENESS:
- Always consider the user's background and needs
- Adapt your communication style appropriately
- Provide relevant examples and analogies
- Consider the broader implications of your recommendations
- Be sensitive to potential cultural or personal biases

Use the context field in your input to understand the specific situation and requirements.`

signature = signature.WithInstruction(systemPrompt)
```

### DSPy Optimization Strategies

DSPy provides optimizers that automatically improve prompts and examples:

```go
import (
    "github.com/XiaoConstantine/dspy-go/pkg/optimizers"
)

// BootstrapFewShot: Automatically generates few-shot examples
optimizer := optimizers.NewBootstrapFewShot(
    optimizers.WithMaxLabeledData(10),
    optimizers.WithMaxBootstrappedData(20),
)

// MIPRO: Multi-prompt optimization
miproOptimizer := optimizers.NewMIPRO(
    optimizers.WithNumCandidates(4),
    optimizers.WithInitTemperature(1.0),
)

// Use optimizer to improve module
optimizedModule := optimizer.Optimize(module, trainingSet, metric)
```

### Performance Optimization in Instructions

```go
systemPrompt := `EFFICIENT REASONING:
- Focus on the most relevant information
- Avoid redundant processing
- Prioritize high-impact analysis
- Be concise while maintaining accuracy
- Structure your response according to the signature fields`

signature = signature.WithInstruction(systemPrompt)
```

### Field-Level Guidance

Use field descriptions to guide the LLM on specific outputs:

```go
signature := core.NewSignature(
    []core.InputField{
        {Field: core.NewField("content", core.WithDescription("Content to evaluate - focus on clarity and relevance"))},
    },
    []core.OutputField{
        {Field: core.NewField("score", core.WithDescription("Score from 0.0 to 10.0 - be precise and justify your rating"))},
        {Field: core.NewField("feedback", core.WithDescription("Detailed feedback - be specific, actionable, and constructive"))},
    },
)
```

## 5. DSPy Module Testing and Validation

### Module Testing Framework

Test DSPy modules with validation sets and metrics:

```go
import (
    "github.com/XiaoConstantine/dspy-go/pkg/core"
)

// Define test cases
type TestCase struct {
    Name            string
    Input           map[string]interface{}
    ExpectedOutput  map[string]interface{}
    ExpectedScore   float64 // For evaluation modules
}

// Test module with validation set
func testModule(module *modules.Predict, testCases []TestCase) error {
    for _, testCase := range testCases {
        // Create input from test case
        input := core.NewExample(
            testCase.Input,
            testCase.ExpectedOutput,
        )
        
        // Run module
        result, err := module.Forward(input)
        if err != nil {
            return fmt.Errorf("module failed for test case %s: %w", testCase.Name, err)
        }
        
        // Validate output
        if !validateOutput(result, testCase.ExpectedOutput) {
            return fmt.Errorf("module output mismatch for test case: %s", testCase.Name)
        }
    }
    return nil
}

// Validate output structure and values
func validateOutput(actual, expected map[string]interface{}) bool {
    // Check structure matches signature
    // Validate key fields
    // Compare values (with tolerance for floats)
    return true
}
```

### Evaluation Metrics

Define metrics to evaluate module performance:

```go
// Define evaluation metric
func accuracyMetric(example *core.Example, prediction map[string]interface{}, trace *core.Trace) float64 {
    expected := example.Outputs
    actual := prediction
    
    // Compare expected vs actual
    if expected["score"] == actual["score"] {
        return 1.0
    }
    
    // For continuous values, use tolerance
    expectedScore := expected["score"].(float64)
    actualScore := actual["score"].(float64)
    if math.Abs(expectedScore-actualScore) < 0.5 {
        return 0.5 // Partial credit
    }
    
    return 0.0
}

// Use metric with optimizer
optimizer := optimizers.NewBootstrapFewShot()
optimizedModule := optimizer.Optimize(module, trainingSet, accuracyMetric)
```

### Bias Detection in Prompts

```go
// Check for potential bias in system prompts
func detectBiasInPrompt(prompt string) []BiasWarning {
    warnings := []BiasWarning{}
    
    // Check for absolute language
    if strings.Contains(prompt, "always") || strings.Contains(prompt, "never") {
        warnings = append(warnings, BiasWarning{
            Type: "absolute_language",
            Message: "Avoid absolute language that may prevent flexible thinking",
        })
    }
    
    // Check for bias towards specific sources
    if strings.Contains(prompt, "prefer") || strings.Contains(prompt, "favor") {
        warnings = append(warnings, BiasWarning{
            Type: "source_bias",
            Message: "Ensure balanced consideration of all information sources",
        })
    }
    
    // Check for gender bias
    if strings.Contains(prompt, "he should") || strings.Contains(prompt, "she should") {
        warnings = append(warnings, BiasWarning{
            Type: "gender_bias",
            Message: "Use gender-neutral language in prompts",
        })
    }
    
    // Check for cultural bias
    if strings.Contains(prompt, "western") || strings.Contains(prompt, "eastern") {
        warnings = append(warnings, BiasWarning{
            Type: "cultural_bias",
            Message: "Avoid cultural assumptions in prompts",
        })
    }
    
    return warnings
}

type BiasWarning struct {
    Type    string
    Message string
}
```

### Module Performance Testing

Test module performance with metrics:

```go
// Test module performance
func testModulePerformance(module *modules.Predict, testSet []*core.Example, metric func(*core.Example, map[string]interface{}, *core.Trace) float64) PerformanceMetrics {
    metrics := PerformanceMetrics{}
    
    for _, example := range testSet {
        start := time.Now()
        
        // Run module
        result, trace, err := module.ForwardWithTrace(example)
        if err != nil {
            metrics.ErrorCount++
            continue
        }
        
        duration := time.Since(start)
        metrics.TotalTime += duration
        
        // Calculate metric score
        score := metric(example, result, trace)
        metrics.TotalScore += score
        metrics.SuccessCount++
    }
    
    metrics.AverageTime = metrics.TotalTime / time.Duration(len(testSet))
    metrics.AverageScore = metrics.TotalScore / float64(metrics.SuccessCount)
    metrics.SuccessRate = float64(metrics.SuccessCount) / float64(len(testSet))
    
    return metrics
}

type PerformanceMetrics struct {
    TotalTime       time.Duration
    AverageTime      time.Duration
    TotalScore      float64
    AverageScore    float64
    SuccessCount    int
    ErrorCount      int
    SuccessRate     float64
}
```

### Signature Validation

Validate that signatures are well-designed:

```go
// Validate signature design
func validateSignature(signature core.Signature) []ValidationWarning {
    warnings := []ValidationWarning{}
    
    inputs := signature.InputFields()
    outputs := signature.OutputFields()
    
    // Check input fields have descriptions
    for _, input := range inputs {
        if input.Field.Description() == "" {
            warnings = append(warnings, ValidationWarning{
                Type: "missing_description",
                Field: input.Field.Name(),
                Message: "Input fields should have clear descriptions",
            })
        }
    }
    
    // Check output fields have descriptions
    for _, output := range outputs {
        if output.Field.Description() == "" {
            warnings = append(warnings, ValidationWarning{
                Type: "missing_description",
                Field: output.Field.Name(),
                Message: "Output fields should have clear descriptions",
            })
        }
    }
    
    // Check for reasonable number of fields
    if len(inputs) > 10 {
        warnings = append(warnings, ValidationWarning{
            Type: "too_many_inputs",
            Message: "Consider simplifying signature with fewer input fields",
        })
    }
    
    return warnings
}

type ValidationWarning struct {
    Type    string
    Field   string
    Message string
}
```

## 6. DSPy Prompt Engineering Best Practices

### Signature Design Principles

**Clear Field Descriptions**:
- Use clear, unambiguous descriptions for all input and output fields
- Define technical terms and concepts in field descriptions
- Provide context about expected formats and ranges
- Avoid vague or abstract field descriptions

**Structured Input/Output**:
- Design signatures that match your actual use case
- Use appropriate field types (string, number, boolean, etc.)
- Group related fields logically
- Keep signatures focused - avoid too many fields

**Bias Mitigation in Instructions**:
- Include explicit bias prevention strategies in system prompts
- Use inclusive language and examples
- Encourage consideration of multiple perspectives
- Provide frameworks for critical thinking

**Instruction Clarity**:
- Write clear, specific instructions that guide behavior
- Define the role and expertise clearly
- Provide examples of desired output format
- Include error prevention guidelines

**Prompt Organization and Hierarchy**:
- Use a clear hierarchical structure to organize system prompts
- Prioritize most critical requirements at the top
- Group related instructions into logical sections
- Use section headers (===) for easy scanning
- Follow this standard structure:

```go
systemPrompt := `You are a [role]. Your primary goal is [goal].

=== CORE REQUIREMENTS ===
1. [Most critical requirement 1]
2. [Most critical requirement 2]
3. [Most critical requirement 3]

=== STRUCTURE (or PROCESS/FORMAT) ===
[How to structure the output or process]
- Step 1: [description]
- Step 2: [description]

=== STYLE GUIDELINES ===
- [Style rule 1]
- [Style rule 2]
- [Style rule 3]

=== CONTENT PRIORITIES ===
1. [Priority 1]
2. [Priority 2]

REASONING PROCESS (document in rationale field — objective recitation first):
1. VOICE: [who you are on this job]
2. MUST: [non-negotiable outcome for this pass]
3. ANTI_PATTERN: [main failure mode to refuse]
4. TASK UNDERSTANDING: [what to do]
5. INPUT PROCESSING: [what you received]
6. OUTPUT CONTRACT: [what to produce]
7. FULFILLMENT REASONING: [how you did it — action-chain bullets, not introspective essay]`
```

**Benefits of Hierarchical Organization**:
- Reduces cognitive load - LLMs can focus on one section at a time
- Prevents conflicting priorities - clear hierarchy shows what matters most
- Easier to maintain - related rules are grouped together
- Better readability - section headers make prompts scannable
- Consistent structure - all prompts follow the same pattern

**Section Guidelines**:
- **CORE REQUIREMENTS**: 3-4 most critical rules (immutable truths, non-negotiables)
- **STRUCTURE/PROCESS**: How to organize output or workflow steps
- **STYLE GUIDELINES**: Writing style, language, tone (condensed to 4-6 rules)
- **CONTENT PRIORITIES**: Ordered list of what to cover (when relevant)
- **REASONING PROCESS**: Objective recitation (VOICE/MUST/ANTI_PATTERN) then step-by-step reasoning for ChainOfThought modules

**Avoid**:
- Too many "CRITICAL" sections (aim for 1-2, max 3)
- Scattered instructions without clear grouping
- Redundant rules across multiple sections
- More than 50 individual instructions total
- Unclear priority hierarchy

### DSPy Optimization Best Practices

**Use Appropriate Optimizers**:
- **BootstrapFewShot**: For generating few-shot examples automatically
- **MIPRO**: For multi-prompt optimization and exploration
- **Manual Tuning**: For specific domain requirements

**Evaluation Metrics**:
- Define clear, measurable metrics
- Use metrics that align with your business goals
- Test metrics on validation sets before optimization
- Monitor metrics during optimization

**Training Data**:
- Create diverse, representative training examples
- Include edge cases and difficult scenarios
- Balance positive and negative examples
- Ensure examples match signature structure

### Testing and Validation

**Generator and Evaluator Prompt Synchronization (MANDATORY)**:
- **ALWAYS update both prompts together** - Generator and evaluator prompts must stay synchronized
- **Use the shared prompt pair** - Co-locate using `dspy.JobPrompts` (Generator + Evaluator fields). Sayings uses type alias `GeneratorPrompts = dspy.JobPrompts`; YouTube uses `dspy.JobPrompts` directly (e.g. ChapterPrompts, TopicPrompts).
- **One file per generator** - Each generator has its own file (e.g., `imageprompt_generator.go`, `translation_generator.go`) containing:
  - `*Prompts` variable (e.g., `ImagePromptPrompts`) using `GeneratorPrompts` struct
  - `*Generator` variable (e.g., `ImagePromptGenerator`) using `GeneratorConfig` with the prompt from the struct
- **Mirror structure** - Evaluator prompts should mirror generator prompts with matching sections and rules
- **Verify synchronization** - Before committing changes, verify that evaluator criteria match generator instructions
- **Example pattern**: 
  ```go
  // In imageprompt_generator.go
  var ImagePromptPrompts = GeneratorPrompts{
      Generator: `...generator prompt...`,
      Evaluator: `...evaluator prompt (mirrors generator)...`,
  }
  
  var ImagePromptGenerator = GeneratorConfig{
      Name: "ImagePromptGenerator",
      SystemPrompt: ImagePromptPrompts.Generator,
      // ... other config
  }
  ```
- **Why critical**: Mismatched prompts cause evaluators to approve incorrect outputs, wasting refinement cycles and degrading quality

**Comprehensive Testing**:
- Test with diverse input scenarios
- Validate output structure matches signature
- Measure performance with defined metrics
- Test edge cases and error handling

**Continuous Improvement**:
- Monitor module performance over time
- Collect feedback on output quality
- Iterate based on performance data
- Update signatures and instructions based on results
- Use optimizers to automatically improve prompts

### Common Pitfalls to Avoid

**Overly Complex Signatures**:
- Avoid too many input/output fields
- Don't create signatures that are hard to understand
- Keep signatures focused on single tasks
- Split complex tasks into multiple modules

**Vague Field Descriptions**:
- Don't use generic descriptions like "data" or "result"
- Be specific about expected formats and ranges
- Include examples in descriptions when helpful
- Clarify relationships between fields

**Bias Introduction**:
- Avoid gender-specific language in prompts
- Don't assume cultural contexts
- Prevent source bias in instructions
- Ensure inclusive examples and scenarios

**Performance Issues**:
- Don't create overly complex reasoning chains in instructions
- Avoid redundant instructions
- Prevent information overload in prompts
- Balance thoroughness with efficiency
- Use DSPy optimizers instead of manual prompt tweaking
- **Avoid too many goals**: Don't create prompts with 4+ "CRITICAL" sections and 50+ individual instructions - use hierarchical organization instead
- **Avoid scattered instructions**: Group related rules together with clear section headers

**Ignoring DSPy Features**:
- Don't manually craft prompts when optimizers can help
- Use ChainOfThought modules for reasoning tasks
- Leverage BootstrapFewShot for few-shot learning
- Take advantage of automatic prompt optimization

**Generator and Evaluator Prompt Synchronization (CRITICAL)**:
- **ALWAYS update generator and evaluator prompts together** - They must stay in sync
- **NEVER update only one** - If you change generator behavior, update evaluator criteria to match
- **Use the shared prompt pair (dspy.JobPrompts)** - Co-locate generator and evaluator prompts; sayings uses alias `GeneratorPrompts`:
  ```go
  var ImagePromptPrompts = GeneratorPrompts{  // GeneratorPrompts = dspy.JobPrompts in sayings
      Generator: `...generator prompt...`,
      Evaluator: `...evaluator prompt (mirrors generator)...`,
  }
  ```
- **One file per generator** - Each generator type has its own file containing both prompts in the struct
- **Mirror the structure** - Evaluator prompts should mirror generator prompts (same sections, same rules)
- **Check for mismatches** - Before committing, verify that evaluator criteria match generator instructions
- **Example**: If generator says "use semantic OR literal translation (NOT idiomatic)", evaluator must check for the same rule, not approve idiomatic usage
- **Why this matters**: Mismatched prompts cause evaluators to approve incorrect outputs, leading to poor quality and wasted refinement cycles

## 7. DSPy Integration Patterns

### Module Composition

Combine multiple modules into workflows:

```go
// Create individual modules
translationModule := CreateTranslationModule(translationPrompt)
evaluationModule := CreateTextEvaluationModule("Evaluator", evaluationPrompt)

// Compose into workflow
// In practice, you'd use a workflow orchestrator or chain modules
func evaluateTranslation(originalText string) (string, float64, error) {
    // Step 1: Generate translation
    translationResult, err := translationModule.Forward(core.NewExample(
        map[string]interface{}{"original_text": originalText},
        nil,
    ))
    if err != nil {
        return "", 0, err
    }
    
    // Step 2: Evaluate translation
    evaluationResult, err := evaluationModule.Forward(core.NewExample(
        map[string]interface{}{
            "content": translationResult["translation"],
            "context": originalText,
        },
        nil,
    ))
    if err != nil {
        return "", 0, err
    }
    
    return translationResult["translation"].(string), 
           evaluationResult["score"].(float64), 
           nil
}
```

### Using DSPy Optimizers

Optimize modules automatically with DSPy optimizers:

```go
import (
    "github.com/XiaoConstantine/dspy-go/pkg/optimizers"
)

// Create training set
trainingSet := []*core.Example{
    core.NewExample(
        map[string]interface{}{"original_text": "Hola mundo"},
        map[string]interface{}{"translation": "Hello world"},
    ),
    // ... more examples
}

// Define metric
metric := func(example *core.Example, prediction map[string]interface{}, trace *core.Trace) float64 {
    expected := example.Outputs["translation"].(string)
    actual := prediction["translation"].(string)
    if expected == actual {
        return 1.0
    }
    return 0.0
}

// Optimize module
optimizer := optimizers.NewBootstrapFewShot(
    optimizers.WithMaxLabeledData(10),
)
optimizedModule := optimizer.Optimize(translationModule, trainingSet, metric)
```

### Context Passing Between Modules

Pass context through module chains:

```go
// Signature that accepts previous step output
explanationSignature := core.NewSignature(
    []core.InputField{
        {Field: core.NewField("original_text", core.WithDescription("Original Spanish saying"))},
        {Field: core.NewField("translation", core.WithDescription("English translation from previous step"))},
        {Field: core.NewField("context", core.WithDescription("Additional context"))},
    },
    []core.OutputField{
        {Field: core.NewField("explanation", core.WithDescription("Cultural explanation"))},
    },
)

// Use in workflow
func generateExplanation(originalText, translation string) (string, error) {
    explanationModule := modules.NewPredict(
        explanationSignature.WithInstruction(explanationPrompt),
    )
    
    result, err := explanationModule.Forward(core.NewExample(
        map[string]interface{}{
            "original_text": originalText,
            "translation": translation,
            "context": "LinkedIn professional audience",
        },
        nil,
    ))
    if err != nil {
        return "", err
    }
    
    return result["explanation"].(string), nil
}
```

### Error Handling in Modules

Handle errors gracefully in DSPy modules:

```go
func safeModuleCall(module *modules.Predict, input *core.Example) (map[string]interface{}, error) {
    result, err := module.Forward(input)
    if err != nil {
        // Log error with context
        log.Printf("Module error: %v, input: %+v", err, input)
        
        // Return structured error
        return nil, fmt.Errorf("module execution failed: %w", err)
    }
    
    // Validate output structure
    if err := validateOutput(result, module.Signature().OutputFields()); err != nil {
        return nil, fmt.Errorf("invalid output structure: %w", err)
    }
    
    return result, nil
}

func validateOutput(output map[string]interface{}, expectedFields []core.OutputField) error {
    for _, field := range expectedFields {
        if _, exists := output[field.Field.Name()]; !exists {
            return fmt.Errorf("missing required output field: %s", field.Field.Name())
        }
    }
    return nil
}
```

### Module Reusability

Design modules for reusability:

```go
// Generic evaluation module factory
func CreateEvaluationModule(
    roleName string,
    expertiseAreas []string,
    focusPoints []string,
) (*modules.Predict, error) {
    signature := NewTextEvaluationSignature()
    
    // Build prompt from parameters
    prompt := buildEvaluationPrompt(roleName, expertiseAreas, focusPoints)
    
    signature = signature.WithInstruction(prompt)
    predict := modules.NewPredict(signature)
    predict.WithName(roleName)
    
    return predict, nil
}

func buildEvaluationPrompt(roleName string, expertiseAreas, focusPoints []string) string {
    return fmt.Sprintf(`You are a %s Evaluator.

Your expertise includes:
%s

When evaluating, focus on:
%s

Provide scores from 0.0 to 10.0, style analysis, and detailed feedback.`,
        roleName,
        formatList(expertiseAreas),
        formatList(focusPoints),
    )
}
```

## Key Takeaways

1. **Understand LLM biases** - Design prompts to mitigate cognitive biases and weaknesses
2. **Design clear signatures** - Define structured input/output with descriptive fields
3. **Use instructions effectively** - Attach system prompts to signatures with `.WithInstruction()`
4. **Organize prompts hierarchically** - Use clear structure (CORE REQUIREMENTS → STRUCTURE → STYLE → CONTENT PRIORITIES) to reduce cognitive load and improve maintainability
5. **Implement bias mitigation** - Include strategies to prevent and detect biases in instructions
6. **Leverage DSPy modules** - Use ChainOfThought, Predict, and other modules appropriately
7. **Recite objectives in rationale first** - Generators must open `<rationale>` with VOICE/MUST/ANTI_PATTERN before other outputs (`CreateGeneratorModule` enforces this)
8. **Optimize automatically** - Use BootstrapFewShot, MIPRO, and other optimizers
9. **Test comprehensively** - Validate modules with diverse scenarios and metrics
10. **Compose workflows** - Chain modules together for complex tasks
11. **Iterate and improve** - Continuously refine signatures and instructions based on performance data

Remember: Effective prompt engineering in DSPy combines well-designed signatures with clear, hierarchically-organized instructions, and leverages DSPy's optimization capabilities for continuous improvement.
