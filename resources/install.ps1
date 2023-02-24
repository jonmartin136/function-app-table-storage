# requires preview extensio: az extension add -n application-insights
[CmdletBinding()]
param ([string] $Subscription = (az account show | ConvertFrom-Json -AsHashTable).id, [string] $ResourceGroup = 'demo', [string] $Location = 'eunn', [string] $EnvId = 'poc01', [string] $App = 'demo', [string] $AccessKeyMode = 'primary', [switch] $PressAnyKey)
begin {

    $locationMap = @{ 'eunn' = @{ 'name' = 'northeurope'; 'displayName' = 'North Europe' }; 'euww' = @{ 'name' = 'westeurope'; 'displayName' = 'West Europe' } }

    $logAnalytics01   = @{ 'name' = ('{0}-{1}-{2}-{3}-{4}' -F 'log',  $App, $Location, $EnvId, '01'); 'location' = $locationMap[$Location].name; 'sku' = 'PerGB2018'; 'quota' = '0.5' }
    $appInsights01    = @{ 'name' = ('{0}-{1}-{2}-{3}-{4}' -F 'appi', $App, $Location, $EnvId, '01'); 'location' = $locationMap[$Location].name }
    $storageAccount01 = @{ 'name' = ('{0}{1}{2}{3}{4}'     -F 'st',   $App, $Location, $EnvId, '01'); 'location' = $locationMap[$Location].name; 'sku' = 'Standard_ZRS';  'accessTier' = 'Hot'; 'kind' = 'StorageV2' }
    $storageAccount02 = @{ 'name' = ('{0}{1}{2}{3}{4}'     -F 'st',   $App, $Location, $EnvId, '02'); 'location' = $locationMap[$Location].name; 'sku' = 'Standard_GZRS'; 'accessTier' = 'Hot'; 'kind' = 'StorageV2' }
    $plan01           = @{ 'name' = ('{0}-{1}-{2}-{3}-{4}' -F 'asp',  $App, $Location, $EnvId, '01'); 'location' = $locationMap[$Location].name; 'sku' = 'Y1'; 'ZoneRedundant' = 'false' }
    $functionApp01    = @{ 'name' = ('{0}-{1}-{2}-{3}-{4}' -F 'func', $App, $Location, $EnvId, '01'); 'location' = $locationMap[$Location].name; 'gitSourceBranch' = 'main'; 'gitSourceUrl' = 'https://github.com/jonmartin136/function-app-table-storage'; 'osType' = 'Windows'; 'runtime' = 'dotnet'; 'runtimeVersion' = '6' }

    $result = $null

    function Invoke-PressAnyKey ($Object, [switch] $PressAnyKey) {
        if ($PressAnyKey) {
            if ($null -ne $Object) { Write-Host ($Object | ConvertTo-Json -Depth 99 | Out-String) }
            Write-Host -NoNewLine 'Press any key to continue...'
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            Write-Host ''
        }
    }

    function Test-ResourceGroup ([string] $Subscription, [string] $Name, [ref] $OutVariable) {
        return ($null -ne ($OutVariable.Value = (az group list --subscription $Subscription | ConvertFrom-Json -AsHashTable) | Where-Object { $_.name -eq $Name }))
    }

    function Test-Resource ([string] $Subscription, [string] $ResourceGroup, [string] $Name, [ref] $OutVariable) {
        return ($null -ne ($OutVariable.Value = (az resource list --subscription $Subscription --resource-group $ResourceGroup | ConvertFrom-Json -AsHashTable) | Where-Object { $_.name -eq $Name }))
    }

    function Test-StorageAccountTable ([string] $Subscription, [string] $ResourceGroup, [string] $AccountName, [string] $AccountKey, [string] $Name, [ref] $OutVariable) {
        return ($null -ne ($OutVariable.Value = (az storage table list --subscription $Subscription --account-name $AccountName --account-key $AccountKey | ConvertFrom-Json -AsHashTable) | Where-Object { $_.name -eq $Name }))
    }

}
process {

    if (-not (Test-ResourceGroup -Subscription $Subscription -Name $ResourceGroup -OutVariable ([ref]$result))) {
        Write-Information -Message ('Creating "{1}" {2} [subscription: {0}] ...' -F $Subscription, $ResourceGroup, 'resource group')
        $result = az group create --subscription $Subscription --name $ResourceGroup --location $locationMap[$Location].Name | ConvertFrom-Json -AsHashTable
    }
    [hashtable] $ResourceGroup = @{ 'name' = $ResourceGroup; 'id' = $result.id }
    Invoke-PressAnyKey -Object $ResourceGroup -PressAnyKey:$PressAnyKey

    if (-not (Test-Resource -Subscription $Subscription -ResourceGroup $ResourceGroup.name -Name $logAnalytics01.name -OutVariable ([ref]$result))) {
        Write-Information -Message ('Creating "{2}" {3} [subscription: {0}, resource group: {1}] ...' -F $Subscription, $ResourceGroup.name, $logAnalytics01.name, 'log analytics resource')
        $result = az monitor log-analytics workspace create --subscription $Subscription --resource-group $ResourceGroup.name --workspace-name $logAnalytics01.name --location $logAnalytics01.location --quota $logAnalytics01.quota --sku $logAnalytics01.sku | ConvertFrom-Json -AsHashTable
    }
    $logAnalytics01.Add('id', $result.id)
    Invoke-PressAnyKey -Object $logAnalytics01 -PressAnyKey:$PressAnyKey

    if (-not (Test-Resource -Subscription $Subscription -ResourceGroup $ResourceGroup.name -Name $appInsights01.name -OutVariable ([ref]$result))) {
        Write-Information -Message ('Creating "{2}" {3} [subscription: {0}, resource group: {1}] ...' -F $Subscription, $ResourceGroup.name, $appInsights01.name, 'app insights resource')
        $result = az monitor app-insights component create --subscription $Subscription --resource-group $ResourceGroup.name --app $appInsights01.name --location $appInsights01.location --application-type 'web' --workspace $logAnalytics01.id | ConvertFrom-Json -AsHashTable
    }
    $appInsights01.Add('id', $result.id)
    $appInsights01.Add('instrumentationKey', (az resource show --id $appInsights01.id --query 'properties.InstrumentationKey' --output tsv))
    Invoke-PressAnyKey -Object $appInsights01 -PressAnyKey:$PressAnyKey

    if (-not (Test-Resource -Subscription $Subscription -ResourceGroup $ResourceGroup.name -Name $storageAccount01.name -OutVariable ([ref]$result))) {
        Write-Information -Message ('Creating "{2}" {3} [subscription: {0}, resource group: {1}] ...' -F $Subscription, $ResourceGroup.name, $storageAccount01.name, 'storage account resource')
        $result = az storage account create --subscription $Subscription --resource-group $ResourceGroup.name --name $storageAccount01.name --location $storageAccount01.location --access-tier $storageAccount01.accessTier --allow-blob-public-access 'false' --https-only 'true' --identity-type 'SystemAssigned' --kind $storageAccount01.kind --min-tls-version 'TLS1_2' --public-network-access 'Enabled' --routing-choice 'MicrosoftRouting' --sku $storageAccount01.sku | ConvertFrom-Json -AsHashTable
    }
    $storageAccount01.Add('id', $result.id)
    $storageAccount01.Add('connectionString', @{ 'primary' = (az storage account show-connection-string --subscription $Subscription --resource-group $ResourceGroup.name --name $storageAccount01.name --key 'primary' --query 'connectionString' --output tsv); 'secondary' = (az storage account show-connection-string --subscription $Subscription --resource-group $ResourceGroup.name --name $storageAccount01.name --key 'secondary' --query 'connectionString' --output tsv) })
    Invoke-PressAnyKey -Object $storageAccount01 -PressAnyKey:$PressAnyKey

    if (-not (Test-Resource -Subscription $Subscription -ResourceGroup $ResourceGroup.name -Name $storageAccount02.name -OutVariable ([ref]$result))) {
        Write-Information -Message ('Creating "{2}" {3} [subscription: {0}, resource group: {1}] ...' -F $Subscription, $ResourceGroup.name, $storageAccount02.name, 'storage account resource')
        $result = az storage account create --subscription $Subscription --resource-group $ResourceGroup.name --name $storageAccount02.name --location $storageAccount02.location --access-tier $storageAccount02.AccessTier --allow-blob-public-access 'false' --https-only 'true' --identity-type 'SystemAssigned' --kind $storageAccount02.Kind --min-tls-version 'TLS1_2' --public-network-access 'Enabled' --routing-choice 'MicrosoftRouting' --sku $storageAccount02.sku | ConvertFrom-Json -AsHashTable
    }
    $storageAccount02.Add('id', $result.id)
    $storageAccount02.Add('connectionString', @{ 'primary' = (az storage account show-connection-string --subscription $Subscription --resource-group $ResourceGroup.name --name $storageAccount02.name --key 'primary' --query 'connectionString' --output tsv); 'secondary' = (az storage account show-connection-string --subscription $Subscription --resource-group $ResourceGroup.name --name $storageAccount02.name --key 'secondary' --query 'connectionString' --output tsv) })
    Invoke-PressAnyKey -Object $storageAccount02 -PressAnyKey:$PressAnyKey

    if (-not (Test-StorageAccountTable -Subscription $Subscription -ResourceGroup $ResourceGroup.name -AccountName $storageAccount02.name -AccountKey ($storageAccount02AccountKey = $storageAccount02.connectionString."$AccessKeyMode" -replace (';BlobEndpoint=.+$', '') -replace ('^.+;AccountKey=', '')) -Name ($storageAccount02TableName = 'outtable') -OutVariable ([ref]$result))) {
        Write-Information -Message ('Creating "{2}/{3}" {4} [subscription: {0}, resource group: {1}] ...' -F $Subscription, $ResourceGroup.name, $storageAccount02.name, $storageAccount02TableName, 'storage account table')
        $result = az storage table create --subscription $Subscription --account-name $storageAccount02.name --name $storageAccount02TableName --account-key $storageAccount02AccountKey --auth-mode 'key'  | ConvertFrom-Json -AsHashTable
    }
    Invoke-PressAnyKey -Object $result -PressAnyKey:$PressAnyKey

    if ($plan01.sku -ne 'Y1') {
        if (-not (Test-Resource -Subscription $Subscription -ResourceGroup $ResourceGroup.name -Name $plan01.name -OutVariable ([ref]$result))) {
            Write-Information -Message ('Creating "{2}" {3} [subscription: {0}, resource group: {1}] ...' -F $Subscription, $ResourceGroup.name, $plan01.name, 'app service plan resource')
            $result = az appservice plan create --subscription $Subscription --resource-group $ResourceGroup.name --name $plan01.name --location $plan01.location --sku $plan01.sku --zone-redundant $plan01.ZoneRedundant
        }
    }
    $plan01.Add('id', $result.id)
    Invoke-PressAnyKey -Object $plan01 -PressAnyKey:$PressAnyKey

    if (-not (Test-Resource -Subscription $Subscription -ResourceGroup $ResourceGroup.name -Name $functionApp01.name -OutVariable ([ref]$result))) {
        if ($plan01.sku -ne 'Y1') {
            Write-Information -Message ('Creating "{2}" {3} [subscription: {0}, resource group: {1}] ...' -F $Subscription, $ResourceGroup.name, $functionApp01.name, 'function app resource')
            $result = az functionapp create --subscription $Subscription --resource-group $ResourceGroup.name --name $functionApp01.name --storage-account $storageAccount01.name --app-insights $appInsights01.name --app-insights-key $appInsights01.instrumentationKey --assign-identity '[system]' --deployment-local-git --deployment-source-branch $functionApp01.gitSourceBranch --deployment-source-url $functionApp01.gitSourceUrl --disable-app-insights 'false' --functions-version '4' --https-only 'true' --os-type $functionApp01.osType --plan $plan01.name --runtime $functionApp01.runtime --runtime-version $functionApp01.runtimeVersion | ConvertFrom-Json -AsHashTable
        }
        else {
            Write-Information -Message ('Creating "{2}" {3} [subscription: {0}, resource group: {1}] ...' -F $Subscription, $ResourceGroup.name, $functionApp01.name, 'function app resource')
            $result = az functionapp create --subscription $Subscription --resource-group $ResourceGroup.name --name $functionApp01.name --storage-account $storageAccount01.name --app-insights $appInsights01.name --app-insights-key $appInsights01.instrumentationKey --assign-identity '[system]' --consumption-plan-location $functionApp01.location --deployment-source-branch $functionApp01.GitSourceBranch --deployment-source-url $functionApp01.GitSourceUrl --disable-app-insights 'false' --functions-version '4' --https-only 'true' --os-type $functionApp01.osType --runtime $functionApp01.runtime --runtime-version $functionApp01.runtimeVersion | ConvertFrom-Json -AsHashTable
        }
    }
    $functionApp01.Add('id', $result.id)
    Invoke-PressAnyKey -Object $functionApp01 -PressAnyKey:$PressAnyKey

    Write-Information -Message ('Configuring "{2}" {3} [subscription: {0}, resource group: {1}] ...' -F $Subscription, $ResourceGroup.name, $functionApp01.name, 'function app resource')
    $result = az functionapp config appsettings set --subscription $Subscription --resource-group $ResourceGroup.name --name $functionApp01.name --settings ('AzureAppStorage={0}' -F ($storageAccount02.connectionString."$AccessKeyMode" -replace (';BlobEndpoint=.+$', '')))

}
