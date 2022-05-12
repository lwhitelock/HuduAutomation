$VaultName = "Your-Key-Vault"
$CloudFlareHuduToken = Get-AzKeyVaultSecret -VaultName $VaultName -Name "CloudFlareHuduToken" -AsPlainText
$HuduAPIKey = Get-AzKeyVaultSecret -vaultName $VaultName -name "HuduAPIKey" -AsPlainText
$HuduBaseDomain = Get-AzKeyVaultSecret -vaultName $VaultName -name "HuduBaseDomain" -AsPlainText

$HuduAssetLayoutName = "CloudFlare Zones"
$BaseURL = 'https://api.cloudflare.com/client/v4'


function Get-CloudFlarePage {
    param (
        [string]$Uri
    )
    $Page = 0
    [System.Collections.Generic.List[PSCustomObject]]$Array = @()
    do {
        $Page++
        $Result = Invoke-RestMethod -URI "$($Uri)?per_page=50&page=$Page"  -Method Get -Headers $AuthHeaders
        $Result.result | foreach-object {
            $Array.add($_)
        }
    } while ($Page -lt $Result.result_info.total_pages)
    Return $Array
}

function Get-LinkBlock($URL, $Icon, $Title) {
    return "<div class='o365__app' style='text-align:center'><a href=$URL target=_blank><h3><i class=`"$Icon`">&nbsp;&nbsp;&nbsp;</i>$Title</h3></a></div>"
}

import-module HuduAPI

New-HuduAPIKey $HuduAPIKey
New-HuduBaseUrl $HuduBaseDomain

$Layout = Get-HuduAssetLayouts -name $HuduAssetLayoutName

if (!$Layout) { 
	$AssetLayoutFields = @(
        @{
			label = 'Link'
			field_type = 'RichText'
			show_in_list = 'false'
			position = 1
		},
		@{
			label = 'Status'
			field_type = 'Text'
			show_in_list = 'true'
			position = 2
		},
		@{
			label = 'Name Servers'
			field_type = 'RichText'
			show_in_list = 'false'
			position = 3
		},
		@{
			label = 'Original Name Servers'
			field_type = 'RichText'
			show_in_list = 'false'
			position = 4
		},
		@{
			label = 'Original Registrar'
			field_type = 'RichText'
			show_in_list = 'false'
			position = 5
		},
		@{
			label = 'Modified On'
			field_type = 'Date'
			show_in_list = 'true'
			position = 6
		},
		@{
			label = 'Account'
			field_type = 'Text'
			show_in_list = 'true'
			position = 7
		},
		@{
			label = 'Plan'
			field_type = 'Text'
			show_in_list = 'true'
			position = 8
		},
		@{
			label = 'Plan Cost'
			field_type = 'Text'
			show_in_list = 'true'
			position = 9
		},
		@{
			label = 'DNSSEC Status'
			field_type = 'Text'
			show_in_list = 'true'
			position = 10
		},
		@{
			label = 'DNS Records'
			field_type = 'RichText'
			show_in_list = 'true'
			position = 11
		},
		@{
			label = 'Zone Settings'
			field_type = 'RichText'
			show_in_list = 'true'
			position = 12
		},
		@{
			label = 'Firewall Rules'
			field_type = 'RichText'
			show_in_list = 'true'
			position = 13
		},
		@{
			label = 'Page Rules'
			field_type = 'RichText'
			show_in_list = 'true'
			position = 14
		}
	)
	
	Write-Host "Creating New Asset Layout $HuduAssetLayoutName"
	$null = New-HuduAssetLayout -name $HuduAssetLayoutName -icon "fas fa-sitemap" -color "#e6892a" -icon_color "#ffffff" -include_passwords $false -include_photos $false -include_comments $false -include_files $false -fields $AssetLayoutFields
	$Layout = Get-HuduAssetLayouts -name $HuduAssetLayoutName
}

$Websites = Get-HuduWebsites
$ParsedSites = $Websites.name | ForEach-Object { $_ -replace 'https://', '' }

$AuthHeaders = @{
    'Authorization' = "Bearer  $CloudFlareHuduToken"
}

$Zones = Get-CloudFlarePage -URI "$BaseURL/zones"

[System.Collections.Generic.List[PSCustomObject]]$UnmatchedZones = @()

foreach ($Zone in $Zones) {
    try {
        if ($Zone.name -in $ParsedSites) {
            # DNS Records
            $Website = $Websites | where-object { "https://$($Zone.name)" -eq $_.name }

            if (($Website | measure-object).count -eq 1) {

                $ZoneRecords = Get-CloudFlarePage -URI "$BaseURL/zones/$($Zone.ID)/dns_records"
                $ZoneHTML = $ZoneRecords | Select-Object @{N = 'Name'; E = { $_.name } }, @{N = 'Type'; E = { $_.type } }, @{N = 'Content'; E = { $_.content } }, @{N = 'Proxied'; E = { $_.proxied } }, @{N = 'TTL'; E = { $_.ttl } }, @{N = 'Modified'; E = { $_.modified_on } } | convertto-html -as Table -Fragment | out-String

                $ZoneSettings = Get-CloudFlarePage -URI "$BaseURL/zones/$($Zone.ID)/settings"
                $ZoneSettingsHTML = $ZoneSettings | Select-Object @{N = 'Setting'; E = { $_.id } },@{N = 'Value'; E = { $_.value } },@{N = 'Modified'; E = { $_.modified_on } } | convertto-html -as Table -Fragment | out-string
        
                $DNSSec = Get-CloudFlarePage -URI "$BaseURL/zones/$($Zone.ID)/dnssec"

                $FirewallRules = Get-CloudFlarePage -URI "$BaseURL/zones/$($Zone.ID)/firewall/rules" | convertto-html -as Table -Fragment | out-string
                $PageRules = Get-CloudFlarePage -URI "$BaseURL/zones/$($Zone.ID)/pagerules" | convertto-html -as Table -Fragment | out-string

                $CloudflareLink = Get-LinkBlock -URL "https://dash.cloudflare.com/$($Zone.account.id)/$($Zone.name)" -Icon "far fa-cloud" -Title "Open in CloudFlare"

                $AssetFields = @{
                    'link' = $CloudflareLink
                    'status' 	= $Zone.status
                    'name_servers'   = $Zone.name_servers -join ', '
                    'original_name_servers'   = $Zone.original_name_servers -join ', '
                    'original_registrar'   = $Zone.original_registrar
                    'modified_on'   = $Zone.modified_on	
                    'account'   = $Zone.account.name
                    'plan'   = $Zone.plan.name
                    'plan_cost'   = "$($Zone.plan.price) $($Zone.plan.currency)"
                    'dnssec_status'   = $DNSSec.status
                    'dns_records'   = $ZoneHTML
                    'firewall_rules'   = $FirewallRules
                    'page_rules'   = $PageRules
                    'zone_settings'   = $ZoneSettingsHTML
                }

                $AssetName = $Zone.name
                $CompanyID = $Website.company_id

                $Asset = Get-HuduAssets -name $AssetName -companyid $CompanyID -assetlayoutid $Layout.id

                if (!$Asset) {
                    Write-Host "Creating new Asset - $($zone.name)"
                    $Asset = New-HuduAsset -name $AssetName -company_id $CompanyID -asset_layout_id $Layout.id -fields $AssetFields	
                }
                else {
                    Write-Host "Updating Asset - $($zone.name)"
                    $Asset = Set-HuduAsset -asset_id $Asset.id -name $AssetName -company_id $CompanyID -asset_layout_id $Layout.id -fields $AssetFields	
                }

                try {
                $null = New-HuduRelation -FromableType "Asset" -FromableId $Asset.asset.id -ToableType "Website" -ToableId $Website.id -ea stop
                } catch {
                    # "Relation already exists"
                }


            } else {
                Throw "Failed to match to a single website"
            }


        } else {
            $UnmatchedZones.add($Zone)
        }
    } catch {
        Write-Error "Failed processing zone $($Zone.name): $_"
    }
}

Write-Host "The following domains were not matched to a website in Hudu. Please add a website under the correct customer for them"
$UnmatchedZones | Select-Object  name, account
