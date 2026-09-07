#!/usr/bin/env bash
set -euo pipefail
umask 077

usage() {
  cat <<'USAGE'
Usage:
  cluster-harness.sh CONFIG validate
  cluster-harness.sh CONFIG check
  cluster-harness.sh CONFIG baseline [OUTPUT_DIR]
  cluster-harness.sh CONFIG sync --apply
  cluster-harness.sh CONFIG image-audit PROFILE --apply
  cluster-harness.sh CONFIG preflight PROFILE
  cluster-harness.sh CONFIG launch PROFILE --apply
  cluster-harness.sh CONFIG stop PROFILE --apply
  cluster-harness.sh CONFIG status PROFILE
  cluster-harness.sh CONFIG smoke PROFILE
  cluster-harness.sh CONFIG gateway-start --apply
  cluster-harness.sh CONFIG gateway-stop --apply
  cluster-harness.sh CONFIG gateway-status
  cluster-harness.sh CONFIG gateway-smoke MODEL_NAME
  cluster-harness.sh CONFIG collect PROFILE [OUTPUT_DIR]

PROFILE is a repository-relative file below configs/profiles/.
All SSH actions require DGX_AGENT_MODE=internal. Mutating actions also require
the literal --apply flag. External or unset mode permits only local `validate`.
USAGE
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
config_file="${1:-}"
action="${2:-}"
test -n "$config_file" && test -n "$action" || { usage >&2; exit 2; }
shift 2
test -f "$config_file" || { printf 'cluster config missing: %s\n' "$config_file" >&2; exit 2; }

agent_mode="${DGX_AGENT_MODE:-external}"
config_placeholder_count=0

validate_config_shape() {
  local line key raw_value value
  local safe_value_re='^[A-Za-z0-9._/@:+,=<>-]*$'
  local -A seen=()
  local -A parsed=()

  bash -n "$config_file" || { printf 'cluster config has invalid Bash syntax: %s\n' "$config_file" >&2; exit 2; }
  while IFS= read -r line || test -n "$line"; do
    line="${line%$'\r'}"
    [[ "$line" =~ ^[[:space:]]*$ || "$line" =~ ^[[:space:]]*# ]] && continue
    [[ "$line" =~ ^([A-Z][A-Z0-9_]*)=(.*)$ ]] || {
      printf 'cluster config must contain only comments, blanks, and KEY=value assignments\n' >&2
      exit 2
    }
    key="${BASH_REMATCH[1]}"
    raw_value="${BASH_REMATCH[2]}"
    case "$key" in
      DGX_AGENT_MODE)
        printf 'DGX_AGENT_MODE must be supplied by the process/session, not CONFIG\n' >&2
        exit 10
        ;;
      CLUSTER_LAUNCHER|DGX1_HOST|DGX2_HOST|SSH_USER|SSH_PORT|SSH_IDENTITY_FILE|SSH_KNOWN_HOSTS_FILE|REMOTE_REPO|REMOTE_NODE_ENV_REL|DGX1_NODE_ENV|DGX2_NODE_ENV|REMOTE_LITELLM_ENV|HEALTH_TIMEOUT_SECONDS|WORKER_START_DELAY_SECONDS|REMOTE_EUGR_DIR|REMOTE_EUGR_PYTHONPATH|REMOTE_EUGR_MANIFEST|REMOTE_EUGR_KNOWN_HOSTS)
        ;;
      *)
        printf 'unknown cluster config key: %s\n' "$key" >&2
        exit 2
        ;;
    esac
    test -z "${seen[$key]+x}" || { printf 'duplicate cluster config key: %s\n' "$key" >&2; exit 2; }
    seen[$key]=1

    value="$raw_value"
    if [[ "$raw_value" == \"* || "$raw_value" == *\" ]]; then
      [[ "$raw_value" == \"*\" && "${#raw_value}" -ge 2 ]] || { printf 'mismatched quotes for config key: %s\n' "$key" >&2; exit 2; }
      value="${raw_value:1:${#raw_value}-2}"
    elif [[ "$raw_value" == \'* || "$raw_value" == *\' ]]; then
      [[ "$raw_value" == \'*\' && "${#raw_value}" -ge 2 ]] || { printf 'mismatched quotes for config key: %s\n' "$key" >&2; exit 2; }
      value="${raw_value:1:${#raw_value}-2}"
    fi
    [[ "$value" =~ $safe_value_re ]] || {
      printf 'unsafe or unsupported characters in cluster config key: %s\n' "$key" >&2
      exit 2
    }
    parsed[$key]="$value"
    if [[ "$value" == *'<'* || "$value" == *'>'* ]]; then
      config_placeholder_count=$((config_placeholder_count + 1))
    fi
  done < "$config_file"

  for key in CLUSTER_LAUNCHER DGX1_HOST DGX2_HOST SSH_USER SSH_PORT SSH_KNOWN_HOSTS_FILE REMOTE_REPO REMOTE_NODE_ENV_REL DGX1_NODE_ENV DGX2_NODE_ENV REMOTE_LITELLM_ENV; do
    test -n "${seen[$key]+x}" || { printf 'missing cluster config key: %s\n' "$key" >&2; exit 2; }
  done
  case "${parsed[CLUSTER_LAUNCHER]}" in
    eugr)
      for key in REMOTE_EUGR_DIR REMOTE_EUGR_PYTHONPATH REMOTE_EUGR_MANIFEST REMOTE_EUGR_KNOWN_HOSTS; do
        test -n "${seen[$key]+x}" || { printf 'missing eugr cluster config key: %s\n' "$key" >&2; exit 2; }
      done
      ;;
    native) ;;
    *) printf 'CLUSTER_LAUNCHER must be eugr or native\n' >&2; exit 2 ;;
  esac
}

validate_config_shape

case "$agent_mode" in
  external)
    if test "$action" = validate && test "$#" -eq 0; then
      printf 'external mode: config syntax/schema valid; unresolved placeholders=%s; all SSH and mutation actions disabled\n' "$config_placeholder_count"
      exit 0
    fi
    printf 'refusing %s: DGX_AGENT_MODE=%s permits only local validate\n' "$action" "$agent_mode" >&2
    exit 10
    ;;
  internal)
    ;;
  *)
    printf 'invalid DGX_AGENT_MODE: expected external or internal, got %s\n' "$agent_mode" >&2
    exit 10
    ;;
esac

config_mode="$(stat -c '%a' "$config_file")"
if (( (8#$config_mode & 077) != 0 )); then
  printf 'internal cluster config must not be group/world accessible: %s mode=%s\n' "$config_file" "$config_mode" >&2
  exit 3
fi

# validate_config_shape guarantees that sourcing cannot invoke commands or
# expansions; actual values are loaded only after the internal-mode gate.
# shellcheck source=/dev/null
source "$config_file"

: "${DGX1_HOST:?set DGX1_HOST}"
: "${DGX2_HOST:?set DGX2_HOST}"
: "${SSH_USER:?set SSH_USER}"
: "${SSH_PORT:?set SSH_PORT}"
: "${SSH_KNOWN_HOSTS_FILE:?set SSH_KNOWN_HOSTS_FILE}"
: "${REMOTE_REPO:?set REMOTE_REPO}"
: "${REMOTE_NODE_ENV_REL:?set REMOTE_NODE_ENV_REL}"
: "${DGX1_NODE_ENV:?set DGX1_NODE_ENV}"
: "${DGX2_NODE_ENV:?set DGX2_NODE_ENV}"
: "${REMOTE_LITELLM_ENV:?set REMOTE_LITELLM_ENV}"
: "${CLUSTER_LAUNCHER:?set CLUSTER_LAUNCHER to eugr or native}"

case "$CLUSTER_LAUNCHER" in
  eugr)
    : "${REMOTE_EUGR_DIR:?set REMOTE_EUGR_DIR for CLUSTER_LAUNCHER=eugr}"
    : "${REMOTE_EUGR_PYTHONPATH:?set REMOTE_EUGR_PYTHONPATH for CLUSTER_LAUNCHER=eugr}"
    : "${REMOTE_EUGR_MANIFEST:?set REMOTE_EUGR_MANIFEST for CLUSTER_LAUNCHER=eugr}"
    : "${REMOTE_EUGR_KNOWN_HOSTS:?set REMOTE_EUGR_KNOWN_HOSTS for CLUSTER_LAUNCHER=eugr}"
    ;;
  native)
    ;;
  *)
    printf 'invalid CLUSTER_LAUNCHER: expected eugr or native, got %s\n' "$CLUSTER_LAUNCHER" >&2
    exit 3
    ;;
esac

health_timeout="${HEALTH_TIMEOUT_SECONDS:-3600}"
worker_start_delay="${WORKER_START_DELAY_SECONDS:-10}"

reject_placeholder() {
  local name="$1" value="$2"
  [[ "$value" != *'<'* && "$value" != *'>'* ]] || {
    printf 'replace placeholder in %s: %s\n' "$name" "$value" >&2
    exit 3
  }
}

safe_absolute_remote_path() {
  local value="$1"
  [[ "$value" =~ ^/[A-Za-z0-9._/-]+$ ]] || return 1
  [[ "/$value/" != *'/../'* && "/$value/" != *'/./'* && "$value" != *'//'* ]]
}

safe_relative_remote_path() {
  local value="$1"
  [[ "$value" =~ ^[A-Za-z0-9._/-]+$ && "$value" != /* ]] || return 1
  [[ "/$value/" != *'/../'* && "/$value/" != *'/./'* && "$value" != *'//'* ]]
}

resolve_local_path() {
  local value="$1"
  case "$value" in
    /*) printf '%s\n' "$value" ;;
    *) printf '%s/%s\n' "$repo_root" "$value" ;;
  esac
}

for pair in \
  "DGX1_HOST=$DGX1_HOST" "DGX2_HOST=$DGX2_HOST" "SSH_USER=$SSH_USER" \
  "SSH_KNOWN_HOSTS_FILE=$SSH_KNOWN_HOSTS_FILE" "REMOTE_REPO=$REMOTE_REPO" \
  "REMOTE_NODE_ENV_REL=$REMOTE_NODE_ENV_REL" "DGX1_NODE_ENV=$DGX1_NODE_ENV" \
  "DGX2_NODE_ENV=$DGX2_NODE_ENV" "REMOTE_LITELLM_ENV=$REMOTE_LITELLM_ENV"; do
  reject_placeholder "${pair%%=*}" "${pair#*=}"
done

[[ "$DGX1_HOST" =~ ^[A-Za-z0-9._-]+$ ]] || { printf 'invalid DGX1_HOST; use an IPv4 address or hostname\n' >&2; exit 3; }
[[ "$DGX2_HOST" =~ ^[A-Za-z0-9._-]+$ ]] || { printf 'invalid DGX2_HOST; use an IPv4 address or hostname\n' >&2; exit 3; }
[[ "$DGX1_HOST" != "$DGX2_HOST" ]] || { printf 'DGX hosts must differ\n' >&2; exit 3; }
[[ "$SSH_USER" =~ ^[A-Za-z_][A-Za-z0-9_-]*$ ]] || { printf 'invalid SSH_USER\n' >&2; exit 3; }
[[ "$SSH_PORT" =~ ^[0-9]+$ ]] && (( SSH_PORT >= 1 && SSH_PORT <= 65535 )) || {
  printf 'SSH_PORT must be an integer from 1 through 65535\n' >&2
  exit 3
}
safe_absolute_remote_path "$REMOTE_REPO" || { printf 'REMOTE_REPO must be a safe absolute path\n' >&2; exit 3; }
safe_relative_remote_path "$REMOTE_NODE_ENV_REL" || {
  printf 'REMOTE_NODE_ENV_REL must be a safe relative path\n' >&2
  exit 3
}
safe_absolute_remote_path "$REMOTE_LITELLM_ENV" || { printf 'REMOTE_LITELLM_ENV must be a safe absolute path\n' >&2; exit 3; }
if test "$CLUSTER_LAUNCHER" = eugr; then
  for pair in \
    "REMOTE_EUGR_DIR=$REMOTE_EUGR_DIR" \
    "REMOTE_EUGR_PYTHONPATH=$REMOTE_EUGR_PYTHONPATH" \
    "REMOTE_EUGR_MANIFEST=$REMOTE_EUGR_MANIFEST" \
    "REMOTE_EUGR_KNOWN_HOSTS=$REMOTE_EUGR_KNOWN_HOSTS"; do
    reject_placeholder "${pair%%=*}" "${pair#*=}"
    safe_absolute_remote_path "${pair#*=}" || {
      printf '%s must be a safe absolute path\n' "${pair%%=*}" >&2
      exit 3
    }
  done
fi
[[ "$health_timeout" =~ ^[0-9]+$ ]] && (( health_timeout > 0 )) || {
  printf 'HEALTH_TIMEOUT_SECONDS must be a positive integer\n' >&2
  exit 3
}
[[ "$worker_start_delay" =~ ^[0-9]+$ ]] && (( worker_start_delay >= 1 && worker_start_delay <= 300 )) || {
  printf 'WORKER_START_DELAY_SECONDS must be an integer from 1 through 300\n' >&2
  exit 3
}

SSH_KNOWN_HOSTS_FILE="$(resolve_local_path "$SSH_KNOWN_HOSTS_FILE")"
DGX1_NODE_ENV="$(resolve_local_path "$DGX1_NODE_ENV")"
DGX2_NODE_ENV="$(resolve_local_path "$DGX2_NODE_ENV")"

test -f "$SSH_KNOWN_HOSTS_FILE" || {
  printf 'known_hosts file missing: %s; verify both host keys out-of-band first\n' "$SSH_KNOWN_HOSTS_FILE" >&2
  exit 4
}
known_hosts_mode="$(stat -c '%a' "$SSH_KNOWN_HOSTS_FILE")"
if (( (8#$known_hosts_mode & 022) != 0 )); then
  printf 'known_hosts file must not be group/world writable: %s mode=%s\n' "$SSH_KNOWN_HOSTS_FILE" "$known_hosts_mode" >&2
  exit 4
fi

ssh_options=(
  -p "$SSH_PORT"
  -o BatchMode=yes
  -o ConnectTimeout=10
  -o StrictHostKeyChecking=yes
  -o "UserKnownHostsFile=$SSH_KNOWN_HOSTS_FILE"
)
scp_options=(
  -q
  -P "$SSH_PORT"
  -o BatchMode=yes
  -o ConnectTimeout=10
  -o StrictHostKeyChecking=yes
  -o "UserKnownHostsFile=$SSH_KNOWN_HOSTS_FILE"
)
if test -n "${SSH_IDENTITY_FILE:-}"; then
  reject_placeholder SSH_IDENTITY_FILE "$SSH_IDENTITY_FILE"
  [[ "$SSH_IDENTITY_FILE" = /* ]] || { printf 'SSH_IDENTITY_FILE must be absolute\n' >&2; exit 4; }
  test -f "$SSH_IDENTITY_FILE" || { printf 'SSH identity file missing: %s\n' "$SSH_IDENTITY_FILE" >&2; exit 4; }
  identity_mode="$(stat -c '%a' "$SSH_IDENTITY_FILE")"
  if (( (8#$identity_mode & 077) != 0 )); then
    printf 'SSH identity file must not be group/world accessible: %s mode=%s\n' "$SSH_IDENTITY_FILE" "$identity_mode" >&2
    exit 4
  fi
  ssh_options+=(-i "$SSH_IDENTITY_FILE")
  scp_options+=(-i "$SSH_IDENTITY_FILE")
fi

dgx1_target="${SSH_USER}@${DGX1_HOST}"
dgx2_target="${SSH_USER}@${DGX2_HOST}"

remote_exec() {
  local target="$1"
  shift
  local remote_command
  printf -v remote_command '%q ' "$@"
  ssh "${ssh_options[@]}" "$target" "$remote_command"
}

remote_bash() {
  local target="$1" remote_script="$2"
  shift 2
  remote_exec "$target" bash -lc "$remote_script" _ "$@"
}

require_apply() {
  test "$#" -eq 1 && test "$1" = --apply || {
    printf 'refusing mutating action without exactly one --apply argument\n' >&2
    exit 5
  }
}

load_profile() {
  local requested_profile="${1:?PROFILE is required}"
  [[ "$requested_profile" =~ ^configs/profiles/[A-Za-z0-9._/-]+\.sh$ ]] || {
    printf 'PROFILE must be below configs/profiles/: %s\n' "$requested_profile" >&2
    exit 6
  }
  [[ "/$requested_profile/" != *'/../'* && "/$requested_profile/" != *'/./'* && "$requested_profile" != *'//'* ]] || {
    printf 'PROFILE must not contain traversal components: %s\n' "$requested_profile" >&2
    exit 6
  }
  profile_abs="$(realpath -e "$repo_root/$requested_profile")" || {
    printf 'profile missing: %s\n' "$repo_root/$requested_profile" >&2
    exit 6
  }
  [[ "$profile_abs" = "$repo_root/configs/profiles/"* ]] || {
    printf 'profile resolves outside configs/profiles/: %s\n' "$requested_profile" >&2
    exit 6
  }
  profile_rel="$requested_profile"
  # shellcheck source=/dev/null
  source "$profile_abs"
  : "${CONTAINER_NAME:?profile must set CONTAINER_NAME}"
  : "${SERVED_MODEL_NAME:?profile must set SERVED_MODEL_NAME}"
  [[ "$CONTAINER_NAME" =~ ^[A-Za-z0-9._-]+$ ]] || { printf 'invalid profile container name\n' >&2; exit 6; }
  [[ "$SERVED_MODEL_NAME" =~ ^[A-Za-z0-9._/-]+$ ]] || { printf 'invalid served model name\n' >&2; exit 6; }
}

remote_profile() {
  local target="$1" script="$2"
  remote_bash "$target" \
    'set -euo pipefail; cd "$1"; exec "$2" "$3" "$4"' \
    "$REMOTE_REPO" "$script" "$profile_rel" "$REMOTE_NODE_ENV_REL"
}

require_private_node_env() {
  local env_file="$1" expected_rank="$2" label="$3" mode rank
  test -f "$env_file" || { printf '%s node env missing: %s\n' "$label" "$env_file" >&2; exit 7; }
  mode="$(stat -c '%a' "$env_file")"
  test "$mode" = 600 || { printf '%s node env must have mode 600: %s mode=%s\n' "$label" "$env_file" "$mode" >&2; exit 7; }
  rank="$(bash -c 'set -euo pipefail; source "$1"; printf "%s" "${NODE_RANK:?node env must set NODE_RANK}"' _ "$env_file")"
  test "$rank" = "$expected_rank" || {
    printf '%s node env must set NODE_RANK=%s, got %s\n' "$label" "$expected_rank" "$rank" >&2
    exit 7
  }
}

verify_remote_rank() {
  local target="$1" expected_rank="$2" label="$3"
  remote_bash "$target" '
    set -euo pipefail
    repo="$1"
    env_rel="$2"
    expected="$3"
    env_file="$repo/$env_rel"
    test -f "$env_file" || { printf "remote node env missing: %s\n" "$env_file" >&2; exit 1; }
    mode="$(stat -c "%a" "$env_file")"
    test "$mode" = 600 || { printf "remote node env must have mode 600: %s mode=%s\n" "$env_file" "$mode" >&2; exit 1; }
    source "$env_file"
    test "${NODE_RANK:-}" = "$expected" || {
      printf "remote NODE_RANK mismatch: expected=%s actual=%s\n" "$expected" "${NODE_RANK:-unset}" >&2
      exit 1
    }
  ' "$REMOTE_REPO" "$REMOTE_NODE_ENV_REL" "$expected_rank" || {
    printf '%s rank validation failed\n' "$label" >&2
    exit 7
  }
}

set_eugr_profile_parameters() {
  case "$profile_rel" in
    configs/profiles/ds4f-base-acceptance.sh)
      eugr_recipe_rel=configs/eugr-recipes/ds4f-base-offline.yaml
      eugr_model_container_path=/models/ds4f
      eugr_dflash=0
      ;;
    configs/profiles/glm53-dflash2-operations.sh)
      eugr_recipe_rel=configs/eugr-recipes/glm53-dflash2-offline.yaml
      eugr_model_container_path=/models/glm53
      eugr_dflash=1
      ;;
    *)
      printf 'profile has no approved eugr recipe mapping; use CLUSTER_LAUNCHER=native: %s\n' "$profile_rel" >&2
      exit 6
      ;;
  esac
}

eugr_gate() {
  remote_bash "$dgx1_target" '
    set -euo pipefail
    repo="$1"
    env_rel="$2"
    eugr_dir="$3"
    manifest="$4"
    pythonpath="$5"
    known_hosts="$6"

    env_file="$repo/$env_rel"
    test -f "$env_file"
    source "$env_file"
    test "${NODE_RANK:-}" = 0 || { printf "eugr must run on NODE_RANK=0\n" >&2; exit 1; }
    [[ "${PEER_FABRIC_IP:-}" =~ ^[A-Za-z0-9._-]+$ ]] || { printf "invalid PEER_FABRIC_IP for eugr\n" >&2; exit 1; }

    test "$known_hosts" = "$HOME/.ssh/known_hosts" || {
      printf "REMOTE_EUGR_KNOWN_HOSTS must be the remote SSH users default: %s/.ssh/known_hosts\n" "$HOME" >&2
      exit 1
    }
    test -f "$known_hosts" || { printf "eugr node-to-node known_hosts missing: %s\n" "$known_hosts" >&2; exit 1; }
    known_hosts_mode="$(stat -c "%a" "$known_hosts")"
    (( (8#$known_hosts_mode & 022) == 0 )) || {
      printf "eugr node-to-node known_hosts is group/world writable: %s mode=%s\n" "$known_hosts" "$known_hosts_mode" >&2
      exit 1
    }

    for file in run-recipe.sh run-recipe.py launch-cluster.sh autodiscover.sh; do
      path="$eugr_dir/$file"
      test -f "$path" || { printf "approved eugr file missing: %s\n" "$path" >&2; exit 1; }
      test -x "$path" || { printf "approved eugr file is not executable: %s\n" "$path" >&2; exit 1; }
      mode="$(stat -c "%a" "$path")"
      (( (8#$mode & 022) == 0 )) || { printf "eugr file is group/world writable: %s mode=%s\n" "$path" "$mode" >&2; exit 1; }
      case "$file" in
        run-recipe.sh) expected=8030c0e0c61cfaa6e85eeeba6bb56ab54cbfbce75a895f7abafb1b43c019cb39 ;;
        run-recipe.py) expected=a1b54bc1da904cd215605f7e9576c541b159f9ccb8cdd3721162c5ef8dfd7a64 ;;
        launch-cluster.sh) expected=9654683812b8b67273e17502d0eaae5613146b4556e731a1740a5241787e5cca ;;
        autodiscover.sh) expected=9d3af8ede40b595c57d314772c288b5fd0cca5d191f40e563e28916a9a02b38b ;;
      esac
      actual="$(sha256sum "$path" | awk "{print \\$1}")"
      test "$actual" = "$expected" || { printf "pinned eugr file SHA-256 mismatch: %s\n" "$file" >&2; exit 1; }
    done
    for forbidden in .git .env build-and-copy.sh hf-download.sh; do
      test ! -e "$eugr_dir/$forbidden" || {
        printf "forbidden repository/download artifact in approved eugr directory: %s\n" "$forbidden" >&2
        exit 1
      }
    done
    while IFS= read -r entry; do
      case "$entry" in
        run-recipe.sh|run-recipe.py|launch-cluster.sh|autodiscover.sh|LICENSE) ;;
        *) printf "unexpected item in approved eugr directory: %s\n" "$entry" >&2; exit 1 ;;
      esac
    done < <(find "$eugr_dir" -mindepth 1 -maxdepth 1 -printf "%f\n" | LC_ALL=C sort)

    test -f "$manifest" || { printf "approved eugr manifest missing: %s\n" "$manifest" >&2; exit 1; }
    "$repo/scripts/verify-sha-manifest.sh" "$eugr_dir" "$manifest"
    bash -n "$eugr_dir/run-recipe.sh" "$eugr_dir/launch-cluster.sh" "$eugr_dir/autodiscover.sh"
    PYTHONDONTWRITEBYTECODE=1 PYTHONPATH="$pythonpath" python3 -c \
      "import ast,pathlib,sys,yaml; assert sys.version_info[:2] == (3,12); root=pathlib.Path(sys.argv[1]).resolve(); yp=pathlib.Path(yaml.__file__).resolve(); assert root in yp.parents, yp; ast.parse(pathlib.Path(sys.argv[2]).read_text())" \
      "$pythonpath" "$eugr_dir/run-recipe.py"

    ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=yes \
      -o "UserKnownHostsFile=$known_hosts" "$PEER_FABRIC_IP" \
      "case \"\$(uname -m)\" in aarch64|arm64) ;; *) exit 1;; esac; docker info >/dev/null"
  ' "$REMOTE_REPO" "$REMOTE_NODE_ENV_REL" "$REMOTE_EUGR_DIR" \
    "$REMOTE_EUGR_MANIFEST" "$REMOTE_EUGR_PYTHONPATH" "$REMOTE_EUGR_KNOWN_HOSTS"
}

eugr_launch() {
  remote_bash "$dgx1_target" '
    set -euo pipefail
    repo="$1"
    env_rel="$2"
    profile_rel="$3"
    recipe_rel="$4"
    model_container_path="$5"
    is_dflash="$6"
    eugr_dir="$7"
    pythonpath="$8"
    known_hosts="$9"

    source "$repo/$env_rel"
    source "$repo/$profile_rel"
    test "${NODE_RANK:-}" = 0
    for value in "$HEAD_FABRIC_IP" "$PEER_FABRIC_IP" "$FABRIC_IFACE" "$RDMA_HCA"; do
      [[ "$value" =~ ^[A-Za-z0-9._-]+$ ]] || { printf "unsafe eugr network value: %s\n" "$value" >&2; exit 1; }
    done
    [[ "$MASTER_PORT" =~ ^[0-9]+$ ]] || { printf "invalid MASTER_PORT\n" >&2; exit 1; }
    [[ "$MODEL_HOST_PATH" =~ ^/[A-Za-z0-9._/-]+$ ]] || { printf "unsafe MODEL_HOST_PATH\n" >&2; exit 1; }

    local_image_ref="$IMAGE_REF"
    if test -n "${LOCAL_IMAGE_ENV:-}" && test -n "${!LOCAL_IMAGE_ENV:-}"; then
      local_image_ref="${!LOCAL_IMAGE_ENV}"
    fi
    [[ "$local_image_ref" =~ ^[A-Za-z0-9._/@:-]+$ ]] || { printf "unsafe local image reference\n" >&2; exit 1; }

    args=(
      "$repo/$recipe_rel"
      -t "$local_image_ref"
      --no-ray
      -d
      -n "$HEAD_FABRIC_IP,$PEER_FABRIC_IP"
      --eth-if "$FABRIC_IFACE"
      --ib-if "$RDMA_HCA"
      --master-port "$MASTER_PORT"
      --name "$CONTAINER_NAME"
      -e "NCCL_IB_ADDR_RANGE=$FABRIC_CIDR"
      -v "$MODEL_HOST_PATH:$model_container_path:ro"
    )
    if test -n "${NCCL_IB_GID_INDEX_OVERRIDE:-}"; then
      [[ "$NCCL_IB_GID_INDEX_OVERRIDE" =~ ^[0-9]+$ ]] || { printf "invalid NCCL_IB_GID_INDEX_OVERRIDE\n" >&2; exit 1; }
      args+=(-e "NCCL_IB_GID_INDEX=$NCCL_IB_GID_INDEX_OVERRIDE")
    fi
    if test -n "${NCCL_DEBUG_OVERRIDE:-}"; then
      case "$NCCL_DEBUG_OVERRIDE" in VERSION|WARN|INFO|TRACE) ;; *) printf "invalid NCCL_DEBUG_OVERRIDE\n" >&2; exit 1;; esac
      args+=(--nccl-debug "$NCCL_DEBUG_OVERRIDE")
    fi

    if test "$is_dflash" = 1; then
      : "${DRAFT_MODEL_HOST_PATH:?node env must set DRAFT_MODEL_HOST_PATH}"
      : "${DRAFT_MODEL_CONTAINER_PATH:?profile must set DRAFT_MODEL_CONTAINER_PATH}"
      : "${PROFILE_PATCH_ENV:?profile must set PROFILE_PATCH_ENV}"
      patch_path="${!PROFILE_PATCH_ENV:-}"
      : "${patch_path:?node env must set the profile patch path}"
      cache_path="${CACHE_HOST_PATH:-/srv/vllm-cache/$PROFILE_ID}"
      for value in "$DRAFT_MODEL_HOST_PATH" "$DRAFT_MODEL_CONTAINER_PATH" "$patch_path" "$PROFILE_PATCH_TARGET" "$cache_path"; do
        [[ "$value" =~ ^/[A-Za-z0-9._/-]+$ ]] || { printf "unsafe eugr mount path: %s\n" "$value" >&2; exit 1; }
      done
      test -d "$cache_path" || { printf "eugr cache directory missing on head: %s\n" "$cache_path" >&2; exit 1; }
      ssh -o BatchMode=yes -o StrictHostKeyChecking=yes -o "UserKnownHostsFile=$known_hosts" \
        "$PEER_FABRIC_IP" test -d "$cache_path" || { printf "eugr cache directory missing on worker: %s\n" "$cache_path" >&2; exit 1; }
      args+=(
        -v "$DRAFT_MODEL_HOST_PATH:$DRAFT_MODEL_CONTAINER_PATH:ro"
        -v "$cache_path:/cache"
        -v "$patch_path:$PROFILE_PATCH_TARGET:ro"
      )
    fi

    cd "$eugr_dir"
    PIP_NO_INDEX=1 PIP_DISABLE_PIP_VERSION_CHECK=1 \
      HF_HUB_OFFLINE=1 TRANSFORMERS_OFFLINE=1 \
      PYTHONDONTWRITEBYTECODE=1 PYTHONPATH="$pythonpath" \
      exec ./run-recipe.sh "${args[@]}"
  ' "$REMOTE_REPO" "$REMOTE_NODE_ENV_REL" "$profile_rel" "$eugr_recipe_rel" \
    "$eugr_model_container_path" "$eugr_dflash" "$REMOTE_EUGR_DIR" \
    "$REMOTE_EUGR_PYTHONPATH" "$REMOTE_EUGR_KNOWN_HOSTS"
}

eugr_stop() {
  remote_bash "$dgx1_target" '
    set -euo pipefail
    repo="$1"
    env_rel="$2"
    eugr_dir="$3"
    name="$4"
    source "$repo/$env_rel"
    cd "$eugr_dir"
    exec ./launch-cluster.sh --no-ray \
      -n "$HEAD_FABRIC_IP,$PEER_FABRIC_IP" \
      --eth-if "$FABRIC_IFACE" --ib-if "$RDMA_HCA" \
      --master-port "$MASTER_PORT" --name "$name" stop
  ' "$REMOTE_REPO" "$REMOTE_NODE_ENV_REL" "$REMOTE_EUGR_DIR" "$CONTAINER_NAME"
}

case "$action" in
  validate)
    test "$#" -eq 0 || { usage >&2; exit 2; }
    printf 'internal cluster configuration passed local static validation: launcher=%s\n' "$CLUSTER_LAUNCHER"
    ;;
  check)
    test "$#" -eq 0 || { usage >&2; exit 2; }
    for spec in "DGX-1|$dgx1_target" "DGX-2|$dgx2_target"; do
      label="${spec%%|*}"
      target="${spec#*|}"
      printf '== %s ==\n' "$label"
      remote_bash "$target" '
        set -euo pipefail
        arch="$(uname -m)"
        case "$arch" in aarch64|arm64) ;; *) printf "unexpected host architecture: %s\n" "$arch" >&2; exit 1 ;; esac
        for cmd in bash curl docker find ibdev2netdev install ip jq nvidia-smi python3 rdma sha256sum ssh stat tar; do
          command -v "$cmd" >/dev/null || { printf "required command missing: %s\n" "$cmd" >&2; exit 1; }
        done
        test "$(docker info --format "{{.Architecture}}")" = arm64 || { printf "Docker architecture is not arm64\n" >&2; exit 1; }
        nvidia-smi -L
        printf "host architecture: %s\n" "$arch"
      '
    done
    ;;
  baseline)
    test "$#" -le 1 || { usage >&2; exit 2; }
    output_dir="${1:-state/baseline-$(date +%Y%m%dT%H%M%S)}"
    if [[ "$output_dir" != /* ]]; then
      output_dir="$repo_root/$output_dir"
    fi
    mkdir -p "$output_dir"
    chmod 700 "$output_dir"
    for spec in "DGX-1|$dgx1_target" "DGX-2|$dgx2_target"; do
      label="${spec%%|*}"
      target="${spec#*|}"
      remote_bash "$target" '
        set -euo pipefail
        repo="$1"
        tmp="$(mktemp -d)"
        trap '\''rm -rf -- "$tmp"'\'' EXIT
        "$repo/scripts/collect-dgx-baseline.sh" "$tmp" >/dev/null
        cat "$tmp/summary.txt"
      ' "$REMOTE_REPO" > "$output_dir/$label.txt"
      chmod 600 "$output_dir/$label.txt"
    done
    printf 'wrote raw DGX baselines to %s\n' "$output_dir"
    ;;
  sync)
    require_apply "$@"
    require_private_node_env "$DGX1_NODE_ENV" 0 DGX-1
    require_private_node_env "$DGX2_NODE_ENV" 1 DGX-2
    for spec in "DGX-1|$dgx1_target|$DGX1_NODE_ENV" "DGX-2|$dgx2_target|$DGX2_NODE_ENV"; do
      label="${spec%%|*}"
      remainder="${spec#*|}"
      target="${remainder%%|*}"
      node_env="${remainder#*|}"
      remote_exec "$target" mkdir -p "$REMOTE_REPO/state"
      tar \
        --exclude=.git \
        --exclude='.env*' \
        --exclude='.ssh' \
        --exclude='configs/cluster.env' \
        --exclude='configs/cluster.*.env' \
        --exclude='configs/*.node.env' \
        --exclude=media \
        --exclude=models \
        --exclude=staging \
        --exclude=state \
        --exclude='*.key' \
        --exclude='*.pem' \
        --exclude='*.log' \
        --exclude='*.tar' \
        --exclude='*.tar.*' \
        --exclude='*.tgz' \
        --exclude='*.zip' \
        --exclude='*.part' \
        --exclude='*.oci' \
        --exclude='*.safetensors' \
        --exclude='*.gguf' \
        --exclude='pytorch_model*.bin' \
        --exclude='*.onnx' \
        --exclude='*.pt' \
        --exclude='*.pth' \
        -czf - -C "$repo_root" . \
        | remote_bash "$target" 'set -euo pipefail; tar -xzf - -C "$1"' "$REMOTE_REPO"
      scp "${scp_options[@]}" "$node_env" "$target:$REMOTE_REPO/$REMOTE_NODE_ENV_REL.next"
      remote_exec "$target" install -m 600 \
        "$REMOTE_REPO/$REMOTE_NODE_ENV_REL.next" "$REMOTE_REPO/$REMOTE_NODE_ENV_REL"
      remote_exec "$target" rm -f "$REMOTE_REPO/$REMOTE_NODE_ENV_REL.next"
      printf 'synced repository and rank-specific node env to %s\n' "$label"
    done
    ;;
  image-audit)
    test "$#" -eq 2 || { usage >&2; exit 2; }
    load_profile "$1"
    require_apply "$2"
    for spec in "DGX-1|$dgx1_target" "DGX-2|$dgx2_target"; do
      label="${spec%%|*}"
      target="${spec#*|}"
      printf 'auditing loaded runtime image on %s\n' "$label"
      remote_bash "$target" '
        set -euo pipefail
        repo="$1"
        env_rel="$2"
        profile_rel="$3"
        source "$repo/$env_rel"
        source "$repo/$profile_rel"
        local_image_ref="$IMAGE_REF"
        if test -n "${LOCAL_IMAGE_ENV:-}" && test -n "${!LOCAL_IMAGE_ENV:-}"; then
          local_image_ref="${!LOCAL_IMAGE_ENV}"
        fi
        exec "$repo/scripts/audit-loaded-image-no-models.sh" "$local_image_ref" "$IMAGE_CONFIG_DIGEST"
      ' "$REMOTE_REPO" "$REMOTE_NODE_ENV_REL" "$profile_rel"
    done
    ;;
  preflight)
    test "$#" -eq 1 || { usage >&2; exit 2; }
    load_profile "$1"
    if test "$CLUSTER_LAUNCHER" = eugr; then
      set_eugr_profile_parameters
    fi
    verify_remote_rank "$dgx2_target" 1 DGX-2
    verify_remote_rank "$dgx1_target" 0 DGX-1
    remote_profile "$dgx2_target" ./scripts/preflight-dgx-node.sh
    remote_profile "$dgx1_target" ./scripts/preflight-dgx-node.sh
    if test "$CLUSTER_LAUNCHER" = eugr; then
      eugr_gate
    fi
    ;;
  launch)
    test "$#" -eq 2 || { usage >&2; exit 2; }
    load_profile "$1"
    require_apply "$2"
    if test "$CLUSTER_LAUNCHER" = eugr; then
      set_eugr_profile_parameters
    fi
    verify_remote_rank "$dgx2_target" 1 DGX-2
    verify_remote_rank "$dgx1_target" 0 DGX-1
    if test "$CLUSTER_LAUNCHER" = eugr; then
      remote_profile "$dgx2_target" ./scripts/preflight-dgx-node.sh
      remote_profile "$dgx1_target" ./scripts/preflight-dgx-node.sh
      eugr_gate
      printf 'starting eugr no-Ray cluster from DGX-1; eugr dispatches worker rank before head rank\n'
      eugr_launch
    else
      printf 'starting native worker rank on DGX-2\n'
      remote_profile "$dgx2_target" ./scripts/launch-vllm-tp2.sh
      sleep "$worker_start_delay"
      worker_state="$(remote_exec "$dgx2_target" docker inspect --format '{{.State.Running}}' "$CONTAINER_NAME" 2>/dev/null || true)"
      if test "$worker_state" != true; then
        printf 'worker container did not remain running; recent log follows\n' >&2
        remote_exec "$dgx2_target" docker logs --tail 80 "$CONTAINER_NAME" >&2 || true
        exit 8
      fi
      printf 'starting native head rank on DGX-1 after %ss worker stabilization\n' "$worker_start_delay"
      remote_profile "$dgx1_target" ./scripts/launch-vllm-tp2.sh
    fi
    deadline=$((SECONDS + health_timeout))
    until remote_exec "$dgx1_target" curl -fsS --max-time 5 http://127.0.0.1:8000/health >/dev/null 2>&1; do
      if (( SECONDS >= deadline )); then
        printf 'vLLM health timeout after %ss; inspect status/logs before stopping either rank\n' "$health_timeout" >&2
        exit 8
      fi
      sleep 5
    done
    printf 'vLLM TP=2 healthy: launcher=%s profile=%s\n' "$CLUSTER_LAUNCHER" "$profile_rel"
    ;;
  stop)
    test "$#" -eq 2 || { usage >&2; exit 2; }
    load_profile "$1"
    require_apply "$2"
    if test "$CLUSTER_LAUNCHER" = eugr; then
      set_eugr_profile_parameters
      eugr_gate
      eugr_stop
    else
      remote_exec "$dgx1_target" "$REMOTE_REPO/scripts/stop-vllm-local.sh" "$CONTAINER_NAME"
      remote_exec "$dgx2_target" "$REMOTE_REPO/scripts/stop-vllm-local.sh" "$CONTAINER_NAME"
    fi
    remaining=0
    for spec in "DGX-1|$dgx1_target" "DGX-2|$dgx2_target"; do
      label="${spec%%|*}"
      target="${spec#*|}"
      if remote_exec "$target" docker container inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
        printf 'container still exists after stop on %s: %s\n' "$label" "$CONTAINER_NAME" >&2
        remaining=1
      fi
    done
    test "$remaining" -eq 0 || exit 8
    ;;
  status)
    test "$#" -eq 1 || { usage >&2; exit 2; }
    load_profile "$1"
    for spec in "DGX-1|$dgx1_target" "DGX-2|$dgx2_target"; do
      label="${spec%%|*}"
      target="${spec#*|}"
      printf '== %s ==\n' "$label"
      remote_bash "$target" '
        name="$1"
        docker ps -a --filter "name=^/${name}$"
        docker top "$name" 2>/dev/null || true
        docker logs --tail 80 "$name" 2>&1 || true
      ' "$CONTAINER_NAME"
    done
    ;;
  smoke)
    test "$#" -eq 1 || { usage >&2; exit 2; }
    load_profile "$1"
    remote_bash "$dgx1_target" \
      'set -euo pipefail; cd "$1"; exec ./scripts/smoke-openai-api.sh http://127.0.0.1:8000/v1 "$2"' \
      "$REMOTE_REPO" "$SERVED_MODEL_NAME"
    ;;
  gateway-start)
    require_apply "$@"
    remote_bash "$dgx1_target" '
      set -euo pipefail
      env_file="$1"
      repo="$2"
      test -f "$env_file" || { printf "LiteLLM environment file missing: %s\n" "$env_file" >&2; exit 1; }
      mode="$(stat -c "%a" "$env_file")"
      (( (8#$mode & 077) == 0 )) || { printf "LiteLLM environment file is group/world accessible: %s mode=%s\n" "$env_file" "$mode" >&2; exit 1; }
      set -a
      source "$env_file"
      set +a
      : "${LITELLM_MASTER_KEY:?LITELLM_MASTER_KEY missing from remote environment file}"
      cd "$repo"
      exec ./scripts/run-litellm.sh configs/litellm.yaml
    ' "$REMOTE_LITELLM_ENV" "$REMOTE_REPO"
    ;;
  gateway-stop)
    require_apply "$@"
    remote_exec "$dgx1_target" "$REMOTE_REPO/scripts/stop-vllm-local.sh" litellm-gateway
    ;;
  gateway-status)
    test "$#" -eq 0 || { usage >&2; exit 2; }
    remote_bash "$dgx1_target" '
      docker ps -a --filter "name=^/litellm-gateway$"
      docker logs --tail 80 litellm-gateway 2>&1 || true
    '
    ;;
  gateway-smoke)
    test "$#" -eq 1 || { usage >&2; exit 2; }
    model_name="$1"
    [[ "$model_name" =~ ^[A-Za-z0-9._/-]+$ ]] || { printf 'invalid model name\n' >&2; exit 6; }
    remote_bash "$dgx1_target" '
      set -euo pipefail
      env_file="$1"
      repo="$2"
      model="$3"
      test -f "$env_file"
      mode="$(stat -c "%a" "$env_file")"
      (( (8#$mode & 077) == 0 )) || { printf "LiteLLM environment file is group/world accessible\n" >&2; exit 1; }
      set -a
      source "$env_file"
      set +a
      export LITELLM_API_KEY="$LITELLM_MASTER_KEY"
      cd "$repo"
      exec ./scripts/smoke-openai-api.sh http://127.0.0.1:4000/v1 "$model"
    ' "$REMOTE_LITELLM_ENV" "$REMOTE_REPO" "$model_name"
    ;;
  collect)
    test "$#" -ge 1 && test "$#" -le 2 || { usage >&2; exit 2; }
    load_profile "$1"
    output_dir="${2:-state/diagnostics-$(date +%Y%m%dT%H%M%S)}"
    if [[ "$output_dir" != /* ]]; then
      output_dir="$repo_root/$output_dir"
    fi
    mkdir -p "$output_dir"
    chmod 700 "$output_dir"
    for spec in "dgx1:$dgx1_target" "dgx2:$dgx2_target"; do
      label="${spec%%:*}"
      target="${spec#*:}"
      remote_bash "$target" '
        name="$1"
        uname -a || true
        nvidia-smi || true
        ip -br addr || true
        rdma link || true
        docker inspect "$name" 2>&1 || true
        docker logs "$name" 2>&1 || true
        docker logs litellm-gateway 2>&1 || true
      ' "$CONTAINER_NAME" > "$output_dir/$label.txt" 2>&1 || true
      chmod 600 "$output_dir/$label.txt"
    done
    printf 'wrote diagnostics to %s\n' "$output_dir"
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
