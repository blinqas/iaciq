function log_info() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $1"
}

function error() {
    >&2 echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] Line $1: $2"
    exit $3
}

function terraform_expand_tfvars_legacy() {
  # Directory where your .tfvars files are located
  local TFVARS_DIR="$1"

  # Find all .tfvars files in the specified directory and prepare them as arguments
  find "$TFVARS_DIR" -name '*.tfvars' -exec echo "-var-file=\"{}\"" \; | xargs
}

function expand_tfvars_folder {
    local PARAMS=""

    # Check the folder path exist
    if [ ! -d "${1}" ]; then
        error "${LINENO}" "Folder ${1} does not exist." 1
    fi

    log_info "Expanding variable files: ${1}/*.tfvars"
    for filename in "${1}"/*.tfvars; do
        if [[ "${filename}" != "${1}/*.tfvars" ]]; then
            PARAMS+="-var-file='${filename}' "
        fi
    done

    log_info "Expanding variable files: ${1}/*.tfvars.json"
    for filename in "${1}"/*.tfvars.json; do
        if [[ "${filename}" != "${1}/*.tfvars.json" ]]; then
            PARAMS+="-var-file='${filename}' "
        fi
    done

    log_info "Expanding variable files: ${1}/*.tfvars.yml and ${1}/*.tfvars.yaml"
    for filename in "${1}"/*.tfvars.{yml,yaml}; do
        # Since brace expansion does not match if there are no files, you need pattern matching here
        if [[ -f "${filename}" ]]; then
            PARAMS+="-var-file='${filename}' "
        fi
    done

    # Check there are some tfvars files
    if [[ -z "${PARAMS}" ]]; then
        error "${LINENO}" "Folder ${1} does not have any tfvars files." 1
    fi

    echo "$PARAMS"
}


function terraform_plan_git_pull_request_comment() {
  # Configure Git user
  git config user.name "GitHub Action"
  git config user.email "action@github.com"

  # Get the current branch name
  branch_name=$(git rev-parse --abbrev-ref HEAD)

  # Check for an existing open PR for this branch
  existing_pr=$(gh pr list --base main -H "$branch_name" -s "open" --json number -q '.[0].number')

  if [ -z "$existing_pr" ]; then
    # Create a new pull request and extract the PR number from the URL
    pr_url=$(gh pr create --base main --head "$branch_name" --title "Review Plan Output" --body "$pr_body")
    pr_id=${pr_url##*/}
  else
    # Comment on the existing PR and use its number
    gh pr comment "$existing_pr" --body "$pr_body"
    pr_id="$existing_pr"
  fi

  # Check if PR ID was obtained successfully
  if [ -z "$pr_id" ]; then
    echo "Failed to create or update the pull request."
    exit 1
  fi

  echo "PR ID: $pr_id"
  echo "pr_id=$pr_id" >> $GITHUB_ENV
}

function terraform_configure_environments() {
  # This function configure ARM and Terraform backend values as GitHub Action Outputs.

  # You can either configure the ARM_CLIENT_ID, ARM_SUBSCRIPTION_ID, ARM_TENANT_ID, TF_STORAGE_ACCOUNT, TF_RESOURCE_GROUP, TF_CONTAINER_NAME, TF_KEY, TF_BACKEND_TYPE and TF_VERSION in the repository variables, repository environment variables or in the ActionsIQ.yaml file. If you define the variables in the ActionsIQ.yaml file, the script will use those values. ActionsIQ.yaml override the repository variables.

  local tf_action=$1
  local ActionsIQ=$2

  # Get values from the ActionsIQ variable (variable passed as input from the W1-Groups.yml file)
  CLIENT_ID=$(echo "$ActionsIQ" | jq -r --arg ACTION "$tf_action" '.data.github_environments[$ACTION].ARM_CLIENT_ID')
  SUBSCRIPTION_ID=$(echo "$ActionsIQ" | jq -r --arg ACTION "$tf_action" '.data.github_environments[$ACTION].ARM_SUBSCRIPTION_ID')
  TENANT_ID=$(echo "$ActionsIQ" | jq -r --arg ACTION "$tf_action" '.data.github_environments[$ACTION].ARM_TENANT_ID')
  STORAGE_ACCOUNT=$(echo "$ActionsIQ" | jq -r '.data.terraform.backend.TF_STORAGE_ACCOUNT')
  RESOURCE_GROUP=$(echo "$ActionsIQ" | jq -r '.data.terraform.backend.TF_RESOURCE_GROUP')
  CONTAINER_NAME=$(echo "$ActionsIQ" | jq -r '.data.terraform.backend.TF_CONTAINER_NAME')
  TF_STATE_FILE=$(echo "$ActionsIQ" | jq -r '.data.terraform.backend.TF_KEY')
  BACKEND_TYPE=$(echo "$ActionsIQ" | jq -r '.data.terraform.backend.TF_BACKEND_TYPE')
  FOLDER_TF_VERSION=$(echo "$ActionsIQ" | jq -r '.data.terraform.backend.TF_VERSION')

  if [ "$CLIENT_ID" != "null" ]; then
    ARM_CLIENT_ID=$CLIENT_ID
  fi

  if [ "$SUBSCRIPTION_ID" != "null" ]; then
    ARM_SUBSCRIPTION_ID=$SUBSCRIPTION_ID
  fi

  if [ "$TENANT_ID" != "null" ]; then
    ARM_TENANT_ID=$TENANT_ID  
  fi

  if [ "$STORAGE_ACCOUNT" != "null" ]; then
    TF_STORAGE_ACCOUNT=$STORAGE_ACCOUNT
  fi

  if [ "$RESOURCE_GROUP" != "null" ]; then
    TF_RESOURCE_GROUP=$RESOURCE_GROUP  
  fi

  if [ "$CONTAINER_NAME" != "null" ]; then
    TF_CONTAINER_NAME=$CONTAINER_NAME
  fi

  if [ "$TF_STATE_FILE" != "null" ]; then
    TF_KEY=$TF_STATE_FILE
  fi

  if [ "$BACKEND_TYPE" != "null" ]; then
    TF_BACKEND_TYPE=$BACKEND_TYPE
  fi

  if [ "$FOLDER_TF_VERSION" != "null" ]; then
    TF_VERSION=$FOLDER_TF_VERSION
  fi


  # Provide terraform backend configuration as GitHub Action Outputs
  echo "ARM_CLIENT_ID=$ARM_CLIENT_ID" >> "$GITHUB_OUTPUT"
  echo "ARM_SUBSCRIPTION_ID=$ARM_SUBSCRIPTION_ID" >> "$GITHUB_OUTPUT"
  echo "ARM_TENANT_ID=$ARM_TENANT_ID" >> "$GITHUB_OUTPUT"
  echo "TF_STORAGE_ACCOUNT=$TF_STORAGE_ACCOUNT" >> "$GITHUB_OUTPUT"
  echo "TF_RESOURCE_GROUP=$TF_RESOURCE_GROUP" >> "$GITHUB_OUTPUT"
  echo "TF_CONTAINER_NAME=$TF_CONTAINER_NAME" >> "$GITHUB_OUTPUT"
  echo "TF_KEY=$TF_KEY" >> "$GITHUB_OUTPUT"
  echo "TF_BACKEND_TYPE=$TF_BACKEND_TYPE" >> "$GITHUB_OUTPUT"
  echo "TF_VERSION=$TF_VERSION" >> "$GITHUB_OUTPUT"
}

function terraform_plan_output_title() {

    local output_file=$1

    # Initialize variable
    plan_output_step_title=""

    # Continue execution on error
    set +e
    # Check various conditions and update variable accordingly
    if grep -E "^Plan: [0-9]+ to add, [0-9]+ to change, [0-9]+ to destroy\.$" $output_file; then
    plan_output_step_title=$(grep -E "^Plan: [0-9]+ to add, [0-9]+ to change, [0-9]+ to destroy\.$" $output_file)
    elif grep -oi "No changes. No objects need to be destroyed." $output_file; then
    plan_output_step_title=$(grep -oi "No changes. No objects need to be destroyed." $output_file)
    elif grep -oi "Changes to Outputs:" $output_file; then
    plan_output_step_title=$(grep -oi "Changes to Outputs:" $output_file)
    elif grep -oi "No changes. Your infrastructure matches the configuration." $output_file; then
    plan_output_step_title=$(grep -oi "No changes. Your infrastructure matches the configuration." $output_file)
    fi
    # Restore error handling behavior
    set -e

    # Set GitHub Actions environment variable if a condition was met
    if [ -n "$plan_output_step_title" ]; then
      echo plan_output_step_title="$plan_output_step_title" >> $GITHUB_ENV
      return $plan_output_step_title
    fi
    return null
}

function terraform_print_essential_plan_output() {
    local output_file=$1
    echo "Terraform Plan Essential Outputs:"

    # Define start and end markers in an array of patterns
    declare -a patterns=(
      "Terraform used the selected providers"
      "Changes to Outputs:"
      "No changes. Your infrastructure matches the configuration."
    )

    # Initialize a variable to track if a pattern has been matched
    pattern_found=false

    # Iterate over the patterns array
    for pattern in "${patterns[@]}"; do
        if grep -q "$pattern" "$output_file"; then
            # Print from the matched pattern to "Terraform plan return code:"
            sed -n "/$pattern/,/Terraform plan return code:/p" "$output_file"
            pattern_found=true
            break # Exit the loop after the first match
        fi
    done

    # If no pattern was matched, print the whole file
    if [ "$pattern_found" = false ]; then
        cat "$output_file"
    fi
}

function terraform_evaluate_plan_exit_code() {
    PLAN_EXIT_CODE=$1
    # Exit with the same exit code as the terraform plan if it's not 0 or 2
    echo "PLAN_EXIT_CODE: $PLAN_EXIT_CODE"
    if [[ $PLAN_EXIT_CODE == "0" ]]; then                                                 # If the plan exit code is 0, then no changes were detected
      echo "No changes detected. Skip apply step."
    elif [[ $PLAN_EXIT_CODE == "1" ]]; then
      echo "Error occurred during Terraform plan. Exiting workflow."
    elif [[ $PLAN_EXIT_CODE == "2" ]]; then                                               # If the plan exit code is 2, then changes were detected
      echo "Changes detected. Proceeding with apply step."
    else                                                                                  # If plan exit code is something else, then exit the workflow
      echo "Unexpected exit code from Terraform plan. Exiting workflow."
    fi
}

function terraform_setup_environment() {
  # Configure github environments for terraform init, plan and apply. Default environment names are terraform-init, terraform-plan, terraform-apply. These can be overridden as optional inputs, who can be overridden by iaciq.yml values
  if [[ -z "${{ fromJson(inputs.iaciq).metadata[inputs.folder].environment_init }}" ]]; then
    echo "environment_init=terraform-init" >> "$GITHUB_OUTPUT"
  else
    echo "environment_init=${{ fromJson(inputs.iaciq).metadata[inputs.folder].environment_init }}" >> "$GITHUB_OUTPUT"
  fi
  if [[ -z "${{ fromJson(inputs.iaciq).metadata[inputs.folder].environment_plan }}" ]]; then
    echo "environment_plan=terraform-plan" >> "$GITHUB_OUTPUT"
  else
    echo "environment_plan=${{ fromJson(inputs.iaciq).metadata[inputs.folder].environment_plan }}" >> "$GITHUB_OUTPUT"
  fi
  if [[ -z "${{ fromJson(inputs.iaciq).metadata[inputs.folder].environment_apply }}" ]]; then
    echo "environment_apply=terraform-apply" >> "$GITHUB_OUTPUT"
  else
    echo "environment_apply=${{ fromJson(inputs.iaciq).metadata[inputs.folder].environment_apply }}" >> "$GITHUB_OUTPUT"
  fi

  # Resolve state file name (TF_KEY), defaults to folder name.tfstate
  if [[ -n "${{ fromJson(inputs.iaciq).metadata[inputs.folder].TF_KEY }}" ]]; then
    echo "TF_KEY=${{ fromJson(inputs.iaciq).metadata[inputs.folder].TF_KEY }}" >> "$GITHUB_OUTPUT"
  else
    basedir=$(basename ${{ inputs.folder }})
    echo "TF_KEY=${basedir}.tfstate" >> "$GITHUB_OUTPUT"
  fi

  # Resolve Terraform version (TF_VERSION), defaults to latest
  if [[ -n "${{ fromJson(inputs.iaciq).metadata[inputs.folder].TF_VERSION }}" ]]; then
    echo "TF_VERSION=${{ fromJson(inputs.iaciq).metadata[inputs.folder].TF_VERSION }}" >> "$GITHUB_OUTPUT"
  elif [[ -n "$TF_VERSION" ]]; then
    echo "TF_VERSION=$TF_VERSION" >> "$GITHUB_OUTPUT"
  else
    # Use curl to get the latest version of Terraform
    TF_VERSION=$(curl -s https://api.github.com/repos/hashicorp/terraform/releases/latest | jq -r '.tag_name')
    echo "TF_VERSION=${TF_VERSION}" >> "$GITHUB_OUTPUT"
  fi

  # Resolve TF_ variables, iaciq.yml values override repository variables
  if [[ -n "${{ fromJson(inputs.iaciq).metadata[inputs.folder].TF_BACKEND_TYPE }}" ]]; then
    echo "TF_BACKEND_TYPE=${{ fromJson(inputs.iaciq).metadata[inputs.folder].TF_BACKEND_TYPE }}" >> "$GITHUB_OUTPUT"
  elif [[ -n "$TF_BACKEND_TYPE" ]]; then
    echo "TF_BACKEND_TYPE=$TF_BACKEND_TYPE" >> "$GITHUB_OUTPUT"
  else
    echo "TF_BACKEND_TYPE=azurerm" >> "$GITHUB_OUTPUT"
  fi

  if [[ -n "${{ fromJson(inputs.iaciq).metadata[inputs.folder].TF_STORAGE_ACCOUNT }}" ]]; then
    echo "TF_STORAGE_ACCOUNT=${{ fromJson(inputs.iaciq).metadata[inputs.folder].TF_STORAGE_ACCOUNT }}" >> "$GITHUB_OUTPUT"
  elif [[ -n "$TF_STORAGE_ACCOUNT" ]]; then
    echo "TF_STORAGE_ACCOUNT=$TF_STORAGE_ACCOUNT" >> "$GITHUB_OUTPUT"
  else
    echo "TF_STORAGE_ACCOUNT=iaciq" >> "$GITHUB_OUTPUT"
  fi

  if [[ -n "${{ fromJson(inputs.iaciq).metadata[inputs.folder].TF_RESOURCE_GROUP }}" ]]; then
    echo "TF_RESOURCE_GROUP=${{ fromJson(inputs.iaciq).metadata[inputs.folder].TF_RESOURCE_GROUP }}" >> "$GITHUB_OUTPUT"
  elif [[ -n "$TF_RESOURCE_GROUP" ]]; then
    echo "TF_RESOURCE_GROUP=$TF_RESOURCE_GROUP" >> "$GITHUB_OUTPUT"
  else
    echo "TF_RESOURCE_GROUP=iaciq" >> "$GITHUB_OUTPUT"
  fi

  if [[ -n "${{ fromJson(inputs.iaciq).metadata[inputs.folder].TF_CONTAINER_NAME }}" ]]; then
    echo "TF_CONTAINER_NAME=${{ fromJson(inputs.iaciq).metadata[inputs.folder].TF_CONTAINER_NAME }}" >> "$GITHUB_OUTPUT"
  elif [[ -n "$TF_CONTAINER_NAME" ]]; then
    echo "TF_CONTAINER_NAME=$TF_CONTAINER_NAME" >> "$GITHUB_OUTPUT"
  else
    echo "TF_CONTAINER_NAME=iaciq" >> "$GITHUB_OUTPUT"
  fi

  # Resolve runs_on variable, iaciq.yml values override repository variables
  if [[ -n "${{ fromJson(inputs.iaciq).metadata[inputs.folder].runs_on }}" ]]; then
    echo "runs_on=${{ fromJson(inputs.iaciq).metadata[inputs.folder].runs_on }}" >> "$GITHUB_OUTPUT"
  elif [[ -n "$runs_on" ]]; then
    echo "runs_on=$runs_on" >> "$GITHUB_OUTPUT"
  else
    echo "runs_on=ubuntu-latest" >> "$GITHUB_OUTPUT"
  fi

  # Resolve terraform_module_path variable, iaciq.yml values override repository variables
  if [[ -n "${{ fromJson(inputs.iaciq).metadata[inputs.folder].terraform_module_path }}" ]]; then
    echo "terraform_module_path=${{ fromJson(inputs.iaciq).metadata[inputs.folder].terraform_module_path }}" >> "$GITHUB_OUTPUT"
  elif [[ -n "$terraform_module_path" ]]; then
    echo "terraform_module_path=$terraform_module_path" >> "$GITHUB_OUTPUT"
  else
    echo "terraform_module_path=${{ inputs.folder }}" >> "$GITHUB_OUTPUT"
  fi
}

function terraform_arm_client_id_init() {
  # ARM_CLIENT_ID_INIT
  if [[ -n "${{ fromJson(inputs.iaciq).metadata[inputs.folder].ARM_CLIENT_ID_INIT }}" ]]; then
    echo "ARM_CLIENT_ID_INIT=${{ fromJson(inputs.iaciq).metadata[inputs.folder].ARM_CLIENT_ID_INIT }}" >> "$GITHUB_OUTPUT"
  elif [[ -n "$ARM_CLIENT_ID_INIT" ]]; then
    echo "ARM_CLIENT_ID_INIT=$ARM_CLIENT_ID_INIT" >> "$GITHUB_OUTPUT"
  elif [[ -n "$ARM_CLIENT_ID" ]]; then
    echo "ARM_CLIENT_ID_INIT=$ARM_CLIENT_ID" >> "$GITHUB_OUTPUT"
  else
    echo "No ARM_CLIENT_ID for Terraform Init found in input, iaciq.yml or github environment"
    exit 1
  fi
}

function terraform_arm_client_id_plan() {
  # ARM_CLIENT_ID_PLAN
  if [[ -n "${{ fromJson(inputs.iaciq).metadata[inputs.folder].ARM_CLIENT_ID_PLAN }}" ]]; then
    echo "ARM_CLIENT_ID_PLAN=${{ fromJson(inputs.iaciq).metadata[inputs.folder].ARM_CLIENT_ID_PLAN }}" >> "$GITHUB_OUTPUT"
  elif [[ -n "$ARM_CLIENT_ID_PLAN" ]]; then
    echo "ARM_CLIENT_ID_PLAN=$ARM_CLIENT_ID_PLAN" >> "$GITHUB_OUTPUT"
  elif [[ -n "$ARM_CLIENT_ID" ]]; then
    echo "ARM_CLIENT_ID_PLAN=$ARM_CLIENT_ID" >> "$GITHUB_OUTPUT"
  else
    echo "No ARM_CLIENT_ID for Terraform Plan found in input, iaciq.yml or github environment"
    exit 1
  fi
}

function terraform_arm_client_id_apply() {
  # ARM_CLIENT_ID_APPLY
  if [[ -n "${{ fromJson(inputs.iaciq).metadata[inputs.folder].ARM_CLIENT_ID_APPLY }}" ]]; then
    echo "ARM_CLIENT_ID_APPLY=${{ fromJson(inputs.iaciq).metadata[inputs.folder].ARM_CLIENT_ID_APPLY }}" | tee -a "$GITHUB_ENV" "$GITHUB_OUTPUT"
  elif [[ -n "$ARM_CLIENT_ID_APPLY" ]]; then
    echo "ARM_CLIENT_ID_APPLY=$ARM_CLIENT_ID_APPLY" | tee -a "$GITHUB_ENV" "$GITHUB_OUTPUT"
  elif [[ -n "$ARM_CLIENT_ID" ]]; then
    echo "ARM_CLIENT_ID_APPLY=$ARM_CLIENT_ID" | tee -a "$GITHUB_ENV" "$GITHUB_OUTPUT"
  else
    echo "No ARM_CLIENT_ID for Terraform Init found in input, iaciq.yml or github environment"
    exit 1
  fi
}