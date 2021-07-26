# Based on the original script by Kelvin Tegelaar https://github.com/KelvinTegelaar/AutomaticDocumentation
#####################################################################
# Get a Hudu API Key from https://yourhududomain.com/admin/api_keys
$HuduAPIKey = 'abcdefght1234567890'
# Set the base domain of your Hudu instance without a trailing /
$HuduBaseDomain = 'https://your.hudu.domain'
#Company Name as it appears in Hudu
$CompanyName = 'Company Name'
$HuduAssetLayoutName = 'Active Directory Groups - AutoDoc'
# Enter the name of the Asset Layout you use for storing contacts
$HuduContactLayout = 'People'
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


# Get the Hudu Company we are working without
$Company = Get-HuduCompanies -name $CompanyName
if ($company) {
    $ContactsLayout = Get-HuduAssetLayouts -name $HuduContactLayout
    if ($ContactsLayout) {

        $Layout = Get-HuduAssetLayouts -name $HuduAssetLayoutName

        if (!$Layout) {
            $AssetLayoutFields = @(
                @{
                    label        = 'Group Name'
                    field_type   = 'Text'
                    show_in_list = 'true'
                    position     = 1
                },
                @{
                    label        = 'Members'
                    field_type   = 'RichText'
                    show_in_list = 'false'
                    position     = 2
                },
                @{
                    label        = 'GUID'
                    field_type   = 'Text'
                    show_in_list = 'false'
                    position     = 3
                },
                @{
                    label        = 'Tagged Users'
                    field_type   = 'AssetTag'
                    show_in_list = 'false'
                    linkable_id  = $ContactsLayout.id
                    position     = 4
                }
            )

            Write-Host 'Creating New Asset Layout'
            $NewLayout = New-HuduAssetLayout -name $HuduAssetLayoutName -icon 'fas fa-sitemap' -color '#00adef' -icon_color '#000000' -include_passwords $false -include_photos $false -include_comments $false -include_files $false -fields $AssetLayoutFields
            $Layout = Get-HuduAssetLayouts -name $HuduAssetLayoutName

        }


        #Collect Data
        $AllGroups = Get-ADGroup -Filter *
        foreach ($Group in $AllGroups) {
            [System.Collections.ArrayList]$Contacts = @()
            Write-Host "Group: $($group.name)"
            $Members = Get-ADGroupMember $Group
            $MembersTable = $members | Select-Object Name, distinguishedName | ConvertTo-Html -Fragment | Out-String
            foreach ($Member in $Members) {
                If ($Member.objectClass -eq 'user') {
                    $email = (Get-ADUser $member -Properties EmailAddress).EmailAddress
                    #Tagging Users
                    if ($email) {
                        Write-Host "Searching for $email"
                        $contact = (get-huduassets -assetlayoutid $ContactsLayout.id -companyid $Company.id) | Where-Object { $_.primary_mail -eq $($email) } | Select-Object id, name
                        if ($contact) {
                            Write-Host "Found $email"
                            $Contacts.add($contact)
                        }
                    }
                }
            }

            # Set the group's asset fields
            $AssetFields = @{
                'group_name'   = $($group.name)
                'members'      = $MembersTable
                'guid'         = $($group.objectguid.guid)
                'tagged_users' = $Contacts
            }

            #Upload data to IT-Glue. We try to match the Server name to current computer name.
            $Asset = Get-HuduAssets -name $($group.name) -companyid $company.id -assetlayoutid $layout.id

            #If the Asset does not exist, we edit the body to be in the form of a new asset, if not, we just upload.
            if (!$Asset) {
                Write-Host 'Creating new Asset'
                $Asset = New-HuduAsset -name $($group.name) -company_id $company.id -asset_layout_id $Layout.id -fields $AssetFields
            } else {
                Write-Host 'Updating Asset'
                $Asset = Set-HuduAsset -asset_id $Asset.id -name $($group.name) -company_id $company.id -asset_layout_id $layout.id -fields $AssetFields
            }

        }

    } else {
        Write-Host "$HuduContactLayout Layout was not found in Hudu"
    }
} else {
    Write-Host "$CompanyName was not found in Hudu"
}
