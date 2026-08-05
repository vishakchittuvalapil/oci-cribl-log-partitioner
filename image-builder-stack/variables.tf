variable "tenancy_ocid" {
  description = "Tenancy OCID. Resource Manager prepopulates this variable when the stack runs in OCI."
  type        = string
}

variable "compartment_ocid" {
  description = "Compartment OCID where the image-builder stack creates DevOps and OCIR resources."
  type        = string
}

variable "region" {
  description = "OCI region, for example us-ashburn-1."
  type        = string
}

variable "object_storage_namespace" {
  description = "Object Storage namespace. Leave empty to let Terraform discover it from the tenancy."
  type        = string
  default     = ""
}

variable "repository_url" {
  description = "GitHub repository URL that contains the Function source and build_spec.yaml."
  type        = string
  default     = "https://github.com/vishakchittuvalapil/oci-cribl-log-partitioner.git"
}

variable "repository_branch" {
  description = "GitHub branch to build."
  type        = string
  default     = "main"
}

variable "build_source_name" {
  description = "OCI DevOps build source folder name."
  type        = string
  default     = "Source"
}

variable "build_spec_file" {
  description = "Build spec path relative to the primary source repository root."
  type        = string
  default     = "build_spec.yaml"
}

variable "create_github_connection" {
  description = "Create a new OCI DevOps GitHub connection using github_access_token_secret_id. Set false to use existing_github_connection_id."
  type        = bool
  default     = false
}

variable "existing_github_connection_id" {
  description = "Existing OCI DevOps GitHub connection OCID. Required when create_github_connection is false."
  type        = string
  default     = ""
}

variable "github_access_token_secret_id" {
  description = "OCI Vault Secret OCID containing a GitHub personal access token. Required when create_github_connection is true."
  type        = string
  default     = ""
  sensitive   = true
}

variable "ocir_repository_name" {
  description = "OCIR repository name for the Function image."
  type        = string
  default     = "cribl-oci-log-partitioner/function"
}

variable "image_tag" {
  description = "Function image tag to publish."
  type        = string
  default     = "0.0.1"
}

variable "create_ocir_repository" {
  description = "Create the OCIR repository. Set false if it already exists."
  type        = bool
  default     = true
}

variable "ocir_repository_is_public" {
  description = "Make the OCIR repository public. Keep false for private tenancy-owned builds."
  type        = bool
  default     = false
}

variable "ocir_repository_is_immutable" {
  description = "Make the OCIR repository immutable. Keep false while iterating on a tag."
  type        = bool
  default     = false
}

variable "devops_project_name" {
  description = "OCI DevOps project name."
  type        = string
  default     = "cribl-oci-log-partitioner-image-builder"
}

variable "devops_project_description" {
  description = "OCI DevOps project description."
  type        = string
  default     = "Build and publish the Cribl OCI log partitioner Function image to OCIR"
}

variable "notification_topic_name" {
  description = "ONS topic name used by the DevOps project."
  type        = string
  default     = "cribl-oci-log-partitioner-build-events"
}

variable "build_pipeline_name" {
  description = "OCI DevOps build pipeline display name."
  type        = string
  default     = "Build-Cribl-OCI-Log-Partitioner-Image"
}

variable "build_stage_name" {
  description = "OCI DevOps managed build stage display name."
  type        = string
  default     = "Build Function Image"
}

variable "deliver_stage_name" {
  description = "OCI DevOps deliver artifact stage display name."
  type        = string
  default     = "Deliver Function Image To OCIR"
}

variable "build_stage_image" {
  description = "Managed build runner base image."
  type        = string
  default     = "OL8_X86_64_STANDARD_10"
}

variable "build_stage_timeout_in_seconds" {
  description = "Managed build stage timeout in seconds."
  type        = number
  default     = 1800
}

variable "run_build" {
  description = "Start a build run during apply."
  type        = bool
  default     = true
}

variable "build_run_version" {
  description = "Change this value to force a new build run on a later apply."
  type        = string
  default     = "1"
}

variable "create_iam_resources" {
  description = "Create dynamic group and IAM policy statements for OCI DevOps to read GitHub secret, use DevOps resources, publish to OCIR, and use notifications."
  type        = bool
  default     = true
}

variable "dynamic_group_name" {
  description = "Dynamic group name for OCI DevOps build pipeline resource principal."
  type        = string
  default     = "cribl-oci-log-partitioner-devops-dg"
}

variable "devops_policy_name" {
  description = "IAM policy name for OCI DevOps build permissions."
  type        = string
  default     = "cribl-oci-log-partitioner-devops-policy"
}

variable "freeform_tags" {
  description = "Freeform tags applied to supported resources."
  type        = map(string)
  default     = {}
}
