# ADR 0002: PostgreSQL, JdbcClient, and HikariCP

- Status: Accepted
- Date: 2026-09-16

## Context

Verification records need durable idempotency, claim ownership, expiration
ordering, JSON state, and transactional completion. The service does not need a
large object-relational model; its SQL is small, explicit, and query-oriented.

## Decision

Use PostgreSQL as the source of truth, Spring JDBC `JdbcClient` for repository
operations, Flyway for schema migration, and HikariCP for the JDBC connection
pool. The `verifications` table stores the lifecycle state, claim token,
timestamps, and JSONB provider result. Partial indexes support expiration and
normalized-query lookup.

## Consequences

SQL remains visible and maps directly to the concurrency protocol. Hikari
provides bounded reuse of database connections and timeout controls. PostgreSQL
transactions and `FOR UPDATE SKIP LOCKED` make batch expiration safe across
workers. The trade-off is that schema evolution and row-level concurrency must
be maintained explicitly instead of delegated to an ORM.

`JdbcTemplate` and a JPA entity model were rejected because they add abstraction
without helping the repository's small set of carefully controlled queries.
