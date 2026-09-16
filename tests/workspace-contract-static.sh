#!/usr/bin/env bash
set -euo pipefail

validator="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)/workspace-validate.sh"

grep -Eq 'for client in e2e/verification\.bats e2e/provider-failures\.bats; do' "$validator"
grep -Eq 'for client in e2e/verification\.bats e2e/provider-failures\.bats performance/locustfile\.py; do' "$validator"
grep -Eq 'canonical field missing from E2E client' "$validator"
grep -Eq 'self\\.client\\.post' "$validator"
! grep -Eq 'canonical field missing from executable clients' "$validator"

get_forms='curl -X GET /backend-service
curl --get /backend-service'
post_forms='curl -X POST /backend-service
curl --request POST /backend-service'
grep -Eq -- '-X\[\[:space:\]\]\+GET.*backend-service|backend-service.*-X\[\[:space:\]\]\+GET' "$validator"
grep -Eq -- '-X\[\[:space:\]\]\+POST.*backend-service|backend-service.*-X\[\[:space:\]\]\+POST' "$validator"
! printf '%s\n' "$get_forms" | grep -Eq -- '--request[[:space:]]+POST|-[Xx][[:space:]]+POST'
printf '%s\n' "$post_forms" | grep -Eq -- '--request[[:space:]]+POST|-[Xx][[:space:]]+POST'

fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/e2e" "$fixture/performance"
cat > "$fixture/e2e/verification.bats" <<'EOF'
curl --request POST /backend-service?verificationId=uuid\&query=text
curl -X POST /backend-service?verificationId=uuid\&query=text
cin name registrationDate address isActive IN_PROGRESS COMPLETED FAILED
EOF
cat > "$fixture/e2e/provider-failures.bats" <<'EOF'
curl --request POST /backend-service?verificationId=uuid\&query=text
curl -X POST /backend-service?verificationId=uuid\&query=text
cin name registrationDate address isActive IN_PROGRESS COMPLETED FAILED
EOF
cat > "$fixture/performance/locustfile.py" <<'EOF'
self.client.post("/backend-service", params={"verificationId": "uuid", "query": "text"})
EOF
"$validator" --client-contract-root "$fixture"

for invalid_get in '-X GET' '--get'; do
  invalid_fixture="$(mktemp -d)"
  cp -R "$fixture/." "$invalid_fixture/"
  printf 'curl %s /backend-service?verificationId=uuid\\&query=text\n' "$invalid_get" > "$invalid_fixture/e2e/verification.bats"
  if "$validator" --client-contract-root "$invalid_fixture" >/dev/null 2>&1; then
    printf 'validator accepted invalid GET form: %s\n' "$invalid_get" >&2
    exit 1
  fi
  rm -rf "$invalid_fixture"
done

printf 'workspace contract static assertions are present\n'
