# :cook: Filet

Filet (**Fil**ecoin **E**xtract **T**ransform) makes it simple to get CSV data from Filecoin Archival Snapshots using [Lily](https://github.com/filecoin-project/lily) and [`lily-archiver`](https://github.com/filecoin-project/lily-archiver/).

## :rocket: Usage

The `filet` image available on Google Container Artifact Hub. Alternatively, you can build it locally with `make build`.

The following command will generate CSVs from an Filecoin Archival Snapshot:

```bash
docker run -it \
    -v $PWD:/tmp/data \
    europe-west1-docker.pkg.dev/protocol-labs-data/pl-data/filet:latest -- \
    /lily/export.sh archival_snapshot.car.zst .
```

## :alarm_clock: Scheduling Jobs

You can use the [`send_export_jobs.sh`](scripts/send_export_jobs.sh) script to schedule jobs on Google Cloud Batch. The script takes a file with a list of snapshots as input.

```bash
./scripts/send_export_jobs.sh SNAPSHOT_LIST_FILE [--dry-run]
```

For more details on the scheduled jobs configuration, you can check the [`gce_batch_job.json`](./gce_batch_job.json) file.

The `SNAPSHOT_LIST_FILE` file should contain a list of snapshots, one per line. The snapshots should be available in the `fil-mainnet-archival-snapshots` Google Cloud Storage bucket.

```
gsutil ls gs://fil-mainnet-archival-snapshots/historical-exports/ | sort --version-sort > all_snapshots.txt
```

To get the batches you can use the following command to filter by snapshot height:

```bash
grep -E '^[2226480-2232002]$'
```

## :wrench: Managing Jobs

In case you need to retry a bunch of failed jobs, you can use the following commands:

```bash
# Get the list of failed jobs
gcloud alpha batch jobs list --format=json --filter="Status.state:FAILED" > failed_jobs.json

# Get the snapshot name from failed jobs
cat failed_jobs.json | jq ".[].taskGroups[0].taskSpec.runnables[0].container.commands[0]" -r | cut -d '/' -f 2 | sort > failed_jobs.list

# Retry the failed jobs
./scripts/send_export_jobs.sh failed_jobs.list
```
