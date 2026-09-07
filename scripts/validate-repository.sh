#!/usr/bin/env bash
set -euo pipefail

# Offline-only repository validation. This script deliberately performs no SSH,
# HTTP, registry, package-manager, container, or service operation.
export LC_ALL=C

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

check_no=0
pass() {
  check_no=$((check_no + 1))
  printf 'PASS %02d %s\n' "$check_no" "$1"
}

fail() {
  printf 'FAIL %02d %s\n' "$((check_no + 1))" "$1" >&2
  exit 1
}

require_file() {
  test -f "$1" || fail "required file missing: $1"
}

required_files=(
  AGENTS.md
  INTERNAL_AGENT.md
  README.md
  docs/06-airgap-deployment-guide.md
  docs/07-validation-and-operations.md
  docs/10-separate-model-import-application.md
  docs/11-oci-model-content-audit.md
  docs/12-external-repository-reference-submission.md
  docs/13-agent-modes.md
  docs/14-ssh-harness.md
  docs/15-local-coding-agent-maintainability.md
  docs/source-ledger.md
  manifests/artifacts.lock.yaml
  manifests/external-repository-references.tsv
  manifests/quarantine-oci-required.txt
  manifests/quarantine-raw-sources.tsv
  manifests/separate-model-import.tsv
  configs/cluster.env.example
  configs/node.env.example
  scripts/audit-import-routing.sh
  scripts/cluster-harness.sh
)

for file in "${required_files[@]}"; do
  require_file "$file"
done
pass 'offline navigation and required maintenance entry points exist'

if find AGENTS.md INTERNAL_AGENT.md README.md docs manifests configs scripts \
    -type f -print0 | xargs -0 grep -Il $'\r' | grep -q .; then
  fail 'CRLF line endings found in maintained repository files'
fi
if grep -RInE '^(<<<<<<<|=======|>>>>>>>)' \
    AGENTS.md INTERNAL_AGENT.md README.md docs manifests configs scripts >/dev/null; then
  fail 'merge-conflict marker found'
fi
pass 'text files have no CRLF or merge-conflict markers'

while IFS= read -r script; do
  bash -n "$script" || fail "bash syntax error: $script"
  test -x "$script" || fail "shell script is not executable: $script"
  grep -Fqx 'set -euo pipefail' "$script" || fail "strict shell mode missing: $script"
done < <(find scripts -maxdepth 1 -type f -name '*.sh' -print | sort)
pass 'all shell scripts pass bash -n, are executable, and use strict mode'

while IFS= read -r source; do
  python3 - "$source" <<'PY' || fail "python syntax error: $source"
import ast
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
PY
done < <(find scripts -maxdepth 1 -type f -name '*.py' -print | sort)
pass 'all Python scripts pass an AST syntax check without writing bytecode'

grep -Fq 'DGX_AGENT_MODE:-external' scripts/cluster-harness.sh || \
  fail 'cluster harness no longer defaults to external mode'
grep -Fq 'StrictHostKeyChecking=yes' scripts/cluster-harness.sh || \
  fail 'strict SSH host-key checking gate is missing'
grep -Fq 'require_apply' scripts/cluster-harness.sh || \
  fail 'mutating-action --apply gate is missing'
grep -Fq 'DGX_AGENT_MODE=internal' docs/13-agent-modes.md || \
  fail 'internal-mode transition is not documented'
grep -Fq 'fail-closed' INTERNAL_AGENT.md || \
  fail 'compact agent entry point does not declare fail-closed behavior'
pass 'agent-mode, SSH host-key, and human mutation gates are discoverable'

external_validate_output="$(DGX_AGENT_MODE=external \
  ./scripts/cluster-harness.sh configs/cluster.env.example validate 2>&1)" || \
  fail 'external-mode local harness validation was rejected'
case "$external_validate_output" in
  *'config syntax/schema valid;'*'all SSH and mutation actions disabled'*) ;;
  *) fail 'external-mode local harness validation did not report its network boundary' ;;
esac

external_check_output=''
if external_check_output="$(DGX_AGENT_MODE=external \
    ./scripts/cluster-harness.sh configs/cluster.env.example check 2>&1)"; then
  fail 'external mode unexpectedly allowed an SSH-capable harness action'
fi
case "$external_check_output" in
  *'permits only local validate'*) ;;
  *) fail 'external-mode SSH refusal was not explicit' ;;
esac

unset_mode_output=''
if unset_mode_output="$(env -u DGX_AGENT_MODE \
    ./scripts/cluster-harness.sh configs/cluster.env.example check 2>&1)"; then
  fail 'unset agent mode unexpectedly allowed an SSH-capable harness action'
fi
case "$unset_mode_output" in
  *'DGX_AGENT_MODE=external permits only local validate'*) ;;
  *) fail 'unset agent mode did not fail closed to external' ;;
esac

invalid_mode_output=''
if invalid_mode_output="$(DGX_AGENT_MODE=invalid \
    ./scripts/cluster-harness.sh configs/cluster.env.example validate 2>&1)"; then
  fail 'invalid agent mode was unexpectedly accepted'
fi
case "$invalid_mode_output" in
  *'expected external or internal'*) ;;
  *) fail 'invalid agent mode refusal was not explicit' ;;
esac
pass 'external-mode harness probe is local-only and rejects SSH-capable actions'

grep -Fqx '.env' .gitignore || fail '.env is not ignored'
grep -Fqx 'state/' .gitignore || fail 'state diagnostics/config directory is not ignored'
grep -Fqx 'configs/cluster.env' .gitignore || fail 'real cluster configuration is not ignored'

if test -e .env; then
  env_mode="$(stat -c '%a' .env)"
  test "$env_mode" = 600 || fail ".env must have mode 600, got $env_mode"
fi

if test -d .git; then
  forbidden_tracked="$(git ls-files | grep -E \
    '(^|/)(\.env($|\.)|state/|staging/|media/|known_hosts([^/]*$)|id_(rsa|ed25519)|[^/]+\.(pem|key)$|configs/cluster(\.[^/]*)?\.env$)' | \
    grep -Ev '(^|/)\.env\.example$' || true)"
  test -z "$forbidden_tracked" || fail 'secret/runtime file is tracked by Git'
  private_key_pattern='-----''BEGIN .*PRIVATE KEY-----'
  if git grep -Il -- "$private_key_pattern" >/dev/null 2>&1; then
    fail 'private-key material found in a tracked file'
  fi
else
  private_key_pattern='-----''BEGIN (OPENSSH |RSA |EC )?PRIVATE KEY-----'
  if grep -RIlE --exclude-dir=.git --exclude-dir=state --exclude-dir=staging \
      --exclude-dir=media --exclude='.env' -- \
      "$private_key_pattern" \
      AGENTS.md INTERNAL_AGENT.md README.md docs manifests configs scripts >/dev/null 2>&1; then
    fail 'private-key material found in a public repository candidate file'
  fi
fi
pass 'secret files are ignored; local .env permission and private-key leak gates pass'

./scripts/audit-import-routing.sh >/dev/null || fail 'import-route separation audit failed'
pass 'OCI, model, repository-reference, and minimal RAW import routes stay separated'

for marker in \
  'status' \
  'collect' \
  'stop' \
  'rollback'; do
  grep -Fqi "$marker" docs/14-ssh-harness.md || \
    fail "SSH troubleshooting workflow is missing marker: $marker"
done
grep -Fq 'docs/12-external-repository-reference-submission.md' INTERNAL_AGENT.md || \
  fail 'compact agent entry point does not route upstream provenance work to the separate reference procedure'
grep -Fq 'manifests/external-repository-references.tsv' INTERNAL_AGENT.md || \
  fail 'compact agent entry point does not route upstream provenance work to the pinned reference manifest'
grep -Fq '작업 단위' INTERNAL_AGENT.md || \
  fail 'compact agent entry point lacks small-context task decomposition'
pass 'provenance and evidence-first troubleshooting workflows are discoverable'

for target in \
  docs/13-agent-modes.md \
  docs/14-ssh-harness.md \
  docs/15-local-coding-agent-maintainability.md \
  INTERNAL_AGENT.md \
  scripts/validate-repository.sh; do
  grep -Fq "$target" AGENTS.md || fail "AGENTS.md navigation missing: $target"
done
pass 'AGENTS.md links the internal-agent contract and one-command validator'

pass 'repository validation completed without network or SSH side effects'
