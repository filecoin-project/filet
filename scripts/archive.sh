#!/usr/bin/env bash
#
# Usage: ./archive.sh [SNAPSHOT_FILE] [EXPORT_DIR]

set -euox pipefail

SNAPSHOT_FILE="${1}"

# Error if the snapshot file is not provided
if [[ -z "${SNAPSHOT_FILE}" ]]; then
  echo "Please provide a snapshot file."
  exit 1
fi

export GOLOG_LOG_FMT="json"
export GOLOG_LOG_LEVEL="debug"
EXPORT_DIR="${2:-$(pwd)}"
REPO_PATH="${REPO_PATH:-"/var/lib/lily"}"
WALK_EPOCHS="${WALK_EPOCHS:-"2880"}"

# If the snapshot is compressed, extract it into tmp
if [[ "${SNAPSHOT_FILE}" == *.zst ]]; then
  unzstd "${SNAPSHOT_FILE}" -o /tmp/snapshot.car
fi

# Start Lily
echo "Initializing Lily repository with ${SNAPSHOT_FILE}"
lily init --config /lily/config.toml --repo "${REPO_PATH}" --import-snapshot /tmp/snapshot.car
nohup lily daemon --repo="${REPO_PATH}" --config=/lily/config.toml --bootstrap=false &> lily.log &

# Wait for Lily to come online
lily wait-api

# Extract the available walking epochs
STATE=$(lily chain state-inspect -l 3000)
# FROM_EPOCH=$(echo "${SNAPSHOT_FILE}" | cut -d'_' -f2)
FROM_EPOCH=$(echo "${STATE}" | jq -r ".summary.stateroots.oldest")
FROM_EPOCH=$((FROM_EPOCH + 1))
# Add WALKEPOCHS to the FROM_EPOCH
TO_EPOCH=$((FROM_EPOCH + WALK_EPOCHS))
# TO_EPOCH=$(echo "${STATE}" | jq -r ".summary.stateroots.newest")

echo "Walking from epoch ${FROM_EPOCH} to ${TO_EPOCH}"
sleep 10

# Run export
archiver export --storage-path /tmp/data --ship-path /tmp/data --min-height="${FROM_EPOCH}" --max-height="${TO_EPOCH}"

# Copy the exported data to the export directory
FILENAME=$(basename "${SNAPSHOT_FILE}" .car.zst)
cp -r /tmp/data/mainnet/ "${EXPORT_DIR}"/"${FILENAME}"/
