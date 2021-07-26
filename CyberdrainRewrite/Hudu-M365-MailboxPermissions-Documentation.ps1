# Based on the original script by Kelvin Tegelaar https://github.com/KelvinTegelaar/AutomaticDocumentation
#####################################################################
# Get a Hudu API Key from https://yourhududomain.com/admin/api_keys
$HuduAPIKey = 'abcdefgh12344456778c'
# Set the base domain of your Hudu instance without a trailing /
$HuduBaseDomain = 'https://your.hudu.domain'
$HuduAssetLayoutName = 'M365 Guest logbook - AutoDoc'
#####################################################################
########################## Azure AD ###########################
$customerExclude = @('Example Cuystomer 1', 'Example Customer 2')
$ApplicationId = 'Your app ID'
$ApplicationSecret = ConvertTo-SecureString -AsPlainText 'Your App Secret' -Force
$TenantID = 'Your Tenant ID'
$RefreshToken = 'Long Refresh Token'
$ExchangeRefreshToken = 'Long Exchange Refresh Token'
$upn = 'UserWhoCreatedApp@domain.com'
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
            label        = 'tenantid'
            field_type   = 'Text'
            show_in_list = 'true'
            position     = 1
        },
        @{
            label        = 'Tenant Name'
            field_type   = 'Text'
            show_in_list = 'false'
            position     = 2
        },
        @{
            label        = 'Permissions'
            field_type   = 'RichText'
            show_in_list = 'true'
            position     = 3
        }
    )

    Write-Host "Creating New Asset Layout $HuduAssetLayoutName"
    $NewLayout = New-HuduAssetLayout -name $HuduAssetLayoutName -icon 'fas fa-user-friends' -color '#00adef' -icon_color '#ffffff' -include_passwords $false -include_photos $false -include_comments $false -include_files $false -fields $AssetLayoutFields
    $Layout = Get-HuduAssetLayouts -name $HuduAssetLayoutName
}

$credential = New-Object System.Management.Automation.PSCredential($ApplicationId, $ApplicationSecret)
$aadGraphToken = New-PartnerAccessToken -ApplicationId $ApplicationId -Credential $credential -RefreshToken $refreshToken -Scopes 'https://graph.windows.net/.default' -ServicePrincipal -Tenant $tenantID
$graphToken = New-PartnerAccessToken -ApplicationId $ApplicationId -Credential $credential -RefreshToken $refreshToken -Scopes 'https://graph.microsoft.com/.default' -ServicePrincipal -Tenant $tenantID
Connect-MsolService -AdGraphAccessToken $aadGraphToken.AccessToken -MsGraphAccessToken $graphToken.AccessToken
$customers = Get-MsolPartnerContract -All

foreach ($customer in $customers) {
    #Check if customer should be excluded
    if (-Not ($customerExclude -contains $customer.Name)) {
        #First lets check for the company
        #Check if they are in Hudu before doing any unnessisary work
        $defaultdomain = $customer.DefaultDomainName
        $hududomain = Get-HuduWebsites -name "https://$defaultdomain"
        if ($($hududomain.id.count) -gt 0) {
            $MSOLPrimaryDomain = (get-msoldomain -TenantId $customer.tenantid | Where-Object { $_.IsInitial -eq $false }).name
            $customerDomains = Get-MsolDomain -TenantId $customer.TenantId | Where-Object { $_.status -contains 'Verified' }
            $MSOLtentantID = $customer.tenantid
            #Connecting to the O365 tenant
            $InitialDomain = Get-MsolDomain -TenantId $customer.TenantId | Where-Object { $_.IsInitial -eq $true }
            Write-Host "Documenting $($Customer.Name)"
            $token = New-PartnerAccessToken -ApplicationId 'a0c73c16-a7e3-4564-9a95-2bdf47383716'-RefreshToken $ExchangeRefreshToken -Scopes 'https://outlook.office365.com/.default' -Tenant $customer.TenantId
            $tokenValue = ConvertTo-SecureString "Bearer $($token.AccessToken)" -AsPlainText -Force
            $credential = New-Object System.Management.Automation.PSCredential($upn, $tokenValue)
            $customerId = $customer.DefaultDomainName
            $session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri "https://ps.outlook.com/powershell-liveid?DelegatedOrg=$($customerId)&BasicAuthToOAuthConversion=true" -Credential $credential -Authentication Basic -AllowRedirection
            $null = Import-PSSession $session -CommandName 'Get-MailboxPermission', 'Get-Mailbox' -AllowClobber
            $Mailboxes = Get-Mailbox -ResultSize:Unlimited | Sort-Object displayname

            foreach ($mailbox in $mailboxes) {
                $AccesPermissions = Get-MailboxPermission -Identity $mailbox.identity | Where-Object { $_.user.tostring() -ne 'NT AUTHORITY\SELF' -and $_.IsInherited -eq $false } -ErrorAction silentlycontinue | Select-Object User, accessrights
                if ($AccesPermissions) { $HTMLPermissions += $AccesPermissions | ConvertTo-Html -frag -PreContent "Permissions on $($mailbox.PrimarySmtpAddress)" | Out-String }
            }
            Remove-PSSession $session

            $AssetFields = @{
                'tenantid'    = $MSOLtentantID
                'permissions' = $HTMLPermissions
                'tenant_name' = $initialdomain.name
            }

            Write-Output "Uploading O365 guest $($guest.userprincipalname) into Hudu"
            $companyid = $hududomain.company_id
            $AssetName = "$defaultdomain - Permissions"
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

            $MSOLPrimaryDomain = $null
            $MSOLtentantID = $null
            $AccesPermissions = $null
            $HTMLPermissions = $null

        } else {
            Write-Host "https://$defaultdomain Not found in Hudu. Please add as a website under the relevant customer" -ForegroundColor Red
        }
    }
}

