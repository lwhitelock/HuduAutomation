# Based on the original script by Kelvin Tegelaar https://github.com/KelvinTegelaar/AutomaticDocumentation
#####################################################################
# Get a Hudu API Key from https://yourhududomain.com/admin/api_keys
$HuduAPIKey = '12345678abcedgerg'
# Set the base domain of your Hudu instance without a trailing /
$HuduBaseDomain = 'https://your.hudu.domain'
#Company Name as it appears in Hudu
$CompanyName = 'Example Customer'
$HuduAssetLayoutName = 'File Shares - AutoDoc'
$RecursiveDepth = 2
#####################################################################
#Get the Hudu API Module if not installed
if (Get-Module -ListAvailable -Name HuduAPI) {
    Import-Module HuduAPI
} else {
    Install-Module HuduAPI -Force
    Import-Module HuduAPI
}

If (Get-Module -ListAvailable -Name 'NTFSSecurity') { Import-Module 'NTFSSecurity' } Else { Install-Module 'NTFSSecurity' -Force; Import-Module 'NTFSSecurity' }

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
                    label        = 'Share Name'
                    field_type   = 'Text'
                    show_in_list = 'true'
                    position     = 1
                },
                @{
                    label        = 'Server'
                    field_type   = 'RichText'
                    show_in_list = 'false'
                    position     = 2
                },
                @{
                    label        = 'Share Path'
                    field_type   = 'RichText'
                    show_in_list = 'false'
                    position     = 3
                },
                @{
                    label        = 'Full Control Permissions'
                    field_type   = 'RichText'
                    show_in_list = 'false'
                    position     = 4
                },
                @{
                    label        = 'Modify Permissions'
                    field_type   = 'RichText'
                    show_in_list = 'false'
                    position     = 5
                },
                @{
                    label        = 'Read permissions'
                    field_type   = 'RichText'
                    show_in_list = 'false'
                    position     = 6
                },
                @{
                    label        = 'Deny permissions'
                    field_type   = 'RichText'
                    show_in_list = 'false'
                    position     = 7
                }

            )

            Write-Host "Creating New Asset Layout $HuduAssetLayoutName"
            $NewLayout = New-HuduAssetLayout -name $HuduAssetLayoutName -icon 'fas fa-folder-open' -color '#4CAF50' -icon_color '#ffffff' -include_passwords $false -include_photos $false -include_comments $false -include_files $false -fields $AssetLayoutFields
            $Layout = Get-HuduAssetLayouts -name $HuduAssetLayoutName
        }




        #Collect Data
        $AllsmbShares = Get-SmbShare | Where-Object { ( (@('Remote Admin', 'Default share', 'Remote IPC') -notcontains $_.Description) ) -and $_.ShareType -eq 'FileSystemDirectory' }
        foreach ($SMBShare in $AllSMBShares) {
            $Permissions = Get-Item $SMBShare.path | get-ntfsaccess
            $Permissions += Get-ChildItem -Depth $RecursiveDepth -Recurse $SMBShare.path | get-ntfsaccess
            $FullAccess = $permissions | Where-Object { $_.'AccessRights' -eq 'FullControl' -AND $_.IsInherited -eq $false -AND $_.'AccessControlType' -ne 'Deny' } | Select-Object FullName, Account, AccessRights, AccessControlType | ConvertTo-Html -Fragment | Out-String
            $Modify = $permissions | Where-Object { $_.'AccessRights' -Match 'Modify' -AND $_.IsInherited -eq $false -and $_.'AccessControlType' -ne 'Deny' } | Select-Object FullName, Account, AccessRights, AccessControlType | ConvertTo-Html -Fragment | Out-String
            $ReadOnly = $permissions | Where-Object { $_.'AccessRights' -Match 'Read' -AND $_.IsInherited -eq $false -and $_.'AccessControlType' -ne 'Deny' } | Select-Object FullName, Account, AccessRights, AccessControlType | ConvertTo-Html -Fragment | Out-String
            $Deny = $permissions | Where-Object { $_.'AccessControlType' -eq 'Deny' -AND $_.IsInherited -eq $false } | Select-Object FullName, Account, AccessRights, AccessControlType | ConvertTo-Html -Fragment | Out-String

            if ($FullAccess.Length / 1kb -gt 64) { $FullAccess = 'The table is too long to display. Please see included CSV file.' }
            if ($ReadOnly.Length / 1kb -gt 64) { $ReadOnly = 'The table is too long to display. Please see included CSV file.' }
            if ($Modify.Length / 1kb -gt 64) { $Modify = 'The table is too long to display. Please see included CSV file.' }
            if ($Deny.Length / 1kb -gt 64) { $Deny = 'The table is too long to display. Please see included CSV file.' }
            $PermCSV = ($Permissions | ConvertTo-Csv -NoTypeInformation -Delimiter ',') -join [Environment]::NewLine
            $Bytes = [System.Text.Encoding]::UTF8.GetBytes($PermCSV)
            $Base64CSV = [Convert]::ToBase64String($Bytes)
            $AssetLink = "<a href=$($ParentAsset.url)>$($ParentAsset.name)</a>"

            $AssetFields = @{
                'share_name'               = $($smbshare.name)
                'share_path'               = $($smbshare.path)
                'full_control_permissions' = $FullAccess
                'read_permissions'         = $ReadOnly
                'modify_permissions'       = $Modify
                'deny_permissions'         = $Deny
                'server'                   = $AssetLink

            }

            $AssetName = "$ComputerName - $($smbshare.name)"

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

        }

    } else {
        Write-Host "$ComputerName was not found in Hudu"
    }

} else {
    Write-Host "$CompanyName was not found in Hudu"
}
