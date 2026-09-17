# Validation and Security Pipelines Design

## Goal

Provide an on-demand and reusable validation workflow for the complete project
quality gate, image builds, and image smoke checks, plus a dedicated security
workflow for source, dependency, secret, and container risks.

## Design

`validation.yml` is the full engineering gate. It checks the Bun provider with
format, type, lint, unit, contract, and production compilation commands. It
checks the Java service through Gradle's `qualityGate`, which includes unit,
integration, contract, E2E test-source, formatting, Checkstyle, coverage,
architecture, build-logic, and OpenAPI validation. A separate matrix builds
both JVM and native amd64 images with digest-pinned Paketo builder/run images,
then runs the existing bounded image smoke check. The workflow supports
`workflow_dispatch` and `workflow_call`; image jobs require explicit immutable
builder/run references.

`security.yml` runs on pull requests, pushes, and manual dispatch. It uses
least-privilege permissions and separate jobs for:

- CodeQL analysis of Java and TypeScript/Bun code.
- Dependency Review on pull requests, failing on high/critical introduced
  vulnerabilities or denied licenses.
- Gitleaks secret scanning across repository history.
- Trivy filesystem scanning for dependency, misconfiguration, and secret
  findings, failing on high/critical vulnerabilities.
- Gradle dependency verification and lock validation, plus provider lockfile
  installation/build checks.
- A JVM image build followed by Trivy OS/library scanning and SBOM upload.

Security reports are uploaded to GitHub code scanning when supported and as
workflow artifacts for auditability. The security image job uses the same
immutable Paketo inputs as the validation flow and fails if those inputs are
missing or mutable.

## Failure policy

High and critical findings fail their relevant job. Medium and low findings are
retained in SARIF/JSON artifacts and do not block delivery. Secret findings,
CodeQL findings, invalid dependency licenses, lock/verification failures, and
workflow/tool failures always fail.

## Constraints

- No production runtime behavior changes are required.
- Existing Gradle and Bun quality commands remain the source of truth.
- Workflow permissions are scoped to read contents, read pull requests, and
  write security events only where a SARIF upload needs it.
- Image references supplied to image jobs must match the repository's
  `@sha256:<64 hex digits>` contract.
- Manual workflows remain bounded and do not publish images.
