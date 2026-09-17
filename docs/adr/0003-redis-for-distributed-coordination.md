# ADR 0003: Redis for Distributed Coordination

- Status: Accepted
- Date: 2026-09-16

## Context

One service instance can use in-memory coordination, but multiple replicas need
shared ownership for duplicate verification work, inbound/provider rate limits,
cache entries, and the expiration scheduler lock.

## Decision

Keep two runtime profiles:

- `single-node`: local coordination and Resilience4j rate limiting; Redis is not
  auto-configured.
- `distributed`: Redis-backed coordination through `repository.coordination`,
  Redis-backed rate limiting through `repository.ratelimit`, shared cache
  entries, and a TTL-based expiration lease.

`CoordinationRepository` and `ExpirationLock` are the service-facing
repository boundaries; `LocalCoordinationRepository`,
`RedisCoordinationRepository`, and the Redis rate-limit implementations are
selected by `config`.

PostgreSQL remains authoritative. Redis may accelerate or coordinate work, but a
Redis outage must not turn cached state into the source of truth.

## Consequences

The distributed profile shares budgets and leases across replicas. Lease keys
have TTLs so a crashed scheduler does not permanently block expiration. Redis
adds a network dependency and operational cost, so it is deliberately excluded
from the single-node profile and unit tests.

Redisson or a database advisory-lock design was rejected for now: the existing
Spring Data Redis/Lettuce stack is sufficient, and PostgreSQL is already used for
durable state rather than ephemeral coordination.
