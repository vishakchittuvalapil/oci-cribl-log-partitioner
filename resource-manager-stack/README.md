# Runtime Resource Manager Stack

This stack deploys the OCI logging pipeline for Cribl.

It creates:

```text
Object Storage bucket
OCI Function
Service Connector Hub connector
Optional Functions application
IAM policies
```

The Function writes objects like:

```text
cribl/YYYY/MM/DD/HH/MM/<log_type>/oci-log-<timestamp>-<uuid>.json.gz
```

## Before Running This Stack

Run the image-builder stack first:

```text
image-builder-stack
```

Copy its output:

```text
function_image
```

Use that value for this stack's `function_image` variable.

## Resource Manager Inputs

Create a Resource Manager stack from GitHub:

```text
Repository URL: https://github.com/vishakchittuvalapil/oci-cribl-log-partitioner
Branch: main
Working directory: resource-manager-stack
Terraform version: 1.5.x
```

Required variables:

```text
compartment_ocid
region
function_image
log_sources
```

## Log Source Example

```hcl
log_sources = [
  {
    compartment_id = "<COMPARTMENT_OCID>"
    log_group_id   = "<LOG_GROUP_OCID>"
    log_id         = "<VCN_FLOW_LOG_OCID>"
    log_type       = "oci-vcn-flow"
  },
  {
    compartment_id = "<COMPARTMENT_OCID>"
    log_group_id   = "<OBJECT_STORAGE_LOG_GROUP_OCID>"
    log_id         = "<OBJECT_STORAGE_LOG_OCID>"
    log_type       = "oci-object-storage"
  }
]
```

The `log_type` value becomes the Cribl partition folder:

```text
cribl/YYYY/MM/DD/HH/MM/oci-vcn-flow/
```

## Cribl Collector

After apply, configure Cribl to collect from:

```text
Bucket: <bucket_name>
Prefix: cribl/
Compression: gzip
Format: json or ndjson
```
