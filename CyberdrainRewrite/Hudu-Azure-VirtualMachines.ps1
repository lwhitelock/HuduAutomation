# Based on the original script by Kelvin Tegelaar https://github.com/KelvinTegelaar/AutomaticDocumentation
#####################################################################
# Get a Hudu API Key from https://yourhududomain.com/admin/api_keys
$HuduAPIKey = 'abcdefght1234567890'
# Set the base domain of your Hudu instance without a trailing /
$HuduBaseDomain = 'https://your.hudu.domain'
$HuduAssetLayoutName = 'Azure VMs - AutoDoc'
#####################################################################
########################## Azure AD ###########################
$customerExclude = @('Example Customer 1', 'Example Customer 2')
$ApplicationId = 'Your-App-ID'
$ApplicationSecret = ConvertTo-SecureString -AsPlainText 'Your App Secret' -Force
$TenantID = 'Your Tenant ID'
$RefreshToken = 'Long refresh token'
$ExchangeRefreshToken = 'Long Exchange Refresh Token'
$upn = 'The user upn you created the app with'
########################## Azure AD ###########################

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

$Layout = Get-HuduAssetLayouts -name $HuduAssetLayoutName

if (!$Layout) {
    $AssetLayoutFields = @(
        @{
            label        = 'Subscription ID'
            field_type   = 'Text'
            show_in_list = 'true'
            position     = 1
        },
        @{
            label        = 'VMs'
            field_type   = 'RichText'
            show_in_list = 'false'
            position     = 2
        },
        @{
            label        = 'NSGs'
            field_type   = 'RichText'
            show_in_list = 'false'
            position     = 3
        },
        @{
            label        = 'Networks'
            field_type   = 'RichText'
            show_in_list = 'false'
            position     = 4
        }
    )

    Write-Host 'Creating New Asset Layout'
    $NewLayout = New-HuduAssetLayout -name $HuduAssetLayoutName -icon 'fas fa-sitemap' -color '#00adef' -icon_color '#000000' -include_passwords $false -include_photos $false -include_comments $false -include_files $false -fields $AssetLayoutFields
    $Layout = Get-HuduAssetLayouts -name $HuduAssetLayoutName

}


$credential = New-Object System.Management.Automation.PSCredential($ApplicationId, $ApplicationSecret)
$azureToken = New-PartnerAccessToken -ApplicationId $ApplicationID -Credential $credential -RefreshToken $refreshToken -Scopes 'https://management.azure.com/user_impersonation' -ServicePrincipal -Tenant $TenantId
$graphToken = New-PartnerAccessToken -ApplicationId $ApplicationID -Credential $credential -RefreshToken $refreshToken -Scopes 'https://graph.microsoft.com/.default' -ServicePrincipal -Tenant $TenantId
$aadGraphToken = New-PartnerAccessToken -ApplicationId $ApplicationId -Credential $credential -RefreshToken $refreshToken -Scopes 'https://graph.windows.net/.default' -ServicePrincipal

Connect-MsolService -AdGraphAccessToken $aadGraphToken.AccessToken -MsGraphAccessToken $graphToken.AccessToken
Connect-AzAccount -AccessToken $azureToken.AccessToken -GraphAccessToken $graphToken.AccessToken -AccountId $upn -TenantId $tenantID
$Subscriptions = Get-AzSubscription | Where-Object { $_.State -eq 'Enabled' } | Sort-Object -Unique -Property Id

foreach ($Sub in $Subscriptions) {


    $OrgTenant = ((Invoke-AzRestMethod -Path "/subscriptions/$($sub.subscriptionid)/?api-version=2020-06-01" -Method GET).content | ConvertFrom-Json).tenantid
    Write-Host "Processing client $($sub.name)"
    $Domains = get-msoldomain -tenant $OrgTenant

    if (-Not ($customerExclude -contains $OrgTenant.DisplayName)) {
        #First lets check for the company
        #Check if they are in Hudu before doing any unnessisary work
        $defaultdomain = $OrgTenant.DefaultDomainName
        $hududomain = Get-HuduWebsites -name "https://$defaultdomain"
        if ($($hududomain.id.count) -gt 0) {
            Write-Host "$($OrgTenant.DisplayName) - $defaultdomain"
            $null = $Sub | Set-AzContext
            $VMs = Get-AzVM -Status | Select-Object PowerState, Name, ProvisioningState, Location,
            @{Name = 'OS Type'; Expression = { $_.Storageprofile.osdisk.OSType } },
            @{Name = 'VM Size'; Expression = { $_.hardwareprofile.vmsize } },
            @{Name = 'OS Disk Type'; Expression = { $_.StorageProfile.osdisk.manageddisk.storageaccounttype } }
            $networks = Get-AzNetworkInterface | Select-Object Primary,
            @{Name = 'NSG'; Expression = { ($_.NetworkSecurityGroup).id -split '/' | Select-Object -Last 1 } },
            @{Name = 'DNS Settings'; Expression = { ($_.DNSsettings).dnsservers -join ',' } },
            @{Name = 'Connected VM'; Expression = { ($_.VirtualMachine).id -split '/' | Select-Object -Last 1 } },
            @{Name = 'Internal IP'; Expression = { ($_.IPConfigurations).PrivateIpAddress -join ',' } },
            @{Name = 'External IP'; Expression = { ($_.IPConfigurations).PublicIpAddress.IpAddress -join ',' } }, tags
            $NSGs = Get-AzNetworkSecurityGroup | Select-Object Name, Location,
            @{Name = 'Allowed Destination Ports'; Expression = { ($_.SecurityRules | Where-Object { $_.direction -eq 'inbound' -and $_.Access -eq 'allow' }).DestinationPortRange } } ,
            @{Name = 'Denied Destination Ports'; Expression = { ($_.SecurityRules | Where-Object { $_.direction -eq 'inbound' -and $_.Access -ne 'allow' }).DestinationPortRange } }

            $AssetFields = @{
                'subscription-id' = $sub.SubscriptionId
                'vms'             = ($VMs | ConvertTo-Html -Fragment | Out-String)
                'nsgs'            = ($NSGs | ConvertTo-Html -Fragment | Out-String)
                'networks'        = ($networks | ConvertTo-Html -Fragment | Out-String)

            }

            $AssetName = $($sub.name)
            $companyid = $hududomain.company_id

            #Check if there is already an asset
            $Asset = Get-HuduAssets -name $AssetName -companyid $companyid -assetlayoutid $Layout.id

            #If the Asset does not exist, we edit the body to be in the form of a new asset, if not, we just upload.
            if (!$Asset) {
                Write-Host 'Creating new Asset'
                $Asset = New-HuduAsset -name $AssetName -company_id $companyid -asset_layout_id $Layout.id -fields $AssetFields
            } else {
                Write-Host 'Updating Asset'
                $Asset = Set-HuduAsset -asset_id $Asset.id -name $AssetName -company_id $companyid -asset_layout_id $layout.id -fields $AssetFields
            }

        } else {
            Write-Host "https://$defaultdomain Not found in Hudu. Please add as a website under the relevant customer" -ForegroundColor Red
        }
    }
}

