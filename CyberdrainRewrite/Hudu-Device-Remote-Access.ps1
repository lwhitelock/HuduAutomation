##### Variables
$CheckTools = "Screenconnect", "RemoteDesktop", "TakeControl", "DattoWebRemote", "Teamviewer"
$ScreenconnectURL = "https://YourScreenConnectURL.com/access"
#####
########################## Hudu ############################
# Get a Hudu API Key from https://yourhududomain.com/admin/api_keys
$HuduAPIKey = "abcdefghijklmnop"
# Set the base domain of your Hudu instance without a trailing /
$HuduBaseDomain = "https://your-hudu.domain"
$TableStyling = "<th>", "<th style=`"background-color:#4CAF50`">"
# This will be appended to the name of the Asset type this computer is created in Hudu as.
$HuduAssetLayoutName = "Remote Access logs"
# The company name for the device in Hudu
$CompanyName = "Example Company"
#####################################################################


#Get the Hudu API Module if not installed
if (Get-Module -ListAvailable -Name HuduAPI) {
    Import-Module HuduAPI 
}
else {
    Install-Module HuduAPI -Force
    Import-Module HuduAPI
}


#Set Hudu logon information
New-HuduAPIKey $HuduAPIKey
New-HuduBaseUrl $HuduBaseDomain

$Company = Get-HuduCompanies -name $CompanyName
if ($company) {	
    #This is the data we'll be sending to Hudu
		
    $ComputerName = $($Env:COMPUTERNAME)
			
    #Find the parent asset from serial
    $ParentAsset = Get-HuduAssets -primary_serial (get-ciminstance win32_bios).serialnumber
			
    # See if there is only one parent asset
    if (($ParentAsset | measure-object).count -ne 1) {
        $ParentAsset = Get-HuduAssets -companyid $company.id -name $ComputerName
    }

    # Check we found an Asset
    if (($ParentAsset | measure-object).count -eq 1) {
        $Layout = Get-HuduAssetLayouts -name $HuduAssetLayoutName

        if (!$Layout) { 
            $AssetLayoutFields = @(
                @{
                    label        = 'Device Name'
                    field_type   = 'Text'
                    show_in_list = 'true'
                    position     = 1
                },
                @{
                    label        = 'Device'
                    field_type   = 'AssetTag'
                    show_in_list = 'false'
                    linkable_id  = $ParentAsset.asset_layout_id
                    position     = 2
                },
                @{
                    label        = 'Access Methods'
                    field_type   = 'RichText'
                    show_in_list = 'false'
                    position     = 3
                },
                @{
                    label        = 'Logs'
                    field_type   = 'RichText'
                    show_in_list = 'false'
                    position     = 4
                }
            )
    
            Write-Host "Creating New Asset Layout $HuduAssetLayoutName"
            $Null = New-HuduAssetLayout -name $HuduAssetLayoutName -icon "fas fa-book" -color "#4CAF50" -icon_color "#ffffff" -include_passwords $false -include_photos $false -include_comments $false -include_files $false -fields $AssetLayoutFields
            $Layout = Get-HuduAssetLayouts -name $HuduAssetLayoutName
        }

 
        function get-ScreenconnectInfo {
            param (
                $URL
            )
            $null = (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\ScreenConnect Client *' -Name ImagePath).ImagePath -Match '(&s=[a-f0-9\-]*)'
            $GUID = $Matches[0] -replace '&s='
            $RawLog = get-winevent -FilterHashtable @{
                Logname      = 'Application'
                ProviderName = 'Screenconnect*'
                StartTime    = (get-date).adddays(-7)
            } | Where-Object -Property LeveldisplayName -ne "error"
 
            $AuditLog = foreach ($log in $Rawlog) {
                switch -Wildcard ($log.message) {
                    "*Disconnected*" { $reason = 'Disconnected' }
                    "*connected*" { $reason = 'Connected' }
                    "**Transfer*" { $reason = 'File Transfer' }
                }
                [PSCustomObject]@{
                    Type    = "Screenconnect"
                    Date    = $log.TimeCreated
                    Reason  = $Reason
                    Message = $log.message
                }
            }
 
            $RemoteControlURL = "$ScreenconnectURL/$guid//Join"
            [PSCustomObject]@{
                'Type'              = "Screenconnect / Control"
                'Enabled'           = if ($guid) { $true } else { $false }
                'RemoteControl URL' = $RemoteControlURL
                AuditLog            = $auditLog
            }
        }
 
 
        function Get-RDPInfo {
            $enabled = (get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\').fDenyTSConnections
            $RawLog = get-winevent -FilterHashtable @{
                Logname   = 'Microsoft-Windows-TerminalServices-LocalSessionManager/Operational'
                StartTime = (get-date).adddays(-7)
                ID        = 21, 22, 24, 25, 39, 40
            } | Where-Object -Property LeveldisplayName -ne "error" | Where-Object { $_.message -notlike "*Source Network Address: LOCAL*" }
 
            $AuditLog = foreach ($log in $Rawlog) {
                switch -Wildcard ($log.message) {
                    "*Disconnected*" { $reason = 'Disconnected' }
                    "*reconnection*" { $reason = 'Reconnected' }
                    "*Shell Start*" { $reason = 'Connected' }
                }
                [PSCustomObject]@{
                    Type    = "RDP"
                    Date    = $log.TimeCreated
                    Reason  = $Reason
                    Message = $log.message
                }
            }
 
            [PSCustomObject]@{
                'Type'              = "RDP"
                'Enabled'           = [bool]!$enabled
                'RemoteControl URL' = "mstsc /v $ENV:COMPUTERNAME"
                AuditLog            = $auditLog
            }
        }
 
 
        function Get-TakeControlInfo {
            $enabled = (Test-Path 'HKLM:\SYSTEM\CurrentControlSet\Services\BASupportExpressStandaloneService*' -erroraction SilentlyContinue)
            $RawLog = get-winevent -FilterHashtable @{
                Logname      = 'Application'
                Providername = 'Solarwinds*'
                StartTime    = (get-date).adddays(-7)
                ID           = 8193, 4102
            } 
 
            $AuditLog = foreach ($log in $Rawlog) {
                switch -Wildcard ($log.message) {
                    "*Session ended*" { $reason = 'Disconnected' }
                    "*Logged*" { $reason = 'Connected' }
                }
                [PSCustomObject]@{
                    Type    = "TakeControl"
                    Date    = $log.TimeCreated
                    Reason  = $Reason
                    Message = $log.message
                }
            }
 
            [PSCustomObject]@{
                'Type'              = "Takecontrol"
                'Enabled'           = $enabled
                'RemoteControl URL' = "mspancsxvp:/$ENV:COMPUTERNAME"
                AuditLog            = $auditLog
            }
        }
 
        function Get-DattoWebInfo {
            $enabled = (Test-Path "C:\ProgramData\CentraStage\AEMAgent\DataLog\webremote.log" -erroraction SilentlyContinue)
            $RawLog = get-content "C:\ProgramData\CentraStage\AEMAgent\DataLog\webremote.log" -ErrorAction SilentlyContinue | convertfrom-csv -Delimiter ' ' -Header Version, datetime, processid, threadid, level, message | Where-Object -Property Message -like "*WEBRTC*"
 
            $AuditLog = foreach ($log in $Rawlog) {
                switch -Wildcard ($log.message) {
                    "*REQUEST*" { $reason = 'Request to join session' }
                    "*|WEBRTC|JOIN" { $reason = 'Joined session' }
                    "*CLOSED*" { $reason = 'Disconnected session' }
                    default { $reason = "INFO" }
                }
                [PSCustomObject]@{
                    Type    = "Datto Web"
                    Date    = $log.DateTime
                    Reason  = $Reason
                    Message = $log.message
                }
            }
 
            [PSCustomObject]@{
                'Type'              = "Datto Web Remote"
                'Enabled'           = $enabled
                'RemoteControl URL' = "Not Available"
                AuditLog            = $auditLog
            }
        }
 
 
        function Get-TeamviewerInfo {
            $enabledQS = (Test-Path "C:\Users\*\AppData\Roaming\TeamViewer" -erroraction SilentlyContinue)
            $enabledPermantely = (Test-Path "C:\Program Files *\TeamViewer" -erroraction SilentlyContinue)
            if ($enabledQS) { $enabled = "True - Via Quick Support" }
            if ($enabledPermantely) { $enabled = "True, full installation" }
            $RawLog = get-item "C:\Users\*\AppData\Roaming\TeamViewer\Connections_incoming.txt", "C:\Program Files*\TeamViewer\Connections_incoming.txt" | get-content | convertfrom-csv -Delimiter "`t" -Header ExternalID, ExternalHostname, ConnectedAt, DisconnectedAt, Username, Action, ID
 
            $AuditLog = foreach ($log in $Rawlog) {
                $Reason = "Event"
                $message = "ID $($log.externalid) with hostname $($log.externalhostname) connected to username $($log.username) at $($log.connectedat) and disconnected at $($log.disconnectedat)"
                [PSCustomObject]@{
                    Type    = "Teamviewer"
                    Date    = $log.ConnectedAt
                    Reason  = $Reason
                    Message = $message
                }
            }
 
            [PSCustomObject]@{
                'Type'              = "Teamviewer"
                'Enabled'           = $enabled
                'RemoteControl URL' = "Not Available"
                AuditLog            = $auditLog
            }
        }
 
 
 
        $Data = foreach ($tool in $CheckTools) {
            switch ($tool) {
                "Screenconnect" { Get-ScreenconnectInfo -url $ScreenconnectURL }
                "RemoteDesktop" { Get-RDPInfo }
                "TakeControl" { Get-TakeControlInfo }
                "DattoWebRemote" { Get-DattoWebInfo }
                "Teamviewer" { get-TeamviewerInfo }
            }
        }
 
 
        # Get  the link for the device.
        $LinkRaw = @{
            id   = $ParentAsset.id
            name = $ParentAsset.name
        }

        $Link = $LinkRaw | convertto-json -compress -AsArray | Out-String

        # Populate Asset Fields
        $AssetFields = @{
            'device_name'    = $($ENV:COMPUTERNAME)
            'device'         = $Link
            'access_methods' = ($Data | Select-Object Type, Enabled , 'RemoteControl URL' | convertto-html -frag | Out-String) -replace $TableStyling
            'logs'           = ($data.auditlog | ConvertTo-Html -frag | Out-String) -replace $TableStyling
        }

        $AssetName = "$($ENV:COMPUTERNAME) - Remote Access"

        $companyid = $Company.id


        write-host "Documenting to Hudu"  -ForegroundColor Green
        $Asset = Get-HuduAssets -name $AssetName -companyid $companyid -assetlayoutid $Layout.id

        #If the Asset does not exist, we edit the body to be in the form of a new asset, if not, we just upload.
        if (!$Asset) {
            Write-Host "Creating new Asset"
            $Asset = New-HuduAsset -name $AssetName -company_id $companyid -asset_layout_id $Layout.id -fields $AssetFields	
        }
        else {
            Write-Host "Updating Asset"
            $Asset = Set-HuduAsset -asset_id $Asset.id -name $AssetName -company_id $companyid -asset_layout_id $layout.id -fields $AssetFields	
        }



    }
    else {
        Write-Host "Device was not found or multiple matching devices found in Hudu"
    }
}
else {
    Write-Host "$CompanyName was not found in Hudu"
}
