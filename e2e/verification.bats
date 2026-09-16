#!/usr/bin/env bats

setup() {
  : "${COMPANY_CHECK_API_URL:=http://127.0.0.1:8080}"
  verification_id="$(python3 -c 'import uuid; print(uuid.uuid4())')"
}

json_field() {
  python3 -c 'import json,sys; value=json.load(sys.stdin); 
path=sys.argv[1].split(".");
for part in path: value=value[int(part)] if isinstance(value,list) else value[part]
print(json.dumps(value) if isinstance(value,(dict,list)) else value)' "$1"
}

submit() { curl --silent --show-error --fail-with-body --get "$COMPANY_CHECK_API_URL/backend-service" --data-urlencode "verificationId=$1" --data-urlencode "query=$2"; }

@test "successful FREE match returns exact canonical PDF fields" {
  run submit "$verification_id" "acme"
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | json_field status)" = MATCH ]
  [ "$(printf '%s' "$output" | json_field company.companyIdentificationNumber)" != "" ]
  [ "$(printf '%s' "$output" | json_field company.companyName)" != "" ]
  [ "$(printf '%s' "$output" | json_field company.registrationDate)" != "" ]
  [ "$(printf '%s' "$output" | json_field company.address)" != "" ]
  [ "$(printf '%s' "$output" | json_field company.isActive)" = true ]
}

@test "no result is terminal NO_MATCH" {
  run submit "$verification_id" "definitely-no-company-match"
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | json_field status)" = NO_MATCH ]
}

@test "multiple active matches return company and otherResults" {
  run submit "$verification_id" "multiple-active"
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | json_field status)" = MATCH ]
  [ "$(printf '%s' "$output" | json_field otherResults.0.companyIdentificationNumber)" != "" ]
}

@test "same completed verification replays without a new provider lookup" {
  run submit "$verification_id" "acme"
  [ "$status" -eq 0 ]
  first="$output"
  run submit "$verification_id" " ACME "
  [ "$status" -eq 0 ]
  [ "$output" = "$first" ]
}

@test "same ID with a different normalized query is rejected" {
  submit "$verification_id" "acme" >/dev/null
  run curl --silent --show-error --output - --write-out $'\n%{http_code}' --get "$COMPANY_CHECK_API_URL/backend-service" --data-urlencode "verificationId=$verification_id" --data-urlencode query="other"
  [ "${output##*$'\n'}" = 409 ]
  [[ "$output" == *VERIFICATION_ID_REUSE* ]]
}

@test "active retrieval reports IN_PROGRESS" {
  id="$(python3 -c 'import uuid; print(uuid.uuid4())')"
  submit "$id" "delayed" >/dev/null &
  run curl --silent --show-error --get "$COMPANY_CHECK_API_URL/verifications/$id"
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | json_field status)" = IN_PROGRESS ]
}
