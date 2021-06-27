############# Settings  #############
# This script can work in two ways.
# It can connect directly to a Mikrotik device and download the configuration directly
# Or it can parse a folder and document all the exported configs from there.
$ConnectToMikrotik = $false

# If ConnectToMiKrotik is $true it will directly connect to the specified device and download the configuration from there.
$MikroTikUser = "mikrotik_user"
$MikroTikPass = 'StrongPasswordToSSHintoMikroTik'
$MikroTikIP = "10.20.30.40"
$MikroTikPort = 22

# If ConnectToMikrotik is false set these settings and it will read from the set folder
$TargetDir = "C:\Temp\Mikrotik\"
$FileExtensions = @("rsc", "export")

### Hudu Settings ###
# Get a Hudu API Key from https://yourhududomain.com/admin/api_keys
$HuduAPIKey = "ABCDEFGHIJ123456789"
# Set the base domain of your Hudu instance without a trailing /
$HuduBaseDomain = "https://your.hudu.domain"

$HuduAssetLayoutName = "MikroTik Device"



############# Functions #############

function Get-MikroTikHeaders {
    param(
        $Body,
        $Object
    )

    $Lines = $Body -Split ([Environment]::NewLine)

    $version = ($Lines[0] -split 'RouterOS ')[1]
    $object | Add-Member -Name 'OSVersion' -Value $version -Type NoteProperty

    $software_id = (($Lines[1] -split '= ')[1])
    $object | Add-Member -Name 'SoftwareID' -Value $software_id -Type NoteProperty

    $model = (($Lines[3] -split '= ')[1])
    $object | Add-Member -Name 'Model' -Value $model -Type NoteProperty

    $serial = (($Lines[4] -split '= ')[1])
    $object | Add-Member -Name 'SerialNumber' -Value $serial -Type NoteProperty

}

function Get-MikroTikDHCP {
    param(
        $body,
        $object
    )
    $template = @"
add name={RangeName*:testing} ranges={Ranges:1.1.1.1-1.1.1.1}
add name={RangeName*:123testingtesting} ranges={Ranges:22.22.22.22-22.22.22.22}
add name={RangeName*:default-dhcp} ranges={Ranges:333.333.333.333-333.333.333.333}
"@
    $DHCP = $body | ConvertFrom-String -TemplateContent $template | Select-Object RangeName, Ranges
    $object | Add-Member -Name 'DHCP' -Value $DHCP -Type NoteProperty
}

function Get-MikroTikQueue {
    param(
        $body,
        $object
    )
    $template = @"
add max-limit={Limit*:1M/1M} name={Name:ExampleServers} target={Target:1.1.1.1/1}
add max-limit={Limit*:20M/20M} name={Name:ABC} target={Target:22.22.22.22/22}
add max-limit={Limit*:100M/100M} name={Name:Company1} target={Target:333.333.333.333/32}
add max-limit={Limit*:1000M/1000M} name={Name:Testing} target={Target:111.111.111.111/32}
"@
    $Queues = $body | ConvertFrom-String -TemplateContent $template | Select-Object Name, Limit, Target
    $object | Add-Member -Name 'Queues' -Value $Queues -Type NoteProperty
}

function Get-MikroTikIPAddress {
    param(
        $body,
        $object
    )
    $template = @"
add address={Address*:1.1.1.1/1} comment={Comment:abc} interface={Interface:ether1} network=\
    {Network:1.1.1.1}
add address={Address*:22.22.22.22/22} comment={Comment:ComPAny} interface={Interface:ether2-master} network=\
    {Network:22.22.22.22}
add address={Address*:333.333.333.333/33} comment={Comment:"ABC / DE / Other"} interface={Interface:ether3} network=\
    {Network:333.333.333.333}
add address={Address*:111.111.111.111/30} comment={Comment:WAN} interface={Interface:sfp1} network=\
    {Network:222.222.222.222}
"@
    $IPAddresses = $body | ConvertFrom-String -TemplateContent $template | Select-Object Address, Comment, Interface, Network
    $object | Add-Member -Name 'IPAddresses' -Value $IPAddresses -Type NoteProperty
}

function Get-MikroTikDNS {
    param(
        $body,
        $object
    )
    $template = @"
set servers={DNSServers*:1.1.1.1,1.1.1.1}
set servers={DNSServers*:22.22.22.22,22.22.22.22}
set servers={DNSServers*:333.333.333.333,333.333.333.333}
"@
    $DNSServers = $body | ConvertFrom-String -TemplateContent $template | Select-Object DNSServers
    $object | Add-Member -Name 'DNSServers' -Value $DNSServers -Type NoteProperty
}

function Get-MikroTikFirewall {
    param(
        $body,
        $object
    )
    $template = @"
{NewRecord*:add} action={Action:accept} chain={Chain:forward} comment={Comment:"Testing Comment"} connection-state="" \
    connection-type={ConnectionType:sip} dst-address={DSTAddress:1.1.1.1} dst-address-list="" \
    dst-port={DSTPort:443} in-interface=bridge in-interface-list=all out-interface=\
    bridge out-interface-list=all port={Port:443} protocol={Protocol:tcp} src-address=\
    {SRCAddress:1.1.1.1} src-address-list="" src-port=""
{NewRecord*:add} action={Action:accept} chain={Chain:forward} comment={Comment:"Testing Comment"} connection-state="" \
    connection-type={ConnectionType:def} dst-address={DSTAddress:22.22.22.22} dst-address-list="" \
    dst-port={DSTPort:80} in-interface=bridge in-interface-list=all out-interface=\
    bridge out-interface-list=all port={Port:80} protocol={Protocol:tcp} src-address=\
    {SRCAddress:22.22.22.22} src-address-list="" src-port=""
"@

    $FirewallRules = $body | ConvertFrom-String -TemplateContent $template | Select-Object Action, Chain, Comment, ConnectionType, DSTAddress, DSTPort, Port, Protocol, SRCAddress
    $object | Add-Member -Name 'FirewallRules' -Value $FirewallRules -Type NoteProperty
}

function Get-MikroTikRoutes {
    param(
        $body,
        $object
    )
    $template = @"
{NewRecord*:add} disabled={Disabled:no} dst-address={DSTAddress:0.0.0.0/0} gateway={Gateway:1.1.1.1}
{NewRecord*:add} disabled={Disabled:yes} dst-address={DSTAddress:222.222.222.222/32} gateway={Gateway:222.222.222.222}
"@
    $Routes = $body | ConvertFrom-String -TemplateContent $template | Select-Object DSTAddress, Gateway, Disabled
    $object | Add-Member -Name 'Routes' -Value $Routes -Type NoteProperty
}

function Get-MikroTikServices {
    param(
        $body,
        $object
    )
    $template = @"
set {Service*:telnet} disabled={Disabled:yes}
set {Service*:api} disabled={Disabled:no}
set {Service*:www-ssl} certificate={Certificate:https-cert} disabled={Disabled:no}
set {Service*:api-ssl} certificate={Certificate:https-cert} tls-version=only-1.2
"@
    $Services = $body | ConvertFrom-String -TemplateContent $template | Select-Object Service, Disabled, Certificate
    $object | Add-Member -Name 'Services' -Value $Services -Type NoteProperty
}

function Get-MikroTikSNMP {
    param(
        $body,
        $object
    )
    $template = @"
set enabled={Enabled*:yes} trap-community={Community:abcdD3424EFG42395434745} trap-version={TrapVersion:2}
set enabled={Enabled*:no} trap-community={Community:public} trap-version={TrapVersion:2}
"@
    $SNMP = $body | ConvertFrom-String -TemplateContent $template | Select-Object Enabled, Community, TrapVersion
    $object | Add-Member -Name 'SNMP' -Value $SNMP -Type NoteProperty
}

function Get-MikroTikClock {
    param(
        $body,
        $object
    )
    $template = @"
set time-zone-name={Timezone*:Europe/London}
"@
    $Timezone = $body | ConvertFrom-String -TemplateContent $template | Select-Object Timezone
    $object | Add-Member -Name 'Timezone' -Value $Timezone.Timezone -Type NoteProperty
}

function Get-MikroTikIdentity {
    param(
        $body,
        $object
    )
    $template = @"
set name={Identity*:DeviceName}
set name={Identity*:device.name.com}
"@
    $Identity = $body | ConvertFrom-String -TemplateContent $template | Select-Object Identity
    $object | Add-Member -Name 'Identity' -Value $Identity.Identity -Type NoteProperty
}

############# Start Script #############

Import-Module Microsoft.PowerShell.Utility

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
			label = 'General Info'
			field_type = 'RichText'
			show_in_list = 'false'
			position = 1
		},
		@{
			label = 'DHCP'
			field_type = 'RichText'
			show_in_list = 'false'
			position = 2
		},
		@{
			label = 'Queues'
			field_type = 'RichText'
			show_in_list = 'false'
			position = 3
		},
		@{
			label = 'IP Addresses'
			field_type = 'RichText'
			show_in_list = 'false'
			position = 4
		},
		@{
			label = 'DNS Servers'
			field_type = 'RichText'
			show_in_list = 'false'
			position = 5
		},
		@{
			label = 'Firewall Rules'
			field_type = 'RichText'
			show_in_list = 'false'
			position = 6
		},
		@{
			label = 'Routes'
			field_type = 'RichText'
			show_in_list = 'false'
			position = 7
		},
		@{
			label = 'Services'
			field_type = 'RichText'
			show_in_list = 'false'
			position = 8
		},
		@{
			label = 'SNMP'
			field_type = 'RichText'
			show_in_list = 'false'
			position = 9
		},
		@{
			label = 'Configuration'
			field_type = 'RichText'
			show_in_list = 'false'
			position = 10
		}
	)
	
	Write-Host "Creating New Asset Layout $HuduAssetLayoutName"
	$NewLayout = New-HuduAssetLayout -name $HuduAssetLayoutName -icon "fas fa-network-wired" -color "#4CAF50" -icon_color "#ffffff" -include_passwords $false -include_photos $false -include_comments $false -include_files $false -fields $AssetLayoutFields
	$Layout = Get-HuduAssetLayouts -name $HuduAssetLayoutName
}


if ($ConnectToMikrotik -eq $false) {
    $Files = foreach ($extension in $FileExtensions) {
        $FileNames = Get-ChildItem -Path $TargetDir -Filter "*.$extension"
        foreach ($FileToParse in $FileNames) {
            $ReturnFile = get-content $FileToParse.fullname -raw
            $ReturnFile
        }
    }
}
else {
    # Start 
    if (Get-Module -ListAvailable -Name Posh-Ssh) {
        Import-Module Posh-Ssh 
    }
    else {
        Install-Module Posh-Ssh -Force
        Import-Module Posh-Ssh
    }

    $Credential = New-Object System.Management.Automation.PSCredential ($MikroTikUser, $(ConvertTo-SecureString $MikroTikPass -AsPlainText -Force))
    New-SSHSession -ComputerName $MikroTikIP -Port $MikroTikPort -Credential $Credential -AcceptKey
    $Result = Invoke-SSHCommand -Index 0 -Command "/export"
    Remove-SSHSession -Index 0

    $Result.output | Out-File "TempConfigFile.export"
    $Files = get-content "TempConfigFile.export" -raw
}

foreach ($file in $files) {

    $MikroTikConfig = [PSCustomObject]@{}


    $Sections = $file -split '[\r\n]+/'

    Get-MikroTikHeaders -body $Sections[0] -Object $MikroTikConfig


    foreach ($Section in $Sections[1..$Sections.Length]) {
        $SectionLines = $Section -Split ([Environment]::NewLine)
        $SectionHeader = $SectionLines[0] -replace "`n" -replace "`r"
        $SectionBody = $SectionLines[1..$SectionLines.Length]

        Switch ($SectionHeader) {
            "ip pool" { Get-MikroTikDHCP -body $SectionBody -object $MikroTikConfig }
            "queue simple" { Get-MikroTikQueue -body $SectionBody -object $MikroTikConfig }
            "ip address" { Get-MikroTikIPAddress -body $SectionBody -object $MikroTikConfig }
            "ip dns" { Get-MikroTikDNS -body $SectionBody -object $MikroTikConfig }
            "ip firewall filter" { Get-MikroTikFirewall -body $SectionBody -object $MikroTikConfig }
            "ip route" { Get-MikroTikRoutes -body $SectionBody -object $MikroTikConfig }
            "ip service" { Get-MikroTikServices -body $SectionBody -object $MikroTikConfig }
            "snmp" { Get-MikroTikSNMP -body $SectionBody -object $MikroTikConfig }
            "system clock" { Get-MikroTikClock -body $SectionBody -object $MikroTikConfig }
            "system identity" { Get-MikroTikIdentity -body $SectionBody -object $MikroTikConfig }

        }
    
    }

    $AssetName = $MikroTikConfig.Identity
    $Asset = Get-HuduAssets -name $AssetName -assetlayoutid $Layout.id

    if (($Asset | Measure-Object).count -eq 1){

    $Settings = @{
        "Identity" = $MikroTikConfig.Identity
        "OS Version" = $MikroTikConfig.OSVersion
        "Software ID" = $MikroTikConfig.SoftwareID
        "Model" = $MikroTikConfig.Model
        "Timezone" = $MikroTikConfig.Timezone
    }

    $SettingsHtml = $Settings | ConvertTo-Html -as list -fragment | Out-String
    
    $AssetFields = @{
        "general_info" = $SettingsHTML
        "dhcp" = $($MikroTikConfig.DHCP | ConvertTo-Html -as table -fragment | Out-String)
        "queues" = $($MikroTikConfig.Queues | ConvertTo-Html -as table -fragment | Out-String)
        "ip_addresses" = $($MikroTikConfig.IPAddresses | ConvertTo-Html -as table -fragment | Out-String)
        "dns_servers" = $($MikroTikConfig.DNSServers | ConvertTo-Html -as table -fragment | Out-String)
        "firewall_rules" = $($MikroTikConfig.FirewallRules | ConvertTo-Html -as table -fragment | Out-String)
        "routes" = $($MikroTikConfig.Routes | ConvertTo-Html -as table -fragment | Out-String)
        "services" = $($MikroTikConfig.Services | ConvertTo-Html -as table -fragment | Out-String)
        "snmp" = $($MikroTikConfig.SNMP | ConvertTo-Html -as list -fragment | Out-String)
        "configuration" = $file -replace ([Environment]::NewLine, "<br />") | Out-String
    }

    Write-Host "Updating Asset"
	$Asset = Set-HuduAsset -asset_id $Asset.id -name $AssetName -company_id $asset.company_id -asset_layout_id $layout.id -fields $AssetFields	


    } else {
        Write-Host "A matched asset could not be found in Hudu. Please create a blank $HuduAssetLayoutName with a name of $($MikroTikConfig.Identity) under the company you wish to sync the data to and rerun this script"  -ForegroundColor Red
    }

}

