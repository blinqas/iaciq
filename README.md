# Work In Progress
# iaciq: Smart Orchestration for IaC Deployments

iaciq brings a new level of intelligence and efficiency to Infrastructure as Code (IaC) deployments on GitHub. By analyzing dependencies and changes within your IaC repositories, iaciq orchestrates the deployment process to ensure optimal execution of your infrastructure updates.

## Features

- **Intelligent Dependency Resolution**: Determines the order of operations based on interdependencies meta data files within your IaC module folders.
- **Parallel Execution**: Processes independent modules concurrently to minimize deployment times.
- **Dynamic Workflow Selection**: Executes the appropriate actions based on the specific needs of each IaC module, ensuring optimal handling of various IaC tools.
- **Configurable Through `iaciq.yml`**: Allows for fine-grained control over workflow behavior directly within your IaC repositories.
- **Seamless Cloud Authentication**: Integrates with cloud authentication mechanisms to securely manage infrastructure resources.

## Workflow Overview

iaciq consists of a series of interconnected workflows that dynamically orchestrate the deployment process:

1. **iaciq-1-starter**: Initiates the process by analyzing the repository against a specified git reference to determine changes and dependencies. Each folder with changes, or folders that depend on folders with changes are identified to be processed. The only way to ensure that a complex infrastructure solution is consistent with the code changes is to process all folders with direct and implicit dependencies to any folder with updats. Folders who is identified to be processed based on the discoverd changes are grouped into concurrency groups. Concurrency is based on dependency configuration in the iaciq.yml file. The workflow is generic for all IaC technologies.
2. **iaciq-2-folder**: Processes each folder identified by iaciq-1-starter. This workflow ensures that each folder processing is isolated and can be executed in parallel with other folders in the same concurrency group. The workflow is generic for all IaC technologies.
3. **iaciq-3-tag**: The only purpose of this workflow is to identify IaC technologies and call the appropriate workflow for the technology. The workflow is generic and can be extended to support more IaC technologies.
4. **iaciq-4-tf-azure**: There will be one level 4 workflow for each IaC technology supported. Currently we only have level 4 workflow for Terraform Azure but more tehcnoogies will be supported in the future. We also welcome contributions to add support for more IaC technologies at level 4.

### : iaciq-4-tf-azure
The steps in the terraform azure workflow are as follows:  
- **PreHook Init**: A prehook to the terraform init command, process script: prehook_init.sh if it exists in the folder.
- **Terraform Init**: Initializes the Terraform working directory.
- **Prehook Validate**: A prehook to the terraform validate command, process script: prehook_validate.sh if it exists in the folder.
- **Terraform Validate**: Validates the configuration files in a directory, referring only to the configuration and not accessing any remote services such as remote state, provider APIs, etc.
- **Prehook Plan**: A prehook to the terraform plan command, process script: prehook_plan.sh if it exists in the folder.
- **Terraform Plan**: Generates an execution plan for Terraform.
- **PreHook Apply**: A prehook to the terraform apply command, process script: prehook_apply.sh if it exists in the folder.
- **Terraform Apply**: Applies the changes required to reach the desired state of the configuration.
- **Apply PostHook**: A posthook to the terraform apply command, process script: posthook_apply.sh if it exists in the folder.
- **Terraform Destroy**: Destroys the Terraform-managed infrastructure.


### Getting Started with iaciq

To integrate iaciq into your IaC projects, follow these steps:

1. **Configure `iaciq.yml` in your iac folders**: Define dependencies and any specific instructions or hooks related to the deployment of each module.

2. **Call iaciq Workflows from Your Repository**: You can call the provided workflows directly from the `blinqas/iaciq` repository, or you can copy the workflows into your repository and customize them to fit your specific needs.

3. **Trigger iaciq Workflows**: Workflows can be triggered via pull requests, push or manually through the GitHub UI using the `workflow_dispatch` event, specifying the git reference to compare against for detecting changes.

### Example Configuration

Here is an example `iaciq.yml` for a module that depends on another module:

```yaml
depends_on:
  - terraform/azurerm-hub-extension-vnet
workflow_tag: iaciq-4-tf-azure
```

This configuration ensures that iaciq will process `azurerm-hub-extension-vnet` before the current module.

### Using iaciq Workflows

Here's how to set up the iaciq-1-starter workflow in your repository's `.github/workflows` directory:

```yaml
name: iaciq

on:
  pull_request:
    branches:
      - main
    types:
      - opened
      - synchronize

  push:
    branches:
      - main

  workflow_dispatch:
    inputs:
      git_ref:
        description: 'Git Ref to compare for changes'
        default: 'main'
      environment_plan:
        type: string
        description: 'The environment to run the plan in. Environment holds the ARM and TF variables for the plan and init actions'
        required: false
      environment_apply:
        type: string
        description: 'The environment to run the apply in. Environment holds the ARM and TF variables for the apply actions'
        required: false
      runs_on:
        type: string
        description: 'The runner to run the workflow on'
        required: false
        default: 'rover'
      groups:
        type: string
        description: 'The Concurrency Groups'
        required: false
      iaciq:
        type: string
        description: 'The full output from iaciq.json'
        required: false

env:
  ARM_CLIENT_ID: "${{ vars.AZURE_CLIENT_ID }}"
  ARM_SUBSCRIPTION_ID: "${{ vars.AZURE_SUBSCRIPTION_ID }}"
  ARM_TENANT_ID: "${{ vars.AZURE_TENANT_ID }}"
  ARM_USE_AZUREAD: true
  ARM_USE_OIDC: true

permissions:
  actions: write
  contents: read
  pull-requests: write
  security-events: read
  id-token: write

jobs:
  iaciq:
    name: iaciq-1-starter
    if: inputs.iaciq == ''
    uses: blinqas/iaciq/.github/workflows/iaciq-1-starter.yml@main
    with:
      runs_on: ubuntu-latest

  iaciqGroups:
    name: "iaciq ${{ matrix.group }}"
    if: inputs.iaciq != '' && inputs.groups != ''
    strategy:
      matrix:
        group: ${{ fromJson(inputs.groups) }}
      max-parallel: 1
    uses: blinqas/iaciq/.github/workflows/iaciq-2-folder.yml@main
    with:      
      environment_plan: ${{ inputs.environment_plan }}
      environment_apply: ${{ inputs.environment_apply }}
      runs_on: ${{ inputs.runs_on }}
      group: ${{ matrix.group }}
      iaciq: ${{ inputs.iaciq }}

```

You can source this workflows directly from the `blinqas/iaciq` repository, or you can copy the workflows into your repository and customize them to fit your specific needs. The code is licensed under the MIT license, so you are free to modify and distribute it as needed.

## Contributing to iaciq

We welcome contributions to iaciq, whether it's adding support for new IaC tools, enhancing dependency resolution, or improving documentation. Your contributions help make iaciq a powerful tool for the community.
```
