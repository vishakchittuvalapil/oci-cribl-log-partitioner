# OCI Logs to Cribl Resource Manager Deployment

[![Deploy to Oracle Cloud](https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg)](https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https://github.com/vishakchittuvalapil/oci-cribl-log-partitioner/archive/refs/heads/main.zip)

This repository is focused on a **Resource Manager-style deployment** for sending OCI logs to Cribl through Object Storage.

The Function writes objects using Cribl-friendly paths:

```text
cribl/YYYY/MM/DD/HH/MM/<log_type>/oci-log-<timestamp>-<uuid>.json.gz
```

This follows [Cribl's OCI guidance](https://cribl.io/blog/capturing-security-and-observability-data-from-oracle-cloud/) to include year, month, day, hour, and optionally minute in the bucket path for time-based filtering.

## Deployment Flow

Click **Deploy to Oracle Cloud** and create one Resource Manager stack.

The stack creates:

```text
Object Storage bucket
OCI Function
Service Connector Hub connector
Optional Functions application
IAM policies for log read, Function invoke, and bucket write
```

No OCI DevOps stack, GitHub connection, Vault secret, Cloud Shell, or local Docker build is required for the default deployment.

## Prebuilt Image

The stack uses this prebuilt Function image by default:

```text
iad.ocir.io/id3kvohtwgjy/cribl-oci-log-partitioner/function:0.0.1
```

Pinned digest:

```text
sha256:f6e957b424be5948324d39c6559f9597419c977e887e79d2b24b8e2fc0779fc1
```

This default is intended for `us-ashburn-1`. If you deploy in another region or want to own the image in your tenancy, override `function_image` and optionally `function_image_digest`.

Maintainer callout:

```text
For this default image to work for users outside your tenancy, the OCIR repository that hosts it must be public or otherwise readable by those users.
```

## Required Inputs

Resource Manager prepopulates common OCI values such as tenancy, compartment, and region.

You provide:

```text
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

## Manual Image Build From Cloud Shell

This is optional. Use it only if you want to publish your own Function image instead of the default prebuilt image.

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

6. Log in to OCIR from Cloud Shell:

```bash
podman login "${REGION_KEY}.ocir.io"
```

Username format:

```text
<namespace>/<oci-username>
```

If your tenancy uses identity domains:

```text
<namespace>/<identity-domain>/<oci-username>
```

Use the OCI Auth Token as the password.

7. Build and push the image:

```bash
podman build --platform linux/amd64 -t "${IMAGE}" .
podman push "${IMAGE}"
```

8. Copy the image URI printed in Step 3 and override the Resource Manager variable:

```text
function_image = <your image URI>
```

## Repository Contents

```text
README.md                 Resource Manager deployment guide
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
