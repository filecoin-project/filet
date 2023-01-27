#!/usr/bin/env bash
#
# Usage: ./export.sh [SNAPSHOT_FILE] [EXPORT_DIR] [TASKS]

set -euo pipefail

# Set arguments
SNAPSHOT_FILE="${1}"
EXPORT_DIR="${2:-$(pwd)}"
TASKS="${3:-}"

# Set environment variables
REPO_PATH="${REPO_PATH:-"/var/lib/lily"}"

# Error if the snapshot file is not provided
if [[ -z "${SNAPSHOT_FILE}" ]]; then
  echo "Please provide a snapshot file."
  exit 1
fi

export GOLOG_LOG_FMT="json"
export GOLOG_LOG_LEVEL="info"

# If the snapshot is compressed, extract it into tmp
if [[ "${SNAPSHOT_FILE}" == *.zst ]]; then
  echo "Extracting snapshot file..."
  unzstd "${SNAPSHOT_FILE}" -o /tmp/snapshot.car
fi

# Start Lily
echo "Initializing Lily repository with ${SNAPSHOT_FILE}..."
lily init --config /lily/config.toml --repo "${REPO_PATH}" --import-snapshot /tmp/snapshot.car

echo "Running daemon..."
lily daemon \
    --repo="${REPO_PATH}" \
    --config=/lily/config.toml \
    --bootstrap=false > >(tee lily.log) 2&>1 &

# Wait for Lily to come online
lily wait-api

# Extract the available walking epochs
echo "Checking available walking epochs..."
STATE=$(lily chain state-inspect -l 3000)

# Get the oldest and newest epochs
FROM_EPOCH=$(echo "${STATE}" | jq -r ".summary.stateroots.oldest")
TO_EPOCH=$(echo "${STATE}" | jq -r ".summary.stateroots.newest")

# Since we can't walk the first epoch (no previous state to diff from), we need to add 1 to the FROM_EPOCH
FROM_EPOCH=$((FROM_EPOCH + 1))

echo "Walking from epoch ${FROM_EPOCH} to ${TO_EPOCH}..."
sleep 5

# Run the walk job, if TASKS is provided, use it
if [[ -z "${TASKS:-}" ]]; then
  lily job run --storage=CSV walk --from "${FROM_EPOCH}" --to "${TO_EPOCH}"
else
  lily job run --storage=CSV --tasks "${TASKS}" walk --from "${FROM_EPOCH}" --to "${TO_EPOCH}"
fi

# Wait for the job to finish
echo "Waiting for job to finish..."
lily job wait --id 1

# Fail if job error is not empty string
JOB_ERROR=$(lily job list | jq ".[0]" | jq -r ".Error")
if [[ "${JOB_ERROR}" != "" ]]; then
  echo "Job failed with error: ${JOB_ERROR}"
  cat lily.log
  exit 1
fi

lily stop

# Check there are no errors on visor_processing_reports.csv
if grep -q "ERROR" /tmp/data/*visor_processing_reports.csv; then
  echo "Errors found on visor_processing_reports!"
  grep "ERROR" /tmp/data/*visor_processing_reports.csv
fi

# Check the chain_consensus file has WALK_EPOCHS + 1 (header) lines
# if [[ $(wc -l < /tmp/data/*chain_consensus.csv) -ne $((WALK_EPOCHS + 1)) ]]; then
#   echo "chain_consensus file has $(wc -l < /tmp/data/*chain_consensus.csv) lines, expected $((WALK_EPOCHS + 2))"
#   exit 1
# fi

# Compress the CSV files
echo "Compressing CSV files..."
gzip /tmp/data/*.csv

# Move files to export dir
echo "Saving CSV files to ${EXPORT_DIR}"

# Clean export dir
# TODO: FILENAME should be the snapshot epoch range
FILENAME=$(basename "${SNAPSHOT_FILE}" .car.zst)
if [ -d "${EXPORT_DIR:?}"/"${FILENAME:?}"/ ]; then
  rm -Rf "${EXPORT_DIR:?}"/"${FILENAME:?}"/;
fi
mkdir -p "$EXPORT_DIR"/"$FILENAME"/

# Add data and log files to export dir
mv /tmp/data/*.csv.gz "$EXPORT_DIR"/"$FILENAME"/
mv lily.log "$EXPORT_DIR"/"$FILENAME"/
