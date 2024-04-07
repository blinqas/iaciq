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