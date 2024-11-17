$projectName = "activeeaadb2carm"  # A relevant project name
$location = "eastus"
$resourceGroupName = "TestRGaadB2CARM"
$storageAccountName = $projectName + "store"
$containerName = $projectName + "templates"  # Container name relevant to the project

# URLs to download templates
$mainTemplateURL = "https://raw.githubusercontent.com/RayGarg-Zapp/aad-b2c-monitor-ARM-templates/refs/heads/main/Main_ARM_Template/Main_ARM_Template.json"
$linkedTemplateAutomationAccountURL = "https://raw.githubusercontent.com/RayGarg-Zapp/aad-b2c-monitor-ARM-templates/refs/heads/main/Linked_ARM_templates/linkedAutomationAccount.json"
$linkedTemplateLogAnalyticsURL = "https://raw.githubusercontent.com/RayGarg-Zapp/aad-b2c-monitor-ARM-templates/refs/heads/main/Linked_ARM_templates/linkedLogAnalyticsWorkspace.json"
$linkedTemplateLogicAppURL = "https://raw.githubusercontent.com/RayGarg-Zapp/aad-b2c-monitor-ARM-templates/refs/heads/main/Linked_ARM_templates/linkedLogicApp.json"
$linkedTemplateStorageAccountURL = "https://raw.githubusercontent.com/RayGarg-Zapp/aad-b2c-monitor-ARM-templates/refs/heads/main/Linked_ARM_templates/linkedStorageAccount.json"

$mainFileName = "Main_ARM_Template.json"
$linkedFileAutomationAccount = "linkedAutomationAccount.json"
$linkedFileLogAnalytics = "linkedLogAnalyticsWorkspace.json"
$linkedFileLogicApp = "linkedLogicApp.json"
$linkedFileStorageAccount = "linkedStorageAccount.json"

# Download templates
Invoke-WebRequest -Uri $mainTemplateURL -OutFile "$home/$mainFileName"
Invoke-WebRequest -Uri $linkedTemplateAutomationAccountURL -OutFile "$home/$linkedFileAutomationAccount"
Invoke-WebRequest -Uri $linkedTemplateLogAnalyticsURL -OutFile "$home/$linkedFileLogAnalytics"
Invoke-WebRequest -Uri $linkedTemplateLogicAppURL -OutFile "$home/$linkedFileLogicApp"
Invoke-WebRequest -Uri $linkedTemplateStorageAccountURL -OutFile "$home/$linkedFileStorageAccount"

# Use existing resource group for testing
Write-Output "Using existing resource group: $resourceGroupName"

# Create a new storage account with a unique name
$storageAccount = New-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName -Location $location -SkuName "Standard_LRS"

# Validate storage account creation
if ($storageAccount -eq $null) {
    Write-Error "Failed to create a storage account. Please check your subscription and resource limits."
    exit
}

# Get storage account context
$context = $storageAccount.Context

# Create a container in the storage account with restricted permission (no public access)
New-AzStorageContainer -Name $containerName -Context $context -Permission Off

# Validate container creation
$container = Get-AzStorageContainer -Context $context -Name $containerName
if ($container -eq $null) {
    Write-Error "Failed to create the container. Please check the permissions and retry."
    exit
}

# Upload the templates
Set-AzStorageBlobContent -Container $containerName -File "$home/$mainFileName" -Blob $mainFileName -Context $context
Set-AzStorageBlobContent -Container $containerName -File "$home/$linkedFileAutomationAccount" -Blob $linkedFileAutomationAccount -Context $context
Set-AzStorageBlobContent -Container $containerName -File "$home/$linkedFileLogAnalytics" -Blob $linkedFileLogAnalytics -Context $context
Set-AzStorageBlobContent -Container $containerName -File "$home/$linkedFileLogicApp" -Blob $linkedFileLogicApp -Context $context
Set-AzStorageBlobContent -Container $containerName -File "$home/$linkedFileStorageAccount" -Blob $linkedFileStorageAccount -Context $context

Write-Host "Templates uploaded. Press [ENTER] to continue ..."
