# Prompt user for project name (must be <= 11 characters)
$projectName = Read-Host -Prompt "Enter the project name (<= 11 characters):"   # Enter project name (e.g., "armtest")

# Define key names for Azure resources
$resourceGroupName = "TestRGaadB2CARM"

# Prompt user for region (location) to use for the deployment
$location = Read-Host -Prompt "Enter a valid region for deployment (e.g., East US, West US, Central US):"

# Storage account and container details
$storageAccountName = "activeeaadb2carmstore"
$containerName = "activeeaadb2carmtemplates"

# Prompt for a unique web app name
$webAppName = Read-Host -Prompt "Enter a unique web app name (e.g., armtestWebApp123)"

# Retrieve the storage account key and create a storage context
$key = (Get-AzStorageAccountKey -ResourceGroupName $resourceGroupName -Name $storageAccountName).Value[0]
$context = New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $key

# Generate SAS token for the container with 2-hour validity
$sasToken = New-AzStorageContainerSASToken -Context $context -Container $containerName -Permission r -ExpiryTime (Get-Date).AddHours(2.0)

# Construct the main template URI correctly
$blobEndPoint = $context.BlobEndPoint.TrimEnd('/')  # Remove any trailing slash to prevent double slashes
$mainTemplateUri = "$blobEndPoint/$containerName/Main_ARM_Template.json?$sasToken"

# Output the Main Template URI for verification if needed
Write-Host "Main Template URI with SAS Token: $mainTemplateUri"
Write-Host "Press [ENTER] after verifying the Main Template URI with SAS if it works in the browser:"
Read-Host

# Execute the deployment with linked templates
try {
    New-AzResourceGroupDeployment -Name "DeployLinkedTemplate" `
        -ResourceGroupName $resourceGroupName `
        -Location $location `
        -TemplateUri $mainTemplateUri `
        -TemplateParameterObject @{
            "projectName" = $projectName;
            "location" = $location;
            "webAppName" = $webAppName;
            "existingAppRegistrationClientId" = "04743af9-d949-4adc-a2c5-35c84a732966";
            "existingAppRegistrationTenantId" = "ff8913f4-cf4e-44f8-9c51-b0c24fce09bc";
            "useExistingLogAnalyticsWorkspace" = $false;
            "existingLogAnalyticsWorkspaceId" = ""
        } `
        -Verbose
}
catch {
    Write-Error "Deployment failed with the following error: $_"
}
