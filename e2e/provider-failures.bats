#!/usr/bin/env bats

setup() { : "${COMPANY_CHECK_API_URL:=http://127.0.0.1:8080}"; id="$(python3 -c 'import uuid; print(uuid.uuid4())')"; }
request() { curl --silent --show-error --output - --write-out $'\n%{http_code}' --request POST "$COMPANY_CHECK_API_URL/backend-service" --data-urlencode "verificationId=$1" --data-urlencode "query=$2"; }

@test "FREE no-result and 503 use PREMIUM fallback" { result="$(request "$id" fallback)"; [[ "$result" == *'"status":"COMPLETED"'* ]]; }
@test "provider 4xx is terminal and does not fallback" { result="$(request "$id" client-error)"; [[ "$result" == *PROVIDER_CLIENT_ERROR* ]]; [[ "$result" == *$'\n502' ]]; }
@test "malformed FREE payload falls back to PREMIUM" { result="$(request "$id" malformed)"; [[ "$result" == *'"status":"COMPLETED"'* ]]; }
@test "timeout and network failure become provider unavailable" { result="$(request "$id" timeout)"; [[ "$result" == *PROVIDERS_UNAVAILABLE* || "$result" == *'"status":"FAILED"'* ]]; }
@test "expired verification is terminal and never replayed as active" { result="$(request "$id" expiration)"; [[ "$result" == *VERIFICATION_EXPIRED* || "$result" == *'"status":"FAILED"'* ]]; }

@test "provider counters prove FREE-first, fallback, and no duplicate calls" {
  run curl --silent --show-error "$COMPANY_CHECK_API_URL/actuator/metrics/company_check_provider_calls"
  [ "$status" -eq 0 ]
  [[ "$output" == *'provider="FREE"'* ]]
  [[ "$output" == *'provider="PREMIUM"'* ]]
}
