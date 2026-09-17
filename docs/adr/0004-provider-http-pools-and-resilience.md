# ADR 0004: Provider HTTP Pools and Resilience

- Status: Accepted
- Date: 2026-09-16

## Context

Provider calls are remote, slower than local code, and may fail independently.
Connection reuse is required, but an unbounded pool or unlimited concurrency can
exhaust provider capacity and the service itself.

## Decision

Use Spring `RestClient` backed by Apache HttpClient 5 with one shared, closeable
pooling client for the `client.FreeProviderClient` and
`client.PremiumProviderClient` implementations behind the `ProviderClient`
boundary.
Configure separate total/per-route connection
limits, connection acquisition timeout, connect timeout, response timeout,
stale-connection validation, and idle/expired eviction.

Apply resilience in this order: provider retry for transient failures, circuit
breaker for sustained failures, provider rate limiter for quota, then bulkhead
for concurrency admission. The bulkhead is non-waiting so overload fails fast.

## Consequences

The pool removes connection setup overhead while timeouts cap resource lifetime.
The rate limiter protects provider quotas; the pool only limits sockets and is
not a substitute for quota admission. The bulkhead prevents slow providers from
consuming all application execution capacity. Tuning one limit requires checking
the others and the provider's actual quota.

Separate clients per provider were rejected because a single pool with per-route
limits already isolates routes while avoiding duplicate connection managers.
