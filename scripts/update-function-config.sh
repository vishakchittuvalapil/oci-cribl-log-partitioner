#!/usr/bin/env bash
set -euo pipefail

: "${FUNCTION_OCID:?Set FUNCTION_OCID}"
: "${REGION:?Set REGION, for example us-ashburn-1}"

OCI_BIN="${OCI_BIN:-oci}"
CONFIG_FILE="${CONFIG_FILE:-examples/function-config.example.json}"

"${OCI_BIN}" fn function update \
  --function-id "${FUNCTION_OCID}" \
  --config "file://${CONFIG_FILE}" \
  --region "${REGION}" \
  --force
