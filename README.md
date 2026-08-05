# OCI Logs to Cribl via Object Storage

This project shows how to capture OCI logs, write them to an OCI Object Storage bucket with Cribl-friendly time partitions, and collect them from Cribl.

The generated Object Storage keys look like this:

```text
cribl/YYYY/MM/DD/HH/MM/<log_type>/oci-log-<timestamp>-<uuid>.json.gz
```

Example:

```text
cribl/2026/08/05/09/18/oci-vcn-flow/oci-log-20260805T091812Z-65100b13ca474f549246c357e7b2f28d.json.gz
```

This aligns with the Cribl guidance to include year, month, day, hour, and optionally minute in the bucket path so Cribl can perform time-based filtering without scanning the whole bucket.

## Architecture

```text
OCI Logging
  -> Service Connector Hub
  -> OCI Function target
  -> OCI Object Storage bucket
  -> Cribl S3 Collector
```

The OCI Function controls the final Object Storage object name. That is what allows dynamic paths such as:

```text
cribl/2026/08/05/09/18/oci-vcn-flow/
```

## Why the Function is the Connector Target

Service Connector Hub can also use:

```text
Logging source -> Function task -> Object Storage target
```

That works for transforming payloads, but the Object Storage target only supports a static `objectNamePrefix`. It does not let the Function task dynamically choose folders such as `YYYY/MM/DD/HH/MM/<log_type>`.

For Cribl-style partitioned object names, use:

```text
Logging source -> Function target
```

Then the Function writes the object to Object Storage directly.

## What the Function Does

For each Service Connector batch, the Function:

1. Reads OCI Logging records.
2. Detects the event timestamp.
3. Detects the log type from `LOG_TYPE_MAP` or from OCI log metadata.
4. Groups records by time and log type.
5. Writes gzip-compressed NDJSON to Object Storage.

Output path:

```text
<OBJECT_PREFIX>/<YYYY>/<MM>/<DD>/<HH>/<MM>/<log_type>/oci-log-<timestamp>-<uuid>.json.gz
```

Default:

```text
cribl/YYYY/MM/DD/HH/MM/<log_type>/...
```

## Repository Contents

```text
func.py                         OCI Function handler
Dockerfile                      Container image for OCI Functions
func.yaml                       Function metadata
requirements.txt                Python dependencies
build_spec.yaml                 OCI DevOps build spec template
examples/                       Placeholder OCI config examples
docs/                           Step-by-step setup guides
scripts/                        Helper scripts with placeholder values
```

## Step-by-Step Setup

### 1. Create an Object Storage Bucket

Create a bucket for Cribl-readable log objects.

Recommended example:

```text
CriblOutput
```

Cribl will later read from:

```text
bucket = CriblOutput
prefix = cribl/
```

### 2. Enable OCI Logs

Enable the OCI logs you want to send to Cribl, for example:

```text
VCN Flow Logs
Object Storage service logs
Audit logs
Load Balancer logs
Cloud Guard logs
```

Each enabled OCI log has a log OCID. That OCID is used in `LOG_TYPE_MAP`.

### 3. Create or Reuse an OCI Functions App

Use an existing Functions app or create a dedicated one.

Callout:

```text
If your tenancy has a Functions application quota limit, reuse an existing app.
```

### 4. Deploy the Function

Build and deploy the Function container image using your preferred method:

```text
OCI Functions CLI
OCI DevOps build pipeline
OCIR + OCI CLI
```

The included `Dockerfile` and `build_spec.yaml` are ready to adapt.

### 5. Configure the Function

Use the example:

```text
examples/function-config.example.json
```

Important values:

```json
{
  "BUCKET_NAME": "CriblOutput",
  "OBJECT_PREFIX": "cribl",
  "INCLUDE_MINUTE": "true",
  "FUNCTION_MODE": "target_writer",
  "LOG_TYPE_MAP": "{\"<VCN_FLOW_LOG_OCID>\":\"oci-vcn-flow\",\"<OBJECT_STORAGE_LOG_OCID>\":\"oci-object-storage\"}"
}
```

`LOG_TYPE_MAP` is what makes a single Service Connector support multiple log types cleanly.

### 6. Create IAM Policies

You need permissions for:

```text
Service Connector Hub to read OCI Logging records
Service Connector Hub to invoke the Function
Function resource principal to write objects to the bucket
```

See:

```text
examples/policy-statements.example.txt
```

### 7. Create the Service Connector

Use:

```text
source.kind = logging
target.kind = functions
tasks = []
```

Use the examples:

```text
examples/sch-source.example.json
examples/sch-target-functions.example.json
```

Recommended starting batch settings:

```text
batchSizeInNum = 100
batchTimeInSec = 60
```

Tune later:

```text
Too many tiny files       -> increase batchSizeInNum
Too much delivery latency -> decrease batchTimeInSec
Function timeouts         -> decrease batchSizeInNum
```

### 8. Configure Cribl

Configure a Cribl S3 Collector or S3 Source to read from the OCI Object Storage bucket using the S3-compatible API.

Recommended values:

```text
Bucket: CriblOutput
Prefix: cribl/
Data format: json or ndjson
Compression: gzip
```

See:

```text
docs/cribl-collector-setup.md
```

## Cribl Alignment

Cribl's S3 destination UI has fields such as:

```text
Key Prefix
Partitioning Expression
File Name Prefix Expression
Compress
```

This Function effectively implements the same idea before Cribl reads the data:

```text
Key Prefix              -> cribl/YYYY/MM/DD/HH/MM
Partitioning Expression -> <log_type>
File Name Prefix        -> oci-log
Compression             -> gzip
```

For example:

```text
cribl/2026/08/05/09/18/oci-vcn-flow/oci-log-20260805T091812Z-65100b13ca474f549246c357e7b2f28d.json.gz
```

## Adding More Log Types

Add additional OCI log OCIDs to `LOG_TYPE_MAP`.

Example:

```json
{
  "<VCN_FLOW_LOG_OCID>": "oci-vcn-flow",
  "<OBJECT_STORAGE_LOG_OCID>": "oci-object-storage",
  "<LOAD_BALANCER_LOG_OCID>": "oci-load-balancer",
  "<CLOUD_GUARD_LOG_OCID>": "oci-cloud-guard"
}
```

The folder name becomes the mapped value:

```text
cribl/YYYY/MM/DD/HH/MM/oci-object-storage/
```

## Validation

Invoke the Function with a sample OCI log record and confirm the response includes:

```json
{
  "records_received": 1,
  "objects_uploaded": [
    "cribl/YYYY/MM/DD/HH/MM/oci-vcn-flow/oci-log-<timestamp>-<uuid>.json.gz"
  ]
}
```

Then confirm the object exists in Object Storage:

```bash
oci os object list \
  --namespace-name <OBJECT_STORAGE_NAMESPACE> \
  --bucket-name CriblOutput \
  --prefix cribl/
```

## Security Notes

Do not commit live tenancy OCIDs, user emails, private keys, auth tokens, or generated deployment outputs to a public repository.

This repo uses placeholders such as:

```text
<COMPARTMENT_OCID>
<FUNCTION_OCID>
<LOG_GROUP_OCID>
<LOG_OCID>
<OBJECT_STORAGE_NAMESPACE>
```
