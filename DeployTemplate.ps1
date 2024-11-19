# Load configuration from the first script to maintain consistency
$configFilePath = "$home/deploymentConfig.json"   # Use Unix-based path format for compatibility

if (-Not (Test-Path -Path $configFilePath)) {
    Write-Error "Configuration file not found at path $configFilePath. Please make sure the first script has been run to create the storage account and container."
    exit
}

# Read and parse the configuration file
$config = Get-Content -Path $configFilePath | ConvertFrom-Json

# Extract values from the config file
$projectName = $config.projectName
$resourceGroupName = $config.resourceGroupName
$location = $config.location
$storageAccountName = $config.storageAccountName
$containerName = $config.containerName

# Prompt for a unique web app name
$webAppName = Read-Host -Prompt "Enter a unique web app name (e.g., armtestWebApp123)"

# Prompt for SQL Server details
$sqlServerName = Read-Host -Prompt "Enter a unique SQL Server name (e.g., armtestSQLServer)"
$sqlAdminUsername = Read-Host -Prompt "Enter the SQL Admin Username"
$sqlAdminPassword = Read-Host -Prompt "Enter the SQL Admin Password (this is secure)" -AsSecureString
$databaseName = Read-Host -Prompt "Enter the name of the SQL Database (e.g., armtestDB)"

# Convert SecureString to plain text (for deployment)
$plainTextSqlPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sqlAdminPassword)
)

# Retrieve the storage account key and create a storage context
$key = (Get-AzStorageAccountKey -ResourceGroupName $resourceGroupName -Name $storageAccountName).Value[0]
$context = New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $key

# Generate SAS token for the container with 2-hour validity (for container-level access)
$sasToken = New-AzStorageContainerSASToken -Context $context -Container $containerName -Permission r -ExpiryTime (Get-Date).AddHours(2.0)

# Construct the main template URI correctly with SAS Token
$blobEndPoint = $context.BlobEndPoint.TrimEnd('/')
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
            "sqlServerName" = $sqlServerName;
            "sqlAdminUsername" = $sqlAdminUsername;
            "sqlAdminPassword" = $plainTextSqlPassword;
            "databaseName" = $databaseName;
            "sasToken" = "?$sasToken"
        } `
        -Verbose
}
catch {
    Write-Error "Deployment failed with the following error: $_"
}
