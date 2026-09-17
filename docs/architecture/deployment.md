# Deployment Topologies

## Single node

```mermaid
flowchart LR
  Host[Host :8080] --> Backend[backend\nsingle-node]
  Backend --> PG[(postgres)]
  Backend --> Free[free-provider]
  Backend --> Premium[premium-provider]
```

There is one backend replica, local coordination, and no Redis service. This is
the simplest topology for local API exploration.

## Distributed

```mermaid
flowchart LR
  LoadBalancer[Internal caller / Locust] --> B1[backend replica 1]
  LoadBalancer --> B2[backend replica 2]
  B1 --> PG[(postgres)]
  B2 --> PG
  B1 --> Redis[(redis)]
  B2 --> Redis
  B1 --> Free[free-provider]
  B2 --> Free
  B1 --> Premium[premium-provider]
  B2 --> Premium
```

The distributed Compose overlay removes the host-published backend port on
purpose. It is an internal network topology; use the Locust service or a
temporary internal-network client to exercise it. Redis shares coordination,
rate limits, cache entries, and the expiration lease across replicas.

Development Compose accepts local image tags from `.env.example`. Release
validation must provide digest-pinned image variables. The performance runner
resolves local images to repository digests before starting its Compose stack.
