# Current Architecture Documentation Refresh

## Scope

Refresh the workspace ADRs, architecture reference pages, Mermaid diagrams, and
architecture-related README text so they describe the checked-out implementation
after the backend migration to a conventional layered structure.

## Design

The backend documentation will use these actual layers and package names:

- `config/` — Spring composition root, profiles, properties, infrastructure
  beans, resilience, persistence, and runtime hints.
- `controller/` — HTTP controllers, request/response DTOs, inbound admission
  filter, and expiration scheduler.
- `service/` — verification and provider workflows plus `service/model/`
  records.
- `repository/` — JDBC persistence, local/Redis coordination, leases, caches,
  and rate-limit implementations/contracts.
- `client/` — provider-neutral client contract, typed provider HTTP clients,
  resilience wrappers, and provider DTOs.
- `mapper/` — explicit conversion between controller, service, repository, and
  provider representations.
- `exception/` — business/integration errors and global HTTP error mapping.

The diagrams will show the real `VerificationService`, `ProviderService`,
`VerificationStoreService`, `VerificationRecoveryService`,
`JdbcVerificationRepository`, `CoordinationRepository`, and `ProviderClient`
boundaries. They will retain the existing runtime behavior: PostgreSQL is the
source of truth; Caffeine is local cache; Redis is used only by the distributed
profile; FREE is tried before PREMIUM fallback; and Compose/observability
topologies remain unchanged.

ADR 0001 will be revised in place, preserving its filename and links, to record
the layered structure as the current decision. The other ADRs will retain their
decisions while correcting stale package and implementation terminology.

## Verification

- Search `docs/**` and `README.md` for obsolete `domain`, `application`,
  `adapter.*`, `StartVerificationService`, and `ProviderResolutionService`
  references.
- Check every Mermaid block is closed and contains the current component names.
- Run `git diff --check`.
- Render/check merged Compose configuration if the local Docker runtime is
  available; otherwise record that limitation.
