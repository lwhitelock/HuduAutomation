# Based on the original script by Kelvin Tegelaar https://github.com/KelvinTegelaar/AutomaticDocumentation
#####################################################################
# Get a Hudu API Key from https://yourhududomain.com/admin/api_keys
$HuduAPIKey = 'abcdefg1234567898'
# Set the base domain of your Hudu instance without a trailing /
$HuduBaseDomain = 'https://your.hudu.domain'
$TableStyling = '<th>', "<th style=`"background-color:#4CAF50`">"
# This will be appended to the name of the Asset type this computer is created in Hudu as.
$HuduAppendedAssetLayoutName = ' - Logbook - Autodoc'
$CompanyName = "Device's Company Name"
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
    #This is the data we'll be sending to Hudu

    $ComputerName = $($Env:COMPUTERNAME)

    # Find the asset we are running from
    $ParentAsset = Get-HuduAssets -primary_serial (Get-CimInstance win32_bios).serialnumber

    $ParentCount = ($ParentAsset | Measure-Object).Count

    if ($ParentCount -ne 1) {
        $ParentAsset = Get-HuduAssets -companyid $company.id -name $ComputerName
    }

    # Check we found an Asset
    if ($ParentAsset) {

        $HuduAssetLayoutName = $ParentAsset.asset_type + $HuduAppendedAssetLayoutName
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
                    label        = 'Events'
                    field_type   = 'RichText'
                    show_in_list = 'false'
                    position     = 3
                },
                @{
                    label        = 'User Profiles'
                    field_type   = 'RichText'
                    show_in_list = 'false'
                    position     = 4
                },
                @{
                    label        = 'Installed Updates'
                    field_type   = 'RichText'
                    show_in_list = 'false'
                    position     = 5
                },
                @{
                    label        = 'Installed Software'
                    field_type   = 'RichText'
                    show_in_list = 'false'
                    position     = 6
                },
                @{
                    label        = 'Device'
                    field_type   = 'AssetLink'
                    show_in_list = 'false'
                    linkable_id  = $ParentAsset.asset_layout_id
                    position     = 2
                }
            )

            Write-Host "Creating New Asset Layout $HuduAssetLayoutName"
            $NewLayout = New-HuduAssetLayout -name $HuduAssetLayoutName -icon 'fas fa-book' -color '#4CAF50' -icon_color '#ffffff' -include_passwords $false -include_photos $false -include_comments $false -include_files $false -fields $AssetLayoutFields
            $Layout = Get-HuduAssetLayouts -name $HuduAssetLayoutName
        }




        Write-Host 'Starting documentation process.' -ForegroundColor green

        Write-Host 'Getting update history.' -ForegroundColor green
        $date = Get-Date
        $hotfixesInstalled = Get-HotFix

        Write-Host 'Getting User Profiles.' -ForegroundColor green

        $UsersProfiles = Get-CimInstance win32_userprofile | Where-Object { $_.special -eq $false } | Select-Object localpath, LastUseTime, Username
        $UsersProfiles = foreach ($Profile in $UsersProfiles) {
            $profile.username = ($profile.localpath -split '\', -1, 'simplematch') | Select-Object -Last 1
            $Profile
        }
        Write-Host 'Getting Installed applications.' -ForegroundColor green

        $InstalledSoftware = (Get-ChildItem 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\' | Get-ItemProperty) + ($software += Get-ChildItem 'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\' | Get-ItemProperty) | Select-Object Displayname, Publisher, Displayversion, InstallLocation, InstallDate
        $installedSoftware = foreach ($Application in $installedSoftware) {
            if ($null -eq $application.InstallLocation) { continue }
            if ($null -eq $Application.InstallDate) { $application.installdate = (Get-Item $application.InstallLocation -ErrorAction SilentlyContinue).CreationTime.ToString('yyyyMMdd') }
            $Application.InstallDate = [datetime]::parseexact($Application.InstallDate, 'yyyyMMdd', $null).ToString('yyyy-MM-dd HH:mm')
            if ($null -eq $application.InstallDate) { continue }
            $application
        }


        Write-Host 'Checking WAN IP' -ForegroundColor green
        $events = @()
        $previousIP = Get-Content "$($env:ProgramData)/LastIP.txt" -ErrorAction SilentlyContinue | Select-Object -First 1
        if (!$previousIP) { Write-Host 'No previous IP found. Compare will fail.' }
        $Currentip = (Invoke-RestMethod -Uri 'https://ipinfo.io/ip') -replace "`n", ''
        $Currentip | Out-File "$($env:ProgramData)/LastIP.txt" -Force

        if ($Currentip -ne $previousIP) {
            $Events += [pscustomobject]@{
                date  = $date.ToString('yyyy-MM-dd HH:mm')
                Event = "WAN IP has changed from $PreviousIP to $CurrentIP"
                type  = 'WAN Event'
            }
        }
        Write-Host 'Getting Installed applications in last 24 hours for events list' -ForegroundColor green
        $InstalledInLast24Hours = $installedsoftware | Where-Object { $_.installDate -ge $date.addhours(-24).tostring('yyyy-MM-dd') }
        foreach ($installation in $InstalledInLast24Hours) {
            $Events += [pscustomobject]@{
                date  = $installation.InstallDate
                Event = "New Software: $($Installation.displayname) has been installed or updated."
                type  = 'Software Event'
            }
        }
        Write-Host 'Getting KBs in last 24 hours for events list' -ForegroundColor green
        $hotfixesInstalled = Get-HotFix | Where-Object { $_.InstalledOn -ge $date.adddays(-2) }
        foreach ($InstalledHotfix in $hotfixesInstalled) {
            $Events += [pscustomobject]@{
                date  = $InstalledHotfix.installedOn.tostring('yyyy-MM-dd HH:mm')
                Event = "Update $($InstalledHotfix.Hotfixid) has been installed."
                type  = 'Update Event'
            }

        }
        Write-Host 'Getting user logon/logoff events of last 24 hours.' -ForegroundColor green
        $UserProfilesDir = Get-ChildItem 'C:\Users'
        foreach ($Users in $UserProfilesDir) {
            if ($users.CreationTime -gt $date.AddDays(-1)) {
                $Events += [pscustomobject]@{
                    date  = $users.CreationTime.tostring('yyyy-MM-dd HH:mm')
                    Event = "First time logon: $($Users.name) has logged on for the first time."
                    type  = 'User event'
                }
            }
            $NTUser = Get-Item "$($users.FullName)\NTUser.dat" -Force -ErrorAction SilentlyContinue
            if ($NTUser.LastWriteTime -gt $date.AddDays(-1)) {
                $Events += [pscustomobject]@{
                    date  = $NTUser.LastWriteTime.tostring('yyyy-MM-dd HH:mm')
                    Event = "Logoff: $($Users.name) has logged off or restarted the computer."
                    type  = 'User event'
                }
            }
            if ($NTUser.LastAccessTime -gt $date.AddDays(-1)) {
                $Events += [pscustomobject]@{
                    date  = $NTUser.LastAccessTime.tostring('yyyy-MM-dd HH:mm')
                    Event = "Logon: $($Users.name) has logged on."
                    type  = 'User event'

                }
            }
        }
        $events = $events | Sort-Object -Property date -Descending
        $eventshtml = ($Events | ConvertTo-Html -Fragment | Out-String) -replace $TableStyling
        $ProfilesHTML = ($UsersProfiles | ConvertTo-Html -Fragment | Out-String) -replace $TableStyling
        $updatesHTML = ($hotfixesInstalled | Select-Object InstalledOn, Hotfixid, caption, InstalledBy | ConvertTo-Html -Fragment | Out-String) -replace $TableStyling
        $SoftwareHTML = ($installedSoftware | ConvertTo-Html -Fragment | Out-String) -replace $TableStyling





        # Populate Asset Fields
        $AssetFields = @{
            'device_name'        = $ComputerName
            'events'             = $eventshtml
            'user_profiles'      = $ProfilesHTML
            'installed_updates'  = $UpdatesHTML
            'installed_software' = $SoftwareHTML
            'device'             = $ParentAsset.id
        }

        $AssetName = "$ComputerName - Logbook"

        $companyid = $ParentAsset.company_id

        $AssetFields | ConvertTo-Json | Out-File c:\temp\json.txt
        Write-Host "New-HuduAsset -name $AssetName -company_id $companyid -asset_layout_id $($Layout.id) -fields $AssetFields	"



        Write-Host 'Documenting to Hudu' -ForegroundColor Green
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
        Write-Host "An Asset was not found for $ComputerName"
    }


} else {
    Write-Host "$CompanyName was not found in Hudu"
}
