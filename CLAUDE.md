# AI Instruction

This is the canonical AI instruction entry point for the LISA Edge project.
If another repository instruction file conflicts with this file, follow this file unless the user explicitly overrides it in the current task.

## 1. Operating Contract

### Communication

- Chat with the user in Vietnamese.
- Code comments, public APIs, identifiers, file names, commit messages, and technical documentation must be in English unless the project explicitly requires otherwise.
- Be direct, practical, and aware of the project's architecture and operational constraints.
- Do not over-explain obvious things.
- Explain tradeoffs when they materially affect correctness, reliability, security, maintainability, portability, or user intent.
- Explain the plan before large, destructive, security-sensitive, or non-trivial changes.
- Ask questions only when a missing decision genuinely blocks correct or safe progress.
- After editing, provide a concise file-level summary of what changed.
- Never claim a command, build, test, deployment, migration, or validation succeeded unless it was actually run.

### Read First

Before non-trivial changes, read only the documents needed for the task:

1. Read `README.md` for the stable operator interface and repository map.
2. Read the relevant index under `docs/README.md`.
3. Read only the document, README, and implementation nearest to the area being changed.

Do not read every document blindly. Use indexes first.
Treat the root `./lisa-edge` CLI and current implementation as the source of truth for available commands and selectable services.
Do not use archived or planned documents as current deployment instructions.
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

## 3. Project Boundary

### Project Identity

LISA Edge is the lightweight local-infrastructure layer of the LISA ecosystem. It provides local availability, connectivity, messaging, service discovery, monitoring, secure remote access, backup, restore, diagnostics, and recovery capabilities for the broader LISA platform.

LISA Edge is infrastructure for LISA. It supports intelligence but does not replace LISA Brain.

The system must remain useful when cloud services are unavailable and should favor local operation, predictable recovery, secure defaults, and hardware independence.

### In Scope

Typical LISA Edge responsibilities include:

- MQTT messaging
- OpenThread Border Router
- Matter and Thread connectivity support
- mDNS and service discovery
- NTP / Chrony
- VPN access
- health monitoring
- diagnostics
- backup and restore
- host bootstrap and hardening
- Docker Compose service lifecycle
- integration support for UniFi, Home Assistant, Homey, Zigbee2MQTT, Node-RED, and future edge services

### Explicit Non-Goals

Do not turn LISA Edge into:

- an LLM inference host
- an agent reasoning or planning system
- a memory or vector database platform
- a video analytics or transcoding server
- a primary NAS
- a large database host
- a heavy observability or analytics stack
- an all-in-one server

Small supporting databases or lightweight APIs may be acceptable only when their resource use, recovery path, and operational value are clearly justified.

### Current Implementation Status

Implemented selectable services:

- MQTT
- Uptime Kuma
- OpenThread Border Router
- Tailscale
- Home Assistant
- Zigbee2MQTT
- Node-RED

Implemented host-level capabilities:

- Chrony
- host bootstrap
- systemd runtime units
- health checks
- diagnostics
- full-stack backup and restore
- OTBR dataset protection
- production and rescue USB workflows
- independent Rescue OS workflow

Planned but not currently selectable:

- NUT / UPS integration
- DNS helpers
- reverse proxy

Never present a planned service as implemented. Use `./lisa-edge service list` and the current code before claiming deployability.

## 4. Architectural Principles

### Core Direction

LISA Edge is:

- Linux-first
- Docker-first
- local-first
- hardware-agnostic
- recovery-focused
- infrastructure-as-code oriented
- Git-managed
- security-conscious

Prefer practical immutable infrastructure:

- Compose-defined services
- Git-managed configuration
- externalized persistent data
- secure secrets outside Git
- reproducible host preparation
- rebuildable deployments
- documented backup and restore procedures

Avoid manual configuration drift, undocumented host mutations, hidden state, and snowflake deployments.

### Recovery Priority

Use this priority order:

1. Backup
2. Restore
3. Reliability
4. Failover

Prefer a replaceable node with tested recovery over an unnecessarily complex cluster.
A design is incomplete if it cannot explain how it is backed up, restored, rebuilt, and diagnosed after failure.

### Deployment Model

The reference deployment is:

```text
eMMC
└── Minimal independent Rescue OS

SSD
└── Production OS, Docker, and persistent service data

NAS or external storage
└── Backup and restore media
```

The architecture must not depend on ZimaBoard-specific behavior.
ZimaBoard 2 is a reference platform, not an architectural requirement.
Supported deployment targets may include suitable Ubuntu or Debian hosts, mini PCs, NUCs, Raspberry Pi systems, VMs, NAS-hosted VMs, or cloud VMs when the selected images support the CPU architecture.

### Rescue and Production Separation

The Rescue Layer exists for:

- emergency access
- diagnostics
- reinstall automation
- backup restore
- production recovery

It must remain lightweight, independent, stable, and free of normal production workloads.

The Production Layer exists for:

- the production OS
- Docker Engine and Compose
- LISA Edge services
- persistent runtime data
- normal operations

Do not place production services or log-heavy workloads on the Rescue Layer.

## 5. Repository and CLI Rules

### Stable Operator Interface

The root command is the stable operator interface:

```bash
./lisa-edge help
```

Users should not need to know where an implementation script lives.
New operational behavior should normally be exposed through the root CLI instead of requiring users to call internal scripts directly.

Canonical commands include:

- `setup`
- `configure`
- `bootstrap`
- `deploy`
- `stop`
- `update`
- `status`
- `health`
- `service list`
- `backup`
- `restore`
- `diagnostics`
- `usb production`
- `usb rescue`
- `rescue`

Do not rename, bypass, or duplicate stable commands casually.
Preserve backward-compatible operator behavior unless a breaking change is explicitly justified and documented.

### Canonical Repository Areas

Use the existing layout:

- `install/usb/` for production and rescue installation media
- `install/provisioning/` for first-boot and site-specific provisioning
- `install/bootstrap/` for host packages, hardening, Docker, and storage preparation
- `services/` for service Compose, configuration, preparation, and provisioning
- `ops/deploy/` for deploy, stop, update, status, health, and systemd runtime behavior
- `ops/backup-restore/` for backup, restore, archive validation, and timers
- `ops/diagnostics/` for diagnostic collection
- `rescue/` for Rescue OS and disaster-recovery tooling
- `docs/` for architecture, operations, security, networking, and procedures
- `tools/` for repository tooling and validation
- `tests/` for structure, unit, security, and integration tests

Do not recreate removed legacy layouts such as `scripts/`, `bootstrap/`, `provisioning/`, `usb-installer/`, `recovery/`, `compose/`, `config/`, or `systemd/`.

### Source of Truth

Use this precedence when determining current behavior:

1. Root CLI behavior and current implementation
2. Current non-archived documentation
3. Planned documentation
4. Archived documentation

Planned documents describe intent, not deployed capability.
Archived documents are historical context only.

## 6. Service Design Rules

### Service Packaging

Prefer Docker Compose for application services.
Host-level capabilities may use systemd, host packages, or scripts when containerization would reduce reliability or complicate recovery.

Each critical service should define:

- ownership and boundary
- configuration inputs
- persistent data locations
- secrets handling
- health checks
- restart behavior
- backup scope
- restore procedure
- upgrade behavior
- failure behavior
- resource expectations

Do not add a service only because it is technically possible.
Confirm that it belongs on LISA Edge and provides material operational value.

### Service Selection

Selectable services must integrate with the existing service catalog and dependency model.
Dependencies must be explicit. For example, a service that requires MQTT must select or validate MQTT through the established mechanism rather than silently assuming it exists.

Do not hard-code one deployment profile, one network, one hardware model, or one service set.

### Resource Discipline

LISA Edge should remain lightweight.
Evaluate CPU, memory, storage, write amplification, log volume, startup behavior, and recovery cost before adding persistent services.

Avoid:

- unbounded logs
- high-frequency writes to eMMC
- large local retention windows
- heavyweight databases without clear need
- unnecessary duplicate services
- polling when event-driven integration is practical

## 7. Networking and Security Rules

### Security Defaults

Prefer:

- VPN-first administration
- SSH key authentication
- no public administrative dashboards
- firewall allow-lists
- least privilege
- minimal exposed ports
- local-first service access
- explicit network boundaries
- secure secret storage

Do not weaken existing VLAN, firewall, or trust boundaries for convenience.

High-sensitivity networks, including access control, alarm, camera, and management networks, require additional scrutiny.

### Network Integration

Networking is a first-class architectural concern.
When adding or changing services, evaluate:

- VLAN placement
- firewall direction and ports
- multicast and mDNS requirements
- Thread and Matter discovery
- DNS behavior
- NTP dependencies
- VPN reachability
- site-to-site implications
- failure behavior when WAN or cloud services are unavailable

Never assume all devices share one flat LAN.
Never require broad inter-VLAN access when narrower rules are sufficient.

### Secrets

Keep `.env`, credentials, private keys, tokens, and runtime secrets outside Git.
Use restrictive permissions such as `0600` where appropriate.
Treat backup archives as sensitive because they may contain credentials.
Do not print secrets in logs, diagnostics, command output, tests, or error messages.

## 8. Automation and Shell Rules

### General Implementation

- Follow existing shell style and helper patterns first.
- Keep scripts non-interactive when automation requires it, and make interactive behavior explicit.
- Use strict validation for destructive inputs.
- Quote variable expansions unless intentional word splitting is required and documented.
- Resolve repository paths from script location rather than the caller's current directory.
- Prefer idempotent operations.
- Make reruns safe.
- Preserve useful exit codes.
- Send actionable errors to stderr.
- Avoid hidden global state.
- Avoid hard-coded installed paths unless the architecture explicitly requires them and tests protect them.
- Do not introduce a new dependency without clear operational justification.

### Destructive Operations

Disk, partition, filesystem, restore, archive extraction, mount, and target-root operations are safety-critical.

Required behavior:

- validate before mutation
- fail closed on ambiguity
- never guess a disk device name
- prefer serial or explicitly reviewed model matching
- protect the running system and mounted production data
- reject unsafe paths and traversal
- make destructive intent visible
- provide dry-run or review steps when practical
- keep cleanup reliable after failure or cancellation

### Configuration

- Preserve user-managed values when safe.
- Do not overwrite `.env` or persistent configuration without explicit intent.
- Validate required variables before deploy.
- Keep defaults conservative and portable.
- Separate generated configuration from source-controlled templates.
- Avoid embedding site-specific IPs, VLANs, hostnames, serial numbers, credentials, or device paths in generic project logic.

### Logging and Diagnostics

Logs and diagnostics should answer:

- What happened?
- Which component failed?
- What input or state caused it?
- What should the operator inspect next?

Prefer concise lifecycle, validation, dependency, and recovery information.
Avoid noisy loop output, secret leakage, duplicated messages, and false success states.

## 9. Backup, Restore, and Recovery Rules

### Backup

Every critical persistent service must identify what must be backed up and what can be recreated.
Backups must not depend solely on the production SSD.
Prefer NAS, external storage, or remote encrypted storage as destinations.

Backup workflows should include:

- archive validation
- checksum sidecars
- clear metadata
- safe temporary files
- predictable naming
- cleanup behavior
- failure reporting

### Restore

Restore is a first-class feature, not a documentation afterthought.

Restore workflows must:

- validate the archive before mutation
- reject unsafe paths and malformed content
- preserve or review image references before deploy
- avoid partial silent success
- clearly state what was restored
- identify required post-restore validation

Do not claim backup reliability without testing restore.

### Power Loss and Partial Failure

When changing persistent state, consider interruption by power loss, reboot, process termination, missing storage, or disconnected network resources.
Prefer atomic writes, temporary staging, checksums, resumable or safely repeatable steps, and explicit cleanup.

## 10. Change Discipline

### General

- Preserve current architecture and operator behavior unless change is justified.
- Make the smallest complete change.
- Do not mix unrelated refactors with feature work.
- Do not reformat unrelated files.
- Do not move files without updating all references and structural tests.
- Do not broaden scope to adjacent services or future plans without need.
- Do not silently convert planned capabilities into implemented ones.

### Refactoring

Before a large refactor:

- identify the operator-facing behavior that must remain stable
- identify affected commands, services, paths, tests, and documentation
- describe migration or compatibility concerns
- produce a short plan

After a refactor, summarize:

- files changed
- responsibilities moved
- behavior preserved
- compatibility impact
- validation performed

### Debugging

When debugging:

- identify observed behavior
- identify expected behavior
- reproduce through the smallest relevant command or test when safe
- trace the root CLI into the smallest relevant implementation path
- identify the root cause
- apply the smallest safe fix
- add a regression test when practical
- mention side effects and recovery considerations

Do not randomly rewrite surrounding automation while fixing one defect.

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

## 11. Testing and Validation

### Canonical Validation

Run the same validation used by CI when practical:

```bash
bash tools/validate-repo.sh
```

The canonical test areas are:

- `tests/structure/` for repository layout, service catalog, stable CLI, and installed paths
- `tests/unit/` for service selection, image policy, and provisioning behavior
- `tests/security/` for archive validation, checksums, mount guards, target-root parsing, and Rescue OS path safety
- `tests/integration/` for complete workflows in isolated temporary filesystem trees

### Test Safety

Tests must:

- resolve `REPO_ROOT` from their own path
- use isolated temporary directories
- never mutate a live host
- never deploy into production paths
- never alter production data
- never require real destructive disk operations
- avoid dependence on external cloud availability unless explicitly isolated

### Validation Expectations

Before finalizing changes, run the narrowest relevant tests first, then the canonical validation when practical.
For operational changes, include safe manual verification steps.
For backup or restore changes, include archive validation and restore-path testing.
For security-sensitive changes, include negative tests that prove unsafe input is rejected.

Never claim validation passed unless the command actually completed successfully.

## 12. Documentation Rules

Documentation is part of the operational interface.

Update documentation when a change affects:

- operator commands
- repository paths
- service availability
- configuration variables
- architecture or boundaries
- security assumptions
- networking requirements
- backup or restore behavior
- recovery procedures
- deployment or validation workflows

Update only directly affected documents.
Do not copy implementation details into multiple documents when one canonical source and links are sufficient.

If implementation and documentation conflict:

1. Mention the conflict.
2. Determine which one represents intended current behavior.
3. Update the incorrect source when within scope.
4. Do not silently preserve contradictory instructions.

## 13. Standard Response Formats

After making code or configuration changes:

```text
Summary:
- ...

Files changed:
- ...

Validation:
- ...

Operational impact:
- ...

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

## 14. Priority Order

When priorities conflict:

1. Safety
2. Correctness
3. Recoverability
4. Security
5. Reliability
6. Maintainability
7. Portability
8. Operator clarity
9. Performance
10. Developer convenience

For destructive storage, restore, networking, security, and production deployment work, safety and recoverability come first.
