# OCI Resource Manager Stack

This folder contains a Terraform configuration that can be used as an OCI Resource Manager stack.

It provisions the OCI side of the Cribl log partitioner:

```text
Object Storage bucket
OCI Function
Service Connector Hub connector
Optional Functions application
Optional IAM dynamic group and policies
```

## Important Build Boundary

Resource Manager runs Terraform. It does not build and push the Function container image from the `Dockerfile`.

Before applying this stack, build and push the image to OCIR:

```text
<region-key>.ocir.io/<namespace>/cribl-oci-log-partitioner/function:0.0.1
```

Then pass that image URI as:

```text
function_image
```

## Final Runtime Flow

```text
OCI Logging
  -> Service Connector Hub
  -> OCI Function target
  -> Object Storage bucket
  -> Cribl S3 Collector
```

The Function writes objects using this Cribl-friendly path:

```text
cribl/YYYY/MM/DD/HH/MM/<log_type>/oci-log-<timestamp>-<uuid>.json.gz
```

## How to Use in OCI Resource Manager

### Option 1: Git Source

1. Open OCI Console.
2. Go to **Developer Services**.
3. Go to **Resource Manager**.
4. Select **Stacks**.
5. Select **Create stack**.
6. Choose **Source code control system** or **Git** as the Terraform source.
7. Use this repository:

   ```text
   https://github.com/vishakchittuvalapil/oci-cribl-log-partitioner
   ```

8. Set the working directory to:

   ```text
   resource-manager-stack
   ```

9. Use Terraform version `1.5.x` in Resource Manager.
10. Enter the variables.
11. Run **Plan**.
12. Review the plan.
13. Run **Apply**.

### Option 2: Zip Upload

Create a zip from this folder:

```bash
cd resource-manager-stack
zip -r ../oci-cribl-log-partitioner-stack.zip .
```

Upload the zip to Resource Manager as the stack configuration.

## Required Variables

```text
tenancy_ocid
compartment_ocid
region
function_image
log_sources
```

If reusing an existing Functions application:

```text
create_functions_application = false
existing_functions_application_id = <existing_app_ocid>
```

If creating a new Functions application:

```text
create_functions_application = true
functions_subnet_ids = ["<subnet_ocid>"]
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
    log_group_id   = "<LOG_GROUP_OCID>"
    log_id         = "<OBJECT_STORAGE_LOG_OCID>"
    log_type       = "oci-object-storage"
  }
]
```

The `log_type` value becomes the Object Storage folder:

```text
cribl/YYYY/MM/DD/HH/MM/oci-vcn-flow/
```

## IAM Scope Callout

The default IAM policy assumes:

```text
Function, bucket, connector, and source logs are in the same compartment.
```

If your logs live in multiple compartments, create broader log-read policies at the tenancy or parent compartment level.

## Cribl Collector

After apply, configure Cribl to read:

```text
bucket = <bucket_name>
prefix = cribl/
compression = gzip
format = json or ndjson
```

## References

- OCI Resource Manager Terraform configuration requirements: https://docs.oracle.com/en-us/iaas/Content/ResourceManager/Concepts/terraformconfigresourcemanager.htm
- OCI Resource Manager stack creation: https://docs.oracle.com/en-us/iaas/Content/ResourceManager/Tasks/create-stack.htm
- OCI Resource Manager supported Terraform versions: https://docs.oracle.com/en-us/iaas/Content/ResourceManager/Reference/terraformversions.htm
- Cribl OCI guidance: https://cribl.io/blog/capturing-security-and-observability-data-from-oracle-cloud/
