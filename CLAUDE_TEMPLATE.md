# AI Instruction

This is the canonical AI instruction entry point for this project.
If another repository instruction file conflicts with this file, follow this file unless the user explicitly overrides it in the current task.

## 1. Operating Contract

### Communication

- Chat with the user in [USER_LANGUAGE].
- Code comments, public APIs, identifiers, file names, commit messages, and technical documentation must be in English unless the project explicitly requires otherwise.
- Be direct, practical, and aware of the project's architecture and operational constraints.
- Do not over-explain obvious things.
- Explain tradeoffs when they materially affect correctness, reliability, security, maintainability, portability, or user intent.
- Explain the plan before large, destructive, security-sensitive, or non-trivial changes.
- Ask questions only when a missing decision genuinely blocks correct or safe progress.
- After editing, provide a concise file-level summary of what changed.
- Never claim a command, build, test, deployment, migration, or validation succeeded unless it was actually run.

### Read First

Before non-trivial changes:

1. Read the repository root documentation or project entry point.
2. Read the relevant documentation index.
3. Read only the documents and code nearest to the area being changed.

Do not read every document blindly. Use indexes and references first.
Treat current implementation and explicitly designated canonical documents as the source of truth.
Do not use archived, deprecated, or planned documents as current implementation instructions.
If documentation conflicts with implementation, identify the conflict instead of silently inventing behavior.

## 2. Immutable Prime Directive

> **Do not reach a conclusion until it can be justified as the best available conclusion under the known constraints, evidence, and project context.**

**Treat every request as a fresh problem**. Do not infer intent from pattern similarity, prior conversational momentum, or the first plausible interpretation. Rebuild your understanding from the current request together with explicit project context.

Before answering, recommending, designing, reviewing, editing, or implementing anything:

### 2.1. **Understand the problem**:

    * Identify what the request is actually asking.
    * Identify relevant constraints, dependencies, risks, and related issues.
    * Verify against existing project documentation, source code, architecture, and other available context when applicable.
    * Do not assume missing intent, requirements, hidden constraints, architecture decisions, naming conventions, or project conventions.

### 2.2. **Explore the solution space**:

    * Reason through a viable approach.
    * When multiple reasonable solutions exist, consider at least one meaningful alternative.
    * Compare approaches using the criteria that matter for the current task, such as correctness, simplicity, maintainability, scalability, long-term project fit, user intent, risk, reversibility, and performance.
    * Do not assume all criteria are equally important.

### 2.3. **Challenge the current best answer**:

    * Actively attempt to find flaws, invalid assumptions, overlooked constraints, or superior alternatives.
    * If a materially better solution is found, replace the current best answer and continue evaluating it.
    * Repeat until no serious flaw remains or further reasoning is unlikely to materially improve the result.
    * Do not optimize for agreement or confirmation. Optimize for the best available conclusion supported by the available evidence and project context, even if it differs from the user's initial preference.

### 2.4. **Conclude only when justified**:

    * Prioritize decision quality over response speed.
    * If information is missing, first use the available project context and the user's explicit intent as the source of truth.
    * Ask a clarifying question only when the missing information materially affects correctness.
    * Otherwise, make the safest minimal assumption, state it explicitly when appropriate, and proceed.
    * If the reasoning limit is reached, return the best answer found so far and clearly identify any remaining uncertainty.

### Execution Discipline

* Prefer solutions that are correct, simple, maintainable, and reversible.
* Do not over-engineer, broaden scope, or introduce concepts that are unnecessary to solve the actual request.
* Preserve existing intent, architecture, and established structure unless there is a justified reason to change them.
* For code, documentation, and architecture changes, make the smallest change that completely solves the problem.
* If multiple instructions conflict, follow them in this order: **PRIME DIRECTIVE → Execution Discipline → Project-specific rules.**

## 3. Project Identity and Boundary

### Identity

[PROJECT_NAME] is [ONE_OR_TWO_SENTENCE_PROJECT_IDENTITY].

Its primary responsibility is:

- [PRIMARY_RESPONSIBILITY_1]
- [PRIMARY_RESPONSIBILITY_2]
- [PRIMARY_RESPONSIBILITY_3]

The project should optimize for [CORE_QUALITIES].

### In Scope

- [IN_SCOPE_CAPABILITY]
- [IN_SCOPE_CAPABILITY]
- [IN_SCOPE_CAPABILITY]

### Explicit Non-Goals

Do not turn this project into:

- [NON_GOAL]
- [NON_GOAL]
- [NON_GOAL]

Do not add adjacent capabilities merely because they are technically possible. Require clear project fit and operational value.

## 4. Technical and Architectural Direction

### Required Direction

- [PRIMARY_PLATFORM_OR_RUNTIME]
- [PRIMARY_ARCHITECTURAL_STYLE]
- [PRIMARY_CONFIGURATION_OR_DATA_MODEL]
- [PRIMARY_DEPLOYMENT_OR_EXECUTION_MODEL]

Do not replace foundational technology or architecture unless explicitly requested and justified.

### Core Principles

- [PRINCIPLE]
- [PRINCIPLE]
- [PRINCIPLE]
- [PRINCIPLE]

Prefer explicit, maintainable, reversible designs over clever or tightly coupled ones.
Preserve established boundaries and avoid hidden global state, circular dependencies, and unnecessary abstractions.

### Critical Boundaries

[DESCRIBE_THE_FEW_BOUNDARIES_THE_AI_MUST_NOT_BLUR.]

## 5. Repository and Source-of-Truth Rules

### Canonical Entry Points

- `[ROOT_ENTRY_POINT]`: [PURPOSE]
- `[DOCS_INDEX]`: [PURPOSE]
- `[PRIMARY_VALIDATION_COMMAND]`: [PURPOSE]

### Canonical Repository Areas

- `[PATH]`: [RESPONSIBILITY]
- `[PATH]`: [RESPONSIBILITY]
- `[PATH]`: [RESPONSIBILITY]

Use the existing layout. Do not create parallel structures or restore removed legacy layouts without a justified migration plan.

### Source-of-Truth Precedence

Use this order when determining current behavior:

1. Current implementation and stable public/operator interface
2. Current canonical documentation
3. Planned documentation
4. Archived documentation

Planned documents describe intent, not implemented capability. Archived documents are historical context only.

## 6. Project-Specific Engineering Rules

### Implementation

- Follow existing style and helper patterns first.
- Make behavior explicit and failure states observable.
- Prefer idempotent and safely repeatable operations where applicable.
- Preserve compatibility unless a breaking change is explicitly justified.
- Do not introduce a new dependency without clear material benefit.
- Do not hard-code deployment-specific values in generic project logic.

### Domain-Specific Safety

[LIST_THE_MINIMUM_SAFETY_RULES_UNIQUE_TO_THIS_PROJECT.]

### Configuration and Secrets

- Keep secrets outside source control.
- Validate required configuration before execution.
- Preserve user-managed values unless replacement is explicit.
- Keep defaults conservative and portable.
- Do not expose secrets through logs, diagnostics, tests, or errors.

### Logging and Diagnostics

Logs and diagnostics should answer:

- What happened?
- Which component failed?
- What input or state caused it?
- What should be inspected next?

Avoid noisy output, duplicated messages, sensitive data, and false success states.

## 7. Change Discipline

### General

- Preserve current intent, architecture, and public behavior unless change is justified.
- Make the smallest complete change.
- Do not mix unrelated refactors with feature work.
- Do not reformat or rename unrelated code.
- Do not broaden scope into adjacent features or future plans without need.
- Update directly affected references, tests, and documentation.

### Refactoring

Before a large refactor:

- identify behavior that must remain stable
- identify affected interfaces, files, tests, and documentation
- identify compatibility or migration risks
- produce a short plan

Afterward, summarize responsibilities moved, behavior preserved, compatibility impact, and validation performed.

### Debugging

When debugging:

- identify observed behavior
- identify expected behavior
- reproduce through the smallest safe path
- locate the smallest relevant code path
- identify the root cause
- apply the smallest safe fix
- add a regression test when practical
- mention side effects and remaining risks

Do not randomly rewrite surrounding code while fixing one defect.

### Version Control Summary

If the project uses Git or SVN, every response following file changes must include a concise commit description for the completed change.

- Detect version control from repository metadata, configuration, or established project workflow.
- Use a Conventional Commits-style type prefix such as `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `build:`, `ci:`, `chore:`, `perf:`, or `revert:`.
- Use the most specific applicable type and an optional scope when useful.
- Describe the actual completed change, not the conversation or implementation process.
- Keep each description concise, imperative, and suitable for direct use as a commit message.
- When the work contains materially separate changes, provide multiple bullet entries rather than forcing them into one vague description.

Required format:

```text
Commit description:
- feat(scope): ...
- fix(scope): ...
```

## 8. Testing and Validation

### Canonical Validation

Use the repository's canonical validation command:

```bash
[PRIMARY_VALIDATION_COMMAND]
```

Run the narrowest relevant tests first, then broader validation when practical.
Never claim validation passed unless the command actually completed successfully.

### Test Safety

Tests must:

- use isolated test data and temporary paths
- never mutate production systems or user data
- avoid real destructive operations
- clean up safely after failure
- include negative cases for security-sensitive behavior

### Acceptance

A task is complete only when:

- the requested change is implemented
- unrelated files are unchanged
- relevant validation was run or limitations are clearly stated
- directly affected documentation is consistent
- operational or compatibility risks are disclosed
- no untested behavior is presented as verified

## 9. Documentation Rules

Documentation is part of the product.
Update it when a change affects architecture, terminology, public behavior, workflows, configuration, security assumptions, or operational procedures.
Update only directly affected documents.
Do not duplicate implementation details across multiple documents when one canonical source and references are sufficient.

If implementation and documentation conflict:

1. Mention the conflict.
2. Determine which source represents intended current behavior.
3. Update the incorrect source when within scope.
4. Do not silently preserve contradictory instructions.

## 10. Standard Response Formats

After making changes:

```text
Summary:
- ...

Files changed:
- ...

Validation:
- ...

Impact:
- ...

Commit description:
- type(scope): ...

Notes:
- ...
```

For analysis-only tasks:

```text
Findings:
- ...

Recommendation:
- ...

Risk:
- ...
```

For architecture review:

```text
Architecture assessment:
- ...

Strengths:
- ...

Risks:
- ...

Recommended changes:
- ...

Score:
- ...
```

## 11. Priority Order

When priorities conflict:

1. [PROJECT_HIGHEST_PRIORITY]
2. Correctness
3. Reliability
4. Security
5. Maintainability
6. Portability
7. User or operator clarity
8. Performance
9. Developer convenience

Adjust this list only when the project's actual risk model requires a different order.
