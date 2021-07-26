# Based on the original script by Kelvin Tegelaar https://github.com/KelvinTegelaar/AutomaticDocumentation
#####################################################################
# Get a Hudu API Key from https://yourhududomain.com/admin/api_keys
$HuduAPIKey = 'abcdefg123465789'
# Set the base domain of your Hudu instance without a trailing /
$HuduBaseDomain = 'https://your.hudu.domain'
$HuduAssetLayoutName = 'M365 Reports - AutoDoc'
#some layout options, change if you want colours to be different or do not like the whitespace.
$TableHeader = "<table class=`"table table-bordered table-hover`" style=`"width:80%`">"
$TableStyling = '<th>', "<th style=`"background-color:#00adef`">"
#####################################################################
########################## Azure AD ###########################
$customerExclude = @('Customer1', 'Customer2')
$ApplicationId = 'Your App ID'
$ApplicationSecret = ConvertTo-SecureString -AsPlainText 'Your App Secret' -Force
$TenantID = 'Your Tenant ID'
$RefreshToken = 'Your Long Refresh Token'
$ExchangeRefreshToken = 'Your Long Exchange Refresh Token'
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
            label        = 'TenantID'
            field_type   = 'Text'
            show_in_list = 'true'
            position     = 1
        },
        @{
            label        = 'Teams Device Reports'
            field_type   = 'RichText'
            show_in_list = 'false'
            position     = 2
        },
        @{
            label        = 'Teams User Reports'
            field_type   = 'RichText'
            show_in_list = 'false'
            position     = 3
        },
        @{
            label        = 'Email Reports'
            field_type   = 'RichText'
            show_in_list = 'false'
            position     = 4
        },
        @{
            label        = 'Mailbox Usage Reports'
            field_type   = 'RichText'
            show_in_list = 'false'
            position     = 5
        },
        @{
            label        = 'O365 Activations Reports'
            field_type   = 'RichText'
            show_in_list = 'false'
            position     = 6
        },
        @{
            label        = 'OneDrive Activity Reports'
            field_type   = 'RichText'
            show_in_list = 'false'
            position     = 7
        },
        @{
            label        = 'OneDrive Usage Reports'
            field_type   = 'RichText'
            show_in_list = 'false'
            position     = 8
        },
        @{
            label        = 'Sharepoint Usage Reports'
            field_type   = 'RichText'
            show_in_list = 'false'
            position     = 9
        }
    )

    Write-Host "Creating New Asset Layout $HuduAssetLayoutName"
    $NewLayout = New-HuduAssetLayout -name $HuduAssetLayoutName -icon 'fab fa-windows' -color '#00adef' -icon_color '#ffffff' -include_passwords $false -include_photos $false -include_comments $false -include_files $false -fields $AssetLayoutFields
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
            Write-Host "Generating token for $($Customer.name)" -ForegroundColor Green
            $graphToken = New-PartnerAccessToken -ApplicationId $ApplicationId -Credential $credential -RefreshToken $refreshToken -Scopes 'https://graph.microsoft.com/.default' -ServicePrincipal -Tenant $customer.TenantID
            $Header = @{
                Authorization = "Bearer $($graphToken.AccessToken)"
            }
            Write-Host "Gathering Reports for $($Customer.name)" -ForegroundColor Green
            #Gathers which devices currently use Teams, and the details for these devices.
            $TeamsDeviceReportsURI = "https://graph.microsoft.com/v1.0/reports/getTeamsDeviceUsageUserDetail(period='D7')"
            $TeamsDeviceReports = (Invoke-RestMethod -Uri $TeamsDeviceReportsURI -Headers $Header -Method Get -ContentType 'application/json') -replace 'ï»¿', '' | ConvertFrom-Csv | ConvertTo-Html -Fragment -PreContent '<h1>Teams device report</h1>' | Out-String
            #Gathers which Users currently use Teams, and the details for these Users.
            $TeamsUserReportsURI = "https://graph.microsoft.com/v1.0/reports/getTeamsUserActivityUserDetail(period='D7')"
            $TeamsUserReports = (Invoke-RestMethod -Uri $TeamsUserReportsURI -Headers $Header -Method Get -ContentType 'application/json') -replace 'ï»¿', '' | ConvertFrom-Csv | ConvertTo-Html -Fragment -PreContent '<h1>Teams user report</h1>' | Out-String
            #Gathers which users currently use email and the details for these Users
            $EmailReportsURI = "https://graph.microsoft.com/v1.0/reports/getEmailActivityUserDetail(period='D7')"
            $EmailReports = (Invoke-RestMethod -Uri $EmailReportsURI -Headers $Header -Method Get -ContentType 'application/json') -replace 'ï»¿', '' | ConvertFrom-Csv | ConvertTo-Html -Fragment -PreContent '<h1>Email users Report</h1>' | Out-String
            #Gathers the storage used for each e-mail user.
            $MailboxUsageReportsURI = "https://graph.microsoft.com/v1.0/reports/getMailboxUsageDetail(period='D7')"
            $MailboxUsage = (Invoke-RestMethod -Uri $MailboxUsageReportsURI -Headers $Header -Method Get -ContentType 'application/json') -replace 'ï»¿', '' | ConvertFrom-Csv | ConvertTo-Html -Fragment -PreContent '<h1>Email storage report</h1>' | Out-String
            #Gathers the activations for each user of office.
            $O365ActivationsReportsURI = 'https://graph.microsoft.com/v1.0/reports/getOffice365ActivationsUserDetail'
            $O365ActivationsReports = (Invoke-RestMethod -Uri $O365ActivationsReportsURI -Headers $Header -Method Get -ContentType 'application/json') -replace 'ï»¿', '' | ConvertFrom-Csv | ConvertTo-Html -Fragment -PreContent '<h1>O365 Activation report</h1>' | Out-String
            #Gathers the Onedrive activity for each user.
            $OneDriveActivityURI = "https://graph.microsoft.com/v1.0/reports/getOneDriveActivityUserDetail(period='D7')"
            $OneDriveActivityReports = (Invoke-RestMethod -Uri $OneDriveActivityURI -Headers $Header -Method Get -ContentType 'application/json') -replace 'ï»¿', '' | ConvertFrom-Csv | ConvertTo-Html -Fragment -PreContent '<h1>Onedrive Activity report</h1>' | Out-String
            #Gathers the Onedrive usage for each user.
            $OneDriveUsageURI = "https://graph.microsoft.com/v1.0/reports/getOneDriveUsageAccountDetail(period='D7')"
            $OneDriveUsageReports = (Invoke-RestMethod -Uri $OneDriveUsageURI -Headers $Header -Method Get -ContentType 'application/json') -replace 'ï»¿', '' | ConvertFrom-Csv | ConvertTo-Html -Fragment -PreContent '<h1>OneDrive usage report</h1>' | Out-String
            #Gathers the Sharepoint usage for each user.
            $SharepointUsageReportsURI = "https://graph.microsoft.com/v1.0/reports/getSharePointSiteUsageDetail(period='D7')"
            $SharepointUsageReports = (Invoke-RestMethod -Uri $SharepointUsageReportsURI -Headers $Header -Method Get -ContentType 'application/json') -replace 'ï»¿', '' | ConvertFrom-Csv | ConvertTo-Html -Fragment -PreContent '<h1>Sharepoint usage report</h1>' | Out-String

            $CharactersToRemove = @('\x80', '\x99')
            foreach ($character in $CharactersToRemove) {
                $TeamsDeviceReports = $TeamsDeviceReports -replace $character, ''
                $TeamsUserReports = $TeamsUserReports -replace $character, ''
                $EmailReports = $EmailReports -replace $character, ''
                $MailboxUsage = $MailboxUsage -replace $character, ''
                $O365ActivationsReports = $O365ActivationsReports -replace $character, ''
                $OneDriveActivityReports = $OneDriveActivityReports -replace $character, ''
                $OneDriveUsageReports = $OneDriveUsageReports -replace $character, ''
                $SharepointUsageReports = $SharepointUsageReports -replace $character, ''
            }


            $AssetFields = @{
                'teams_device_reports'      = ($TableHeader + $TeamsDeviceReports) -replace $TableStyling
                'teams_user_reports'        = ($TableHeader + $TeamsUserReports ) -replace $TableStyling
                'email_reports'             = ($TableHeader + $EmailReports) -replace $TableStyling
                'mailbox_usage_reports'     = ($TableHeader + $MailboxUsage) -replace $TableStyling
                'o365_activations_reports'  = ($TableHeader + $O365ActivationsReports) -replace $TableStyling
                'onedrive_activity_reports' = ($TableHeader + $OneDriveActivityReports) -replace $TableStyling
                'onedrive_usage_reports'    = ($TableHeader + $OneDriveUsageReports) -replace $TableStyling
                'sharepoint_usage_reports'  = ($TableHeader + $SharepointUsageReports) -replace $TableStyling
                'tenantid'                  = $customer.TenantId
            }

            Write-Output "Uploading M365 Team $($settings.displayname) into Hudu"
            $companyid = $hududomain.company_id

            #Swap out # as Hudu doesn't like it when searching
            $AssetName = "$($customer.TenantId) - Reports"

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
