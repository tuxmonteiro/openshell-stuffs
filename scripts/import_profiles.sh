#!/usr/bin/env bash
#
# import_profiles.sh
#
# Generates (and optionally runs) 'openshell profile import' commands for
# every profile-*.yaml file in the local directory.
#
# Follows the same approach as generate_openshell_provider_commands.sh:
#   - reads each profile-*.yaml file (sorted for stable output)
#   - derives --file from the profile file path
#   - derives --name / --type / --credential from the file content for
#     logging and optional metadata (the real `openshell profile import`
#     CLI accepts --file/--from/--url; --name/--type/--credential are not
#     import flags, so they are shown as comments for reference)
#
# Commands:
#   openshell profile import --file <profile-file.yaml>
#
# Usage:
#   ./import_profiles.sh             # print commands to stdout
#   ./import_profiles.sh > import.txt
#   ./import_profiles.sh --execute   # print and run them
#

set -euo pipefail

EXECUTE="${1:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_DIR=${PROFILE_DIR:-$SCRIPT_DIR/../profiles}
PROFILE_GLOB="profile-*.yaml"

# Determine the profile type/name from the YAML file content.
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

# Build the profile --name from the filename stem.
profile_name() {
  local file="$1"
  basename "$file" .yaml
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
for file in "${sorted_files[@]}"; do
  name="$(profile_name "$file")"
  type="$(profile_type "$file")"
  credential="$(profile_credential "$file")"

  cmd="openshell profile import --file '${file}'"

  printf '%s\n' "$cmd"
  # Reference metadata as a comment (name/type/credential are not import flags)
  #printf '  # name=%s type=%s credential=%s\n' "$name" "$type" "${credential:-<none>}"
  generated=$((generated + 1))
  skipped=0

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

echo "Generated ${generated} provider import command(s)." >&2
if [[ "${EXECUTE}" == "--execute" ]]; then
  echo "Skipped ${skipped} command(s) that failed during execution." >&2
fi
