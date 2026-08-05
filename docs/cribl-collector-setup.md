# Cribl Collector Setup

Use this when Cribl is reading log objects from an OCI Object Storage bucket through the S3-compatible API.

## Collector Values

```text
Bucket: CriblOutput
Prefix: cribl/
Data format: json or ndjson
Compression: gzip
```

If your Cribl S3 configuration follows OCI's S3-compatible examples, the region field is commonly left empty and the endpoint is pointed at OCI Object Storage.

Example object key Cribl will read:

```text
cribl/2026/08/05/09/18/oci-vcn-flow/oci-log-20260805T091812Z-65100b13ca474f549246c357e7b2f28d.json.gz
```

## What Prefix Means

The Cribl collector prefix is the top-level path to scan.

Use:

```text
cribl/
```

Do not set the collector prefix to a full date folder unless you only want to collect that specific date or hour.

## How Time Filtering Works

The bucket path contains:

```text
YYYY/MM/DD/HH/MM
```

That lets Cribl limit collection by time instead of scanning the entire bucket.

## Log Type Folder

The folder after the minute is the log type:

```text
oci-vcn-flow
oci-object-storage
oci-load-balancer
oci-cloud-guard
oci-audit
oci-generic
```

This is similar to a Cribl `sourcetype` partition.
