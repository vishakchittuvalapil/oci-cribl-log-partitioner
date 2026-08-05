variable "tenancy_ocid" {
  description = "Tenancy OCID. Resource Manager prepopulates this variable when the stack runs in OCI."
  type        = string
}

variable "compartment_ocid" {
  description = "Compartment OCID where the stack creates the bucket, function, connector, and compartment-scoped policies."
  type        = string
}

variable "region" {
  description = "OCI region, for example us-ashburn-1."
  type        = string
  default     = "us-ashburn-1"
}

variable "object_storage_namespace" {
  description = "Object Storage namespace. Leave empty to let Terraform discover it from the tenancy."
  type        = string
  default     = ""
}

variable "bucket_name" {
  description = "Object Storage bucket name for Cribl-readable objects."
  type        = string
  default     = "CriblOutput"
}

variable "create_bucket" {
  description = "Create the Object Storage bucket. Set false if the bucket already exists."
  type        = bool
  default     = true
}

variable "object_prefix" {
  description = "Top-level Object Storage prefix Cribl should scan."
  type        = string
  default     = "cribl"
}

variable "include_minute" {
  description = "Include the minute folder in the object path."
  type        = bool
  default     = true
}

variable "log_sources" {
  description = "OCI Logging sources and their Cribl log_type folder names."
  type = list(object({
    compartment_id = string
    log_group_id   = string
    log_id         = string
    log_type       = string
  }))

  validation {
    condition = length(var.log_sources) > 0 && alltrue([
      for source in var.log_sources :
      trimspace(source.compartment_id) != "" &&
      trimspace(source.log_group_id) != "" &&
      trimspace(source.log_id) != "" &&
      trimspace(source.log_type) != ""
    ])
    error_message = "Provide at least one log source, and include compartment_id, log_group_id, log_id, and log_type for each source."
  }
}

variable "function_image" {
  description = "OCIR image URI for the Function container. Build and push the image first, then paste the image URI here."
  type        = string
}

variable "function_image_digest" {
  description = "Optional image digest to pin the exact Function image."
  type        = string
  default     = ""
}

variable "function_name" {
  description = "OCI Function display name."
  type        = string
  default     = "cribl-oci-log-partitioner"
}

variable "function_memory_in_mbs" {
  description = "Function memory in MiB."
  type        = number
  default     = 256
}

variable "function_timeout_in_seconds" {
  description = "Function timeout in seconds."
  type        = number
  default     = 120
}

variable "create_functions_application" {
  description = "Create a new Functions application. Set false to reuse an existing app."
  type        = bool
  default     = false
}

variable "existing_functions_application_id" {
  description = "Existing Functions application OCID. Required when create_functions_application is false."
  type        = string
  default     = ""
}

variable "functions_application_name" {
  description = "Display name for the Functions application when create_functions_application is true."
  type        = string
  default     = "cribl-log-partitioner-app"
}

variable "functions_subnet_ids" {
  description = "Subnet OCIDs for a new Functions application. Required when create_functions_application is true."
  type        = list(string)
  default     = []
}

variable "functions_application_shape" {
  description = "Functions application shape."
  type        = string
  default     = "GENERIC_X86"
}

variable "service_connector_name" {
  description = "Service Connector Hub connector display name."
  type        = string
  default     = "OCI-to-Cribl-Partitioner"
}

variable "service_connector_description" {
  description = "Service Connector Hub connector description."
  type        = string
  default     = "Send OCI logs to a Function target that writes Cribl-friendly partitioned objects to Object Storage"
}

variable "connector_batch_size_in_num" {
  description = "Maximum number of records per Function invocation."
  type        = number
  default     = 100
}

variable "connector_batch_time_in_sec" {
  description = "Maximum time in seconds before Connector Hub invokes the Function with a partial batch."
  type        = number
  default     = 60
}

variable "create_iam_resources" {
  description = "Create dynamic group and IAM policies needed by the connector and Function."
  type        = bool
  default     = true
}

variable "dynamic_group_name" {
  description = "Dynamic group name for OCI Functions resource principal."
  type        = string
  default     = "cribl-oci-log-partitioner-functions-dg"
}

variable "function_bucket_policy_name" {
  description = "Policy name for Function writes to Object Storage."
  type        = string
  default     = "cribl-oci-log-partitioner-bucket-policy"
}

variable "service_connector_policy_name" {
  description = "Policy name for Service Connector Hub log reads and Function invocation."
  type        = string
  default     = "cribl-oci-log-partitioner-connector-policy"
}

variable "freeform_tags" {
  description = "Freeform tags applied to supported resources."
  type        = map(string)
  default     = {}
}
