# Based on the original script by Kelvin Tegelaar https://github.com/KelvinTegelaar/AutomaticDocumentation
#####################################################################
# Get a Hudu API Key from https://yourhududomain.com/admin/api_keys
$HuduAPIKey = 'abcdef1234565'
# Set the base domain of your Hudu instance without a trailing /
$HuduBaseDomain = 'https://your.hudu.domain'
#Company Name as it appears in Hudu
$CompanyName = 'Example Company'
$HuduAssetLayoutName = 'Network Overview - AutoDoc'
#####################################################################
#Get the Hudu API Module if not installed
if (Get-Module -ListAvailable -Name HuduAPI) {
    Import-Module HuduAPI
} else {
    Install-Module HuduAPI -Force
    Import-Module HuduAPI
}

If (Get-Module -ListAvailable -Name 'PSnmap') { Import-Module 'PSnmap' } Else { Install-Module 'PSnmap' -Force; Import-Module 'PSnmap' }
#Set Hudu logon information
New-HuduAPIKey $HuduAPIKey
New-HuduBaseUrl $HuduBaseDomain

$Company = Get-HuduCompanies -name $CompanyName
if ($company) {

    $Layout = Get-HuduAssetLayouts -name $HuduAssetLayoutName

    if (!$Layout) {
        $AssetLayoutFields = @(
            @{
                label        = 'Subnet Network'
                field_type   = 'Text'
                show_in_list = 'true'
                position     = 1
            },
            @{
                label        = 'Subnet Gateway'
                field_type   = 'Text'
                show_in_list = 'false'
                position     = 2
            },
            @{
                label        = 'Subnet DNS Servers'
                field_type   = 'Text'
                show_in_list = 'false'
                position     = 3
            },
            @{
                label        = 'Subnet DHCP Servers'
                field_type   = 'Text'
                show_in_list = 'false'
                position     = 4
            },
            @{
                label        = 'Scan Results'
                field_type   = 'RichText'
                show_in_list = 'false'
                position     = 5
            }
        )

        Write-Host "Creating New Asset Layout $HuduAssetLayoutName"
        $NewLayout = New-HuduAssetLayout -name $HuduAssetLayoutName -icon 'fas fa-network-wired' -color '#4CAF50' -icon_color '#ffffff' -include_passwords $false -include_photos $false -include_comments $false -include_files $false -fields $AssetLayoutFields
        $Layout = Get-HuduAssetLayouts -name $HuduAssetLayoutName
    }






    $ConnectedNetworks = Get-NetIPConfiguration -Detailed | Where-Object { $_.Netadapter.status -eq 'up' }


    foreach ($Network in $ConnectedNetworks) {
        $DHCPServer = (Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration | Where-Object { $_.IPAddress -eq $network.IPv4Address }).DHCPServer
        $Subnet = "$($network.IPv4DefaultGateway.nexthop)/$($network.IPv4Address.PrefixLength)"
        $NetWorkScan = Invoke-PSnmap -ComputerName $subnet -Port 80, 443, 3389, 21, 22, 25, 587 -Dns -NoSummary
        $HTMLFrag = $NetworkScan | Where-Object { $_.Ping -eq $true } | ConvertTo-Html -Fragment -PreContent "<h1> Network scan of $($subnet) <br/><table class=`"table table-bordered table-hover`" >" | Out-String




        $AssetFields = @{
            'subnet_network'      = "$Subnet"
            'subnet_gateway'      = $network.IPv4DefaultGateway.nexthop
            'subnet_dns_servers'  = $network.dnsserver.serveraddresses
            'subnet_dhcp_servers' = $DHCPServer
            'scan_results'        = $HTMLFrag
        }





        $companyid = $company.id
        #Check if there is already an asset
        $Asset = Get-HuduAssets -name $Subnet -companyid $companyid -assetlayoutid $Layout.id

        #If the Asset does not exist, we edit the body to be in the form of a new asset, if not, we just upload.
        if (!$Asset) {
            Write-Host 'Creating new Asset'
            $Asset = New-HuduAsset -name $Subnet -company_id $companyid -asset_layout_id $Layout.id -fields $AssetFields
        } else {
            Write-Host 'Updating Asset'
            $Asset = Set-HuduAsset -asset_id $Asset.id -name $Subnet -company_id $companyid -asset_layout_id $layout.id -fields $AssetFields
        }

    }
} else {
    Write-Host "$CompanyName Not found in Hudu." -ForegroundColor Red
}
