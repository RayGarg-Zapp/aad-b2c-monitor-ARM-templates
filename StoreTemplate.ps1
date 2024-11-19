# Function to get valid user input for project name and location
function Get-ValidInput {
    param (
        [string]$prompt,
        [string]$defaultValue
    )

    while ($true) {
        $inputValue = Read-Host "$prompt (default: '$defaultValue')"
        if ([string]::IsNullOrWhiteSpace($inputValue)) {
            $inputValue = $defaultValue
        }

        if ($inputValue -ne "") {
            return $inputValue
        }
        else {
            Write-Host "Invalid input. Please enter a valid value." -ForegroundColor Red
        }
    }
}

# Get project-specific variables from the user with proper validation
$projectName = Get-ValidInput -prompt "Enter a relevant project name" -defaultValue "StoreArmTemplatesAADB2C"
$location = Get-ValidInput -prompt "Enter the location for the resources" -defaultValue "eastus"

$storageAccountName = $projectName + "store"
$containerName = $projectName + "templates"  # Container name relevant to the project

# URLs to download templates (update these URLs if needed)
$mainTemplateURL = "https://raw.githubusercontent.com/RayGarg-Zapp/aad-b2c-monitor-ARM-templates/refs/heads/main/Main_ARM_Template/Main_ARM_Template.json"
$linkedTemplateAutomationAccountURL = "https://raw.githubusercontent.com/RayGarg-Zapp/aad-b2c-monitor-ARM-templates/refs/heads/main/Linked_ARM_templates/linkedAutomationAccount.json"
$linkedTemplateLogAnalyticsURL = "https://raw.githubusercontent.com/RayGarg-Zapp/aad-b2c-monitor-ARM-templates/refs/heads/main/Linked_ARM_templates/linkedLogAnalyticsWorkspace.json"
$linkedTemplateLogicAppURL = "https://raw.githubusercontent.com/RayGarg-Zapp/aad-b2c-monitor-ARM-templates/refs/heads/main/Linked_ARM_templates/linkedLogicApp.json"
$linkedTemplateStorageAccountURL = "https://raw.githubusercontent.com/RayGarg-Zapp/aad-b2c-monitor-ARM-templates/refs/heads/main/Linked_ARM_templates/linkedStorageAccount.json"
$linkedTemplateSQLDatabaseURL = "https://raw.githubusercontent.com/RayGarg-Zapp/aad-b2c-monitor-ARM-templates/refs/heads/main/Linked_ARM_templates/linkedSQLDatabase.json"

$mainFileName = "Main_ARM_Template.json"
$linkedFileAutomationAccount = "linkedAutomationAccount.json"
$linkedFileLogAnalytics = "linkedLogAnalyticsWorkspace.json"
$linkedFileLogicApp = "linkedLogicApp.json"
$linkedFileStorageAccount = "linkedStorageAccount.json"
$linkedFileSQLDatabase = "linkedSQLDatabase.json"

# Download templates
Invoke-WebRequest -Uri $mainTemplateURL -OutFile "$home/$mainFileName"
Invoke-WebRequest -Uri $linkedTemplateAutomationAccountURL -OutFile "$home/$linkedFileAutomationAccount"
Invoke-WebRequest -Uri $linkedTemplateLogAnalyticsURL -OutFile "$home/$linkedFileLogAnalytics"
Invoke-WebRequest -Uri $linkedTemplateLogicAppURL -OutFile "$home/$linkedFileLogicApp"
Invoke-WebRequest -Uri $linkedTemplateStorageAccountURL -OutFile "$home/$linkedFileStorageAccount"
Invoke-WebRequest -Uri $linkedTemplateSQLDatabaseURL -OutFile "$home/$linkedFileSQLDatabase"

# Ask user if they want to use an existing Resource Group or create a new one
$resourceGroupChoice = Read-Host "Would you like to use an existing Resource Group (type 'existing') or create a new one (type 'new')?"

if ($resourceGroupChoice -eq "existing") {
    # User wants to use an existing Resource Group
    $resourceGroupName = Read-Host "Enter the name of the existing Resource Group you want to use"
    
    # Check if Resource Group exists
    $resourceGroup = Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
    if ($resourceGroup -eq $null) {
        Write-Error "The resource group '$resourceGroupName' does not exist. Please enter a valid resource group name."
        exit
    }
}
elseif ($resourceGroupChoice -eq "new") {
    # User wants to create a new Resource Group
    $resourceGroupName = Read-Host "Enter the name for the new Resource Group"
    $location = Get-ValidInput -prompt "Enter the location for the new Resource Group" -defaultValue $location

    # Create a new resource group
    $resourceGroup = New-AzResourceGroup -Name $resourceGroupName -Location $location
    if ($resourceGroup -eq $null) {
        Write-Error "Failed to create the resource group. Please check your subscription and permissions."
        exit
    }
}
else {
    Write-Error "Invalid choice. Please run the script again and type 'existing' or 'new'."
    exit
}

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
Set-AzStorageBlobContent -Container $containerName -File "$home/$linkedFileSQLDatabase" -Blob $linkedFileSQLDatabase -Context $context

Write-Host "Templates uploaded successfully. Press [ENTER] to continue ..."

# Save configuration to JSON file for use in Script 2
$configPath = "$home/armDeploymentConfig.json"
$config = @{
    projectName = $projectName
    location = $location
    storageAccountName = $storageAccountName
    containerName = $containerName
    resourceGroupName = $resourceGroupName
}

# Convert to JSON and save
$config | ConvertTo-Json | Set-Content -Path $configPath

Write-Host "Configuration saved to $configPath."
