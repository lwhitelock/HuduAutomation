# Based on the original script by Kelvin Tegelaar https://github.com/KelvinTegelaar/AutomaticDocumentation
#####################################################################
# Get a Hudu API Key from https://yourhududomain.com/admin/api_keys
$HuduAPIKey = 'abcdefgh123456788'
# Set the base domain of your Hudu instance without a trailing /
$HuduBaseDomain = 'https://your.hudu.domain'
$HuduAssetLayoutName = 'Unifi - AutoDoc'
$UnifiBaseUri = 'https://unifi.yourdomain.com:8443/api'
$UnifiUser = 'PSAPIUser'
$UnifiPassword = 'APIUserPassword'
$TableStyling = '<th>', "<th style=`"background-color:#4CAF50`">"
#####################################################################

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
            label        = 'Site Name'
            field_type   = 'Text'
            show_in_list = 'true'
            position     = 1
        },
        @{
            label        = 'WAN'
            field_type   = 'RichText'
            show_in_list = 'false'
            position     = 2
        },
        @{
            label        = 'LAN'
            field_type   = 'RichText'
            show_in_list = 'false'
            position     = 3
        },
        @{
            label        = 'VPN'
            field_type   = 'RichText'
            show_in_list = 'false'
            position     = 4
        },
        @{
            label        = 'Wi-Fi'
            field_type   = 'RichText'
            show_in_list = 'false'
            position     = 5
        },
        @{
            label        = 'Port Forwards'
            field_type   = 'RichText'
            show_in_list = 'false'
            position     = 6
        },
        @{
            label        = 'Switches'
            field_type   = 'RichText'
            show_in_list = 'false'
            position     = 7
        }
    )

    Write-Host "Creating New Asset Layout $HuduAssetLayoutName"
    $NewLayout = New-HuduAssetLayout -name $HuduAssetLayoutName -icon 'fas fa-network-wired' -color '#4CAF50' -icon_color '#ffffff' -include_passwords $false -include_photos $false -include_comments $false -include_files $false -fields $AssetLayoutFields
    $Layout = Get-HuduAssetLayouts -name $HuduAssetLayoutName
}


Write-Host 'Start documentation process.' -ForegroundColor green


$UniFiCredentials = @{
    username = $UnifiUser
    password = $UnifiPassword
    remember = $true
} | ConvertTo-Json

Write-Host 'Logging in to Unifi API.' -ForegroundColor Green
try {
    Invoke-RestMethod -Uri "$UnifiBaseUri/login" -Method POST -Body $uniFiCredentials -SessionVariable websession
} catch {
    Write-Host "Failed to log in on the Unifi API. Error was: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host 'Collecting sites from Unifi API.' -ForegroundColor Green
try {
    $sites = (Invoke-RestMethod -Uri "$UnifiBaseUri/self/sites" -WebSession $websession).data
} catch {
    Write-Host "Failed to collect the sites. Error was: $($_.Exception.Message)" -ForegroundColor Red
}

foreach ($site in $sites) {
    #First we will see if there is an Asset that matches the site name with this Asset Layout
    Write-Host "Attempting to map $($site.desc)"
    $Asset = Get-HuduAssets -name $($site.desc) -assetlayoutid $Layout.id
    if (!$Asset) {
        #Check on company name
        $Company = Get-HuduCompanies -name $($site.desc)
        if (!$company) {
            Write-Host "A company in Hudu could not be matched to the site. Please create a blank $HuduAssetLayoutName asset, with a name of `"$($site.desc)`" under the company in Hudu you wish to map this site to." -ForegroundColor Red
            continue
        }
    }

    $unifiDevices = Invoke-RestMethod -Uri "$UnifiBaseUri/s/$($site.name)/stat/device" -WebSession $websession
    $UnifiSwitches = $unifiDevices.data | Where-Object { $_.type -contains 'usw' }
    $SwitchPorts = foreach ($unifiswitch in $UnifiSwitches) {
        "<h2>$($unifiswitch.name) - $($unifiswitch.mac)</h2> <table><tr>"
        foreach ($Port in $unifiswitch.port_table) {
            "<th>$($port.port_idx)</th>"
        }
        '</tr><tr>'
        foreach ($Port in $unifiswitch.port_table) {
            $colour = if ($port.up -eq $true) { '02ab26' } else { 'ad2323' }
            $speed = switch ($port.speed) {
                10000 { '10Gb' }
                1000 { '1Gb' }
                100 { '100Mb' }
                10 { '10Mb' }
                0 { 'Port off' }
            }
            "<td style='background-color:#$($colour)'>$speed</td>"
        }
        '</tr><tr>'
        foreach ($Port in $unifiswitch.port_table) {
            $poestate = if ($port.poe_enable -eq $true) { 'PoE on'; $colour = '02ab26' } elseif ($port.port_poe -eq $false) { 'No PoE'; $colour = '#696363' } else { 'PoE Off'; $colour = 'ad2323' }
            "<td style='background-color:#$($colour)'>$Poestate</td >"
        }
        '</tr></table>'
    }

    $uaps = $unifiDevices.data | Where-Object { $_.type -contains 'uap' }

    $Wifinetworks = $uaps.vap_table | Group-Object Essid
    $wifi = foreach ($Wifinetwork in $Wifinetworks) {
        $Wifinetwork | Select-Object @{n = 'SSID'; e = { $_.Name } }, @{n = 'Access Points'; e = { $uaps.name -join "`n" } }, @{n = 'Channel'; e = { $_.group.channel -join ', ' } }, @{n = 'Usage'; e = { $_.group.usage | Sort-Object -Unique } }, @{n = 'Enabled'; e = { $_.group.up | Sort-Object -Unique } }
    }

    $alarms = (Invoke-RestMethod -Uri "$UnifiBaseUri/s/$($site.name)/stat/alarm" -WebSession $websession).data
    $alarms = $alarms | Select-Object @{n = 'Universal Time'; e = { [datetime]$_.datetime } }, @{n = 'Device Name'; e = { $_.$(($_ | Get-Member | Where-Object { $_.Name -match '_name' }).name) } }, @{n = 'Message'; e = { $_.msg } } -First 10

    $portforward = (Invoke-RestMethod -Uri "$UnifiBaseUri/s/$($site.name)/rest/portforward" -WebSession $websession).data
    $portForward = $portforward | Select-Object Name, @{n = 'Source'; e = { "$($_.src):$($_.dst_port)" } }, @{n = 'Destination'; e = { "$($_.fwd):$($_.fwd_port)" } }, @{n = 'Protocol'; e = { $_.proto } }


    $networkConf = (Invoke-RestMethod -Uri "$UnifiBaseUri/s/$($site.name)/rest/networkconf" -WebSession $websession).data

    $NetworkInfo = foreach ($network in $networkConf) {
        [pscustomobject] @{
            'Purpose'                 = $network.purpose
            'Name'                    = $network.name
            'vlan'                    = "$($network.vlan_enabled) $($network.vlan)"
            'LAN IP Subnet'           = $network.ip_subnet
            'LAN DHCP Relay Enabled'  = $network.dhcp_relay_enabled
            'LAN DHCP Enabled'        = $network.dhcpd_enabled
            'LAN Network Group'       = $network.networkgroup
            'LAN Domain Name'         = $network.domain_name
            'LAN DHCP Lease Time'     = $network.dhcpd_leasetime
            'LAN DNS 1'               = $network.dhcpd_dns_1
            'LAN DNS 2'               = $network.dhcpd_dns_2
            'LAN DNS 3'               = $network.dhcpd_dns_3
            'LAN DNS 4'               = $network.dhcpd_dns_4
            'DHCP Range'              = "$($network.dhcpd_start) - $($network.dhcpd_stop)"
            'WAN IP Type'             = $network.wan_type
            'WAN IP'                  = $network.wan_ip
            'WAN Subnet'              = $network.wan_netmask
            'WAN Gateway'             = $network.wan_gateway
            'WAN DNS 1'               = $network.wan_dns1
            'WAN DNS 2'               = $network.wan_dns2
            'WAN Failover Type'       = $network.wan_load_balance_type
            'VPN Ike Version'         = $network.ipsec_key_exchange
            'VPN Encryption protocol' = $network.ipsec_encryption
            'VPN Hashing protocol'    = $network.ipsec_hash
            'VPN DH Group'            = $network.ipsec_dh_group
            'VPN PFS Enabled'         = $network.ipsec_pfs
            'VPN Dynamic Routing'     = $network.ipsec_dynamic_routing
            'VPN Local IP'            = $network.ipsec_local_ip
            'VPN Peer IP'             = $network.ipsec_peer_ip
            'VPN IPSEC Key'           = $network.x_ipsec_pre_shared_key
        }

    }

    $WANs = ($networkinfo | Where-Object { $_.Purpose -eq 'wan' } | Select-Object Name, *WAN* | ConvertTo-Html -frag | Out-String) -replace $tablestyling
    $LANS = ($networkinfo | Where-Object { $_.Purpose -eq 'corporate' } | Select-Object Name, *LAN* | ConvertTo-Html -frag | Out-String) -replace $tablestyling
    $VPNs = ($networkinfo | Where-Object { $_.Purpose -eq 'site-vpn' } | Select-Object Name, *VPN* | ConvertTo-Html -frag | Out-String) -replace $tablestyling
    $Wifi = ($wifi | ConvertTo-Html -frag | Out-String) -replace $tablestyling
    $PortForwards = ($Portforward | ConvertTo-Html -frag | Out-String) -replace $tablestyling

    $AssetFields = @{
        'site_name'     = $site.name
        'wan'           = $WANs
        'lan'           = $LANS
        'vpn'           = $VPNs
        'wi-fi'         = $wifi
        'port_forwards' = $PortForwards
        'switches'      = ($SwitchPorts | Out-String)
    }



    $AssetName = $($site.desc)
    if (!$Asset) {
        $companyid = $company.id
        Write-Host 'Creating new Asset'
        $Asset = New-HuduAsset -name $AssetName -company_id $companyid -asset_layout_id $Layout.id -fields $AssetFields
    } else {
        $companyid = $Asset.company_id
        Write-Host 'Updating Asset'
        $Asset = Set-HuduAsset -asset_id $Asset.id -name $AssetName -company_id $companyid -asset_layout_id $layout.id -fields $AssetFields
    }
}

