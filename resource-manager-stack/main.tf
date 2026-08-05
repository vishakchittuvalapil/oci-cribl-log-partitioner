data "oci_objectstorage_namespace" "this" {
  compartment_id = var.tenancy_ocid
}

locals {
  object_storage_namespace = trimspace(var.object_storage_namespace) != "" ? var.object_storage_namespace : data.oci_objectstorage_namespace.this.namespace
  log_type_map             = { for source in var.log_sources : source.log_id => source.log_type }
  functions_application_id = var.create_functions_application ? oci_functions_application.this[0].id : var.existing_functions_application_id
}

resource "oci_objectstorage_bucket" "this" {
  count = var.create_bucket ? 1 : 0

  compartment_id = var.compartment_ocid
  namespace      = local.object_storage_namespace
  name           = var.bucket_name
  access_type    = "NoPublicAccess"
  storage_tier   = "Standard"
  freeform_tags  = var.freeform_tags
}

resource "oci_identity_dynamic_group" "function" {
  count = var.create_iam_resources ? 1 : 0

  compartment_id = var.tenancy_ocid
  name           = var.dynamic_group_name
  description    = "Functions allowed to write Cribl-partitioned log objects to Object Storage"
  matching_rule  = "ALL {resource.type = 'fnfunc', resource.compartment.id = '${var.compartment_ocid}'}"
}

resource "oci_identity_policy" "function_bucket" {
  count = var.create_iam_resources ? 1 : 0

  compartment_id = var.compartment_ocid
  name           = var.function_bucket_policy_name
  description    = "Allow Cribl OCI log partitioner Function to write objects to the Cribl bucket"

  statements = [
    "Allow dynamic-group ${oci_identity_dynamic_group.function[0].name} to manage objects in compartment id ${var.compartment_ocid} where target.bucket.name='${var.bucket_name}'"
  ]
}

resource "oci_identity_policy" "service_connector" {
  count = var.create_iam_resources ? 1 : 0

  compartment_id = var.compartment_ocid
  name           = var.service_connector_policy_name
  description    = "Allow Service Connector Hub to read logs and invoke the Cribl partitioner Function"

  statements = [
    "Allow any-user to read log-content in compartment id ${var.compartment_ocid} where all {request.principal.type='serviceconnector'}",
    "Allow any-user to read log-groups in compartment id ${var.compartment_ocid} where all {request.principal.type='serviceconnector'}",
    "Allow any-user to use fn-function in compartment id ${var.compartment_ocid} where all {request.principal.type='serviceconnector'}",
    "Allow any-user to use fn-invocation in compartment id ${var.compartment_ocid} where all {request.principal.type='serviceconnector'}"
  ]
}

resource "oci_functions_application" "this" {
  count = var.create_functions_application ? 1 : 0

  compartment_id = var.compartment_ocid
  display_name   = var.functions_application_name
  subnet_ids     = var.functions_subnet_ids
  shape          = var.functions_application_shape
  freeform_tags  = var.freeform_tags
}

resource "oci_functions_function" "this" {
  application_id     = local.functions_application_id
  display_name       = var.function_name
  image              = var.function_image
  image_digest       = trimspace(var.function_image_digest) != "" ? var.function_image_digest : null
  memory_in_mbs      = var.function_memory_in_mbs
  timeout_in_seconds = var.function_timeout_in_seconds
  freeform_tags      = var.freeform_tags

  config = {
    BUCKET_NAME    = var.bucket_name
    FUNCTION_MODE  = "target_writer"
    INCLUDE_MINUTE = tostring(var.include_minute)
    LOG_TYPE_MAP   = jsonencode(local.log_type_map)
    OBJECT_PREFIX  = trim(var.object_prefix, "/")
  }

  depends_on = [
    oci_objectstorage_bucket.this,
    oci_identity_policy.function_bucket
  ]
}

resource "oci_sch_service_connector" "this" {
  count = var.create_service_connector ? 1 : 0

  compartment_id = var.compartment_ocid
  display_name   = var.service_connector_name
  description    = var.service_connector_description
  state          = "ACTIVE"
  freeform_tags  = var.freeform_tags

  source {
    kind = "logging"

    dynamic "log_sources" {
      for_each = var.log_sources
      content {
        compartment_id = log_sources.value.compartment_id
        log_group_id   = log_sources.value.log_group_id
        log_id         = log_sources.value.log_id
      }
    }
  }

  target {
    kind              = "functions"
    function_id       = oci_functions_function.this.id
    batch_size_in_num = var.connector_batch_size_in_num
    batch_time_in_sec = var.connector_batch_time_in_sec
  }

  depends_on = [
    oci_identity_policy.service_connector
  ]

  lifecycle {
    precondition {
      condition     = length(var.log_sources) > 0
      error_message = "Set create_service_connector=false for an initial deployment without log sources, or provide at least one log source before creating the Service Connector."
    }
  }
}
