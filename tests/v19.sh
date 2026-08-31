#!/bin/bash
set -Eeuo pipefail
umask 077

result=${TKL_TEST_RESULT:?TKL_TEST_RESULT is required}
password=${TKL_TEST_APP_PASS:?TKL_TEST_APP_PASS is required}
base=https://127.0.0.1/couchdb
database=tkl_v19_smoke_$$
document=main_flow
response=/tmp/tkl-couchdb-response.$$

cleanup() {
    if [[ -n $database ]]; then
        curl --insecure --silent --show-error --user "admin:$password" \
            --request DELETE "$base/$database" >/dev/null 2>&1 || true
    fi
    rm -f -- "$response"
}
trap cleanup EXIT

systemctl --quiet is-active couchdb.service nginx.service multi-user.target
installed=$(dpkg-query -W -f='${Version}' couchdb)

curl --insecure --fail --silent --show-error https://127.0.0.1/ >"$response"
grep -q 'TurnKey CouchDB' "$response"
curl --insecure --fail --location --silent --show-error \
    "$base/_utils/" >/dev/null

curl --insecure --fail --silent --show-error --user "admin:$password" \
    "$base/_session" >"$response"
python3 -c 'import json,sys; assert json.load(open(sys.argv[1]))["userCtx"]["name"] == "admin"' \
    "$response"

unauthenticated_status=$(curl --insecure --silent --show-error \
    --output /dev/null --write-out '%{http_code}' --request PUT \
    "$base/${database}_unauthenticated")
test "$unauthenticated_status" = 401

curl --insecure --fail --silent --show-error --user "admin:$password" \
    --request PUT "$base/$database" >/dev/null
curl --insecure --fail --silent --show-error --user "admin:$password" \
    --header 'Content-Type: application/json' --request PUT \
    --data '{"kind":"turnkey-v19","main_flow":true}' \
    "$base/$database/$document" >/dev/null
curl --insecure --fail --silent --show-error --user "admin:$password" \
    "$base/$database/$document" >"$response"
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["_id"] == "main_flow" and d["kind"] == "turnkey-v19" and d["main_flow"] is True' \
    "$response"
curl --insecure --fail --silent --show-error --user "admin:$password" \
    --request DELETE "$base/$database" >/dev/null
database=

before=$installed
apt-get update >/dev/null
candidate=$(apt-cache policy couchdb | awk '/Candidate:/ {print $2}')
test -n "$candidate"
test "$candidate" != '(none)'
candidate_priority() {
    apt-cache policy "$1" |
        awk '$1 == "Candidate:" { candidate=$2; next }
             candidate != "" && $1 == candidate { print $2; exit }
             candidate != "" && $1 == "***" && $2 == candidate {
                 print $3; exit
             }'
}
test "$(candidate_priority couchdb)" = 500
test "$(candidate_priority couchdb-nouveau)" = 100
! dpkg-query -W couchdb-nouveau >/dev/null 2>&1
apt-get indextargets --format '$(SITE)|$(SUITE)|$(COMPONENT)' |
    grep -Fx 'https://apache.jfrog.io/artifactory/couchdb-deb|trixie|main' \
        >/dev/null
test "$(dpkg-query -W -f='${Version}' couchdb)" = "$before"
grep -Fxq 'Signed-By: /usr/share/keyrings/couchdb.gpg' \
    /etc/apt/sources.list.d/couchdb.sources

cat >"$result" <<EOF
package_source=Official Apache CouchDB APT repository for Debian Trixie
installed_version=$installed
runtime_checks=normal init; CouchDB and Nginx active; admin authentication; Admin Party disabled; landing page and Fauxton; database and document create, read, and delete
updater_command=apt-get update; apt-cache policy couchdb; apt-get indextargets
updater_result=signed metadata refreshed; installed version unchanged; eligible candidate $candidate; couchdb priority 500; uninstalled couchdb-nouveau priority 100
updater_channel=Apache CouchDB Trixie APT repository
integrity_evidence=APT accepted signed repository metadata using /usr/share/keyrings/couchdb.gpg
EOF
