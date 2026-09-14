#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  eamxx_flux_cycle_wrapper.sh BASE_RUNSCRIPT TOTAL_CYCLES

Meaning:
  BASE_RUNSCRIPT   Configuration source, e.g. test-...tuo.32.sh
  TOTAL_CYCLES     Number of future continue-run cycles to submit

Environment overrides:
  POLL_SEC=60            Restart polling interval when Flux wait is unavailable
  WAIT_TIMEOUT_SEC=0     0 means no timeout for restart polling fallback
  HISTORY_FILE=...       Defaults to CASE_SCRIPTS_DIR/auto_resubmit_history.log

Behavior:
The wrapper never executes BASE_RUNSCRIPT.
  It only parses CASE_SCRIPTS_DIR, CASE_RUN_DIR, PROJECT, walltime,
  STOP_OPTION, STOP_N, REST_OPTION, and REST_N
  from BASE_RUNSCRIPT, then for each cycle it runs:
    ./xmlchange CONTINUE_RUN=TRUE
    ./xmlchange RESUBMIT=0
    ./xmlchange STOP_OPTION=...,STOP_N=...
    ./xmlchange REST_OPTION=...,REST_N=...
    ./xmlchange JOB_WALLCLOCK_TIME=${walltime}
    ./xmlchange BATCH_COMMAND_FLAGS="  --time ${walltime_flux} --queue \$JOB_QUEUE --bank \$PROJECT"
    ./case.setup --reset
    ./case.submit

The wrapper always parses CHECKOUT / COMPSET / RRMgrid / MACHINE / run
from BASE_RUNSCRIPT and derives CASE_SCRIPTS_DIR and CASE_RUN_DIR.
No manual override is allowed, so the wrapper stays consistent with
the base runscript by construction.

Success criteria for each completed cycle:
  1. If Flux jobid is available, "flux job status JOBID" must return success.
  2. A valid restart tag must already exist before cycle 1.
  3. The five rpointer files must all exist and point to the same restart time tag.
  4. That time tag must advance relative to the previous cycle.
EOF
}

log() {
  printf '[%s] %s\n' "$(date '+%F %T')" "$*" >&2
}

die() {
  log "ERROR: $*"
  exit 1
}

validate_walltime() {
  local value="$1"
  local hours minutes seconds

  [[ "$value" =~ ^[0-9]{1,3}:[0-9]{2}:[0-9]{2}$ ]] || return 1
  IFS=: read -r hours minutes seconds <<< "$value"
  (( 10#$minutes < 60 && 10#$seconds < 60 ))
}

strip_quotes() {
  local value="${1:-}"
  value="${value%\"}"
  value="${value#\"}"
  value="${value%\'}"
  value="${value#\'}"
  printf '%s\n' "$value"
}

extract_assignment() {
  local file="$1"
  local name="$2"
  local value

  value="$(sed -nE "s/^[[:space:]]*readonly[[:space:]]+${name}=(.*)$/\\1/p" "$file" | head -n1)"
  if [[ -z "$value" ]]; then
    value="$(sed -nE "s/^[[:space:]]*${name}=(.*)$/\\1/p" "$file" | head -n1)"
  fi

  strip_quotes "$value"
}

resolve_case_dirs_from_runscript() {
  local script="$1"
  local checkout compset rrmgrid machine run_name case_root_template resolution case_name case_root

  checkout="$(extract_assignment "$script" "CHECKOUT")"
  compset="$(extract_assignment "$script" "COMPSET")"
  rrmgrid="$(extract_assignment "$script" "RRMgrid")"
  machine="$(extract_assignment "$script" "MACHINE")"
  run_name="$(extract_assignment "$script" "run")"
  case_root_template="$(extract_assignment "$script" "CASE_ROOT")"

  [[ -n "$checkout" ]] || die "Could not parse CHECKOUT from $script"
  [[ -n "$compset" ]] || die "Could not parse COMPSET from $script"
  [[ -n "$rrmgrid" ]] || die "Could not parse RRMgrid from $script"
  [[ -n "$machine" ]] || die "Could not parse MACHINE from $script"
  [[ -n "$run_name" ]] || die "Could not parse run from $script"
  [[ -n "$case_root_template" ]] || die "Could not parse CASE_ROOT from $script"

  resolution="${rrmgrid}pg2_${rrmgrid}pg2"
  case_name="${checkout}.${resolution}.${compset}.${machine}"
  case_root="${case_root_template//\$\{CASE_NAME\}/$case_name}"

  printf '%s\n' "${case_root}/tests/${run_name}/case_scripts"
  printf '%s\n' "${case_root}/tests/${run_name}/run"
}

extract_walltime_from_runscript() {
  local script="$1"
  local walltime

  walltime="$(sed -nE 's/^[[:space:]]*walltime="([^"]+)".*$/\1/p' "$script" | head -n1)"
  [[ -n "$walltime" ]] || die "Could not parse walltime from $script"
  printf '%s\n' "$walltime"
}

extract_run_units_and_length() {
  local script="$1"
  local run_name segment units length

  run_name="$(extract_assignment "$script" "run")"
  [[ -n "$run_name" ]] || die "Could not parse run from $script"

  segment="$(printf '%s\n' "$run_name" | cut -d'_' -f2)"
  units="${segment%%x*}"
  length="${segment##*x}"

  [[ -n "$units" ]] || die "Could not derive run units from $run_name"
  [[ -n "$length" ]] || die "Could not derive run length from $run_name"

  printf '%s\n' "$units"
  printf '%s\n' "$length"
}

resolve_runtime_value() {
  local raw_value="$1"
  local units_value="$2"
  local length_value="$3"
  local stop_option_value="${4:-}"
  local stop_n_value="${5:-}"
  local resolved="$raw_value"

  resolved="$(strip_quotes "$resolved")"
  resolved="${resolved//\$\{units\}/$units_value}"
  resolved="${resolved//\$units/$units_value}"
  resolved="${resolved//\$\{length\}/$length_value}"
  resolved="${resolved//\$length/$length_value}"
  resolved="${resolved//\$\{STOP_OPTION\}/$stop_option_value}"
  resolved="${resolved//\$STOP_OPTION/$stop_option_value}"
  resolved="${resolved//\$\{STOP_N\}/$stop_n_value}"
  resolved="${resolved//\$STOP_N/$stop_n_value}"

  printf '%s\n' "$resolved"
}

require_dir() {
  local path="$1"
  [[ -d "$path" ]] || die "Directory not found: $path"
}

sanitize_yaml_file() {
  local yaml_file="$1"
  local marker_count tmp_file

  [[ -f "$yaml_file" ]] || return 0
  marker_count="$(grep -c '^%YAML 1\.1$' "$yaml_file" || true)"
  if (( marker_count <= 1 )); then
    return 0
  fi

  log "Sanitizing duplicated YAML documents in $yaml_file"
  tmp_file="$(mktemp)"
  awk '
    /^%YAML 1\.1$/ {
      seen_yaml++
      if (seen_yaml > 1) {
        exit
      }
    }
    { print }
  ' "$yaml_file" > "$tmp_file"
  mv "$tmp_file" "$yaml_file"
}

sanitize_case_yaml_files() {
  local path
  for path in "$CASE_SCRIPTS_DIR"/*.yaml "$CASE_RUN_DIR"/data/*.yaml; do
    [[ -e "$path" ]] || continue
    sanitize_yaml_file "$path"
  done
}

restore_build_complete_if_possible() {
  local exeroot

  exeroot="$(./xmlquery EXEROOT --value)"
  [[ -n "$exeroot" ]] || die "Could not query EXEROOT from ${CASE_SCRIPTS_DIR}"

  if [[ -x "${exeroot}/e3sm.exe" ]]; then
    log "Reusing existing executable at ${exeroot}/e3sm.exe"
    ./xmlchange BUILD_COMPLETE=TRUE
    return 0
  fi

  die "BUILD_COMPLETE is FALSE and no executable was found at ${exeroot}/e3sm.exe; run case.build"
}

latest_flux_jobid() {
  flux job last 2>/dev/null | head -n1 | tr -d '[:space:]'
}

extract_flux_jobid_from_file() {
  local path="$1"
  [[ -f "$path" ]] || return 1

  perl -ne '
    if (/^\s*(\x{0192}[A-Za-z0-9]+)\s*$/) {
      print "$1\n";
      next;
    }
    if (/\bjobid\b[^[:alnum:]]*(\x{0192}[A-Za-z0-9]+|[0-9]+)/i) {
      print "$1\n";
      next;
    }
    if (/\bsubmitted\b.*?(\x{0192}[A-Za-z0-9]+|[0-9]+)/i) {
      print "$1\n";
      next;
    }
  ' "$path" | tail -n1
}

read_restart_tag() {
  local run_dir="$1"
  local -a pointer_files=(
    "rpointer.atm"
    "rpointer.drv"
    "rpointer.ice"
    "rpointer.lnd"
    "rpointer.ocn"
  )
  local -a tags=()
  local pointer pointer_path core_restart_line tag

  for pointer in "${pointer_files[@]}"; do
    pointer_path="${run_dir}/${pointer}"
    [[ -f "$pointer_path" ]] || {
      log "Missing restart pointer file: $pointer_path"
      return 1
    }

    core_restart_line="$(grep -E '\.r\..*[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{5}' "$pointer_path" | tail -n1 || true)"
    [[ -n "$core_restart_line" ]] || {
      log "Could not find core restart line (.r.) in $pointer_path"
      return 1
    }

    tag="$(printf '%s\n' "$core_restart_line" | grep -Eo '[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{5}' | tail -n1 || true)"
    [[ -n "$tag" ]] || {
      log "Could not extract restart tag from core restart line in $pointer_path"
      return 1
    }

    tags+=("$tag")
  done

  tag="${tags[0]}"
  local current
  for current in "${tags[@]}"; do
    [[ "$current" == "$tag" ]] || die "Inconsistent restart tags under $run_dir: ${tags[*]}"
  done

  printf '%s\n' "$tag"
}

append_history() {
  local cycle="$1"
  local tag="$2"
  printf '%s cycle=%s restart_tag=%s\n' "$(date '+%F %T')" "$cycle" "$tag" >> "$HISTORY_FILE"
}

wait_for_restart_advance() {
  local run_dir="$1"
  local previous_tag="$2"
  local cycle="$3"
  local poll_sec="$4"
  local timeout_sec="$5"
  local start_epoch now_epoch current_tag

  start_epoch="$(date +%s)"

  while true; do
    current_tag="$(read_restart_tag "$run_dir" 2>/dev/null || true)"
    if [[ -n "$current_tag" ]]; then
      if [[ -z "$previous_tag" || "$current_tag" != "$previous_tag" ]]; then
        log "Cycle ${cycle} restart tag is ${current_tag}"
        append_history "$cycle" "$current_tag"
        printf '%s\n' "$current_tag"
        return 0
      fi
    fi

    if (( timeout_sec > 0 )); then
      now_epoch="$(date +%s)"
      if (( now_epoch - start_epoch >= timeout_sec )); then
        die "Timed out waiting for restart tag to advance from ${previous_tag:-<none>} in ${run_dir}"
      fi
    fi

    sleep "$poll_sec"
  done
}

wait_for_flux_completion() {
  local jobid="$1"
  local cycle="$2"

  log "Waiting on Flux job ${jobid} for cycle ${cycle}"
  if ! flux job status "$jobid"; then
    die "Flux job ${jobid} failed for cycle ${cycle}"
  fi
}

prepare_and_submit_cycle() {
  local cycle="$1"
  local walltime="$2"
  local walltime_flux="$3"

  log "Preparing cycle ${cycle} under ${CASE_SCRIPTS_DIR}"
  (
    cd "$CASE_SCRIPTS_DIR"
    sanitize_case_yaml_files
    ./xmlchange CONTINUE_RUN=TRUE
    ./xmlchange RESUBMIT=0
    ./xmlchange STOP_OPTION="${STOP_OPTION}",STOP_N="${STOP_N}"
    ./xmlchange REST_OPTION="${REST_OPTION}",REST_N="${REST_N}"
    ./xmlchange JOB_WALLCLOCK_TIME="${walltime}"
    ./xmlchange BATCH_COMMAND_FLAGS="  --time ${walltime_flux} --queue \$JOB_QUEUE --bank \$PROJECT"
    ./case.setup --reset
    restore_build_complete_if_possible
    ./case.submit
  )
}

if (( $# != 2 )); then
  usage
  exit 2
fi

BASE_RUNSCRIPT="$1"
TOTAL_CYCLES="$2"
POLL_SEC="${POLL_SEC:-60}"
WAIT_TIMEOUT_SEC="${WAIT_TIMEOUT_SEC:-0}"

[[ -f "$BASE_RUNSCRIPT" ]] || die "Base runscript not found: $BASE_RUNSCRIPT"
[[ "$TOTAL_CYCLES" =~ ^[1-9][0-9]*$ ]] || die "TOTAL_CYCLES must be a positive integer"
[[ "$POLL_SEC" =~ ^[1-9][0-9]*$ ]] || die "POLL_SEC must be a positive integer"
[[ "$WAIT_TIMEOUT_SEC" =~ ^[0-9]+$ ]] || die "WAIT_TIMEOUT_SEC must be a non-negative integer"

mapfile -t resolved_dirs < <(resolve_case_dirs_from_runscript "$BASE_RUNSCRIPT")
CASE_SCRIPTS_DIR="${resolved_dirs[0]}"
CASE_RUN_DIR="${resolved_dirs[1]}"
PROJECT="$(extract_assignment "$BASE_RUNSCRIPT" "PROJECT")"
WALLTIME="$(extract_walltime_from_runscript "$BASE_RUNSCRIPT")"
mapfile -t run_parts < <(extract_run_units_and_length "$BASE_RUNSCRIPT")
RUN_UNITS="${run_parts[0]}"
RUN_LENGTH="${run_parts[1]}"
STOP_OPTION_RAW="$(extract_assignment "$BASE_RUNSCRIPT" "STOP_OPTION")"
STOP_N_RAW="$(extract_assignment "$BASE_RUNSCRIPT" "STOP_N")"
REST_OPTION_RAW="$(extract_assignment "$BASE_RUNSCRIPT" "REST_OPTION")"
REST_N_RAW="$(extract_assignment "$BASE_RUNSCRIPT" "REST_N")"
STOP_OPTION="$(resolve_runtime_value "$STOP_OPTION_RAW" "$RUN_UNITS" "$RUN_LENGTH")"
STOP_N="$(resolve_runtime_value "$STOP_N_RAW" "$RUN_UNITS" "$RUN_LENGTH")"
REST_OPTION="$(resolve_runtime_value "$REST_OPTION_RAW" "$RUN_UNITS" "$RUN_LENGTH" "$STOP_OPTION" "$STOP_N")"
REST_N="$(resolve_runtime_value "$REST_N_RAW" "$RUN_UNITS" "$RUN_LENGTH" "$STOP_OPTION" "$STOP_N")"

HISTORY_FILE="${HISTORY_FILE:-${CASE_SCRIPTS_DIR}/auto_resubmit_history.log}"

[[ -n "$PROJECT" ]] || die "Could not parse PROJECT from $BASE_RUNSCRIPT"
validate_walltime "$WALLTIME" || die "Parsed walltime is invalid: $WALLTIME"
[[ -n "$STOP_OPTION" ]] || die "Could not parse STOP_OPTION from $BASE_RUNSCRIPT"
[[ "$STOP_N" =~ ^[0-9]+$ ]] || die "Parsed STOP_N is invalid: $STOP_N"
[[ -n "$REST_OPTION" ]] || die "Could not parse REST_OPTION from $BASE_RUNSCRIPT"
[[ "$REST_N" =~ ^[0-9]+$ ]] || die "Parsed REST_N is invalid: $REST_N"
IFS=: read -r walltime_h walltime_m walltime_s <<< "$WALLTIME"
WALLTIME_FLUX="$((10#$walltime_h * 60 + 10#$walltime_m))m"

log "Base runscript: $BASE_RUNSCRIPT"
log "Total cycles: ${TOTAL_CYCLES}"
log "Case scripts dir: ${CASE_SCRIPTS_DIR}"
log "Case run dir: ${CASE_RUN_DIR}"
log "Project: ${PROJECT}"
log "Walltime: ${WALLTIME}"
log "Flux walltime: ${WALLTIME_FLUX}"
log "Stop segment: ${STOP_OPTION} x ${STOP_N}"
log "Restart segment: ${REST_OPTION} x ${REST_N}"
log "History file: ${HISTORY_FILE}"

previous_tag="$(read_restart_tag "$CASE_RUN_DIR" || true)"
[[ -n "$previous_tag" ]] || die "No valid restart tag found in ${CASE_RUN_DIR}; this wrapper only handles continue-run cycles"
log "Detected existing restart tag before cycle 1: ${previous_tag}"

for (( cycle=1; cycle<=TOTAL_CYCLES; cycle++ )); do
  flux_jobid_before=""
  flux_jobid_after=""
  flux_jobid=""

  if command -v flux >/dev/null 2>&1; then
    flux_jobid_before="$(latest_flux_jobid || true)"
  fi

  require_dir "$CASE_SCRIPTS_DIR"
  prepare_and_submit_cycle "$cycle" "$WALLTIME" "$WALLTIME_FLUX"

  require_dir "$CASE_SCRIPTS_DIR"
  require_dir "$CASE_RUN_DIR"

  if command -v flux >/dev/null 2>&1; then
    flux_jobid_after="$(latest_flux_jobid || true)"
    if [[ -n "$flux_jobid_after" && "$flux_jobid_after" != "$flux_jobid_before" ]]; then
      flux_jobid="$flux_jobid_after"
    elif [[ -f "${CASE_SCRIPTS_DIR}/submitout.txt" ]]; then
      flux_jobid="$(extract_flux_jobid_from_file "${CASE_SCRIPTS_DIR}/submitout.txt" || true)"
    fi
  fi

  if [[ -n "$flux_jobid" ]]; then
    wait_for_flux_completion "$flux_jobid" "$cycle"
  else
    log "Flux jobid unavailable for cycle ${cycle}; falling back to restart polling"
  fi

  previous_tag="$(wait_for_restart_advance "$CASE_RUN_DIR" "$previous_tag" "$cycle" "$POLL_SEC" "$WAIT_TIMEOUT_SEC")"
done

log "All ${TOTAL_CYCLES} cycles completed successfully"
