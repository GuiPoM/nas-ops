#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

for script in "$ROOT_DIR"/install.sh "$ROOT_DIR"/nas-*; do
    bash -n "$script"
done

mkdir -p "$TMP_DIR/bin" "$TMP_DIR/stack-a" "$TMP_DIR/stack-b"

cat > "$TMP_DIR/bin/docker" <<'MOCK_DOCKER'
#!/bin/bash
case "$1" in
    compose)
        printf '%s\n' "$PWD|$*" >> "$TEST_COMPOSE_LOG"
        ;;
    ps)
        printf '%s\n' 'abc123:app"one'
        ;;
    pull)
        ;;
    inspect)
        format="$2"
        case "$format" in
            *working_dir*) printf '%s\n' "$TEST_STACK_A" ;;
            *Config.Image*) printf '%s\n' 'repo:"tag' ;;
            *'{{.Image}}'*) printf '%s\n' 'old-image' ;;
            *'{{.Id}}'*) printf '%s\n' 'new-image' ;;
            *'org.opencontainers.image.version'*) printf '%s\n' 'v"2' ;;
            *'org.opencontainers.image.source'*) printf '%s\n' 'https://example.com/a"b.git' ;;
            *) printf '\n' ;;
        esac
        ;;
esac
MOCK_DOCKER
chmod +x "$TMP_DIR/bin/docker"

export TEST_STACK_A="$TMP_DIR/stack-a"
export PATH="$TMP_DIR/bin:$PATH"

pull_result=$(bash "$ROOT_DIR/nas-docker-pull")
python3 - "$pull_result" <<'PY'
import json
import sys

result = json.loads(sys.argv[1])
container = result["containers"][0]
assert container["name"] == 'app"one', container
assert container["source"] == 'https://example.com/a"b', container
assert result["sources"][0]["releases"].endswith('/releases'), result
print("JSON contract: OK")
PY

cat > "$TMP_DIR/cache.json" <<EOF_CACHE
{"count":3,"containers":[{"name":"app","compose_dir":"$TMP_DIR/stack-a","current":"1","available":"2"},{"name":"db","compose_dir":"$TMP_DIR/stack-a","current":"1","available":"2"},{"name":"other","compose_dir":"$TMP_DIR/stack-b","current":"3","available":"4"}],"sources":[]}
EOF_CACHE

export TEST_COMPOSE_LOG="$TMP_DIR/compose.log"
result=$(bash "$ROOT_DIR/nas-docker-up" --from-cache "$TMP_DIR/cache.json" --yes)

python3 - "$result" "$TEST_COMPOSE_LOG" <<'PY'
import json
import sys

result = json.loads(sys.argv[1])
assert result == {"upgraded": 3, "failed": 0}, result
with open(sys.argv[2], encoding="utf-8") as stream:
    calls = stream.readlines()
assert len(calls) == 2, calls
print("Contract tests: OK")
PY
