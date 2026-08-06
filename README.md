# OCI Logs to Cribl with OCI Functions

Deploy an OCI Function from Cloud Shell with the Fn CLI, then create the Service Connector manually when you know which logs to send.

The Function writes objects using Cribl-friendly paths:

```text
cribl/YYYY/MM/DD/HH/MM/<log_type>/oci-log-<timestamp>-<uuid>.json.gz
```

This follows [Cribl's OCI guidance](https://cribl.io/blog/capturing-security-and-observability-data-from-oracle-cloud/) to include year, month, day, hour, and optionally minute in the bucket path for time-based filtering.

## What This Deploys

```text
Functions application
OCI Function
Function container image in OCIR
Object Storage bucket for Cribl to read
```

You create the Service Connector manually later:

```text
Source: Logging
Target: Functions
Function: cribl-oci-log-partitioner
```

Do not use Object Storage as the Service Connector target for this version. The Function is the target because it writes the final Cribl partitioned object path into Object Storage.

Resource order:

```text
1. Configure the Fn CLI context
2. Create a dedicated Functions application for this Function
3. Deploy the Function into that application
4. Create the Service Connector manually after selecting logs
```

## Step 1: Open Cloud Shell

Clone the repo:

```bash
git clone https://github.com/vishakchittuvalapil/oci-cribl-log-partitioner.git
cd oci-cribl-log-partitioner
```

If you cloned this repo earlier, pull the latest files before deploying:

```bash
git pull origin main
ls -l func.yaml Dockerfile func.py requirements.txt
```

`fn deploy` must be run from the directory that contains `func.yaml`.

## Step 2: Set Variables

Update these values for your tenancy:

```bash
export REGION_IDENTIFIER="us-ashburn-1"
export REGION_KEY="iad"
export COMPARTMENT_OCID="<COMPARTMENT_OCID>"
export SUBNET_OCID="<PRIVATE_OR_PUBLIC_SUBNET_OCID>"
export APP_NAME="cribl-log-partitioner-app"
export FUNCTION_NAME="cribl-oci-log-partitioner"
export BUCKET_NAME="Cribl_SIEM"
export NAMESPACE="$(oci os ns get --query data --raw-output)"
echo "${APP_NAME}"
```

Use the region values for your OCI region. For example, Ashburn is:

```text
REGION_IDENTIFIER=us-ashburn-1
REGION_KEY=iad
```

The subnet can be private. For a private subnet, make sure the VCN has a Service Gateway route to **All <region> Services in Oracle Services Network** so OCI Functions can pull from OCIR and the Function can write to Object Storage without public internet access.

## Step 3: Log In To OCIR

Generate an OCI Auth Token:

```text
Profile -> My profile -> Tokens and keys -> Auth tokens -> Generate token
```

Set your OCIR username:

```bash
export OCIR_USERNAME="${NAMESPACE}/<Domain_name>/<OCI_USERNAME>"
```

Example:

```text
id3kvohtwgjy/Default/vishak.chittuvalapil@oracle.com
```

Log in:

```bash
docker logout "${REGION_KEY}.ocir.io" || true
docker login "${REGION_KEY}.ocir.io" --username "${OCIR_USERNAME}"
```

Use the OCI Auth Token as the password.

Oracle documents the required username format as `<namespace>/<username>` or `<namespace>/<domain-name>/<username>` for federated/domain users: [Log in to OCIR](https://docs.oracle.com/en-us/iaas/Content/Functions/Tasks/functionslogintoocir.htm).

## Step 4: Configure The Fn CLI Context

This step only configures the local Fn CLI in Cloud Shell. It does not create the OCI Function yet.

Cloud Shell normally already has Fn contexts. Select your region context and point it to your compartment and OCIR repo prefix:

```bash
fn list context
fn use context "${REGION_IDENTIFIER}"
fn update context oracle.compartment-id "${COMPARTMENT_OCID}"
fn update context oracle.image-compartment-id "${COMPARTMENT_OCID}"
fn update context registry "${REGION_KEY}.ocir.io/${NAMESPACE}/cribl-oci-log-partitioner"
```

Oracle's Cloud Shell quickstart uses the same Fn context pattern: [Functions QuickStart on Cloud Shell](https://docs.oracle.com/en-us/iaas/Content/Functions/Tasks/functionsquickstartcloudshell.htm).

## Step 5: Create The Bucket

Create the Object Storage bucket that Cribl will read:

```bash
oci os bucket create \
  --compartment-id "${COMPARTMENT_OCID}" \
  --name "${BUCKET_NAME}" \
  --public-access-type NoPublicAccess \
  --storage-tier Standard
```

If the bucket already exists, continue.

## Step 6: Create A Dedicated Functions Application

Create a dedicated Functions application for this Function:

```bash
fn create app "${APP_NAME}" --subnet-id "${SUBNET_OCID}"
```

You can use a private subnet. The Function does not need inbound public access, but it does need outbound access to OCI services:

```text
Private subnet: use a Service Gateway to All <region> Services in Oracle Services Network
Public subnet: use an Internet Gateway route and egress rules
```

For this project, a private subnet with a Service Gateway is preferred because the Function only needs OCI service access: OCIR for image pull and Object Storage for bucket writes. Oracle documents this Functions networking requirement in the Functions troubleshooting guide: [Issues invoking functions](https://docs.oracle.com/en-us/iaas/Content/Functions/Tasks/functionstroubleshooting_topic-Issues-invoking-functions.htm).

If you already created a dedicated app for this Function, reuse that app name and skip this command.

Check apps:

```bash
fn list apps
```

## Step 7: Deploy The Function

Deploy from the repo directory:

```bash
ls -l func.yaml
echo "${APP_NAME}"
fn -v deploy --app "${APP_NAME}"
```

This command builds the container image, pushes it to OCIR, and creates or updates the OCI Function. Oracle documents that `fn -v deploy --app <app-name>` performs build, push, and deploy in one step: [Creating and Deploying Functions](https://docs.oracle.com/en-us/iaas/Content/Functions/Tasks/functionsuploading.htm).

If Cloud Shell reports `no space left on device`, clean unused local container build data and retry:

```bash
docker system prune --all --force --volumes
fn -v deploy --app "${APP_NAME}"
```

## Step 8: Configure The Function

Set the runtime config:

```bash
fn config function "${APP_NAME}" "${FUNCTION_NAME}" BUCKET_NAME "${BUCKET_NAME}"
fn config function "${APP_NAME}" "${FUNCTION_NAME}" FUNCTION_MODE "target_writer"
fn config function "${APP_NAME}" "${FUNCTION_NAME}" OBJECT_PREFIX "cribl"
fn config function "${APP_NAME}" "${FUNCTION_NAME}" INCLUDE_MINUTE "true"
fn config function "${APP_NAME}" "${FUNCTION_NAME}" LOG_TYPE_MAP "{}"
```

OCI Functions exposes these config values as environment variables to the Function. See [OCI custom Function configuration parameters](https://docs.oracle.com/en-us/iaas/Content/Functions/Tasks/functionspassingconfigparams.htm).

Keep `LOG_TYPE_MAP` as `{}` for the normal deployment. The Function detects common OCI log types automatically, including VCN flow logs, Object Storage, Audit, Cloud Guard, and Load Balancer logs. Unknown logs go to:

```text
cribl/YYYY/MM/DD/HH/MM/oci-generic/
```

## Step 9: Create IAM Access

The Function needs permission to write to the bucket. Create a dynamic group for functions in your compartment:

```text
ALL {resource.type = 'fnfunc', resource.compartment.id = '<COMPARTMENT_OCID>'}
```

Add this policy in the bucket compartment:

```text
Allow dynamic-group <DYNAMIC_GROUP_NAME> to manage objects in compartment id <COMPARTMENT_OCID> where target.bucket.name='<BUCKET_NAME>'
```

Service Connector Hub also needs permission to read logs and invoke the Function. Add these policies in the relevant compartments:

```text
Allow any-user to read log-content in compartment id <LOG_COMPARTMENT_OCID> where all {request.principal.type='serviceconnector'}
Allow any-user to read log-groups in compartment id <LOG_COMPARTMENT_OCID> where all {request.principal.type='serviceconnector'}
Allow any-user to use fn-function in compartment id <FUNCTION_COMPARTMENT_OCID> where all {request.principal.type='serviceconnector'}
Allow any-user to use fn-invocation in compartment id <FUNCTION_COMPARTMENT_OCID> where all {request.principal.type='serviceconnector'}
```

If the Service Connector wizard offers to create required policies for you, you can use that option.

## Step 10: Create Service Connector Manually

Open OCI Console:

```text
Analytics & AI -> Messaging -> Connector Hub -> Create connector
```

Use these settings:

```text
Source: Logging
Target: Functions
Task: None
```

For the source:

```text
Compartment: compartment containing the log
Log group: selected log group
Logs: selected logs
```

For the target:

```text
Function compartment: compartment containing the Function
Function application: cribl-log-partitioner-app
Function: cribl-oci-log-partitioner
Batch size: 100 messages
Batch time: 60 seconds
```

Oracle's Connector Hub docs confirm that a Logging source can target Functions, and that Functions targets receive log data as JSON batches: [Creating a Connector with a Logging Source](https://docs.public.content.oci.oraclecloud.com/en-us/iaas/Content/connector-hub/create-service-connector-logging-source.htm).

## Step 11: Configure Cribl

Configure Cribl to read from OCI Object Storage using the S3-compatible collector/source.

Recommended values:

```text
Bucket: Cribl_SIEM
Prefix: cribl/
Format: json or ndjson
Compression: gzip
```

Expected object path:

```text
cribl/2026/08/05/15/17/oci-vcn-flow/oci-log-20260805T151700Z-<uuid>.json.gz
```

## Repository Contents

```text
README.md         Manual Cloud Shell and Connector Hub guide
func.yaml         Fn CLI function metadata
Dockerfile        Function image build definition
func.py           Function code that writes Cribl-friendly paths
requirements.txt  Function Python dependencies
```

## References

- [Cribl OCI guidance](https://cribl.io/blog/capturing-security-and-observability-data-from-oracle-cloud/)
- [OCI Functions Cloud Shell quickstart](https://docs.oracle.com/en-us/iaas/Content/Functions/Tasks/functionsquickstartcloudshell.htm)
- [OCI Functions custom Dockerfiles](https://docs.oracle.com/en-us/iaas/Content/Functions/Tasks/functionsusingcustomdockerfiles.htm)
- [OCI Function configuration parameters](https://docs.oracle.com/en-us/iaas/Content/Functions/Tasks/functionspassingconfigparams.htm)
- [OCI Functions networking troubleshooting](https://docs.oracle.com/en-us/iaas/Content/Functions/Tasks/functionstroubleshooting_topic-Issues-invoking-functions.htm)
- [OCI Connector Hub Logging source](https://docs.public.content.oci.oraclecloud.com/en-us/iaas/Content/connector-hub/create-service-connector-logging-source.htm)
