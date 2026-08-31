#!/bin/bash
set -Eeuo pipefail
umask 077

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
old_version=3.5.1~trixie
admin=admin
password=turnkey-upgrade-test
database=tkl_v19_upgrade
document=pre_upgrade_document
response=/tmp/couchdb-upgrade-response.$$
couchdb_pid=/tmp/couchdb-upgrade-pid.$$
couchdb_log=/tmp/couchdb-upgrade.log

stop_couchdb() {
    if [[ ! -s $couchdb_pid ]]; then
        return
    fi
    pid=$(cat "$couchdb_pid")
    kill "$pid"
    for _ in $(seq 1 30); do
        if ! kill -0 "$pid" 2>/dev/null; then
            rm -f -- "$couchdb_pid"
            return
        fi
        sleep 1
    done
    echo 'CouchDB did not stop cleanly' >&2
    return 1
}

cleanup() {
    curl --fail --silent --show-error --user "$admin:$password" \
        --request DELETE "http://127.0.0.1:5984/$database" \
        >/dev/null 2>&1 || true
    stop_couchdb >/dev/null 2>&1 || true
    rm -f -- "$response" "$couchdb_pid"
}
trap cleanup EXIT

export DEBIAN_FRONTEND=noninteractive
apt-get update >/dev/null
apt-get install --assume-yes --no-install-recommends \
    ca-certificates curl gpg >/dev/null
update-ca-certificates >/dev/null

curl --fail --silent --show-error --proto '=https' --tlsv1.2 \
    https://couchdb.apache.org/repo/keys.asc -o /tmp/couchdb-keys.asc
fingerprint=$(gpg --show-keys --with-colons /tmp/couchdb-keys.asc |
    sed -n 's/^fpr:::::::::\([^:]*\):$/\1/p' | head -n1)
test "$fingerprint" = 390EF70BB1EA12B2773962950EE62FB37A00258D
gpg --batch --dearmor --output /usr/share/keyrings/couchdb.gpg \
    /tmp/couchdb-keys.asc
chmod 0644 /usr/share/keyrings/couchdb.gpg

install -Dm0644 "$repo_root/overlay/etc/apt/sources.list.d/couchdb.sources" \
    /etc/apt/sources.list.d/couchdb.sources
install -Dm0644 "$repo_root/overlay/etc/apt/preferences.d/couchdb.pref" \
    /etc/apt/preferences.d/couchdb.pref
apt-get update >/dev/null

candidate=$(apt-cache policy couchdb | awk '/Candidate:/ {print $2}')
test "$candidate" = 3.5.2.1~trixie
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

debconf-set-selections <<EOF
couchdb couchdb/adminpass password $password
couchdb couchdb/adminpass_again password $password
couchdb couchdb/postrm_remove_databases boolean false
couchdb couchdb/bindaddress string 127.0.0.1
couchdb couchdb/cookie string upgradeCookie
couchdb couchdb/nodename string couchdb@localhost
couchdb couchdb/mode select standalone
EOF
apt-get install --assume-yes "couchdb=$old_version" >/dev/null
test "$(dpkg-query -W -f='${Version}' couchdb)" = "$old_version"

start_couchdb() {
    su -s /bin/sh couchdb -c \
        "HOME=/opt/couchdb /opt/couchdb/bin/couchdb >'$couchdb_log' 2>&1 & echo \$!" \
        >"$couchdb_pid"
    for _ in $(seq 1 60); do
        if curl --fail --silent --show-error \
                "http://127.0.0.1:5984/" >/dev/null 2>&1; then
            return
        fi
        sleep 1
    done
    echo 'CouchDB did not become ready' >&2
    cat "$couchdb_log" >&2
    return 1
}

start_couchdb
curl --fail --silent --show-error --user "$admin:$password" \
    http://127.0.0.1:5984/_session >"$response"
grep -Eq '"name"[[:space:]]*:[[:space:]]*"admin"' "$response"
curl --fail --silent --show-error --user "$admin:$password" \
    --request PUT "http://127.0.0.1:5984/$database" >/dev/null
curl --fail --silent --show-error --user "$admin:$password" \
    --header 'Content-Type: application/json' --request PUT \
    --data '{"created_before_upgrade":true,"value":"preserved"}' \
    "http://127.0.0.1:5984/$database/$document" >/dev/null
stop_couchdb

apt-get install --assume-yes --only-upgrade couchdb >/dev/null
installed=$(dpkg-query -W -f='${Version}' couchdb)
test "$installed" = "$candidate"

start_couchdb
curl --fail --silent --show-error --user "$admin:$password" \
    http://127.0.0.1:5984/_session >"$response"
grep -Eq '"name"[[:space:]]*:[[:space:]]*"admin"' "$response"
curl --fail --silent --show-error --user "$admin:$password" \
    "http://127.0.0.1:5984/$database/$document" >"$response"
grep -Eq '"created_before_upgrade"[[:space:]]*:[[:space:]]*true' "$response"
grep -Eq '"value"[[:space:]]*:[[:space:]]*"preserved"' "$response"

cat <<EOF
upgrade_from=$old_version
upgrade_to=$installed
upgrade_result=admin authentication and pre-upgrade document retrieval passed
policy_result=couchdb priority 500; uninstalled couchdb-nouveau priority 100
integrity_result=TLS verified; Apache signing key fingerprint $fingerprint; signed APT metadata accepted
EOF
