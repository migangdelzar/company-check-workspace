# Validation and Security Pipelines Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add complete on-demand/reusable validation and dedicated security workflows without changing application runtime behavior.

**Architecture:** Keep project checks in Gradle/Bun and orchestrate them from two focused GitHub workflows. Validation builds both service image variants from immutable Paketo inputs; security analyzes source, dependencies, secrets, filesystem configuration, and the built JVM image.

**Tech Stack:** GitHub Actions, Gradle 9, Java 25, Bun 1.3, CodeQL, Dependency Review, Gitleaks, Trivy, Syft/SPDX.

## Global Constraints

- High and critical security findings fail; medium and low findings are reported.
- Image builder and run references must be immutable `@sha256:<64 hex digits>` values.
- Use least-privilege workflow permissions.
- Preserve existing application and Compose behavior.

---

### Task 1: Add complete validation workflow

**Files:**
- Create: `.github/workflows/validation.yml`

- [ ] Add `workflow_dispatch` and `workflow_call` inputs for Paketo builder/run digests.
- [ ] Run provider format/type/lint/unit/contract/build commands.
- [ ] Run service `qualityGate` with Java 25 and Docker-aware integration tests.
- [ ] Build JVM and native amd64 images and run `imageSmoke` for each variant.
- [ ] Upload image/build reports on failure and validate YAML syntax locally.

### Task 2: Add dedicated security workflow

**Files:**
- Create: `.github/workflows/security.yml`

- [ ] Add PR/push/manual triggers and least-privilege permissions.
- [ ] Add CodeQL Java and JavaScript/TypeScript analysis.
- [ ] Add Dependency Review for pull requests with high/critical thresholds.
- [ ] Add Gitleaks secret scanning and SARIF/artifact retention.
- [ ] Add Trivy filesystem scanning and lock/verification checks.
- [ ] Build a digest-pinned JVM image and scan it for high/critical OS/library vulnerabilities.
- [ ] Generate and upload an SPDX SBOM for the service image.

### Task 3: Verify and commit

**Files:**
- Modify: documentation only if workflow usage needs to be recorded.

- [ ] Parse all changed YAML files and run shell/Python syntax checks.
- [ ] Run service `qualityGate`, provider `quality` and `test:contract` locally.
- [ ] Run JVM/native Gradle image dry-runs with local immutable Paketo references.
- [ ] Confirm clean status and commit the workflow/spec/plan changes.
