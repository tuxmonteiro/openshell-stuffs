#!/usr/bin/env bash
#
# create_providers.sh
#
# Generates 'openshell provider create' commands for every exclusive
# profile-<host>.yaml profile in the local directory.
#
# Each command:
#   --name   : provider-<kebab-case profile id> (from the YAML id field,
#              'profile-' prefix replaced by 'provider-')
#   --type   : the profile id (kebab-case) derived from the file content
#   --credential : the related environment variable name (without value),
#                  derived from the profile's credentials block
#
# If a related system environment variable is not set, the command is skipped:
#   - show-only mode : the command is printed commented out with an inline
#                      skip reason
#   - --execute mode : a warning is shown and execution continues to the next
#                      command (one failing command never aborts the run)
#
# Usage:
#   ./create_providers.sh            # print commands to stdout
#   ./create_providers.sh > commands.txt
#   ./create_providers.sh --execute   # print and run them
#

set -euo pipefail

EXECUTE="${1:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_DIR=${PROFILE_DIR:-$SCRIPT_DIR/../profiles}
PROFILE_GLOB="profile-*.yaml"

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Determine the profile type from the YAML file content.
# Preference order: id -> display_name -> filename stem.
profile_type() {
  local file="$1"
  local type
  type="$(/usr/bin/python3 -c "
import sys, yaml
with open(sys.argv[1]) as f:
    d = yaml.safe_load(f)
print(d.get('id') or d.get('display_name') or '')
" "$file" 2>/dev/null || true)"
  if [[ -z "${type}" ]]; then
    # Fallback to the filename stem (without .yaml)
    type="$(basename "$file" .yaml)"
  fi
  printf '%s' "$type"
}

# Determine the related credential environment variable name (without value)
# from the profile's credentials block.
profile_credential() {
  local file="$1"
  local cred
  cred="$(/usr/bin/python3 -c "
import sys, yaml
with open(sys.argv[1]) as f:
    d = yaml.safe_load(f)
creds = d.get('credentials') or []
if creds:
    envs = creds[0].get('env_vars') or []
    if envs:
        print(envs[0])
" "$file" 2>/dev/null || true)"
  printf '%s' "$cred"
}

# Build the profile --name from the YAML id field (kebab-case rule name),
# same as --type, but with the 'profile-' prefix replaced by 'provider-'.
profile_name() {
  local file="$1"
  local name
  name="$(/usr/bin/python3 -c "
import sys, yaml
with open(sys.argv[1]) as f:
    d = yaml.safe_load(f)
print(d.get('id') or d.get('display_name') or '')
" "$file" 2>/dev/null || true)"
  if [[ -z "${name}" ]]; then
    name="$(basename "$file" .yaml)"
  fi
  # Replace the leading 'profile-' prefix with 'provider-' for --name
  name="${name#profile-}"
  name="provider-${name}"
  printf '%s' "$name"
}

# Collect matching profile files (sorted for stable output).
shopt -s nullglob
files=($PROFILE_DIR/$PROFILE_GLOB)

if [[ ${#files[@]} -eq 0 ]]; then
  echo "No profile files matching '$PROFILE_GLOB' found in $SCRIPT_DIR" >&2
  exit 1
fi

IFS=$'\n' sorted_files=($(printf '%s\n' "${files[@]}" | sort)); unset IFS

generated=0
skipped=0
for file in "${sorted_files[@]}"; do
  name="$(profile_name "$file")"
  type="$(profile_type "$file")"
  credential="$(profile_credential "$file")"

  cmd="openshell provider create --name '${name}' --type '${type}'"
  if [[ -n "${credential}" ]]; then
    cmd="${cmd} --credential '${credential}'"
  fi

  # If there is a related credential, check that the corresponding system
  # environment variable is set. If it is missing, handle depending on mode.
  if [[ -n "${credential}" ]] && [[ -z "${!credential:-}" ]]; then
    if [[ "${EXECUTE}" == "--execute" ]]; then
      echo "  # WARNING: skipping '$cmd' - environment variable '${credential}' is not set" >&2
      skipped=$((skipped + 1))
      continue
    else
      # Show-only mode: comment the command out, with skip reason inline.
      printf '# %s  # skipped: environment variable %s is not set\n' "$cmd" "$credential"
      generated=$((generated + 1))
      skipped=$((skipped + 1))
      continue
    fi
  fi

  printf '%s\n' "$cmd"
  generated=$((generated + 1))

  if [[ "${EXECUTE}" == "--execute" ]]; then
    echo "  # executing: $cmd" >&2
    # Temporarily allow failures so one bad command does not abort the run.
    set +e
    eval "$cmd"
    status=$?
    set -e
    if [[ ${status} -ne 0 ]]; then
      echo "  # WARNING: command failed with exit ${status}: $cmd" >&2
      skipped=$((skipped + 1))
    fi
  fi
done

echo "Generated ${generated} provider create command(s)." >&2
if [[ "${EXECUTE}" == "--execute" ]]; then
  echo "Skipped ${skipped} command(s) (missing env var or execution failure)." >&2
fi
