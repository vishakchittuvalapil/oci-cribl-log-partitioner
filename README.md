# OCI Logs to Cribl Resource Manager Deployment

[![Deploy to Oracle Cloud](https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg)](https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https://github.com/vishakchittuvalapil/oci-cribl-log-partitioner/archive/refs/heads/main.zip)

This repository deploys an OCI log pipeline for Cribl through OCI Resource Manager.

The Function writes objects using Cribl-friendly paths:

```text
cribl/YYYY/MM/DD/HH/MM/<log_type>/oci-log-<timestamp>-<uuid>.json.gz
```

This follows [Cribl's OCI guidance](https://cribl.io/blog/capturing-security-and-observability-data-from-oracle-cloud/) to include year, month, day, hour, and optionally minute in the bucket path for time-based filtering.

## Deployment Flow

Use this flow:

```text
1. Build and push the Function image from OCI Cloud Shell
2. Click Deploy to Oracle Cloud
3. Paste the image URI into function_image
4. Enter log_sources
5. Run Plan and Apply
```

There is no prebuilt image dependency and no OCI DevOps, GitHub connection, or Vault secret requirement.

## Step 1: Build Image From Cloud Shell

1. Open **OCI Cloud Shell**.

2. Clone the repo:

```bash
git clone https://github.com/vishakchittuvalapil/oci-cribl-log-partitioner.git
cd oci-cribl-log-partitioner
```

3. Set image variables:

```bash
export REGION_KEY=iad
export NAMESPACE="$(oci os ns get --query data --raw-output)"
export REPO_NAME=cribl-oci-log-partitioner/function
export TAG=0.0.1
export IMAGE="${REGION_KEY}.ocir.io/${NAMESPACE}/${REPO_NAME}:${TAG}"
echo "${IMAGE}"
```

Use the region key for your OCI region. For example, `iad` is `us-ashburn-1`.

4. Create the OCIR repository:

```bash
oci artifacts container repository create \
  --compartment-id "<COMPARTMENT_OCID>" \
  --display-name "${REPO_NAME}" \
  --is-public false
```

If the repository already exists, continue.

5. Generate an OCI Auth Token:

```text
Profile -> My profile -> Tokens and keys -> Auth tokens -> Generate token
```

6. Set your OCIR username and log in from Cloud Shell:

```bash
export OCIR_USERNAME="${NAMESPACE}/<Domain_name>/<OCI_USERNAME>"
```

Replace `<Domain_name>` with your OCI identity domain, such as `Default`, and replace `<OCI_USERNAME>` with the username shown in your OCI profile, usually an email address.

Then log in:

```bash
podman logout "${REGION_KEY}.ocir.io" || true
podman login "${REGION_KEY}.ocir.io" --username "${OCIR_USERNAME}"
```

If `podman logout` says `not logged into`, that is safe to ignore. Use the OCI Auth Token as the password when `podman login` prompts for it.

Oracle documents the required username format as `<namespace>/<username>` or `<namespace>/<domain-name>/<username>` for federated/domain users: [Log in to OCIR](https://docs.oracle.com/en-us/iaas/Content/Functions/Tasks/functionslogintoocir.htm).

7. Build and push the image:

```bash
podman build --layers=false --platform linux/amd64 -t "${IMAGE}" .
podman push "${IMAGE}"
```

If Cloud Shell reports `no space left on device`, clean unused local Podman build data and retry:

```bash
podman system prune --all --force --volumes
podman build --layers=false --no-cache --platform linux/amd64 -t "${IMAGE}" .
podman push "${IMAGE}"
```

This cleanup affects only unused local Cloud Shell container images, containers, volumes, and build cache. It does not delete OCI resources or images already pushed to OCIR.

8. Copy the image URI printed in Step 3:

```text
<REGION_KEY>.ocir.io/<NAMESPACE>/cribl-oci-log-partitioner/function:0.0.1
```

You will paste it into Resource Manager as:

```text
function_image
```

## Step 2: Deploy With Resource Manager

Click **Deploy to Oracle Cloud** at the top of this README.

The stack creates:

```text
Object Storage bucket
OCI Function
Service Connector Hub connector
Optional Functions application
IAM policies for log read, Function invoke, and bucket write
```

Resource Manager prepopulates common OCI values such as tenancy, compartment, and region.

You provide:

```text
function_image
log_sources
existing_functions_application_id
```

If you want the stack to create a new Functions application, set:

```text
create_functions_application = true
functions_subnet_ids = ["<SUBNET_OCID>"]
```

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
README.md                 Deployment guide
Dockerfile                Function image build definition
func.py                   Function code that writes Cribl-friendly paths
requirements.txt          Function Python dependencies
resource-manager-stack/   Resource Manager stack that deploys the OCI logging pipeline
main.tf                   Root wrapper for the Deploy to Oracle Cloud button
variables.tf              Root runtime stack variables
versions.tf               Root Terraform/provider constraints
outputs.tf                Root runtime stack outputs
schema.yaml               Resource Manager UI metadata
```

## References

- [Cribl OCI guidance](https://cribl.io/blog/capturing-security-and-observability-data-from-oracle-cloud/)
- [OCI Resource Manager Terraform configuration requirements](https://docs.oracle.com/en-us/iaas/Content/ResourceManager/Concepts/terraformconfigresourcemanager.htm)
- [OCI Resource Manager schema documents](https://docs.oracle.com/en-us/iaas/Content/ResourceManager/Concepts/terraformconfigresourcemanager_topic-schema.htm)
