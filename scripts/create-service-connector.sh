#!/usr/bin/env bash
set -euo pipefail

: "${COMPARTMENT_OCID:?Set COMPARTMENT_OCID}"
: "${DISPLAY_NAME:?Set DISPLAY_NAME, for example OCI-to-Cribl-Partitioner}"
: "${REGION:?Set REGION, for example us-ashburn-1}"

OCI_BIN="${OCI_BIN:-oci}"
SOURCE_FILE="${SOURCE_FILE:-examples/sch-source.example.json}"
TARGET_FILE="${TARGET_FILE:-examples/sch-target-functions.example.json}"

"${OCI_BIN}" sch service-connector create \
  --compartment-id "${COMPARTMENT_OCID}" \
  --display-name "${DISPLAY_NAME}" \
  --description "Send OCI logs to a Function target that writes Cribl-friendly partitioned objects to Object Storage" \
  --source "file://${SOURCE_FILE}" \
  --target "file://${TARGET_FILE}" \
  --tasks '[]' \
  --region "${REGION}"
