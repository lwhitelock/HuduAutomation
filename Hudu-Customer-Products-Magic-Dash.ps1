$VaultName = "Your Key Vault Name"
#### Hudu Settings ####
$HuduAPIKey = Get-AzKeyVaultSecret -vaultName $VaultName -name "HuduAPIKey" -AsPlainText
# Set the base domain of your Hudu instance without a trailing /
$HuduBaseDomain = Get-AzKeyVaultSecret -vaultName $VaultName -name "HuduBaseDomain" -AsPlainText

$DetailsLayoutName = 'Company Details'
$SplitChar = ':'

import-module HuduAPI

#Login to Hudu
New-HuduAPIKey $HuduAPIKey
New-HuduBaseUrl $HuduBaseDomain

$AllowedActions = @('ENABLED', 'NOTE', 'URL')

# Get the Asset Layout
$DetailsLayout = Get-HuduAssetLayouts -name $DetailsLayoutName

# Check we found the layout
if (($DetailsLayout | measure-object).count -ne 1) {
    Write-Error "No / multiple layout(s) found with name $DetailsLayoutName"
} else {
    # Get all the detail assets and loop
    $DetailsAssets = Get-HuduAssets -assetlayoutid $DetailsLayout.id
    foreach ($Asset in $DetailsAssets) {

        # Loop through all the fields on the Asset
        $Fields = foreach ($field in $Asset.fields) {
            # Split the field name
            $SplitField = $Field.label -split $SplitChar

            # Check the field has an allowed action.
            if ($SplitField[1] -notin $AllowedActions) {
                Write-Error "Field $($Field.label) is not an allowed action"
            } else {

                # Format an object to work with
                [PSCustomObject]@{
                    ServiceName   = $SplitField[0]
                    ServiceAction = $SplitField[1]
                    Value         = $field.value
                }
            }
        }

        Foreach ($Service in $fields.servicename | select-object -unique){
            $EnabledField = $fields | Where-Object {$_.servicename -eq $Service -and $_.serviceaction -eq 'ENABLED'}
            $NoteField = $fields | Where-Object {$_.servicename -eq $Service -and $_.serviceaction -eq 'NOTE'}
            $URLField = $fields | Where-Object {$_.servicename -eq $Service -and $_.serviceaction -eq 'URL'}
            if ($EnabledField){
                $Colour = Switch ($EnabledField.value) {
                    $True {'success'}
                    $False {'grey'}
                    default {'grey'}
                }

                $Param = @{
                    Title = $Service
                    CompanyName = $Asset.company_name
                    Shade = $Colour
                }
                
                if ($NoteField.value){
                    $Param['Message'] = $NoteField.value
                    $Param | Add-Member -MemberType NoteProperty -Name 'Message' -Value $NoteField.value
                } else {
                    $Param['Message'] =Switch ($EnabledField.value) {
                        $True {"Customer has $Service"}
                        $False {"No $Service"}
                        default {"No $Service"}
                    }

                }

                if ($URLField.value){
                    $Param['ContentLink'] = $URLField.value
                }
                
                Set-HuduMagicDash @Param

            } else {
                Write-Error "No Enabled Field was found"
            }
        }

    }

}


