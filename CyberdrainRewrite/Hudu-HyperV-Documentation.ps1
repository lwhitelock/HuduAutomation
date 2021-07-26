# Based on the original script by Kelvin Tegelaar https://github.com/KelvinTegelaar/AutomaticDocumentation
#####################################################################
# Get a Hudu API Key from https://yourhududomain.com/admin/api_keys
$HuduAPIKey = 'abcde1234556'
# Set the base domain of your Hudu instance without a trailing /
$HuduBaseDomain = 'https://your.hudu.domain'
#Company Name as it appears in Hudu
$CompanyName = 'Example Company'
$HuduAssetLayoutName = 'Hyper-v - AutoDoc'
$RecursiveDepth = 2
$TableHeader = "<table class=`"table table-bordered table-hover`" style=`"width:80%`">"
$Whitespace = '<br/>'
$TableStyling = '<th>', "<th style=`"background-color:#00adef`">"
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
    $ComputerName = $($Env:COMPUTERNAME)

    # Find the asset we are running from
    $ParentAsset = Get-HuduAssets -primary_serial (Get-CimInstance win32_bios).serialnumber

    #If count exists we either got 0 or more than 1 either way lets try to match off name
    if ($ParentAsset.count) {
        $ParentAsset = Get-HuduAssets -companyid $company.id -name $ComputerName
    }

    # Check we found an Asset
    if ($ParentAsset) {

        $Layout = Get-HuduAssetLayouts -name $HuduAssetLayoutName

        if (!$Layout) {
            $AssetLayoutFields = @(
                @{
                    label        = 'Host name'
                    field_type   = 'Text'
                    show_in_list = 'true'
                    position     = 1
                },
                @{
                    label        = 'Virtual Machines'
                    field_type   = 'RichText'
                    show_in_list = 'false'
                    position     = 2
                },
                @{
                    label        = 'Network Settings'
                    field_type   = 'RichText'
                    show_in_list = 'false'
                    position     = 3
                },
                @{
                    label        = 'Replication Settings'
                    field_type   = 'RichText'
                    show_in_list = 'false'
                    position     = 4
                },
                @{
                    label        = 'Host Settings'
                    field_type   = 'RichText'
                    show_in_list = 'false'
                    position     = 5
                }

            )

            Write-Host "Creating New Asset Layout $HuduAssetLayoutName"
            $NewLayout = New-HuduAssetLayout -name $HuduAssetLayoutName -icon 'fas fa-server' -color '#00adef' -icon_color '#ffffff' -include_passwords $false -include_photos $false -include_comments $false -include_files $false -fields $AssetLayoutFields
            $Layout = Get-HuduAssetLayouts -name $HuduAssetLayoutName
        }



        Write-Host 'Start documentation process.' -ForegroundColor green

        $VirtualMachines = Get-VM | Select-Object VMName, Generation, Path, Automatic*, @{n = 'Minimum(gb)'; e = { $_.memoryminimum / 1gb } }, @{n = 'Maximum(gb)'; e = { $_.memorymaximum / 1gb } }, @{n = 'Startup(gb)'; e = { $_.memorystartup / 1gb } }, @{n = 'Currently Assigned(gb)'; e = { $_.memoryassigned / 1gb } }, ProcessorCount | ConvertTo-Html -Fragment | Out-String
        $VirtualMachines = $TableHeader + ($VirtualMachines -replace $TableStyling) + $Whitespace
        $NetworkSwitches = Get-VMSwitch | Select-Object name, switchtype, NetAdapterInterfaceDescription, AllowManagementOS | ConvertTo-Html -Fragment | Out-String
        $VMNetworkSettings = Get-VMNetworkAdapter * | Select-Object Name, IsManagementOs, VMName, SwitchName, MacAddress, @{Name = 'IP'; Expression = { $_.IPaddresses -join ',' } } | ConvertTo-Html -Fragment | Out-String
        $NetworkSettings = $TableHeader + ($NetworkSwitches -replace $TableStyling) + ($VMNetworkSettings -replace $TableStyling) + $Whitespace
        $ReplicationSettings = Get-VMReplication | Select-Object VMName, State, Mode, FrequencySec, PrimaryServer, ReplicaServer, ReplicaPort, AuthType | ConvertTo-Html -Fragment | Out-String
        $ReplicationSettings = $TableHeader + ($ReplicationSettings -replace $TableStyling) + $Whitespace
        $HostSettings = Get-VMHost | Select-Object Computername, LogicalProcessorCount, iovSupport, EnableEnhancedSessionMode, MacAddressMinimum, *max*, NumaspanningEnabled, VirtualHardDiskPath, VirtualMachinePath, UseAnyNetworkForMigration, VirtualMachineMigrationEnabled | ConvertTo-Html -Fragment -As List | Out-String

        $AssetFields = @{
            'host_name'            = $env:COMPUTERNAME
            'virtual_machines'     = $VirtualMachines
            'network_settings'     = $NetworkSettings
            'replication_settings' = $ReplicationSettings
            'host_settings'        = $HostSettings
        }



        $AssetName = "$ComputerName - Hyper-V"

        Write-Host 'Documenting to Hudu' -ForegroundColor Green
        $Asset = Get-HuduAssets -name $AssetName -companyid $company.id -assetlayoutid $Layout.id

        #If the Asset does not exist, we edit the body to be in the form of a new asset, if not, we just upload.
        if (!$Asset) {
            Write-Host 'Creating new Asset'
            $Asset = New-HuduAsset -name $AssetName -company_id $company.id -asset_layout_id $Layout.id -fields $AssetFields
        } else {
            Write-Host 'Updating Asset'
            $Asset = Set-HuduAsset -asset_id $Asset.id -name $AssetName -company_id $company.id -asset_layout_id $layout.id -fields $AssetFields
        }

    } else {
        Write-Host "$ComputerName was not found in Hudu"
    }

} else {
    Write-Host "$CompanyName was not found in Hudu"
}
