# Image Builder Resource Manager Stack

[![Deploy Image Builder to Oracle Cloud](https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg)](https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https://github.com/vishakchittuvalapil/oci-cribl-log-partitioner/archive/refs/heads/deploy-image-builder.zip)

This stack builds the OCI Function image in the user's tenancy using OCI DevOps.

It creates:

```text
OCIR repository
ONS notification topic
OCI DevOps project
OCI DevOps build pipeline
Managed Build stage
Deliver Artifacts stage
Build run
IAM policy for DevOps image publishing
```

The output image is used by the runtime stack:

```text
ocir.<region>.oci.oraclecloud.com/<namespace>/cribl-oci-log-partitioner/function:<image_tag>
```

## Resource Manager Inputs

Create a Resource Manager stack from GitHub:

```text
Repository URL: https://github.com/vishakchittuvalapil/oci-cribl-log-partitioner
Branch: main
Working directory: image-builder-stack
Terraform version: 1.5.x
```

Required variables:

```text
compartment_ocid
region
existing_github_connection_id
```

OCI DevOps needs a GitHub connection for GitHub build sources.

Use one of these:

```text
Preferred: existing_github_connection_id
Alternative: create_github_connection = true and github_access_token_secret_id
```

For the alternative path, store the GitHub token in OCI Vault and pass the Vault secret OCID. Do not paste GitHub tokens into Resource Manager variables.

## After Apply

Copy the output:

```text
function_image
```

Paste it into the runtime stack variable:

```text
function_image
```

If `function_image_digest` is present, paste it into the runtime stack too. This pins the exact build.

## Rebuild

To trigger a new build from Resource Manager, change:

```text
build_run_version
```

Then run **Plan** and **Apply** again.
