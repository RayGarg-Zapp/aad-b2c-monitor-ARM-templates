# Prompt user for project name (must be <= 11 characters)
$projectName = Read-Host -Prompt "Enter the project name (<= 11 characters):"   # Enter project name (e.g., "armtest")

# Define key names for Azure resources
$resourceGroupName = "TestRGaadB2CARM"

# Prompt user for region (location) to use for the deployment
$location = Read-Host -Prompt "Enter a valid region for deployment (e.g., East US, West US, Central US):"

# Storage account and container details
$storageAccountName = "armmmstore"   # Hardcoded based on your updated information
$containerName = "armmmtemplates"    # Hardcoded based on your updated information

# Prompt for a unique web app name
$webAppName = Read-Host -Prompt "Enter a unique web app name (e.g., armtestWebApp123)"

# Prompt for SQL Server details
$sqlServerName = Read-Host -Prompt "Enter a unique SQL Server name (e.g., armmSQLServer)"
$sqlAdminUsername = Read-Host -Prompt "Enter the SQL Admin Username"
$sqlAdminPassword = Read-Host -Prompt "Enter the SQL Admin Password (this is secure)" -AsSecureString
$databaseName = Read-Host -Prompt "Enter the name of the SQL Database (e.g., armmDB)"

# Convert SecureString to plain text (for deployment)
$plainTextSqlPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sqlAdminPassword)
)

# Retrieve the storage account key and create a storage context
$key = (Get-AzStorageAccountKey -ResourceGroupName $resourceGroupName -Name $storageAccountName).Value[0]
$context = New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $key

# Generate SAS token for the container with 12-hour validity
$sasToken = New-AzStorageContainerSASToken -Context $context -Container $containerName -Permission r -ExpiryTime (Get-Date).AddHours(12.0)

# Construct the main template URI correctly
$blobEndPoint = $context.BlobEndPoint.TrimEnd('/')
$mainTemplateUri = "$blobEndPoint/$containerName/Main_ARM_Template.json?$sasToken"

# Output the Main Template URI for verification if needed
Write-Host "Main Template URI with SAS Token: $mainTemplateUri"

# Execute the deployment with linked templates
try {
    $deploymentParams = @{
        "projectName"      = $projectName;
        "location"         = $location;
        "webAppName"       = $webAppName;
        "sqlServerName"    = $sqlServerName;
        "sqlAdminUsername" = $sqlAdminUsername;
        "sqlAdminPassword" = $plainTextSqlPassword;
        "databaseName"     = $databaseName
    }

    # Deploy to the resource group using the generated SAS token URI
    New-AzResourceGroupDeployment -Name "DeployLinkedTemplate" `
        -ResourceGroupName $resourceGroupName `
        -Location $location `
        -TemplateUri $mainTemplateUri `
        -TemplateParameterObject $deploymentParams `
        -Verbose
}
catch {
    Write-Error "Deployment failed with the following error: $_"
}
