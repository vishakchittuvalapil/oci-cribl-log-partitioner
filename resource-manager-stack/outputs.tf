output "bucket_name" {
  description = "Object Storage bucket for Cribl collection."
  value       = var.bucket_name
}

output "cribl_collector_prefix" {
  description = "Prefix to configure in the Cribl S3 Collector."
  value       = "${trim(var.object_prefix, "/")}/"
}

output "object_path_pattern" {
  description = "Object path written by the Function."
  value       = var.include_minute ? "${trim(var.object_prefix, "/")}/YYYY/MM/DD/HH/MM/<log_type>/oci-log-<timestamp>-<uuid>.json.gz" : "${trim(var.object_prefix, "/")}/YYYY/MM/DD/HH/<log_type>/oci-log-<timestamp>-<uuid>.json.gz"
}

output "function_id" {
  description = "Created OCI Function OCID."
  value       = oci_functions_function.this.id
}

output "functions_application_id" {
  description = "Functions application OCID used by the stack."
  value       = local.functions_application_id
}

output "service_connector_id" {
  description = "Service Connector Hub connector OCID."
  value       = oci_sch_service_connector.this.id
}

output "log_type_map" {
  description = "Log OCID to Cribl log type mapping used by the Function."
  value       = local.log_type_map
}
