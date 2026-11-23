#!/usr/bin/env bash
set -Eeuo pipefail

# Run the CS683 Phase 2 LLBP-X timing sensitivity experiment.

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

EXPECTED_SOURCE_COMMIT="390e8d3"
EXPECTED_SHA256="e61bfcb63ac25b1ea0f8754219303542e878f2f1279177388fe422d1bad17735"

WARMUP=100000000
SIM_INSTRUCTIONS=200000000
JOBS=4
OUTPUT_ROOT="results/phase2_timing"

MODE=""

usage() {
    echo "Usage:"
    echo "  $0 --dry-run"
    echo "  $0 --run"
}

die() {
    echo "ERROR: $*" >&2
    exit 1
}

# Require an explicit choice between preview and execution.
while (($#)); do
    case "$1" in
        --dry-run)
            [[ -z "$MODE" ]] || die "Choose only one mode."
            MODE="dry-run"
            ;;
        --run)
            [[ -z "$MODE" ]] || die "Choose only one mode."
            MODE="run"
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            usage
            die "Unknown option: $1"
            ;;
    esac
    shift
done

[[ -n "$MODE" ]] || {
    usage
    die "Specify --dry-run or --run explicitly."
}

# Predictor configurations.
CAPACITY_NAMES=(
    "LogG10"
    "LogG9"
    "LogG8"
)

BASELINE_MODELS=(
    "llbpx"
    "llbpx-reduced-tagged"
    "llbpx-logg8"
)

TIMING_MODELS=(
    "llbpx-timing"
    "llbpx-reduced-tagged-timing"
    "llbpx-logg8-timing"
)

DELAYS=(0 2 4 8 16)

# Official 14-workload list from scripts/eval_all.sh.
WORKLOADS=(
    "mwnginxfpm-wiki"
    "dacapo-kafka"
    "dacapo-tomcat"
    "dacapo-spring"
    "renaissance-finagle-chirper"
    "renaissance-finagle-http"
    "benchbase-tpcc"
    "benchbase-twitter"
    "benchbase-wikipedia"
    "nodeapp-nodeapp"
    "charlie.1006518"
    "delta.507252"
    "merced.467915"
    "whiskey.426708"
)

# Preflight checks.
[[ -x build/predictor ]] || die "build/predictor is missing or not executable."
command -v xargs >/dev/null 2>&1 || die "xargs is not installed."
command -v sha256sum >/dev/null 2>&1 || die "sha256sum is not installed."

REPO_COMMIT="$(git rev-parse --short=7 HEAD)"

git diff --quiet ||
    die "Tracked working-tree changes detected. Review them before running."

git diff --cached --quiet ||
    die "Staged changes detected. Review them before running."

ACTUAL_SHA256="$(sha256sum build/predictor | awk '{print $1}')"
[[ "$ACTUAL_SHA256" == "$EXPECTED_SHA256" ]] ||
    die "Predictor SHA-256 does not match the validated Release executable."

# Verify every required trace exists.
for workload in "${WORKLOADS[@]}"; do
    trace="traces/${workload}.champsim.trace.gz"
    [[ -s "$trace" ]] || die "Missing or empty trace: $trace"
done

# Construct the complete run matrix.
RUN_SPECS=()

for index in "${!CAPACITY_NAMES[@]}"; do
    capacity="${CAPACITY_NAMES[$index]}"
    baseline_model="${BASELINE_MODELS[$index]}"
    timing_model="${TIMING_MODELS[$index]}"

    for workload in "${WORKLOADS[@]}"; do
        trace="traces/${workload}.champsim.trace.gz"

        # Five timing-enabled runs per workload and capacity.
        for delay in "${DELAYS[@]}"; do
            RUN_SPECS+=(
                "timing|${capacity}|${timing_model}|${workload}|${trace}|${delay}"
            )
        done

        # One non-timing reference per workload and capacity.
        RUN_SPECS+=(
            "non_timing|${capacity}|${baseline_model}|${workload}|${trace}|NA"
        )
    done
done

TOTAL_RUNS="${#RUN_SPECS[@]}"
[[ "$TOTAL_RUNS" -eq 252 ]] ||
    die "Expected 252 runs, generated $TOTAL_RUNS."

echo "=========================================="
echo "CS683 Phase 2: LLBP-X Timing Experiment"
echo "=========================================="
echo "Repository revision:       $REPO_COMMIT"
echo "Reference source revision:  $EXPECTED_SOURCE_COMMIT"
echo "Predictor SHA-256:  $ACTUAL_SHA256"
echo "Warm-up:            $WARMUP"
echo "Measured:           $SIM_INSTRUCTIONS"
echo "BTB:                enabled"
echo "Concurrency:        $JOBS"
echo "Timing runs:        210"
echo "Non-timing runs:    42"
echo "Total runs:         $TOTAL_RUNS"
echo

if [[ "$MODE" == "dry-run" ]]; then
    echo "DRY RUN: no simulations will be started."
    echo "No result directories or files will be created."
    echo "Output root: $OUTPUT_ROOT"
    echo "First configuration: ${RUN_SPECS[0]}"

    LAST_INDEX=$((TOTAL_RUNS - 1))
    echo "Last configuration:  ${RUN_SPECS[$LAST_INDEX]}"
    echo
    echo "Preflight checks passed. Matrix contains exactly 252 runs."
    exit 0
fi

# Create a unique output directory; never overwrite an earlier run.
RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_DIR="${OUTPUT_ROOT}/run_${RUN_ID}"

[[ ! -e "$OUT_DIR" ]] ||
    die "Output directory already exists: $OUT_DIR"

mkdir -p "$OUT_DIR"

# Record provenance and settings.
{
    echo "Experiment: CS683 Phase 2 LLBP-X Timing Sensitivity"
    echo "UTC start time: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    echo "Repository revision: $REPO_COMMIT"
    echo "Predictor source revision (pinned): $EXPECTED_SOURCE_COMMIT"
    echo "Predictor SHA-256: $ACTUAL_SHA256"
    echo "Build type: Release"
    echo "Warm-up instructions: $WARMUP"
    echo "Measured instructions: $SIM_INSTRUCTIONS"
    echo "BTB: enabled"
    echo "Concurrency: $JOBS"
    echo "Access delays: ${DELAYS[*]}"
    echo "Workloads: ${#WORKLOADS[@]}"
    echo "Total simulations: $TOTAL_RUNS"
} > "$OUT_DIR/metadata.txt"

# Save a manifest describing every planned run.
{
    printf 'type\tcapacity\tmodel\tworkload\ttrace\tdelay\n'

    for spec in "${RUN_SPECS[@]}"; do
        IFS='|' read -r kind capacity model workload trace delay <<< "$spec"
        printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$kind" "$capacity" "$model" "$workload" "$trace" "$delay"
    done
} > "$OUT_DIR/run_matrix.tsv"

# Each worker runs one simulation and records its exit code.
run_one() {
    local spec="$1"
    local kind capacity model workload trace delay
    local log_file status

    IFS='|' read -r kind capacity model workload trace delay <<< "$spec"

    if [[ "$kind" == "timing" ]]; then
        log_file="$OUT_DIR/timing/$capacity/delay_$delay/$workload.log"
    else
        log_file="$OUT_DIR/non_timing/$capacity/$workload.log"
    fi

    mkdir -p "$(dirname "$log_file")"

    if [[ "$kind" == "timing" ]]; then
        if ./build/predictor \
            --bpmodel "$model" \
            --input-file "$trace" \
            --simulate-btb \
            --access-delay "$delay" \
            --inst-warm "$WARMUP" \
            --inst-sim "$SIM_INSTRUCTIONS" \
            > "$log_file" 2>&1
        then
            status=0
        else
            status=$?
        fi
    else
        if ./build/predictor \
            --bpmodel "$model" \
            --input-file "$trace" \
            --simulate-btb \
            --inst-warm "$WARMUP" \
            --inst-sim "$SIM_INSTRUCTIONS" \
            > "$log_file" 2>&1
        then
            status=0
        else
            status=$?
        fi
    fi

    printf '%s\n' "$status" > "${log_file}.exitcode"

    if [[ "$status" -eq 0 ]]; then
        printf '[PASS] %s %s %s delay=%s\n' \
            "$capacity" "$workload" "$kind" "$delay"
    else
        printf '[FAIL exit=%s] %s %s %s delay=%s\n' \
            "$status" "$capacity" "$workload" "$kind" "$delay"
    fi

    return "$status"
}

export OUT_DIR WARMUP SIM_INSTRUCTIONS
export -f run_one

echo "Starting formal experiment."
echo "Results directory: $OUT_DIR"
echo

# xargs executes at most four simulations simultaneously.
set +e
printf '%s\0' "${RUN_SPECS[@]}" |
    xargs -0 -r -n 1 -P "$JOBS" \
        bash -c 'set -Eeuo pipefail; run_one "$1"' _
XARGS_STATUS=$?
set -e

# Count completed, passed and failed runs.
COMPLETED=0
PASSED=0
FAILED=0

while IFS= read -r -d '' status_file; do
    status="$(cat "$status_file")"
    COMPLETED=$((COMPLETED + 1))

    if [[ "$status" == "0" ]]; then
        PASSED=$((PASSED + 1))
    else
        FAILED=$((FAILED + 1))
    fi
done < <(find "$OUT_DIR" -type f -name '*.log.exitcode' -print0)

MISSING=$((TOTAL_RUNS - COMPLETED))

echo
echo "=========================================="
echo "Phase 2 experiment summary"
echo "=========================================="
echo "Expected runs:   $TOTAL_RUNS"
echo "Completed:       $COMPLETED"
echo "Passed:          $PASSED"
echo "Failed:          $FAILED"
echo "Missing status:  $MISSING"
echo "xargs exit code: $XARGS_STATUS"
echo "Results:         $OUT_DIR"

if [[ "$FAILED" -ne 0 || "$MISSING" -ne 0 || "$XARGS_STATUS" -ne 0 ]]; then
    echo "Experiment finished with failures or incomplete runs."
    echo "Existing output has been preserved."
    exit 1
fi

echo "All 252 simulations completed successfully."
