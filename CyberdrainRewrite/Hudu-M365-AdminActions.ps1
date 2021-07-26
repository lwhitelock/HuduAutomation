# Based on the original script by Kelvin Tegelaar https://www.cyberdrain.com/documenting-with-powershell-documenting-admin-actions/
#####################################################################
# Get a Hudu API Key from https://yourhududomain.com/admin/api_keys
$HuduAPIKey = 'abcdefght1234567890'
# Set the base domain of your Hudu instance without a trailing /
$HuduBaseDomain = 'https://your.hudu.domain'
$HuduAssetLayoutName = 'M365 Admin Actions - AutoDoc'
#####################################################################
########################## Azure AD ###########################
$customerExclude = @('Example Customer 1', 'Example Customer 2')
$ApplicationId = 'Your-App-ID'
$ApplicationSecret = ConvertTo-SecureString -AsPlainText 'Your App Secret' -Force
$TenantID = 'Your Tenant ID'
$RefreshToken = 'Long refresh token'
$ExchangeRefreshToken = 'Long Exchange Refresh Token'
$upn = 'The user upn you created the app with'
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

$Layout = Get-HuduAssetLayouts -name $HuduAssetLayoutName

if (!$Layout) {
    $AssetLayoutFields = @(
        @{
            label        = 'Tenant'
            field_type   = 'Text'
            show_in_list = 'true'
            position     = 1
        },
        @{
            label        = 'Actions'
            field_type   = 'RichText'
            show_in_list = 'false'
            position     = 2
        }
    )

    Write-Host 'Creating New Asset Layout'
    $NewLayout = New-HuduAssetLayout -name $HuduAssetLayoutName -icon 'fas fa-sitemap' -color '#00adef' -icon_color '#000000' -include_passwords $false -include_photos $false -include_comments $false -include_files $false -fields $AssetLayoutFields
    $Layout = Get-HuduAssetLayouts -name $HuduAssetLayoutName

}

$credential = New-Object System.Management.Automation.PSCredential($ApplicationId, $ApplicationSecret)
$aadGraphToken = New-PartnerAccessToken -ApplicationId $ApplicationId -Credential $credential -RefreshToken $refreshToken -Scopes 'https://graph.windows.net/.default' -ServicePrincipal -Tenant $tenantID
$graphToken = New-PartnerAccessToken -ApplicationId $ApplicationId -Credential $credential -RefreshToken $refreshToken -Scopes 'https://graph.microsoft.com/.default' -ServicePrincipal -Tenant $tenantID
Connect-MsolService -AdGraphAccessToken $aadGraphToken.AccessToken -MsGraphAccessToken $graphToken.AccessToken

$customers = Get-MsolPartnerContract -All

foreach ($customer in $customers) {
    #Check if customer should be excluded
    if (-Not ($customerExclude -contains $customer.DisplayName)) {
        #First lets check for the company
        #Check if they are in Hudu before doing any unnessisary work
        $defaultdomain = $customer.DefaultDomainName
        $hududomain = Get-HuduWebsites -name "https://$defaultdomain"
        if ($($hududomain.id.count) -gt 0) {
            $domains = Get-MsolDomain -TenantId $customer.TenantId
            $token = New-PartnerAccessToken -ApplicationId 'a0c73c16-a7e3-4564-9a95-2bdf47383716'-RefreshToken $ExchangeRefreshToken -Scopes 'https://outlook.office365.com/.default' -Tenant $customer.TenantId
            $tokenValue = ConvertTo-SecureString "Bearer $($token.AccessToken)" -AsPlainText -Force
            $credential = New-Object System.Management.Automation.PSCredential($upn, $tokenValue)
            $customerId = $customer.DefaultDomainName
            $session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri "https://ps.outlook.com/powershell-liveid?DelegatedOrg=$($customerId)&BasicAuthToOAuthConversion=true" -Credential $credential -Authentication Basic -AllowRedirection
            $null = Import-PSSession $session -AllowClobber -DisableNameChecking -CommandName 'Search-unifiedAuditLog', 'Get-AdminAuditLogConfig'
            $AdminRoles = (Get-MsolRole | Where-Object -Property name -Like '*admin*' | ForEach-Object { Get-MsolRoleMember -TenantId $customer.TenantId -RoleObjectId $_.ObjectId }).emailaddress -join ','
            $startDate = (Get-Date).AddDays(-1)
            $endDate = (Get-Date)
            Write-Host "Retrieving logs for $($customer.name)" -ForegroundColor Blue
            $Logs = do {
                $log = Search-unifiedAuditLog -SessionCommand ReturnLargeSet -SessionId $customer.name -UserIds $AdminRoles -ResultSize 5000 -StartDate $startDate -EndDate $endDate
                $log
                Write-Host "    Retrieved $($log.count) logs" -ForegroundColor Green
            } while ($Log.count % 5000 -eq 0 -and $log.count -ne 0)
            Remove-PSSession $session -ErrorAction SilentlyContinue
            $Actions = $logs | ForEach-Object {
                $AuditData = ConvertFrom-Json $_.AuditData
                [PSCustomObject]@{
                    'Creationdate '      = $_.Creationdate
                    'User'               = $_.UserIDs
                    'Operation'          = $_.Operations
                    'Workload'           = $AuditData.Workload
                    'ObjectID'           = $AuditData.ObjectId
                    'Client IP'          = $AuditData.ClientIP
                    'Updated Properties' = ($AuditData.modifiedproperties | Where-Object -Property name -EQ 'Included Updated Properties').newvalue -join ','
                }
            }
            if (!$actions) {
                $HTMLActions = '<b>No logs have been found for this period</b>'
            } else {
                $HTMLActions = ($Actions | ConvertTo-Html -Fragment | Out-String) -replace '<th>', "<th style=`"background-color:#00adef`">"
            }


            $AssetFields = @{
                'tenant'  = $customer.name
                'actions' = $HTMLActions

            }

            $AssetName = "$($customer.name) - Admin Actions"
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
