# OCI Setup Guide

This guide describes the OCI resources needed for the Cribl OCI log partitioner.

## 1. Object Storage Bucket

Create a bucket:

```text
CriblOutput
```

Recommended storage tier:

```text
Standard
```

## 2. OCI Logging

Enable the logs you want to send to Cribl. Examples:

```text
VCN Flow Logs
Object Storage service logs
Load Balancer logs
Cloud Guard logs
Audit logs
```

Capture these values:

```text
Log group OCID
Log OCID
Compartment OCID
```

## 3. OCI Function

Deploy the Function from this folder.

Required config:

```json
{
  "BUCKET_NAME": "CriblOutput",
  "OBJECT_PREFIX": "cribl",
  "INCLUDE_MINUTE": "true",
  "FUNCTION_MODE": "target_writer",
  "LOG_TYPE_MAP": "{\"<LOG_OCID>\":\"oci-vcn-flow\"}"
}
```

## 4. IAM

Create a dynamic group for the Function:

```text
ALL {resource.type = 'fnfunc', resource.compartment.id = '<COMPARTMENT_OCID>'}
```

Allow the Function to write to the bucket:

```text
Allow dynamic-group <FUNCTION_DYNAMIC_GROUP_NAME> to manage objects in compartment <COMPARTMENT_NAME> where target.bucket.name='CriblOutput'
```

Allow Service Connector Hub to read log content:

```text
Allow any-user to read log-content in compartment <COMPARTMENT_NAME> where all {request.principal.type='serviceconnector'}
Allow any-user to read log-groups in compartment <COMPARTMENT_NAME> where all {request.principal.type='serviceconnector'}
```

Allow Service Connector Hub to invoke the Function:

```text
Allow any-user to use fn-function in compartment <COMPARTMENT_NAME> where all {request.principal.type='serviceconnector'}
Allow any-user to use fn-invocation in compartment <COMPARTMENT_NAME> where all {request.principal.type='serviceconnector'}
```

## 5. Service Connector Hub

Create a connector:

```text
Source: Logging
Target: Functions
Task: none
```

Target:

```json
{
  "kind": "functions",
  "functionId": "<FUNCTION_OCID>",
  "batchSizeInNum": 100,
  "batchTimeInSec": 60
}
```

## 6. Validate

List the bucket prefix:

```bash
oci os object list \
  --namespace-name <OBJECT_STORAGE_NAMESPACE> \
  --bucket-name CriblOutput \
  --prefix cribl/
```

Expected:

```text
cribl/YYYY/MM/DD/HH/MM/<log_type>/oci-log-<timestamp>-<uuid>.json.gz
```
