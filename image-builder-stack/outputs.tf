output "function_image" {
  description = "Image URI to pass to the main Cribl Resource Manager stack."
  value       = local.function_image
}

output "function_image_digest" {
  description = "Image digest delivered by the build run. Empty if run_build is false or the build output is not available yet."
  value       = var.run_build ? try(oci_devops_build_run.this[0].build_outputs[0].delivered_artifacts[0].items[0].delivered_artifact_hash, "") : ""
}

output "ocir_repository_name" {
  description = "OCIR repository name that stores the Function image."
  value       = var.ocir_repository_name
}

output "ocir_repository_id" {
  description = "Created OCIR repository OCID. Empty when create_ocir_repository is false."
  value       = var.create_ocir_repository ? oci_artifacts_container_repository.function[0].id : ""
}

output "devops_project_id" {
  description = "OCI DevOps project OCID."
  value       = oci_devops_project.this.id
}

output "github_connection_id" {
  description = "OCI DevOps GitHub connection OCID used by the build stage."
  value       = local.github_connection_id
}

output "build_pipeline_id" {
  description = "OCI DevOps build pipeline OCID."
  value       = oci_devops_build_pipeline.this.id
}

output "build_run_id" {
  description = "OCI DevOps build run OCID. Empty when run_build is false."
  value       = var.run_build ? oci_devops_build_run.this[0].id : ""
}

output "next_stack_function_image_value" {
  description = "Copy this value into the main stack function_image variable."
  value       = local.function_image
}
