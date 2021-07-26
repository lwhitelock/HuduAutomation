# Based on the original script by Kelvin Tegelaar https://github.com/KelvinTegelaar/AutomaticDocumentation
#####################################################################
# Get a Hudu API Key from https://yourhududomain.com/admin/api_keys
$HuduAPIKey = 'abcedfg1234567890'
# Set the base domain of your Hudu instance without a trailing /
$HuduBaseDomain = 'https://your.hudu.domain'
#Company Name as it appears in Hudu
$CompanyName = 'Company Name'
$HuduAssetLayoutName = 'DHCP Server - Autodoc'
#####################################################################

#Get the Hudu API Module if not installed
if (Get-Module -ListAvailable -Name HuduAPI) {
    Import-Module HuduAPI
} else {
    Install-Module HuduAPI -Force
    Import-Module HuduAPI
}

#Set Hudu logon information
New-HuduAPIKey $HuduAPIKey
New-HuduBaseUrl $HuduBaseDomain

$Company = Get-HuduCompanies -name $CompanyName
if ($company) {

    $Layout = Get-HuduAssetLayouts -name $HuduAssetLayoutName

    if (!$Layout) {
        $AssetLayoutFields = @(
            @{
                label        = 'DHCP Server Name'
                field_type   = 'Text'
                show_in_list = 'true'
                position     = 1
            },
            @{
                label        = 'DHCP Server Settings'
                field_type   = 'RichText'
                show_in_list = 'false'
                position     = 2
            },
            @{
                label        = 'DHCP Server Database Information'
                field_type   = 'RichText'
                show_in_list = 'false'
                position     = 3
            },
            @{
                label        = 'DHCP Domain Authorisation'
                field_type   = 'RichText'
                show_in_list = 'false'
                position     = 4
            },
            @{
                label        = 'DHCP Scopes'
                field_type   = 'RichText'
                show_in_list = 'false'
                position     = 5
            },
            @{
                label        = 'DHCP Scope Information'
                field_type   = 'RichText'
                show_in_list = 'false'
                position     = 6
            },
            @{
                label        = 'DHCP Statistics'
                field_type   = 'RichText'
                show_in_list = 'false'
                position     = 7
            }
        )

        Write-Host "Creating New Asset Layout $HuduAssetLayoutName"
        $NewLayout = New-HuduAssetLayout -name $HuduAssetLayoutName -icon 'fas fa-network-wired' -color '#4CAF50' -icon_color '#ffffff' -include_passwords $false -include_photos $false -include_comments $false -include_files $false -fields $AssetLayoutFields
        $Layout = Get-HuduAssetLayouts -name $HuduAssetLayoutName
    }



    $DCHPServerSettings = Get-DhcpServerSetting | Select-Object ActivatePolicies, ConflictDetectionAttempts, DynamicBootp, IsAuthorized, IsDomainJoined, NapEnabled, NpsUnreachableAction, RestoreStatus | ConvertTo-Html -Fragment | Out-String
    $databaseinfo = Get-DhcpServerDatabase | Select-Object BackupInterval, BackupPath, CleanupInterval, FileName, LoggingEnabled, RestoreFromBackup | ConvertTo-Html -Fragment | Out-String
    $DHCPDCAuth = Get-DhcpServerInDC | Select-Object IPAddress, DnsName | ConvertTo-Html -Fragment | Out-String
    $Scopes = Get-DhcpServerv4Scope
    $ScopesAvailable = $Scopes | Select-Object ScopeId, SubnetMask, StartRange, EndRange, ActivatePolicies, Delay, Description, LeaseDuration, MaxBootpClients, Name, NapEnable, NapProfile, State, SuperscopeName, Type | ConvertTo-Html -Fragment | Out-String
    $ScopeInfo = foreach ($Scope in $scopes) {
        $scope | Get-DhcpServerv4Lease | Select-Object ScopeId, IPAddress, AddressState, ClientId, ClientType, Description, DnsRegistration, DnsRR, HostName, LeaseExpiryTime | ConvertTo-Html -Fragment -PreContent "<h2>Scope Information: $($Scope.name) - $($scope.ScopeID) </h2>" | Out-String
    }

    $DHCPServerStats = Get-DhcpServerv4Statistics | Select-Object InUse, Available, Acks, AddressesAvailable, AddressesInUse, Declines, DelayedOffers, Discovers, Naks, Offers, PendingOffers, PercentageAvailable, PercentageInUse, PercentagePendingOffers, Releases, Requests, ScopesWithDelayConfigured, ServerStartTime, TotalAddresses, TotalScope | ConvertTo-Html -Fragment -As List | Out-String


    # Populate Asset Fields
    $AssetFields = @{
        'dhcp_server_name'                 = $env:computername
        'dhcp_server_settings'             = $DCHPServerSettings
        'dhcp_server_database_information' = $databaseinfo
        'dhcp_domain_authorisation'        = $DHCPDCAuth
        'dhcp_scopes'                      = $ScopesAvailable
        'dhcp_scope_information'           = $ScopeInfo
        'dhcp_statistics'                  = $DHCPServerStats
    }


    $assetname = "$($env:computername) - DHCP Server"
    #Check if there is already an asset
    $Asset = Get-HuduAssets -name $assetname -companyid $company.id -assetlayoutid $layout.id

    #If the Asset does not exist, we edit the body to be in the form of a new asset, if not, we just upload.
    if (!$Asset) {
        Write-Host 'Creating new Asset'
        $Asset = New-HuduAsset -name $assetname -company_id $company.id -asset_layout_id $layout.id -fields $AssetFields
    } else {
        Write-Host 'Updating Asset'
        $Asset = Set-HuduAsset -asset_id $Asset.id -name $assetname -company_id $company.id -asset_layout_id $layout.id -fields $AssetFields
    }

} else {
    Write-Host "$CompanyName was not found in Hudu"
}
