# Aruba Settings
$ArubaInstantOnUser = 'api-user@yourdomain.com'
$ArubaInstantOnPass = 'Make a long randomly generated password for the account that you save securely'

# Hudu Settings
$HuduAPIKey = 'abcdefghijk1234567'
$HuduBaseDomain = 'https://your.hududomain.com'

$HuduAssetLayoutNameSite = 'Aruba Instant On - Site'
$HuduAssetLayoutNameDevice = 'Aruba Instant On - Device'

#$TableStyling = "<th>", "<th style=`"background-color:#F5831F`">"
$TableStyling = ''

function Get-URLEncode {
    param(
        [Byte[]]$Bytes
    )
    # Convert to Base 64
    $EncodedText = [Convert]::ToBase64String($Bytes)

    # Calculate Number of Padding Chars
    $Found = $false
    $EndPos = $EncodedText.Length
    do {
        if ($EncodedText[$EndPos] -ne '=') {
            $found = $true
        }
        $EndPos = $EndPos - 1
    } while ($found -eq $false)

    # Trim the Padding Chars
    $Stripped = $EncodedText.Substring(0, $EndPos)

    # Add the number of padding chars to the end
    $PaddingNumber = "$Stripped$($EncodedText.Length - ($EndPos + 1))"

    # Replace Characters
    $URLEncodedString = $PaddingNumber -replace [RegEx]::Escape('+'), '-' -replace [RegEx]::Escape('/'), '_'

    return $URLEncodedString

}


#### Start ####
if (Get-Module -ListAvailable -Name HuduAPI) {
    Import-Module HuduAPI
} else {
    Install-Module HuduAPI -Force
    Import-Module HuduAPI
}

#Set Hudu logon information
New-HuduAPIKey $HuduAPIKey
New-HuduBaseUrl $HuduBaseDomain

# Prepare Asset Layouts
$SiteLayout = Get-HuduAssetLayouts -name $HuduAssetLayoutNameSite

if (!$SiteLayout) {
    $SiteAssetLayoutFields = @(
        @{
            label        = 'Site Name'
            field_type   = 'Text'
            show_in_list = 'true'
            position     = 1
        },
        @{
            label        = 'Site Details'
            field_type   = 'RichText'
            show_in_list = 'false'
            position     = 2
        },
        @{
            label        = 'Admins'
            field_type   = 'RichText'
            show_in_list = 'false'
            position     = 3
        },
        @{
            label        = 'Alerts'
            field_type   = 'RichText'
            show_in_list = 'false'
            position     = 4
        },
        @{
            label        = 'Wired Networks'
            field_type   = 'RichText'
            show_in_list = 'false'
            position     = 5
        },
        @{
            label        = 'Wireless Networks'
            field_type   = 'RichText'
            show_in_list = 'false'
            position     = 6
        },
        @{
            label        = 'Application Usage'
            field_type   = 'RichText'
            show_in_list = 'false'
            position     = 7
        },
        @{
            label        = 'Clients'
            field_type   = 'RichText'
            show_in_list = 'false'
            position     = 7
        }
    )

    Write-Host "Creating New Asset Layout $HuduAssetLayoutNameSite"
    $null = New-HuduAssetLayout -name $HuduAssetLayoutNameSite -icon 'fas fa-network-wired' -color '#4CAF50' -icon_color '#ffffff' -include_passwords $false -include_photos $false -include_comments $false -include_files $false -fields $SiteAssetLayoutFields
    $SiteLayout = Get-HuduAssetLayouts -name $HuduAssetLayoutNameSite
}

$DeviceLayout = Get-HuduAssetLayouts -name $HuduAssetLayoutNameDevice

if (!$DeviceLayout) {
    $SiteAssetLayoutFields = @(
        @{
            label        = 'Device Name'
            field_type   = 'Text'
            show_in_list = 'true'
            position     = 1
        },
        @{
            label        = 'Site'
            field_type   = 'AssetTag'
            linkable_id  = $SiteLayout.id
            show_in_list = 'true'
            position     = 2
        },
        @{
            label        = 'Management URL'
            field_type   = 'RichText'
            show_in_list = 'false'
            position     = 2
        },
        @{
            label        = 'Type'
            field_type   = 'Text'
            show_in_list = 'true'
            position     = 3
        },
        @{
            label        = 'IP'
            field_type   = 'Text'
            show_in_list = 'true'
            position     = 4
        },
        @{
            label        = 'MAC'
            field_type   = 'Text'
            show_in_list = 'false'
            position     = 5
        },
        @{
            label        = 'Serial Number'
            field_type   = 'Text'
            show_in_list = 'false'
            position     = 6
        },
        @{
            label        = 'Model'
            field_type   = 'Text'
            show_in_list = 'false'
            position     = 7
        },
        @{
            label        = 'Uptime'
            field_type   = 'Text'
            show_in_list = 'false'
            position     = 8
        },
        @{
            label        = 'Radios'
            field_type   = 'RichText'
            show_in_list = 'false'
            position     = 9
        },
        @{
            label        = 'Ethernet Ports'
            field_type   = 'RichText'
            show_in_list = 'false'
            position     = 10
        },
        @{
            label        = 'Alerts'
            field_type   = 'RichText'
            show_in_list = 'false'
            position     = 11
        },
        @{
            label        = 'Clients'
            field_type   = 'RichText'
            show_in_list = 'false'
            position     = 12
        }

    )

    Write-Host "Creating New Asset Layout $HuduAssetLayoutNameDevice"
    $null = New-HuduAssetLayout -name $HuduAssetLayoutNameDevice -icon 'fas fa-network-wired' -color '#4CAF50' -icon_color '#ffffff' -include_passwords $false -include_photos $false -include_comments $false -include_files $false -fields $SiteAssetLayoutFields
    $DeviceLayout = Get-HuduAssetLayouts -name $HuduAssetLayoutNameDevice
}



# The API appears to use PKCE. A detailed explination of the steps can be found here https://auth0.com/docs/flows/call-your-api-using-the-authorization-code-flow-with-pkce

# Generate the Code Verified and Code Challange used in OAUth
$RandomNumberGenerator = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
$Bytes = New-Object Byte[] 32
$RandomNumberGenerator.GetBytes($Bytes)
$CodeVerifier = (Get-URLEncode($Bytes)).Substring(0, 43)

$StateRandomNumberGenerator = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
$StateBytes = New-Object Byte[] 32
$StateRandomNumberGenerator.GetBytes($StateBytes)
$State = (Get-URLEncode($StateBytes)).Substring(0, 43)

$hasher = [System.Security.Cryptography.HashAlgorithm]::Create('sha256')
$hash = $hasher.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($CodeVerifier))
$CodeChallenge = (Get-URLEncode($hash)).Substring(0, 43)

#Create the form body for the initial login
$LoginRequest = [ordered]@{
    username = $ArubaInstantOnUser
    password = $ArubaInstantOnPass
}

# Perform the initial authorisation
$ContentType = 'application/x-www-form-urlencoded'
$Token = (Invoke-WebRequest -Method POST -Uri 'https://sso.arubainstanton.com/aio/api/v1/mfa/validate/full' -Body $LoginRequest -ContentType $ContentType).content | ConvertFrom-Json

# Dowmload the global settings and get the Client ID incase this changes.
$OAuthSettings = (Invoke-WebRequest -Method Get -Uri 'https://portal.arubainstanton.com/settings.json') | ConvertFrom-Json
$ClientID = $OAuthSettings.ssoClientIdAuthZ

# Use the initial token to perform the authorisation
$URL = "https://sso.arubainstanton.com/as/authorization.oauth2?client_id=$ClientID&redirect_uri=https://portal.arubainstanton.com&response_type=code&scope=profile%20openid&state=$State&code_challenge_method=S256&code_challenge=$CodeChallenge&sessionToken=$($Token.access_token)"
$AuthCode = Invoke-WebRequest -Method GET -Uri $URL -MaximumRedirection 1

# Extract the code returned in the redirect URL
if ($null -ne $AuthCode.BaseResponse.ResponseUri) {
    # This is for Powershell 5
    $redirectUri = $AuthCode.BaseResponse.ResponseUri
} elseif ($null -ne $AuthCode.BaseResponse.RequestMessage.RequestUri) {
    # This is for Powershell core
    $redirectUri = $AuthCode.BaseResponse.RequestMessage.RequestUri
}

$QueryParams = [System.Web.HttpUtility]::ParseQueryString($redirectUri.Query)
$i = 0
$ParsedQueryParams = foreach ($QueryStringObject in $QueryParams) {
    $queryObject = New-Object -TypeName psobject
    $queryObject | Add-Member -MemberType NoteProperty -Name Name -Value $QueryStringObject
    $queryObject | Add-Member -MemberType NoteProperty -Name Value -Value $QueryParams[$i]
    $queryObject
    $i++
}

$LoginCode = ($ParsedQueryParams | Where-Object { $_.name -eq 'code' }).value

# Build the form data to request an actual token
$TokenAuth = @{
    client_id     = $ClientID
    redirect_uri  = 'https://portal.arubainstanton.com'
    code          = $LoginCode
    code_verifier = $CodeVerifier
    grant_type    = 'authorization_code'

}

# Obtain the Bearer Token
$Bearer = (Invoke-WebRequest -Method POST -Uri 'https://sso.arubainstanton.com/as/token.oauth2' -Body $TokenAuth -ContentType $ContentType).content | ConvertFrom-Json


# Get the headers ready for talking to the API. Note you get 500 errors if you don't include x-ion-api-version 7 for some endpoints and don't get full data on others
$ContentType = 'application/json'
$headers = @{
    Authorization       = "Bearer $($Bearer.access_token)"
    'x-ion-api-version' = 7
}

# Get all sites under account
$Sites = (Invoke-WebRequest -Method GET -Uri 'https://nb.portal.arubainstanton.com/api/sites/' -ContentType $ContentType -Headers $headers).content | ConvertFrom-Json

# Loop through each site and create documentation
foreach ($site in $sites.Elements) {
    #First we will see if there is an Asset that matches the site name with this Asset Layout
    Write-Host "Attempting to map $($Site.name)"
    $SiteAsset = Get-HuduAssets -name $($Site.name) -assetlayoutid $SiteLayout.id
    if (!$SiteAsset) {
        #Check on company name
        $Company = Get-HuduCompanies -name $($Site.name)
        if (!$company) {
            Write-Host "A company in Hudu could not be matched to the site. Please create a blank '$HuduAssetLayoutNameSite' asset, with a name of `"$($Site.name)`" under the company in Hudu you wish to map this site to." -ForegroundColor Red
            continue
        }
    }
    Write-Host "Processing $($Site.name)"

    #Gather all Data
    #Site Details
    $LandingPage = (Invoke-WebRequest -Method GET -Uri "https://nb.portal.arubainstanton.com/api/sites/$($Site.id)/landingPage" -ContentType $ContentType -Headers $headers).content | ConvertFrom-Json
    $administration = (Invoke-WebRequest -Method GET -Uri "https://nb.portal.arubainstanton.com/api/sites/$($Site.id)/administration" -ContentType $ContentType -Headers $headers).content | ConvertFrom-Json
    $timezone = (Invoke-WebRequest -Method GET -Uri "https://nb.portal.arubainstanton.com/api/sites/$($Site.id)/timezone" -ContentType $ContentType -Headers $headers).content | ConvertFrom-Json
    $maintenance = (Invoke-WebRequest -Method GET -Uri "https://nb.portal.arubainstanton.com/api/sites/$($Site.id)/maintenance" -ContentType $ContentType -Headers $headers).content | ConvertFrom-Json
    $Alerts = (Invoke-WebRequest -Method GET -Uri "https://nb.portal.arubainstanton.com/api/sites/$($Site.id)/alerts" -ContentType $ContentType -Headers $headers).content | ConvertFrom-Json
    $AlertsSummary = (Invoke-WebRequest -Method GET -Uri "https://nb.portal.arubainstanton.com/api/sites/$($Site.id)/alertsSummary" -ContentType $ContentType -Headers $headers).content | ConvertFrom-Json
    $applicationCategoryUsage = (Invoke-WebRequest -Method GET -Uri "https://nb.portal.arubainstanton.com/api/sites/$($Site.id)/applicationCategoryUsage" -ContentType $ContentType -Headers $headers).content | ConvertFrom-Json

    # Devices
    $Inventory = (Invoke-WebRequest -Method GET -Uri "https://nb.portal.arubainstanton.com/api/sites/$($Site.id)/inventory" -ContentType $ContentType -Headers $headers).content | ConvertFrom-Json
    $ClientSummary = (Invoke-WebRequest -Method GET -Uri "https://nb.portal.arubainstanton.com/api/sites/$($Site.id)/clientSummary" -ContentType $ContentType -Headers $headers).content | ConvertFrom-Json
    $WiredClientSummary = (Invoke-WebRequest -Method GET -Uri "https://nb.portal.arubainstanton.com/api/sites/$($Site.id)/wiredClientSummary" -ContentType $ContentType -Headers $headers).content | ConvertFrom-Json

    # Networks
    $WiredNetworks = (Invoke-WebRequest -Method GET -Uri "https://nb.portal.arubainstanton.com/api/sites/$($Site.id)/wiredNetworks" -ContentType $ContentType -Headers $headers).content | ConvertFrom-Json
    $networksSummary = (Invoke-WebRequest -Method GET -Uri "https://nb.portal.arubainstanton.com/api/sites/$($Site.id)/networksSummary" -ContentType $ContentType -Headers $headers).content | ConvertFrom-Json

    # Not Used in this example
    # $Summary = (Invoke-WebRequest -Method GET -Uri "https://nb.portal.arubainstanton.com/api/sites/$($Site.id)" -ContentType $ContentType -Headers $headers).content | ConvertFrom-Json
    # $capabilities = (Invoke-WebRequest -Method GET -Uri "https://nb.portal.arubainstanton.com/api/sites/$($Site.id)/capabilities" -ContentType $ContentType -Headers $headers).content | ConvertFrom-Json
    # $radiusNasSettings = (Invoke-WebRequest -Method GET -Uri "https://nb.portal.arubainstanton.com/api/sites/$($Site.id)/radiusNasSettings" -ContentType $ContentType -Headers $headers).content | ConvertFrom-Json
    # $reservedIpSubnets = (Invoke-WebRequest -Method GET -Uri "https://nb.portal.arubainstanton.com/api/sites/$($Site.id)/reservedIpSubnets" -ContentType $ContentType -Headers $headers).content | ConvertFrom-Json
    # $defaultWiredNetwork = (Invoke-WebRequest -Method GET -Uri "https://nb.portal.arubainstanton.com/api/sites/$($Site.id)/defaultWiredNetwork" -ContentType $ContentType -Headers $headers).content | ConvertFrom-Json
    # $guestPortalSettings = (Invoke-WebRequest -Method GET -Uri "https://nb.portal.arubainstanton.com/api/sites/$($Site.id)/guestPortalSettings" -ContentType $ContentType -Headers $headers).content | ConvertFrom-Json
    # $ClientBlacklist = (Invoke-WebRequest -Method GET -Uri "https://nb.portal.arubainstanton.com/api/sites/$($Site.id)/clientBlacklist" -ContentType $ContentType -Headers $headers).content | ConvertFrom-Json
    # $applicationCategoryUsageConfiguration = (Invoke-WebRequest -Method GET -Uri "https://nb.portal.arubainstanton.com/api/sites/$($Site.id)/applicationCategoryUsageConfiguration" -ContentType $ContentType -Headers $headers).content | ConvertFrom-Json

    $SiteDetails = [PSCustomObject]@{
        'Wired Clients'                              = $LandingPage.wiredClientsCount
        'Wireless Clients'                           = $LandingPage.wirelessClientsCount
        'Active Wired Networks'                      = "$($LandingPage.currentlyActiveWiredNetworksCount) / $($LandingPage.configuredWiredNetworksCount)"
        'Active Wireless Networks'                   = "$($LandingPage.currentlyActiveWirelessNetworksCount) / $($LandingPage.configuredWirelessNetworksCount)"
        'Data Transferred in the last 24 hours (GB)' = [math]::round(($LandingPage.totalDataTransferredDuringLast24HoursInBytes / 1024 / 1024 / 1024), 2)
        'Health'                                     = $LandingPage.health
        'Health Reason'                              = $LandingPage.healthReason
        'Timezone'                                   = $($timezone.timezoneIana)
        'Maintenance Window'                         = "$($maintenance.day) - $($maintenance.startTime)"
    }

    $SiteDetailsHTML = ($SiteDetails | ConvertTo-Html -As List -Fragment | Out-String) -replace $TableStyling

    $AdminsHTML = ($administration.accounts | Select-Object @{n = 'Email'; e = { $_.email } }, @{n = 'Active'; e = { $_.isActivated } }, @{n = 'Primary Account'; e = { $_.isPrimaryAccount } } | ConvertTo-Html -Fragment | Out-String) -replace $TableStyling

    $AlertsHTML = ($alerts.elements | Select-Object @{n = 'Created'; e = { (Get-Date 01.01.1970) + ([System.TimeSpan]::fromseconds($_.raisedTime)) } }, @{n = 'Resolved'; e = { (Get-Date 01.01.1970) + ([System.TimeSpan]::fromseconds($_.clearedTime)) } }, @{n = 'Type'; e = { $_.type } }, @{n = 'Severity'; e = { $_.severity } } | ConvertTo-Html -Fragment | Out-String) -replace $TableStyling

    $WiredNetworksHTML = ($WiredNetworks.elements | Select-Object @{n = 'Name'; e = { $_.wiredNetworkName } }, @{n = 'Management'; e = { $_.isManagement } }, @{n = 'Enabled'; e = { $_.isEnabled } }, @{n = 'Wireless Networks'; e = { $_.wirelessnetworks.networkname -join ', ' } } | ConvertTo-Html -Fragment | Out-String) -replace $TableStyling

    $WirelessNetworksHTML = ($networksSummary.elements | Select-Object @{n = 'Name'; e = { $_.networkName } }, @{n = 'Type'; e = { $_.type } }, @{n = 'Enabled'; e = { $_.isEnabled } }, @{n = 'SSID Hidden'; e = { $_.isSsidHidden } }, @{n = 'Authentication'; e = { $_.authentication } }, @{n = 'Security'; e = { $_.security } }, @{n = 'Captive Portal Enabled'; e = { $_.isCaptivePortalEnabled } } | ConvertTo-Html -Fragment | Out-String) -replace $TableStyling

    $ApplicationUsageHTML = ($applicationCategoryUsage.elements | Where-Object { $_.downstreamDataTransferredDuringLast24HoursInBytes -gt 0 -or $_.upstreamDataTransferredDuringLast24HoursInBytes -gt 0 } `
        | Sort-Object downstreamDataTransferredDuringLast24HoursInBytes -Descending `
        | Select-Object @{n = 'Name'; e = { $_.networkSsid } }, `
        @{n = 'Category'; e = { $_.applicationCategory } }, `
        @{n = 'Downloaded in last 24 hours (GBs)'; e = { [math]::Round(($_.downstreamDataTransferredDuringLast24HoursInBytes / 1024 / 1024 / 1024), 2) } }, `
        @{n = 'Uploaded in last 24 hours (GBs)'; e = { [math]::Round(($_.upstreamDataTransferredDuringLast24HoursInBytes / 1024 / 1024 / 1024), 2) } } `
        | ConvertTo-Html -Fragment | Out-String) -replace $TableStyling

    $WirelessClientsHTML = ($ClientSummary.elements | Select-Object @{n = 'Name'; e = { $_.name } }, @{n = 'Network'; e = { $_.NetworkSsid } }, @{n = 'IP Address'; e = { $_.ipAddress } }, @{n = 'AP'; e = { $_.apName } }, @{n = 'Protocol'; e = { $_.wirelessProtocol } }, @{n = 'Security'; e = { $_.wirelessSecurity } }, @{n = 'Connected (Hours)'; e = { [math]::Round(($_.connectionDurationInSeconds / 60 / 60), 2) } }, @{n = 'Signal Quality'; e = { $_.signalQuality } }, @{n = 'Signal'; e = { $_.signalInDbm } }, @{n = 'Noise'; e = { $_.noiseInDbm } }, @{n = 'SNR'; e = { $_.snrInDb } } | ConvertTo-Html -Fragment | Out-String) -replace $TableStyling

    $WiredClientsHTML = ($WiredClientSummary.elements | Select-Object @{n = 'Name'; e = { $_.name } }, @{n = 'MAC'; e = { $_.macAddress } }, @{n = 'Type'; e = { $_.clientType } }, @{n = 'Voice Device'; e = { $_.isVoiceDevice } }, @{n = 'IP Address'; e = { $_.ipAddress } } | ConvertTo-Html -Fragment | Out-String) -replace $TableStyling


    $SiteFields = @{
        'site_name'         = $($Site.name)
        'site_details'      = $SiteDetailsHTML
        'admins'            = $AdminsHTML
        'alerts'            = $AlertsHTML
        'wired_networks'    = $WiredNetworksHTML
        'wireless_networks' = $WirelessNetworksHTML
        'application_usage' = $ApplicationUsageHTML
        'clients'           = "<h3>Wireless Clients</h3>$WirelessClientsHTML<h3>Wired Clients</h3>$WiredClientsHTML"
    }


    $AssetName = $($Site.name)
    if (!$SiteAsset) {
        $companyid = $company.id
        Write-Host 'Creating new Asset'
        $SiteAsset = (New-HuduAsset -name $AssetName -company_id $companyid -asset_layout_id $SiteLayout.id -fields $SiteFields).asset
    } else {
        $companyid = $SiteAsset.company_id
        Write-Host 'Updating Asset'
        $SiteAsset = (Set-HuduAsset -asset_id $SiteAsset.id -name $AssetName -company_id $companyid -asset_layout_id $SiteLayout.id -fields $SiteFields).asset
    }


    $LinkRaw = @{
        id   = $SiteAsset.id
        name = $SiteAsset.name
    }

    $Link = $LinkRaw | ConvertTo-Json -Compress -AsArray | Out-String


    $DeviceAssets = foreach ($device in $Inventory.elements) {

        $RadiosHTML = ($device.radios | Select-Object @{n = 'MAC'; e = { $_.id } }, @{n = 'Band'; e = { $_.band } }, @{n = 'Channel'; e = { $_.channel } }, @{n = 'Clients'; e = { $_.wirelessClientsCount } }, @{n = 'Radio Power'; e = { $_.radioPower } }, @{n = 'Power Dbm'; e = { $_.txPowerEirpInDbm } }, @{n = 'In Use'; e = { $_.isRadioInUse } } | ConvertTo-Html -Fragment | Out-String) -replace $TableStyling

        # The port map status table is based off Kelvin Tegelaar's Unifi documentation script
        if (($Device.ethernetports | Measure-Object).count -gt 1) {
            $SwitchPortsStatusHTML = $(
                '<h3>Ports Status</h3><table><tr>'
                foreach ($Port in $Device.ethernetports) {
                    "<th>$($port.portNumber)</th>"
                }
                '</tr><tr>'
                foreach ($Port in $Device.ethernetports) {
                    $colour = if ($port.isLinkUp -eq $true) { '02ab26' } else { 'ad2323' }
                    $speed = switch ($port.speed) {
                        'mbps10000' { '10Gb' }
                        'mbps1000' { '1Gb' }
                        'mbps100' { '100Mb' }
                        'mbps10' { '10Mb' }
                        'mbps0' { 'Port off' }
                    }
                    "<td style='background-color:#$($colour)'>$speed</td>"
                }
                '</tr><tr>'
                foreach ($Port in $Device.ethernetports) {
                    $poestate = if ($port.poePseStatus -eq 'deliveringPower') { 'PoE on'; $colour = '02ab26' } elseif ($port.poePseStatus -eq 'searching') { 'No PoE'; $colour = '#696363' } elseif ($port.poePseStatus -eq 'otherFault') { 'Fault'; $colour = '#696363' }else { 'PoE Off'; $colour = 'ad2323' }
                    "<td style='background-color:#$($colour)'>$Poestate</td >"
                }
                '</tr></table><br/>'
            )
        }

        $SwitchPortsDetailHTML = ($device.ethernetports | Select-Object @{n = 'Name'; e = { $_.name } }, `
            @{n = 'No'; e = { $_.portNumber } }, `
            @{n = 'PoE Prov'; e = { $_.isProvidingPower } }, `
            @{n = 'PoE MW Prov'; e = { $_.powerProvidedInMilliwatts } }, `
            @{n = 'PoE MW Req'; e = { $_.powerRequestedInMilliwatts } }, `
            @{n = 'PoE Status'; e = { $_.poePseStatus } }, `
            @{n = 'PoE HW Status'; e = { $_.poePseHardwareStatus } }, `
            @{n = 'Speed'; e = { $_.speed } }, `
            @{n = 'Link Up'; e = { $_.isLinkUp } }, `
            @{n = 'Loop'; e = { $_.isLoopDetected } }, `
            @{n = 'Direct Device'; e = { $_.directlyConnectedDeviceName } }, `
            @{n = 'Uplink Device'; e = { $_.uplinkDeviceName } }, `
            @{n = 'Downloaded GBs'; e = { [math]::Round(($_.downstreamDataTransferredInBytes / 1024 / 1024 / 1024), 2) } }, `
            @{n = 'Uploaded GBs'; e = { [math]::Round(($_.upstreamDataTransferredInBytes / 1024 / 1024 / 1024), 2) } } `
            | ConvertTo-Html -Fragment | Out-String) -replace $TableStyling

        $SwitchPortHTML = "$($SwitchPortsStatusHTML)<h3>Port Details</h3>$SwitchPortsDetailHTML"

        $ActiveDeviceAlertsHTML = ($Device.ActiveAlerts | Select-Object @{n = 'Created'; e = { (Get-Date 01.01.1970) + ([System.TimeSpan]::fromseconds($_.raisedTime)) } }, @{n = 'Open for (hours)'; e = { [math]::round(($_.numberOfSecondsSinceRaised / 60 / 60), 2) } }, @{n = 'Type'; e = { $_.type } }, @{n = 'Severity'; e = { $_.severity } } | ConvertTo-Html -Fragment | Out-String) -replace $TableStyling

        $DeviceClients = $ClientSummary.elements | Where-Object { $_.apName -eq $device.name }
        $DeviceClientsHTML = ($DeviceClients | Select-Object @{n = 'Name'; e = { $_.name } }, @{n = 'Network'; e = { $_.NetworkSsid } }, @{n = 'IP Address'; e = { $_.ipAddress } }, @{n = 'AP'; e = { $_.apName } }, @{n = 'Protocol'; e = { $_.wirelessProtocol } }, @{n = 'Security'; e = { $_.wirelessSecurity } }, @{n = 'Connected (Hours)'; e = { [math]::Round(($_.connectionDurationInSeconds / 60 / 60), 2) } }, @{n = 'Signal Quality'; e = { $_.signalQuality } }, @{n = 'Signal'; e = { $_.signalInDbm } }, @{n = 'Noise'; e = { $_.noiseInDbm } }, @{n = 'SNR'; e = { $_.snrInDb } } | ConvertTo-Html -Fragment | Out-String) -replace $TableStyling

        $DeviceFields = @{
            'device_name'    = $device.name
            'site'           = $link
            'management_url' = "<a href=https://portal.arubainstanton.com/#/site/$($Site.ID)/home/view/inventory/devices>https://portal.arubainstanton.com/#/site/$($Site.ID)/home/view/inventory/devices</a>"
            'type'           = $device.deviceType
            'ip'             = $device.ipAddress
            'mac'            = $device.macAddress
            'serial_number'  = $device.serialNumber
            'model'          = $device.model
            'uptime'         = "$([math]::Round(($device.uptimeInSeconds /60 / 60 / 24),2)) Days"
            'radios'         = $RadiosHTML
            'ethernet_ports' = $SwitchPortHTML
            'alerts'         = $ActiveDeviceAlertsHTML
            'clients'        = $DeviceClientsHTML
        }

        Write-Host "Pushing $($device.name) to Hudu"
        $AssetName = $device.name
        $companyid = $SiteAsset.company_id

        #Check if there is already an asset
        $DeviceAsset = Get-HuduAssets -name $AssetName -companyid $companyid -assetlayoutid $DeviceLayout.id

        if (!$DeviceAsset) {
            Write-Host 'Creating new Asset'
            (New-HuduAsset -name $AssetName -company_id $companyid -asset_layout_id $DeviceLayout.id -fields $DeviceFields).asset
        } else {
            Write-Host 'Updating Asset'
            (Set-HuduAsset -asset_id $DeviceAsset.id -name $AssetName -company_id $companyid -asset_layout_id $DeviceLayout.id -fields $DeviceFields).asset
        }



    }

    $Shade = 'success'
    if ($AlertsSummary.activeInfoAlertsCount -gt 0 -or $AlertsSummary.activeMinorAlertsCount -gt 0) {
        $Shade = 'warning'
    }

    if ($AlertsSummary.activeMajorAlertsCount -gt 0) {
        $Shade = 'danger'
    }

    $DeviceCount = ($Inventory.elements | Measure-Object).count
    $UpDevices = ($Inventory.elements | Where-Object { $_.status -eq 'up' } | Measure-Object).count


    $SiteManagementURL = "https://portal.arubainstanton.com/#/site/$($Site.ID)/home/view/inventory/devices"
    $LinkDeviceHTML = foreach ($LinkDevice in $DeviceAssets) {
        "<div class='basic_info__section'>
        <h2>$($LinkDevice.name)</h2>
        <p>
            <a href=$($LinkDevice.url)>View Device in Hudu</a> | <a href=$SiteManagementURL>View Device in Aruba</a>
        </p>
        </div>"
    }



    $LinkedDevicesHTML = "<div class='nasa__block'>
							<header class='nasa__block-header'>
							<h1><i class='fas fa-info-circle icon'></i>Devices</h1>
							 </header>
								<main>
								<article>
								$LinkDeviceHTML
						</article>
						</main>
						</div>"


    $SiteDetailsFormattedHTML = "<div class='nasa__block'>
        <header class='nasa__block-header'>
        <h1><i class='fas fa-info-circle icon'></i>Site Details</h1>
        </header>
        <main>
        <article>
        $SiteDetailsHTML
        </article>
        </main>
        </div>"

    $body = "<div class='nasa__block'>
			<header class='nasa__block-header'>
			<h1><a href=$($SiteAsset.url)><i class='fas fa-wifi icon'></i>$($site.name)</a></h1>
	 		</header>
             </div>
             <br/>
			<div class=`"nasa__content`">
			$SiteDetailsFormattedHTML
            $LinkedDevicesHTML
			 </div>
			 <br/>
             <div class='nasa__block'>
			<header class='nasa__block-header'>
			<h1><i class='fas fa-exclamation-triangle'></i> Alerts</h1>
	 		</header>
			 <div>$AlertsHTML</div>
             </div>
			 "
    # Create a Magic Dash
    $null = Set-HuduMagicDash -title "Aruba IO - $($site.name)" -company_name $SiteAsset.company_name -message "$UpDevices / $DeviceCount Online" -icon 'fas fa-wifi' -content $body -shade $Shade


}

