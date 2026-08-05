data "oci_objectstorage_namespace" "this" {
  compartment_id = var.tenancy_ocid
}

locals {
  object_storage_namespace = trimspace(var.object_storage_namespace) != "" ? var.object_storage_namespace : data.oci_objectstorage_namespace.this.namespace
  registry_domain          = "ocir.${var.region}.oci.oraclecloud.com"
  function_image           = "${local.registry_domain}/${local.object_storage_namespace}/${var.ocir_repository_name}:${var.image_tag}"
  github_connection_id     = var.create_github_connection ? oci_devops_connection.github[0].id : var.existing_github_connection_id
}

resource "oci_ons_notification_topic" "this" {
  compartment_id = var.compartment_ocid
  name           = var.notification_topic_name
  description    = "OCI DevOps build notifications for the Cribl OCI log partitioner image"
  freeform_tags  = var.freeform_tags
}

resource "oci_devops_project" "this" {
  compartment_id = var.compartment_ocid
  name           = var.devops_project_name
  description    = var.devops_project_description
  freeform_tags  = var.freeform_tags

  notification_config {
    topic_id = oci_ons_notification_topic.this.id
  }
}

resource "oci_devops_connection" "github" {
  count = var.create_github_connection ? 1 : 0

  access_token    = var.github_access_token_secret_id
  connection_type = "GITHUB_ACCESS_TOKEN"
  project_id      = oci_devops_project.this.id
  display_name    = "Cribl OCI Log Partitioner GitHub"
  description     = "GitHub source connection for Cribl OCI log partitioner Function image builds"
  freeform_tags   = var.freeform_tags

  lifecycle {
    precondition {
      condition     = trimspace(var.github_access_token_secret_id) != ""
      error_message = "When create_github_connection is true, github_access_token_secret_id must be an OCI Vault secret OCID containing a GitHub token."
    }
  }
}

resource "oci_artifacts_container_repository" "function" {
  count = var.create_ocir_repository ? 1 : 0

  compartment_id = var.compartment_ocid
  display_name   = var.ocir_repository_name
  is_immutable   = var.ocir_repository_is_immutable
  is_public      = var.ocir_repository_is_public
  freeform_tags  = var.freeform_tags
}

resource "oci_identity_dynamic_group" "devops" {
  count = var.create_iam_resources ? 1 : 0

  compartment_id = var.tenancy_ocid
  name           = var.dynamic_group_name
  description    = "OCI DevOps build pipelines allowed to publish the Cribl OCI log partitioner image"
  matching_rule  = "ALL {resource.type = 'devopsbuildpipeline', resource.compartment.id = '${var.compartment_ocid}'}"
}

resource "oci_identity_policy" "devops" {
  count = var.create_iam_resources ? 1 : 0

  compartment_id = var.compartment_ocid
  name           = var.devops_policy_name
  description    = "Allow OCI DevOps to build from GitHub and deliver the Function image to OCIR"

  statements = [
    "Allow dynamic-group ${oci_identity_dynamic_group.devops[0].name} to manage devops-family in compartment id ${var.compartment_ocid}",
    "Allow dynamic-group ${oci_identity_dynamic_group.devops[0].name} to manage repos in compartment id ${var.compartment_ocid}",
    "Allow dynamic-group ${oci_identity_dynamic_group.devops[0].name} to read secret-family in compartment id ${var.compartment_ocid}",
    "Allow dynamic-group ${oci_identity_dynamic_group.devops[0].name} to use ons-topics in compartment id ${var.compartment_ocid}"
  ]
}

resource "oci_devops_build_pipeline" "this" {
  project_id    = oci_devops_project.this.id
  display_name  = var.build_pipeline_name
  description   = "Build and deliver ${local.function_image}"
  freeform_tags = var.freeform_tags

  build_pipeline_parameters {
    items {
      name          = "BUILD_RUN_VERSION"
      default_value = var.build_run_version
      description   = "Change this value to force a new image build run from Resource Manager."
    }
  }

  depends_on = [
    oci_identity_policy.devops
  ]
}

resource "oci_devops_deploy_artifact" "function_image" {
  project_id                 = oci_devops_project.this.id
  display_name               = "Cribl OCI Log Partitioner Function Image"
  description                = "OCIR image target for the Cribl OCI log partitioner Function"
  deploy_artifact_type       = "DOCKER_IMAGE"
  argument_substitution_mode = "NONE"
  freeform_tags              = var.freeform_tags

  deploy_artifact_source {
    deploy_artifact_source_type = "OCIR"
    image_uri                   = local.function_image
  }
}

resource "oci_devops_build_pipeline_stage" "build" {
  build_pipeline_id         = oci_devops_build_pipeline.this.id
  build_pipeline_stage_type = "BUILD"
  display_name              = var.build_stage_name
  description               = "Build the OCI Functions container image from GitHub"

  build_spec_file                    = var.build_spec_file
  image                              = var.build_stage_image
  primary_build_source               = var.build_source_name
  stage_execution_timeout_in_seconds = var.build_stage_timeout_in_seconds
  freeform_tags                      = var.freeform_tags

  build_pipeline_stage_predecessor_collection {
    items {
      id = oci_devops_build_pipeline.this.id
    }
  }

  build_source_collection {
    items {
      connection_type = "GITHUB"
      branch          = var.repository_branch
      connection_id   = local.github_connection_id
      name            = var.build_source_name
      repository_url  = var.repository_url
    }
  }

  lifecycle {
    precondition {
      condition     = var.create_github_connection || trimspace(var.existing_github_connection_id) != ""
      error_message = "Provide existing_github_connection_id, or set create_github_connection=true and provide github_access_token_secret_id."
    }
  }
}

resource "oci_devops_build_pipeline_stage" "deliver" {
  build_pipeline_id         = oci_devops_build_pipeline.this.id
  build_pipeline_stage_type = "DELIVER_ARTIFACT"
  display_name              = var.deliver_stage_name
  description               = "Deliver the built Function image to OCIR"
  freeform_tags             = var.freeform_tags

  build_pipeline_stage_predecessor_collection {
    items {
      id = oci_devops_build_pipeline_stage.build.id
    }
  }

  deliver_artifact_collection {
    items {
      artifact_id   = oci_devops_deploy_artifact.function_image.id
      artifact_name = "cribl-oci-log-partitioner-image"
    }
  }
}

resource "oci_devops_build_run" "this" {
  count = var.run_build ? 1 : 0

  build_pipeline_id = oci_devops_build_pipeline.this.id
  display_name      = "Build Cribl OCI Log Partitioner ${var.image_tag}"

  build_run_arguments {
    items {
      name  = "BUILD_RUN_VERSION"
      value = var.build_run_version
    }
  }

  depends_on = [
    oci_artifacts_container_repository.function,
    oci_devops_build_pipeline_stage.deliver
  ]
}
