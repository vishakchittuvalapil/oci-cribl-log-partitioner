output "bucket_name" {
  description = "Object Storage bucket for Cribl collection."
  value       = module.cribl_oci_log_partitioner.bucket_name
}

output "cribl_collector_prefix" {
  description = "Prefix to configure in the Cribl S3 Collector."
  value       = module.cribl_oci_log_partitioner.cribl_collector_prefix
}

output "object_path_pattern" {
  description = "Object path written by the Function."
  value       = module.cribl_oci_log_partitioner.object_path_pattern
}

output "function_id" {
  description = "Created OCI Function OCID."
  value       = module.cribl_oci_log_partitioner.function_id
}

output "functions_application_id" {
  description = "Functions application OCID used by the stack."
  value       = module.cribl_oci_log_partitioner.functions_application_id
}

output "service_connector_id" {
  description = "Service Connector Hub connector OCID."
  value       = module.cribl_oci_log_partitioner.service_connector_id
}

output "log_type_map" {
  description = "Log OCID to Cribl log type mapping used by the Function."
  value       = module.cribl_oci_log_partitioner.log_type_map
}
