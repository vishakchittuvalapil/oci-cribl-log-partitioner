# Runtime Resource Manager Stack

This is the only Resource Manager stack needed for the default deployment.

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

## Resource Manager Inputs

Create a Resource Manager stack from GitHub:

```text
Repository URL: https://github.com/vishakchittuvalapil/oci-cribl-log-partitioner
Branch: main
Working directory: resource-manager-stack
Terraform version: 1.5.x
```

The root **Deploy to Oracle Cloud** button uses this stack through the root Terraform wrapper.

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
