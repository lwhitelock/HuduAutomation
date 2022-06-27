
#### Settings ####

$ArubaInstantOnUser = 'api-user@yourdomain.com'
$ArubaInstantOnPass = 'Make a long randomly generated password for the account that you save securely'
ReportRoot = "Directory to hold the report directory"
$ReportFolder = "Directory to place the report files"
$ReportPath = "$ReportRoot\$ReportFolder"

#Check and create report path
$FolderExist = Test-Path -Path $ReportPath

#If Folder doesn't exist - Make it
If ($FolderExist -eq $False){
	#Create Folder
	New-Item -Path "$ReportRoot" -Name $ReportFolder -ItemType "directory"
}

#### Functions ####

function Get-URLEncode{
    param(
        [Byte[]]$Bytes
    )
    # Convert to Base 64
    $EncodedText =[Convert]::ToBase64String($Bytes)

    # Calculate Number of Padding Chars
    $Found = $false
    $EndPos = $EncodedText.Length
    do{
        if ($EncodedText[$EndPos] -ne '='){
            $found = $true
        }    
        $EndPos = $EndPos -1
    } while ($found -eq $false)

    # Trim the Padding Chars
    $Stripped = $EncodedText.Substring(0, $EndPos)
    
    # Add the number of padding chars to the end
    $PaddingNumber = "$Stripped$($EncodedText.Length - ($EndPos + 1))" 

    # Replace Characters
    $URLEncodedString = $PaddingNumber -replace [RegEx]::Escape("+"), '-' -replace [RegEx]::Escape("/"), '_'
    
    return $URLEncodedString

}


#### Start ####
If (Get-Module -ListAvailable -Name "PsWriteHTML") { 
    Import-module PswriteHTML
}
Else { 
    Install-Module PsWriteHTML -Force
    Import-Module PsWriteHTML
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
$Token = (Invoke-WebRequest -Method POST -Uri "https://sso.arubainstanton.com/aio/api/v1/mfa/validate/full" -body $LoginRequest -ContentType $ContentType).content | ConvertFrom-Json

# Dowmload the global settings and get the Client ID incase this changes.
$OAuthSettings = (Invoke-WebRequest -Method Get -Uri "https://portal.arubainstanton.com/settings.json") | ConvertFrom-Json
$ClientID = $OAuthSettings.ssoClientIdAuthZ

# Use the initial token to perform the authorisation
$URL = "https://sso.arubainstanton.com/as/authorization.oauth2?client_id=$ClientID&redirect_uri=https://portal.arubainstanton.com&response_type=code&scope=profile%20openid&state=$State&code_challenge_method=S256&code_challenge=$CodeChallenge&sessionToken=$($Token.access_token)"
$AuthCode = Invoke-WebRequest -Method GET -Uri $URL -MaximumRedirection 1

# Extract the code returned in the redirect URL
if ($null -ne $AuthCode.BaseResponse.ResponseUri) {
    # This is for Powershell 5
    $redirectUri = $AuthCode.BaseResponse.ResponseUri
}
elseif ($null -ne $AuthCode.BaseResponse.RequestMessage.RequestUri) {
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

$LoginCode = ($ParsedQueryParams | where-object { $_.name -eq 'code' }).value

# Build the form data to request an actual token
$TokenAuth = @{
    client_id     = $ClientID
    redirect_uri  = 'https://portal.arubainstanton.com'
    code          = $LoginCode
    code_verifier = $CodeVerifier
    grant_type    = 'authorization_code'

}

# Obtain the Bearer Token
$Bearer = (Invoke-WebRequest -Method POST -Uri "https://sso.arubainstanton.com/as/token.oauth2" -body $TokenAuth -ContentType $ContentType).content | ConvertFrom-Json


# Get the headers ready for talking to the API. Note you get 500 errors if you don't include x-ion-api-version 7 for some endpoints and don't get full data on others
$ContentType = 'application/json'
$headers = @{
    Authorization       = "Bearer $($Bearer.access_token)"
    'x-ion-api-version' = 7
}

# Get all sites under account
$Sites = (Invoke-WebRequest -Method GET -Uri "https://nb.portal.arubainstanton.com/api/sites/" -ContentType $ContentType -Headers $headers).content | ConvertFrom-Json

# Loop through each site and create documentation
foreach ($site in $sites.Elements) {
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
    
    # Clients
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

    New-HTML -Title 'Aruba Instant On Details' -FilePath "$ReportPath\$($Site.name).html" {
        New-HTMLTAb -Name 'Site Summary' {
            New-HTMLSection -HeaderText 'Summary' {
                $LandingPage | Select-Object -ExcludeProperty kind | convertto-html -as list -Fragment
            }
            New-HTMLSection -HeaderText 'Other Settings' {
                "Timezone: $($timezone.timezoneIana)<br/>"
                "Maintenance Time: $($maintenance.day) - $($maintenance.startTime)<br/>"
            }
            New-HTMLSection -HeaderText 'Admins' {
                $administration.accounts | select-object email, isActivated, isPrimaryAccount | convertto-html -Fragment
            }
            New-HTMLSection -HeaderText 'Alerts Summary' {
                "Active Info Alerts: $($AlertsSummary.activeInfoAlertsCount) <br/>"
                "Active Minor Alerts: $($AlertsSummary.activeMinorAlertsCount) <br/>"
                "Active Major Alerts: $($AlertsSummary.activeMajorAlertsCount) <br/>"
            }
            New-HTMLSection -HeaderText 'Alerts' {
                New-HTMLTable -DataTable ($alerts.elements | Select-Object kind, type, severity, @{n = 'Created'; e = { (Get-Date 01.01.1970) + ([System.TimeSpan]::fromseconds($_.raisedTime)) } }, @{n = 'Resolved'; e = { (Get-Date 01.01.1970) + ([System.TimeSpan]::fromseconds($_.clearedTime)) } })
            }
            New-HTMLSection -HeaderText 'Application Usage' {
                New-HTMLTable -DataTable ($applicationCategoryUsage.elements | sort-object downstreamDataTransferredDuringLast24HoursInBytes -Descending | Select-Object networkSsid, applicationCategory, downstreamDataTransferredDuringLast24HoursInBytes, upstreamDataTransferredDuringLast24HoursInBytes)
            }
        }
        New-HTMLTab -Name 'Networks' {
            New-HTMLSection -HeaderText 'Wireless Networks' {
                New-HTMLTable -DataTable ($networksSummary.elements | select-object networkName, type, isEnabled, isSsidHidden, authentication, security, preSharedKey)
            }
            New-HTMLSection -HeaderText 'Wired Networks' {
                New-HTMLTable -DataTable ($WiredNetworks.elements | select-object wiredNetworkName, isManagement, isEnabled)
            }
          
        }
        New-HTMLTab -Name 'Devices' {
            New-HTMLSection -HeaderText 'Devices' {
                New-HTMLTable -DataTable ($Inventory.elements | Select-Object deviceType, name, status, operationalState, ipAddress, macAddress, model, serialNumber, uptimeInSeconds)
            }
          
        }
        New-HTMLTab -Name 'Clients' {
            New-HTMLSection -HeaderText 'Wireless Clients' {
                New-HTMLTable -DataTable ($ClientSummary.elements | Select-Object name, NetworkSsid, ipAddress, apName, wirelessProtocol, wirelessSecurity, connectionDurationInSeconds, signalQuality, signalInDbm, noiseInDbm, snrInDb)
            }
            New-HTMLSection -HeaderText 'Wired Clients' {
                New-HTMLTable -DataTable ($WiredClientSummary.elements | Select-Object name, macAddress, clientType, isVoiceDevice, ipAddress)
            }
        }
            
    }
}
