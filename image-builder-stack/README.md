# OCI DevOps Image Builder Stack

This Resource Manager stack builds the Cribl OCI log partitioner Function image in a user's own OCI tenancy.

It creates:

```text
OCIR repository
ONS notification topic
OCI DevOps project
Optional OCI DevOps GitHub connection
OCI DevOps build pipeline
Managed Build stage
Deliver Artifacts stage
Optional Build Run
Optional IAM dynamic group and policy
```

The build produces this output:

```text
ocir.<region>.oci.oraclecloud.com/<namespace>/cribl-oci-log-partitioner/function:<image_tag>
```

For example:

```text
ocir.us-ashburn-1.oci.oraclecloud.com/id3kvohtwgjy/cribl-oci-log-partitioner/function:0.0.1
```

## Why This Exists

The main Cribl stack needs `function_image`, but OCI Resource Manager does not build Docker images from a `Dockerfile`.

This stack keeps the workflow OCI-native by using OCI DevOps:

```text
GitHub source
  -> OCI DevOps Managed Build
  -> OCI DevOps Deliver Artifacts
  -> OCI Container Registry
```

Then pass the resulting `function_image` output to the main Resource Manager stack.

## Prerequisite: GitHub Source Connection

OCI DevOps requires a GitHub connection for GitHub build sources, even when the GitHub repository is public.

Use either:

```text
Option A: existing_github_connection_id
Option B: create_github_connection = true with github_access_token_secret_id
```

For Option B:

1. Create a GitHub personal access token with repository read access.
2. Store the token in OCI Vault as a secret.
3. Pass the secret OCID as `github_access_token_secret_id`.

Do not paste the GitHub token directly into Resource Manager variables.

## Resource Manager Steps

1. Open OCI Console.
2. Go to **Developer Services**.
3. Go to **Resource Manager**.
4. Select **Stacks**.
5. Select **Create stack**.
6. Choose Git source.
7. Use this repository:

   ```text
   https://github.com/vishakchittuvalapil/oci-cribl-log-partitioner
   ```

8. Use branch:

   ```text
   main
   ```

9. Use working directory:

   ```text
   image-builder-stack
   ```

10. Use Terraform version `1.5.x`.
11. Enter the variables.
12. Run **Plan**.
13. Run **Apply**.
14. Copy the `function_image` output.
15. Paste that value into the main Cribl stack's `function_image` variable.

## Important Variables

```text
compartment_ocid
region
repository_url
repository_branch
existing_github_connection_id
ocir_repository_name
image_tag
```

Defaults:

```text
repository_url = https://github.com/vishakchittuvalapil/oci-cribl-log-partitioner.git
repository_branch = main
ocir_repository_name = cribl-oci-log-partitioner/function
image_tag = 0.0.1
```

## Rebuilding

To force another build from Resource Manager, change:

```text
build_run_version
```

Example:

```text
build_run_version = 2
```

Then run **Plan** and **Apply** again.

## Outputs

Use this output in the main Cribl stack:

```text
function_image
```

If available, use this output too:

```text
function_image_digest
```

The digest pins the exact image build.

## References

- OCI DevOps build specification: https://docs.oracle.com/en-us/iaas/Content/devops/using/build_specs.htm
- OCI DevOps Managed Build stage: https://docs.oracle.com/iaas/Content/devops/using/add_buildstage.htm
- OCI DevOps Deliver Artifacts stage: https://docs.oracle.com/en-us/iaas/Content/devops/using/add_deliverartifact.htm
- OCI DevOps IAM policies: https://docs.oracle.com/en-us/iaas/Content/devops/using/devops_iampolicies.htm
