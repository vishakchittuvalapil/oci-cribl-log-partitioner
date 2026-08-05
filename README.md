# OCI Logs to Cribl Resource Manager Deployment

This repository is focused on **OCI Resource Manager deployment only**.

It deploys an OCI log pipeline that writes Cribl-friendly Object Storage paths:

```text
cribl/YYYY/MM/DD/HH/MM/<log_type>/oci-log-<timestamp>-<uuid>.json.gz
```

This follows [Cribl's OCI guidance](https://cribl.io/blog/capturing-security-and-observability-data-from-oracle-cloud/) to include year, month, day, hour, and optionally minute in the bucket path for time-based filtering.

## Deployment Flow

Use two OCI Resource Manager stacks:

```text
Stack 1: image-builder-stack
  -> Builds the Function image in the user's OCI tenancy using OCI DevOps
  -> Pushes the image to the user's OCIR repository
  -> Outputs function_image

Stack 2: runtime stack
  -> Creates Object Storage bucket
  -> Creates or reuses OCI Functions application
  -> Creates OCI Function from function_image
  -> Creates Service Connector Hub connector
  -> Creates IAM policies
```

No local Docker, Cloud Shell, OCI CLI, or manual script execution is required for the main deployment path.

## Step 1: Build The Function Image

Create a Resource Manager stack from GitHub:

```text
Repository URL: https://github.com/vishakchittuvalapil/oci-cribl-log-partitioner
Branch: main
Working directory: image-builder-stack
Terraform version: 1.5.x
```

This stack creates an OCI DevOps build pipeline that builds the Function image from this repo and delivers it to OCI Container Registry.

Required input:

```text
compartment_ocid
region
existing_github_connection_id
```

If you want the stack to create the GitHub connection, use:

```text
create_github_connection = true
github_access_token_secret_id = <OCI Vault secret OCID containing GitHub token>
```

After **Apply**, copy the output:

```text
function_image
```

Example:

```text
ocir.us-ashburn-1.oci.oraclecloud.com/<namespace>/cribl-oci-log-partitioner/function:0.0.1
```

## Step 2: Deploy The OCI To Cribl Pipeline

[![Deploy to Oracle Cloud](https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg)](https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https://github.com/vishakchittuvalapil/oci-cribl-log-partitioner/archive/refs/heads/main.zip)

Use the button above after Step 1.

The button opens OCI Resource Manager using the root Terraform wrapper. It deploys the runtime stack.

You can also create the runtime stack from GitHub:

```text
Repository URL: https://github.com/vishakchittuvalapil/oci-cribl-log-partitioner
Branch: main
Working directory: resource-manager-stack
Terraform version: 1.5.x
```

Required input:

```text
compartment_ocid
region
function_image
log_sources
```

Use the `function_image` output from Step 1.

## Log Sources

`log_sources` maps each OCI Logging source to the folder name Cribl will see.

Example:

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
    log_group_id   = "<LOG_GROUP_OCID>"
    log_id         = "<OBJECT_STORAGE_LOG_OCID>"
    log_type       = "oci-object-storage"
  }
]
```

The `log_type` value becomes part of the Object Storage path:

```text
cribl/YYYY/MM/DD/HH/MM/oci-vcn-flow/
cribl/YYYY/MM/DD/HH/MM/oci-object-storage/
```

## What Gets Created

The image-builder stack creates:

```text
OCIR repository
OCI DevOps project
OCI DevOps build pipeline
Managed Build stage
Deliver Artifacts stage
Build run
IAM policy for DevOps image publishing
```

The runtime stack creates:

```text
Object Storage bucket
OCI Function
Service Connector Hub connector
Optional Functions application
IAM policies for log read, Function invoke, and bucket write
```

## Cribl Collector Settings

Configure Cribl to read from OCI Object Storage using the S3-compatible collector/source.

Recommended values:

```text
Bucket: <bucket_name>
Prefix: cribl/
Format: json or ndjson
Compression: gzip
```

## Repository Contents

```text
README.md                 Resource Manager deployment guide
Dockerfile                Function image build definition used by OCI DevOps
func.py                   Function code that writes Cribl-friendly paths
requirements.txt          Function Python dependencies
build_spec.yaml           OCI DevOps build spec
image-builder-stack/      Resource Manager stack that builds/pushes the image
resource-manager-stack/   Resource Manager stack that deploys OCI logging pipeline
main.tf                   Root wrapper for the Deploy to Oracle Cloud button
variables.tf              Root runtime stack variables
versions.tf               Root Terraform/provider constraints
outputs.tf                Root runtime stack outputs
schema.yaml               Resource Manager UI metadata for the root stack
```

## References

- [Cribl OCI guidance](https://cribl.io/blog/capturing-security-and-observability-data-from-oracle-cloud/)
- [OCI Resource Manager Terraform configuration requirements](https://docs.oracle.com/en-us/iaas/Content/ResourceManager/Concepts/terraformconfigresourcemanager.htm)
- [OCI Resource Manager schema documents](https://docs.oracle.com/en-us/iaas/Content/ResourceManager/Concepts/terraformconfigresourcemanager_topic-schema.htm)
- [OCI DevOps build specifications](https://docs.oracle.com/en-us/iaas/Content/devops/using/build_specs.htm)
