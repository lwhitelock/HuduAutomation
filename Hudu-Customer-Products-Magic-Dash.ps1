<#
.SYNOPSIS
This script interacts with the Hudu API to manage Magic Dash items based on asset details.

.DESCRIPTION
Logs into Hudu using provided credentials and manages Magic Dash items by processing asset details from a specified asset layout. Supports setting actions and values based on asset fields.

.PARAMETER ApiKey
The API Key for accessing Hudu. If not provided as a parameter, the script will attempt to use the HuduAPIKey environment variable.

.PARAMETER BaseDomain
The base domain of your Hudu instance without a trailing slash. If not provided as a parameter, the script will attempt to use the HuduBaseDomain environment variable.

.PARAMETER DetailsLayoutName
The name of the asset layout to process. Defaults to 'Company Details'.

.EXAMPLE
PS> .\Hudu-Customer-Products-Magic-Dash.ps1 -ApiKey "yourapikey" -BaseDomain "your.hudu.domain"
This example runs the script with the API key and base domain provided directly as parameters.
#>
param (
    [string]$ApiKey = $env:HuduAPIKey,
    [string]$BaseDomain = $env:HuduBaseDomain,
    [string]$DetailsLayoutName = 'Company Details'
)

if (-not $ApiKey -or -not $BaseDomain) {
    Write-Error "API Key and Base Domain must be provided either as parameters or as environment variables."
    exit
}

$SplitChar = ':'

Import-Module HuduAPI

# Login to Hudu
New-HuduAPIKey $ApiKey
New-HuduBaseUrl $BaseDomain

$AllowedActions = @('ENABLED', 'NOTE', 'URL')

# Get the Asset Layout
$DetailsLayout = Get-HuduAssetLayouts -name $DetailsLayoutName

# Check we found the layout
if (($DetailsLayout | Measure-Object).Count -ne 1) {
    Write-Error "No / multiple layout(s) found with name $DetailsLayoutName"
    exit
}

# Get all the detail assets and loop
$DetailsAssets = Get-HuduAssets -assetlayoutid $DetailsLayout.id
foreach ($Asset in $DetailsAssets) {
    # Loop through all the fields on the Asset
    $Fields = foreach ($field in $Asset.fields) {
        # Split the field name
        $SplitField = $Field.label -split $SplitChar

        # Check the field has an allowed action.
        if ($SplitField[1] -notin $AllowedActions) {
            Write-Host "Skipping field $($Field.label) as it is not an allowed action"
        } else {
            # Format an object to work with
            [PSCustomObject]@{
                ServiceName   = $SplitField[0]
                ServiceAction = $SplitField[1]
                Value         = $field.value
            }
        }
    }

    Foreach ($Service in $Fields.ServiceName | Select-Object -Unique){
        $EnabledField = $Fields | Where-Object {$_.ServiceName -eq $Service -and $_.ServiceAction -eq 'ENABLED'}
        $NoteField = $Fields | Where-Object {$_.ServiceName -eq $Service -and $_.ServiceAction -eq 'NOTE'}
        $URLField = $Fields | Where-Object {$_.ServiceName -eq $Service -and $_.ServiceAction -eq 'URL'}

        if ($EnabledField) {
            $Colour = Switch ($EnabledField.Value) {
                $True {'success'}
                $False {'grey'}
                default {'grey'}
            }

            $DashTitle = "$($Asset.company_name) - $Service"
            $Message = if ($NoteField) { $NoteField.Value } elseif ($EnabledField.Value -eq $True) { "Customer has $Service" } else { "No $Service" }

            $Param = @{
                Title = $DashTitle
                CompanyName = $Asset.company_name
                Shade = $Colour
                Message = if ($Message) { $Message } else { "Details not available" }
            }

            if ($URLField) {
                $Param['ContentLink'] = $URLField.Value
            }

            $null = Set-HuduMagicDash @Param

        } else {
            Write-Error "No ENABLED Field was found for service $Service in asset $($Asset.company_name)"
        }
    }
}
