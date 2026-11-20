#!/usr/bin/env bash
#
# cleanup.sh
#
# Removes OpenShell provider profiles AND providers from openshell (not the local files).
# Follows the same approach as generate_openshell_provider_commands.sh and
# import_openshell_profiles.sh: reads each profile-*.yaml file in the local
# directory (sorted for stable output) and derives the profile id / provider
# name from its YAML 'id' field.
#
# Dry-run shows BOTH the provider delete and profile delete commands.
# With --execute, providers are deleted BEFORE profiles (dependency order),
# because a provider may reference its profile.
#
# Uses:
#   openshell provider delete [--global] <NAME>...
#   openshell profile delete  [--global] <ID>...
#
# Usage:
#   ./cleanup.sh                      # dry-run: show both commands
#   ./cleanup.sh --execute            # run both (providers first)
#   ./cleanup.sh --global             # include --global flag
#   ./cleanup.sh --global --execute   # delete platform-scoped
#
# Safety: without --execute, nothing is run (dry-run). One failing command shows
# a warning and execution continues (never aborts the whole run).

set -euo pipefail

EXECUTE=""
GLOBAL=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --execute) EXECUTE="--execute" ;;
    --global)  GLOBAL="--global" ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
  shift
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_DIR=${PROFILE_DIR:-$SCRIPT_DIR/../profiles}
PROFILE_GLOB="profile-*.yaml"

# Determine the profile id (kebab-case rule name) from the YAML 'id' field.
profile_id() {
  local file="$1"
  local id
  id="$(/usr/bin/python3 -c "
import sys, yaml
with open(sys.argv[1]) as f:
    d = yaml.safe_load(f)
print(d.get('id') or '')
" "$file" 2>/dev/null || true)"
  printf '%s' "$id"
}

# Collect matching profile files (sorted for stable output).
shopt -s nullglob
files=($PROFILE_DIR/$PROFILE_GLOB)

if [[ ${#files[@]} -eq 0 ]]; then
  echo "No profile files matching '$PROFILE_GLOB' found in $SCRIPT_DIR" >&2
  exit 0
fi

IFS=$'\n' sorted_files=($(printf '%s\n' "${files[@]}" | sort)); unset IFS

ids=()      # profile ids (kebab-case, with 'profile-' prefix) -> for profile delete
pnames=()   # provider names (kebab-case, with 'provider-' prefix) -> for provider delete
for file in "${sorted_files[@]}"; do
  pid="$(profile_id "$file")"
  if [[ -z "$pid" ]]; then
    pid="$(basename "$file" .yaml)"
  fi
  ids+=("$pid")
  pnames+=("provider-${pid#profile-}")
done

if [[ ${#ids[@]} -eq 0 ]]; then
  echo "No profile ids found." >&2
  exit 0
fi

deleted_providers=0
deleted_profiles=0
failed=0

# Dry-run: show one command per line for both provider and profile deletion.
for pname in "${pnames[@]}"; do
  printf 'openshell provider delete %s%s\n' "${GLOBAL:+$GLOBAL }" "$pname"
done
for pid in "${ids[@]}"; do
  printf 'openshell profile delete %s%s\n' "${GLOBAL:+$GLOBAL }" "$pid"
done

if [[ "${EXECUTE}" == "--execute" ]]; then
  # Dependency order: delete providers first, then profiles.
  # One command per line so a not-found error on one id does not block the others.
  for pname in "${pnames[@]}"; do
    cmd="openshell provider delete ${GLOBAL:+$GLOBAL }$pname"
    echo "  # executing: $cmd" >&2
    set +e
    eval "$cmd"
    status=$?
    set -e
    if [[ ${status} -ne 0 ]]; then
      echo "  # WARNING: command failed with exit ${status}: $cmd" >&2
      failed=$((failed + 1))
    else
      deleted_providers=$((deleted_providers + 1))
    fi
  done

  for pid in "${ids[@]}"; do
    cmd="openshell profile delete ${GLOBAL:+$GLOBAL }$pid"
    echo "  # executing: $cmd" >&2
    set +e
    eval "$cmd"
    status=$?
    set -e
    if [[ ${status} -ne 0 ]]; then
      echo "  # WARNING: command failed with exit ${status}: $cmd" >&2
      failed=$((failed + 1))
    else
      deleted_profiles=$((deleted_profiles + 1))
    fi
  done
fi

echo "" >&2
echo "Summary:" >&2
echo "  providers: ${#ids[@]} name(s) addressed, ${deleted_providers} deleted" >&2
echo "  profiles:  ${#ids[@]} id(s) addressed,  ${deleted_profiles} deleted" >&2
if [[ ${failed} -gt 0 ]]; then
  echo "  failed:    ${failed} operation(s)" >&2
fi

if [[ "${EXECUTE}" != "--execute" ]]; then
  echo "" >&2
  echo "Dry-run complete. Re-run with --execute to delete providers (first) then profiles." >&2
fi
