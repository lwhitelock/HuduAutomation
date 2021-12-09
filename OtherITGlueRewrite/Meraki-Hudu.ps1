###############
# Based on an original IT Glue script by Matt Dewart https://github.com/mdewart-springpoint

#### Hudu Settings ####
### Add matching variables to an Azure Key Vault you have access to
$VaultName = "YourAzureKeyVaultName";
$HuduAPIKey = Get-AzKeyVaultSecret -VaultName $VaultName -Name "HuduAPIKey" -AsPlainText
$HuduBaseDomain = Get-AzKeyVaultSecret -VaultName $VaultName -Name "HuduBaseDomain" -AsPlainText
$MerakiAPIKey = Get-AzKeyVaultSecret -VaultName $VaultName -Name "MerakiAPIKey" -AsPlainText
$HuduAssetLayoutName = "Meraki Networks"

##############
 
$TableStyling = "<th>", "<th style=`"background-color:#4CAF50`">"

#Settings Hudu information
if (Get-Module -ListAvailable -Name HuduAPI) {
    Import-Module HuduAPI 
} else {
    Install-Module HuduAPI -Force
    Import-Module HuduAPI
}
if (Get-Module -ListAvailable -Name PSMeraki) {
    Import-Module PSMeraki 
} else {
    Install-Module PSMeraki -Force
    Import-Module PSMeraki
}

Set-MrkRestApiKey -key $MerakiAPIKey

#Set Hudu logon information
New-HuduAPIKey $HuduAPIKey
New-HuduBaseUrl $HuduBaseDomain

# Prepare Asset Layouts
$NetworkLayout = Get-HuduAssetLayouts -name $HuduAssetLayoutName

if (!$NetworkLayout) { 
    $NetworkAssetLayoutFields = @(
        @{
            label        = 'Network Name'
            field_type   = 'Text'
            show_in_list = 'true'
            position     = 1
        },
        @{
            label        = 'Intrusion Detection'
            field_type   = 'RichText'
            show_in_list = 'false'
            position     = 2
        },
        @{
            label        = 'Content Filtering'
            field_type   = 'RichText'
            show_in_list = 'false'
            position     = 3
        },
        @{
            label        = 'Firewall Rules'
            field_type   = 'RichText'
            show_in_list = 'false'
            position     = 4
        },
        @{
            label        = 'IP and VLANs config'
            field_type   = 'RichText'
            show_in_list = 'false'
            position     = 5
        },
        @{
            label        = 'Wireless'
            field_type   = 'RichText'
            show_in_list = 'false'
            position     = 6
        },
        @{
            label        = 'Switching'
            field_type   = 'RichText'
            show_in_list = 'false'
            position     = 7
        },
        @{
            label        = 'Firmware Status'
            field_type   = 'RichText'
            show_in_list = 'false'
            position     = 8
        }
    )
	
    Write-Host "Creating New Asset Layout $HuduAssetLayoutName"
    $null = New-HuduAssetLayout -name $HuduAssetLayoutName -icon "fas fa-network-wired" -color "#4CAF50" -icon_color "#ffffff" -include_passwords $false -include_photos $false -include_comments $false -include_files $false -fields $NetworkAssetLayoutFields
    $NetworkLayout = Get-HuduAssetLayouts -name $HuduAssetLayoutName
}
 
Write-Host "Start documentation process." -ForegroundColor green
$MrkOrgs = Get-MrkOrganization
# id(int), name(string), url(string), @{apistatus}

foreach ($mrkOrg in $MrkOrgs) {
    $MrkNetworks = Get-MrkNetwork -orgId $mrkOrg.id
    # id, organizationid, name, producttypes, timeZone, tags, url, notes
    foreach ($mrkNetwork in $MrkNetworks) {
        #First we will see if there is an Asset that matches the site name with this Asset Layout
        Write-Host "Attempting to map $($mrkNetwork.name)"
        $NetworkAsset = Get-HuduAssets -name $($mrkNetwork.name) -assetlayoutid $NetworkLayout.id
        if (!$NetworkAsset) {
            #Check on company name
            $Company = Get-HuduCompanies -name $($mrkNetwork.name)
            if (!$company) {
                Write-Host "A company in Hudu could not be matched to the site. Please create a blank '$HuduAssetLayoutName' asset, with a name of `"$($mrkNetwork.name)`" under the company in Hudu you wish to map this site to."  -ForegroundColor Red
                continue
            }
        }
        Write-Host "Processing $($mrkNetwork.name)"

        $MrkDevices = Get-MrkDevice -networkId $mrkNetwork.id
        Remove-Variable intrusionraw, l3firwallraw, l7firewallraw, publicIP, vlansettings, wireless, switching, firmwaredetails, contentfiltering -ErrorAction SilentlyContinue

        If ($mrkNetwork.productTypes -contains 'appliance') {
            $intrusionraw = [PSCustomObject]@{
                Details = "Intrusion details not currently supported with PSMeraki 2.0.0 PowerShell module."
            }
            $contentfilteringraw = Get-MrkNetworkMxCfRule -networkId $mrkNetwork.id
            # urlCategoryListSize (topsites), blockedUrlCategories, blockedUrlPatterns, allowedUrlPatterns
            $vlansettingsraw = Get-MrkNetworkVLAN -networkId $mrkNetwork.id
            # id, networkId, name, applianceIp, subnet, fixedIpAssignments, reservedIpRanges, dnsnameservers, dhcpHandling
            $publicIPsettingsraw = Get-MrkDevicesStatus -orgId $mrkOrg.id | Where-Object { $_.productType -eq 'appliance' -and $_.networkId -eq $mrkNetwork.id }
            # name, serial, mac, publicIp, neworkId, status, lastreportedat, producttype, components(power supply), usingcellularfailover, wan1Ip, wan1Gateway, wan1IpType, wan1PrimaryDns, Wan1SecondaryDns, wan2Ip...
            If ($publicIPsettingsraw | Get-Member -Name wan2Gateway) {
                $publicIP = [PSCustomObject]@{
                    'Wan1 IP Type'       = $publicIPsettingsraw.wan1IpType
                    'Wan1 IP'            = $publicIPsettingsraw.wan1Ip
                    'Wan1 Gateway'       = $publicIPsettingsraw.wan1Gateway
                    'Wan1 Primary DNS'   = $publicIPsettingsraw.wan1PrimaryDns
                    'Wan1 Secondary DNS' = $publicIPsettingsraw.wan1SecondaryDns
                    'Wan2 IP Type'       = $publicIPsettingsraw.wan2IpType
                    'Wan2 IP'            = $publicIPsettingsraw.wan2Ip
                    'Wan2 Gateway'       = $publicIPsettingsraw.wan2Gateway
                    'Wan2 Primary DNS'   = $publicIPsettingsraw.wan2PrimaryDns
                    'Wan2 Secondary DNS' = $publicIPsettingsraw.wan2SecondaryDns
                }
            } else {
                $publicIP = [PSCustomObject]@{
                    'Wan1 IP Type'       = $publicIPsettingsraw.wan1IpType
                    'Wan1 IP'            = $publicIPsettingsraw.wan1Ip
                    'Wan1 Gateway'       = $publicIPsettingsraw.wan1Gateway
                    'Wan1 Primary DNS'   = $publicIPsettingsraw.wan1PrimaryDns
                    'Wan1 Secondary DNS' = $publicIPsettingsraw.wan1SecondaryDns
                }
            }

            $vlansettings = foreach ($vlan in $vlansettingsraw) {
                [PSCustomObject]@{
                    VLAN        = $vlan.id
                    Name        = $vlan.Name
                    Subnet      = $vlan.subnet
                    ApplianceIP = $vlan.applianceIp
                }
            }

            $l3firwallraw = (Get-MrkNetworkMXL3FwRule -networkId $mrkNetwork.id).rules
            $l7firewallraw = (Get-MrkNetworkMXL7FwRule -networkId $mrkNetwork.id).rules

            $contentfiltering = $contentfilteringraw | Select-Object @{n = "Category"; e = { ($contentfilteringraw.blockedUrlCategories.name | Sort-Object) -join ":::" } }, @{n = "BlockedURLs"; e = { ($contentfilteringraw.blockedUrlPatterns | Sort-Object) -join ":::" } }, @{n = "AllowedURLs"; e = { ($contentfilteringraw.allowedUrlPatterns | Sort-Object) -join ":::" } }            
        }# end if appliance


        If ($mrkNetwork.productTypes -contains 'switch') {
            $switchIPsettingsraw = Get-MrkDevicesStatus -orgId $mrkOrg.id | Where-Object { $_.productType -eq 'switch' -and $_.networkId -eq $mrkNetwork.id }
            $switchIPs = foreach ($mrkSwitchIPs in $switchIPsettingsraw) {
                [PSCustomObject]@{
                    Name    = $mrkSwitchIPs.Name
                    MAC     = $mrkSwitchIPs.mac
                    LanIP   = $mrkSwitchIPs.lanIp
                    Type    = $mrkSwitchIPs.iptype
                    Gateway = $mrkSwitchIPs.gateway
                    DNS1    = $mrkSwitchIPs.primaryDns
                    DNS2    = $mrkSwitchIPs.secondaryDns
                }
            }
            $switching = $switchIPs # + ports in the future
        }



        If ($mrkNetwork.productTypes -contains 'wireless') {
            $wirelessdevicesraw = $MrkDevices | Where-Object { ($_.networkId -eq $mrkNetwork.id) -and ($_.firmware -match 'wireless') }
            $wirelessdevices = foreach ($wapdevice in $wirelessdevicesraw) {
                [PSCustomObject]@{
                    Name  = $wapdevice.Name
                    LanIP = $wapdevice.lanip
                }
            }
            $wireless = $wirelessdevices
        }


        $endofsupportdetails = @"
        [{"Product":"Solar","EOS":"12/31/2015"},{"Product":"Wall Plug","EOS":"12/31/2015"},{"Product":"Mini","EOS":"9/25/2017"},{"Product":"Indoor","EOS":"6/30/2016"},{"Product":"MX50","EOS":"9/1/2016"},{"Product":"MX70","EOS":"3/31/2017"},{"Product":"MR11","EOS":"8/30/2017"},{"Product":"MR14","EOS":"8/30/2017"},{"Product":"OD2","EOS":"10/30/2017"},{"Product":"MR58","EOS":"10/30/2017"},{"Product":"MX90","EOS":"4/26/2021"},{"Product":"MS22","EOS":"4/26/2021"},{"Product":"MS22P","EOS":"4/26/2021"},{"Product":"MS42","EOS":"4/26/2021"},{"Product":"MS42P","EOS":"4/26/2021"},{"Product":"MR16","EOS":"5/31/2021"},{"Product":"MR24","EOS":"5/31/2021"},{"Product":"ANT-11","EOS":"4/24/2022"},{"Product":"ANT-13","EOS":"4/24/2022"},{"Product":"MX60","EOS":"10/24/2022"},{"Product":"MX60W","EOS":"10/24/2022"},{"Product":"MR12","EOS":"10/24/2022"},{"Product":"MX80","EOS":"8/30/2023"},{"Product":"MR26","EOS":"5/9/2023"},{"Product":"AC-MR-1-XX","EOS":"5/9/2023"},{"Product":"MR34","EOS":"10/31/2023"},{"Product":"MS420","EOS":"10/31/2023"},{"Product":"MR18","EOS":"3/31/2024"},{"Product":"MS320","EOS":"3/31/2024"},{"Product":"MR32","EOS":"7/31/2024"},{"Product":"MR72","EOS":"4/30/2024"},{"Product":"MS220","EOS":"7/29/2024"},{"Product":"MR66","EOS":"6/9/2024"},{"Product":"MR62","EOS":"11/15/2024"},{"Product":"ANT-10","EOS":"9/11/2024"},{"Product":"MS220-8","EOS":"7/28/2025"},{"Product":"MX400","EOS":"5/20/2025"},{"Product":"MX600","EOS":"5/20/2025"},{"Product":"Z1","EOS":"7/27/2025"},{"Product":"MC74","EOS":"4/1/2019"},{"Product":"MX65","EOS":"5/28/2026"},{"Product":"MV21","EOS":"6/19/2026"},{"Product":"MR55","EOS":"8/1/2028"},{"Product":"MR33","EOS":"7/21/2026"},{"Product":"MR42/42E","EOS":"7/21/2026"},{"Product":"MR45","EOS":"7/21/2026"},{"Product":"MR52","EOS":"7/21/2026"},{"Product":"MR53","EOS":"7/21/2026"},{"Product":"MR53E","EOS":"7/21/2026"},{"Product":"MR74","EOS":"7/21/2026"},{"Product":"MR84","EOS":"7/21/2026"},{"Product":"MX84","EOS":"10/31/2026"},{"Product":"MX100","EOS":"10/31/2026"},{"Product":"MV71","EOS":"6/19/2026"},{"Product":"MS321","EOS":"3/31/2024"},{"Product":"MS221","EOS":"7/29/2024"},{"Product":"MS322","EOS":"3/31/2024"},{"Product":"MS222","EOS":"7/29/2024"},{"Product":"MS323","EOS":"3/31/2024"},{"Product":"MS223","EOS":"7/29/2024"},{"Product":"MS324","EOS":"3/31/2024"},{"Product":"MS224","EOS":"7/29/2024"},{"Product":"MS325","EOS":"3/31/2024"},{"Product":"MS225","EOS":"7/29/2024"},{"Product":"MS326","EOS":"3/31/2024"},{"Product":"MS226","EOS":"7/29/2024"},{"Product":"MS327","EOS":"3/31/2024"},{"Product":"MS227","EOS":"7/29/2024"},{"Product":"MS328","EOS":"3/31/2024"},{"Product":"MS228","EOS":"7/29/2024"},{"Product":"MS329","EOS":"3/31/2024"},{"Product":"MS229","EOS":"7/29/2024"}]
"@ | ConvertFrom-Json
        
        $firmwaredetails = foreach ($mrkdevice in $MrkDevices) {
            $mrkdevice  | Select-Object @{n = 'Name'; e = { $MrkDevice.name } }, @{n = "Model"; e = { $MrkDevice.model } }, @{n = 'Serial'; e = { $MrkDevice.serial } }, @{n = 'firmware'; e = { ($MrkDevice.firmware -split "-", 2)[1] -replace '-', '.' } }, @{n = 'End of Support'; e = { ($endofsupportdetails | Where-Object { $_.product -match $mrkdevice.model } ).EOS } }
        }

        $intrusion = ($intrusionraw | ConvertTo-Html -Fragment | Out-String) -replace $tablestyling
        $firewallrules = (($l3firwallraw | ConvertTo-Html -Fragment | Out-String) + ( $l7firewallraw | ConvertTo-Html -Fragment | Out-String)) -replace $TableStyling
        $ipandvlan = ($publicIP | ConvertTo-Html -Fragment | Out-String) + ($vlansettings | ConvertTo-Html -Fragment | Out-String) -replace $tablestyling
        $contentfiltering = (($contentfiltering | ConvertTo-Html -Fragment | Out-String) -replace $TableStyling).Replace(":::", "<br/>")
        $wireless = ($wireless | ConvertTo-Html -Fragment | Out-String) -replace $tablestyling
        $switching = ($switching | ConvertTo-Html -Fragment | Out-String) -replace $tablestyling
        $firmware = ($firmwaredetails | ConvertTo-Html -Fragment | Out-String) -replace $TableStyling
        $networkname = $mrkNetwork.name

        $NetworkFields = @{
            'network_name'        = $networkname
            'intrusion_detection' = $intrusion
            'content_filtering'   = $contentfiltering
            'firewall_rules'      = $firewallrules
            'ip_and_vlans_config' = $ipandvlan
            'wireless'            = $wireless
            'switching'           = $switching
            'firmware_status'     = $firmware
        }

        $AssetName = $($networkname)
        if (!$NetworkAsset) {
            $companyid = $company.id
            Write-Host "Creating new Asset"
            $NetworkAsset = (New-HuduAsset -name $AssetName -company_id $companyid -asset_layout_id $NetworkLayout.id -fields $NetworkFields).asset
        } else {
            $companyid = $NetworkAsset.company_id
            Write-Host "Updating Asset"
            $NetworkAsset = (Set-HuduAsset -asset_id $NetworkAsset.id -name $AssetName -company_id $companyid -asset_layout_id $NetworkLayout.id -fields $NetworkFields).asset
        }


    }
}
