# Starting the Application

This is the complete local startup path for the single-node profile. The
recommended interface is `mise`; it uses the existing Gradle/Paketo image
contract and Docker Compose for PostgreSQL, the provider simulators, and the
Spring Boot backend.

## Prerequisites

1. Install `mise` and initialize the workspace submodules:

   ```sh
   mise trust
   mise run install
   ```

   `mise run install` initializes the submodules, installs every pinned tool
   (Java 25, Docker, Compose, Bun, and the optional Colima runtime), and creates
   `.env` from `.env.example` only when `.env` is absent.

## Complete setup with mise

Choose exactly one image path:

```sh
mise run setup-jvm
# or: mise run setup-native
```

The setup task uses an existing Docker daemon first and starts Colima (profile
`emme` by default, override with `COLIMA_PROFILE`) only when Docker is
unavailable; it does not overwrite `.env`, Docker Desktop, or an existing Colima
configuration. It runs the locked provider checks, builds
`company-check-provider:local` and `company-check-service:local`, starts the
single-node overlay, and waits for `/actuator/health`.

Image-build memory guidance:

| Image path | Setup gate | Guidance |
|---|---:|---|
| JVM | 4 GiB Docker memory | 2 GiB is a constrained lower-bound attempt and may fail from build overhead. |
| Native | 12 GiB Docker memory | Native compilation runs with the GraalVM/native-image toolchain. |

The runner checks the active daemon and reports the required allocation before
building. These values are local operational recommendations, not hard Paketo
minimums. See the [Paketo Java Native Image Buildpack reference](https://paketo.io/docs/reference/java-native-image-reference/).

## Manual image/build fallback

When diagnosing a build, the equivalent lower-level commands are:

```sh
(cd company-check-provider && bun install --frozen-lockfile && bun run quality)
docker build -t company-check-provider:local company-check-provider
./company-check-service/gradlew -p company-check-service bootBuildImage \
  -PimageName=company-check-service:local
```

For a native image, add `-PimageVariant=native`. The Spring Boot plugin
auto-resolves the Paketo builder and its embedded run image.

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
