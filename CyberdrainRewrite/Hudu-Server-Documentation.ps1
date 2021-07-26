# Based on the original script by Kelvin Tegelaar https://github.com/KelvinTegelaar/AutomaticDocumentation
#####################################################################
# Get a Hudu API Key from https://yourhududomain.com/admin/api_keys
$HuduAPIKey = 'abcdefgh12345677889'
# Set the base domain of your Hudu instance without a trailing /
$HuduBaseDomain = 'https://your.hudu.domain'
#Company Name as it appears in Hudu
$CompanyName = 'Example Company'
$HuduAssetLayoutName = 'Server Overview - AutoDoc'
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

$Company = Get-HuduCompanies -name $CompanyName
if ($company) {

    $Layout = Get-HuduAssetLayouts -name $HuduAssetLayoutName

    if (!$Layout) {
        $AssetLayoutFields = @(
            @{
                label        = 'Name'
                field_type   = 'Text'
                show_in_list = 'true'
                position     = 1
            },
            @{
                label        = 'Information'
                field_type   = 'RichText'
                show_in_list = 'false'
                position     = 2
            }
        )

        Write-Host "Creating New Asset Layout $HuduAssetLayoutName"
        $NewLayout = New-HuduAssetLayout -name $HuduAssetLayoutName -icon 'fas fa-network-wired' -color '#4CAF50' -icon_color '#ffffff' -include_passwords $false -include_photos $false -include_comments $false -include_files $false -fields $AssetLayoutFields
        $Layout = Get-HuduAssetLayouts -name $HuduAssetLayoutName
    }



    #This is the object we'll be sending to IT-Glue.
    $ComputerSystemInfo = Get-CimInstance -ClassName Win32_ComputerSystem
    if ($ComputerSystemInfo.model -match 'Virtual' -or $ComputerSystemInfo.model -match 'VMware') { $MachineType = 'Virtual' } Else { $MachineType = 'Physical' }
    $networkName = Get-CimInstance -ClassName Win32_NetworkAdapter | Where-Object { $_.PhysicalAdapter -eq 'True' } | Sort-Object Index
    $networkIP = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration | Where-Object { $_.MACAddress -gt 0 } | Sort-Object Index
    $networkSummary = New-Object -TypeName 'System.Collections.ArrayList'

    foreach ($nic in $networkName) {
        $nic_conf = $networkIP | Where-Object { $_.Index -eq $nic.Index }

        $networkDetails = New-Object PSObject -Property @{
            Index                = [int]$nic.Index;
            AdapterName          = [string]$nic.NetConnectionID;
            Manufacturer         = [string]$nic.Manufacturer;
            Description          = [string]$nic.Description;
            MACAddress           = [string]$nic.MACAddress;
            IPEnabled            = [bool]$nic_conf.IPEnabled;
            IPAddress            = [string]$nic_conf.IPAddress;
            IPSubnet             = [string]$nic_conf.IPSubnet;
            DefaultGateway       = [string]$nic_conf.DefaultIPGateway;
            DHCPEnabled          = [string]$nic_conf.DHCPEnabled;
            DHCPServer           = [string]$nic_conf.DHCPServer;
            DNSServerSearchOrder = [string]$nic_conf.DNSServerSearchOrder;
        }
        $networkSummary += $networkDetails
    }
    $NicRawConf = $networkSummary | Select-Object AdapterName, IPaddress, IPSubnet, DefaultGateway, DNSServerSearchOrder, MACAddress | ConvertTo-Html -Fragment | Select-Object -Skip 1
    $NicConf = "<br/><table class=`"table table-bordered table-hover`" >" + $NicRawConf

    $RAM = (systeminfo | Select-String 'Total Physical Memory:').ToString().Split(':')[1].Trim()

    $ApplicationsFrag = Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Select-Object DisplayName, DisplayVersion, Publisher, InstallDate | ConvertTo-Html -Fragment | Select-Object -Skip 1
    $ApplicationsTable = "<br/><table class=`"table table-bordered table-hover`" >" + $ApplicationsFrag

    $RolesFrag = Get-WindowsFeature | Where-Object { $_.Installed -eq $True } | Select-Object displayname, name | ConvertTo-Html -Fragment | Select-Object -Skip 1
    $RolesTable = "<br/><table class=`"table table-bordered table-hover`" >" + $RolesFrag

    if ($machineType -eq 'Physical' -and $ComputerSystemInfo.Manufacturer -match 'Dell') {
        $DiskLayoutRaw = omreport storage pdisk controller=0 -fmt cdv
        $DiskLayoutSemi = $DiskLayoutRaw | Select-String -SimpleMatch 'ID;Status;' -Context 0, ($DiskLayoutRaw).Length | ConvertFrom-Csv -Delimiter ';' | Select-Object Name, Status, Capacity, State, 'Bus Protocol', 'Product ID', 'Serial No.', 'Part Number', Media | ConvertTo-Html -Fragment
        $DiskLayoutTable = "<br/><table class=`"table table-bordered table-hover`" >" + $DiskLayoutsemi

        #Try to get RAID layout
        $RAIDLayoutRaw = omreport storage vdisk controller=0 -fmt cdv
        $RAIDLayoutSemi = $RAIDLayoutRaw | Select-String -SimpleMatch 'ID;Status;' -Context 0, ($RAIDLayoutRaw).Length | ConvertFrom-Csv -Delimiter ';' | Select-Object Name, Status, State, Layout, 'Device Name', 'Read Policy', 'Write Policy', Media | ConvertTo-Html -Fragment
        $RAIDLayoutTable = "<br/><table class=`"table table-bordered table-hover`" >" + $RAIDLayoutsemi
    } else {
        $RAIDLayoutTable = 'Could not get physical disk info'
        $DiskLayoutTable = 'Could not get physical disk info'
    }

    $HTMLFile = "
    <b>Servername</b>: $ENV:COMPUTERNAME <br>
    <b>Server Type</b>: $machineType <br>
    <b>Amount of RAM</b>: $RAM <br>
    <br>
    <h1>NIC Configuration</h1> <br>
    $NicConf
    <br>
    <h1>Installed Applications</h1> <br>
    $ApplicationsTable
    <br>
    <h1>Installed Roles</h1> <br>
    $RolesTable
    <br>
    <h1>Physical Disk information</h1>
    $DiskLayoutTable
    <h1>RAID information</h1>
    $RAIDLayoutTable
    "

    $AssetFields = @{
        'name'        = $ENV:COMPUTERNAME
        'information' = $HTMLFile
    }


    $companyid = $company.id
    $AssetName = "$($ENV:COMPUTERNAME) - Overview"

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
    Write-Host "$CompanyName Not found in Hudu." -ForegroundColor Red
}
