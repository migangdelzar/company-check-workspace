# Architecture Decision Records

| ADR | Decision | Status |
|---|---|---|
| [0001](0001-hexagonal-modulith.md) | Keep the service as a conventional layered Spring Modulith application | Accepted |
| [0002](0002-postgresql-jdbcclient-and-hikari.md) | Use PostgreSQL with `JdbcClient` and HikariCP as the authoritative store | Accepted |
| [0003](0003-redis-for-distributed-coordination.md) | Use Redis only when coordination must cross service instances | Accepted |
| [0004](0004-provider-http-pools-and-resilience.md) | Use one shared provider HTTP pool with Resilience4j limits | Accepted |
| [0005](0005-filters-observations-and-aop-boundaries.md) | Use servlet filters for request admission and annotations for observations | Accepted |
| [0006](0006-virtual-threads-and-bounded-resources.md) | Enable virtual threads while keeping every scarce resource bounded | Accepted |
| [0007](0007-gradle-paketo-and-immutable-compose.md) | Standardize build conventions, Paketo images, and digest-pinned Compose inputs | Accepted |
| [0008](0008-testcontainers-docker-context.md) | Make Testcontainers Docker endpoint and socket discovery explicit | Accepted |

ADRs describe why a choice exists. The [architecture documents](../architecture/README.md)
describe how the current system behaves.
