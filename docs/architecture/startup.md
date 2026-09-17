# Starting the Application

This is the complete local startup path for the single-node profile. It uses
Docker Compose for PostgreSQL, the provider simulators, and the Spring Boot
backend.

## Prerequisites

1. Initialize the provider submodule:

   ```sh
   git submodule update --init --recursive
   ```

2. Install Java 25, Docker, Compose, and Bun. With `mise`:

   ```sh
   mise trust
   mise install --include-lazy
   ```

3. Start or select a Docker runtime. Docker Desktop/Engine may already be
   running. With the mise-managed Colima runtime:

   ```sh
   colima start --cpu 4 --memory 4
   ```

## Build the local images

1. Create the local environment file:

   ```sh
   cp .env.example .env
   ```

2. Install and verify the provider, then build its image:

   ```sh
   (cd company-check-provider && bun install --frozen-lockfile && bun run quality)
   docker build -t company-check-provider:local company-check-provider
   ```

3. Build the backend image. Copy
   `company-check-service/gradle.properties.example` to
   `company-check-service/gradle.properties`, replace the two Paketo
   `<64-hex-digest>` placeholders with approved immutable references, and run:

   ```sh
   ./company-check-service/gradlew -p company-check-service image \
     -PimageName=company-check-service:local
   ```

   Alternatively, pass `-PpaketoBuilderImage` and `-PpaketoRunImage` with the
   approved digest references instead of creating the local properties file.

## Start and verify single-node mode

After the local images are available, `mise run start` performs the same
single-node startup and starts Colima automatically when Docker is unavailable
and Colima is installed. The direct commands below expose each step.

1. Render the merged Compose configuration:

   ```sh
   docker compose -f compose.yaml -f compose.single.yaml config
   ```

2. Start one backend replica. PostgreSQL and both provider simulators are
   started automatically and must become healthy first:

   ```sh
   docker compose -f compose.yaml -f compose.single.yaml up -d --scale backend=1
   ```

3. Check container status and backend health:

   ```sh
   docker compose -f compose.yaml -f compose.single.yaml ps
   curl --fail http://localhost:8080/actuator/health
   ```

4. Exercise the API:

   ```sh
   verification_id="$(uuidgen)"
   curl --fail --get http://localhost:8080/backend-service \
     --data-urlencode "verificationId=$verification_id" \
     --data-urlencode "query=Acme"
   curl --fail http://localhost:8080/verifications/"$verification_id"
   ```

The application uses the `single-node` profile by default. Coordination and
rate limiting are local in this mode; PostgreSQL remains the verification
state authority.

## Optional profiles

Start distributed mode with two backend replicas and shared Redis:

```sh
docker compose -f compose.yaml -f compose.distributed.yaml up -d --scale backend=2
docker compose -f compose.yaml -f compose.distributed.yaml ps
```

The distributed overlay has no host port for an individual backend replica.
Use the Locust profile or an internal Compose-network client to send requests.

Add local metrics, traces, logs, and dashboards to the single-node stack:

```sh
docker compose -f compose.yaml -f compose.single.yaml \
  -f compose.observability.yaml --profile observability up -d --scale backend=1
```

## Stop the application

Stop the profile that was started. This removes containers and networks but
keeps database volumes unless `-v` is explicitly supplied:

```sh
docker compose -f compose.yaml -f compose.single.yaml down --remove-orphans
# or
docker compose -f compose.yaml -f compose.distributed.yaml down --remove-orphans
```

To inspect failures before stopping:

```sh
docker compose ps
docker compose logs --no-color backend free-provider premium-provider postgres
```
