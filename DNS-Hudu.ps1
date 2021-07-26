#####################################################################
# Get a Hudu API Key from https://yourhududomain.com/admin/api_keys
$HuduAPIKey = 'abcdefghij123455'
# Set the base domain of your Hudu instance without a trailing /
$HuduBaseDomain = 'https://your.hudu.domain'
$HuduAssetLayoutName = 'DNS Entries - Autodoc'
#####################################################################
# Enable sending alerts on dns change to a teams webhook
$enableTeamsAlerts = $true
$teamsWebhook = 'Your Teams Webhook URL'
# Enable sending alerts on dns change to an email address
$enableEmailAlerts = $true
$mailTo = 'alerts@domain.com'
$mailFrom = 'alerts@domain.com'
$mailServer = 'mailserver.domain.com'
$mailPort = '25'
$mailUseSSL = $true
$mailUser = 'user'
$mailPass = 'pass'
#####################################################################

function Check-DNSChange {
	Param (
		[string]$currentDNS = '',
		[string]$newDNS = '',
		[string]$recordType = '',
		[string]$website = '',
		[string]$companyName = ''
	)
	$Comp = Compare-Object -ReferenceObject $($currentDNS -split "`n") -DifferenceObject $($newDNS -split "`n")
	if ($Comp) {
		# Send Teams Alert
		if ($enableTeamsAlerts) {
			$JSONBody = [PSCustomObject][Ordered]@{
				'@type'      = 'MessageCard'
				'@context'   = 'http://schema.org/extensions'
				'summary'    = "$companyName - $website - DNS $recordType change detected"
				'themeColor' = '0078D7'
				'sections'   = @(
					@{
						'activityTitle' = "$companyName - $website - DNS $recordType Change Detected"
						'facts'         = @(
							@{
								'name'  = 'Original DNS Records'
								'value' = $((($Comp | Where-Object -filter { $_.SideIndicator -eq '<=' }).InputObject | Out-String ) -replace '<[^>]+>', ' ')
							},
							@{
								'name'  = 'New DNS Records'
								'value' = $((($Comp | Where-Object -filter { $_.SideIndicator -eq '=>' }).InputObject | Out-String ) -replace '<[^>]+>', ' ')
							}
						)
						'markdown'      = $true
					}
				)
			}

			$TeamMessageBody = ConvertTo-Json $JSONBody -Depth 100

			$parameters = @{
				'URI'         = $teamsWebhook
				'Method'      = 'POST'
				'Body'        = $TeamMessageBody
				'ContentType' = 'application/json'
			}

			$result = Invoke-RestMethod @parameters

		}
		if ($enableEmailAlerts) {
			$oldVal = ($Comp | Where-Object -filter { $_.SideIndicator -eq '<=' }).InputObject | Out-String
			$newVal = ($Comp | Where-Object -filter { $_.SideIndicator -eq '=>' }).InputObject | Out-String
			$mailSubject = "$companyName - $website - DNS $recordType change detected"
			$body = "
					<h3>$mailSubject</h3>
					<p>Original DNS Record:</p>
					<table>
					$oldVal
					</table>
					<p>New DNS Record:</p>
					<table>
					$newVal
					</table>
					"

			$password = ConvertTo-SecureString $mailPass -AsPlainText -Force
			$mailcred = New-Object System.Management.Automation.PSCredential ($mailUser, $password)

			$sendMailParams = @{
				From       = $mailFrom
				To         = $mailTo
				Subject    = $mailSubject
				Body       = $body
				SMTPServer = $mailServer
				UseSsl     = $mailUseSSL
				Credential = $mailcred
			}


			Send-MailMessage @sendMailParams -BodyAsHtml
		}

	}
}

#Get the Hudu API Module if not installed
if (Get-Module -ListAvailable -Name HuduAPI) {
	Import-Module HuduAPI
} else {
	Install-Module HuduAPI -Force
	Import-Module HuduAPI
}

#Login to Hudu
New-HuduAPIKey $HuduAPIKey
New-HuduBaseUrl $HuduBaseDomain

$Layout = Get-HuduAssetLayouts -name $HuduAssetLayoutName

if (!$Layout) {
	$AssetLayoutFields = @(
		@{
			label        = 'A and AAAA Records'
			field_type   = 'RichText'
			show_in_list = 'true'
			position     = 1
		},
		@{
			label        = 'MX Records'
			field_type   = 'RichText'
			show_in_list = 'false'
			position     = 2
		},
		@{
			label        = 'Name Servers'
			field_type   = 'RichText'
			show_in_list = 'false'
			position     = 3
		},
		@{
			label        = 'TXT Records'
			field_type   = 'RichText'
			show_in_list = 'false'
			position     = 4
		},
		@{
			label        = 'SOA Records'
			field_type   = 'RichText'
			show_in_list = 'false'
			position     = 5
		}
	)

	Write-Host "Creating New Asset Layout $HuduAssetLayoutName"
	$NewLayout = New-HuduAssetLayout -name $HuduAssetLayoutName -icon 'fas fa-sitemap' -color '#00adef' -icon_color '#ffffff' -include_passwords $false -include_photos $false -include_comments $false -include_files $false -fields $AssetLayoutFields
	$Layout = Get-HuduAssetLayouts -name $HuduAssetLayoutName
}

$websites = Get-HuduWebsites | Where-Object -filter { $_.disable_dns -eq $false }
foreach ($website in $websites) {
	$dnsname = ([System.Uri]$website.name).authority
	try {
		$arecords = Resolve-DnsName $dnsname -Type A_AAAA -ErrorAction Stop | Select-Object type, IPADDRESS | Sort-Object IPADDRESS | ConvertTo-Html -Fragment | Out-String
		$mxrecords = Resolve-DnsName $dnsname -Type MX -ErrorAction Stop | Sort-Object NameExchange | ConvertTo-Html -Fragment -Property NameExchange | Out-String
		$nsrecords = Resolve-DnsName $dnsname -Type NS -ErrorAction Stop | Sort-Object NameHost | ConvertTo-Html -Fragment -Property NameHost | Out-String
		$txtrecords = Resolve-DnsName $dnsname -Type TXT -ErrorAction Stop | Select-Object @{N = 'Records'; E = { $($_.strings) } } | Sort-Object Records | ConvertTo-Html -Fragment -Property Records | Out-String
		$soarecords = Resolve-DnsName $dnsname -Type SOA -ErrorAction Stop | Select-Object PrimaryServer, NameAdministrator, SerialNumber | Sort-Object NameAdministrator | ConvertTo-Html -Fragment | Out-String
	} catch {
		Write-Host "$dnsname lookup failed" -ForegroundColor red
		continue
	}

	$AssetFields = @{
		'a_and_aaaa_records' = $arecords
		'mx_records'         = $mxrecords
		'name_servers'       = $nsrecords
		'txt_records'        = $txtrecords
		'soa_records'        = $soarecords
	}


	Write-Host "$dnsname lookup successful" -ForegroundColor green

	$companyid = $website.company_id

	#Swap out # as Hudu doesn't like it when searching
	$AssetName = $dnsname

	#Check if there is already an asset
	$Asset = Get-HuduAssets -name $AssetName -companyid $companyid -assetlayoutid $Layout.id

	#If the Asset does not exist, we edit the body to be in the form of a new asset, if not, we just upload.
	if (!$Asset) {
		Write-Host 'Creating new Asset'
		$Asset = New-HuduAsset -name $AssetName -company_id $companyid -asset_layout_id $Layout.id -fields $AssetFields
	} else {
		#Get the existing records
		$a_cur_value = ($Asset.fields | Where-Object -filter { $_.label -eq 'A and AAAA Records' }).value
		$mx_cur_value = ($Asset.fields | Where-Object -filter { $_.label -eq 'MX Records' }).value
		$ns_cur_value = ($Asset.fields | Where-Object -filter { $_.label -eq 'Name Servers' }).value
		$txt_cur_value = ($Asset.fields | Where-Object -filter { $_.label -eq 'TXT Records' }).value
		$soa_cur_value = ($Asset.fields | Where-Object -filter { $_.label -eq 'SOA Records' }).value

		#Compare the new and old values and send alerts
		Check-DNSChange -currentDNS $a_cur_value -newDNS $arecords -recordType 'A / AAAA' -website $AssetName -companyName $website.company_name
		Check-DNSChange -currentDNS $mx_cur_value -newDNS $mxrecords -recordType 'MX' -website $AssetName -companyName $website.company_name
		Check-DNSChange -currentDNS $ns_cur_value -newDNS $nsrecords -recordType 'Name Servers' -website $AssetName -companyName $website.company_name
		Check-DNSChange -currentDNS $txt_cur_value -newDNS $txtrecords -recordType 'TXT' -website $AssetName -companyName $website.company_name

		Write-Host 'Updating Asset'
		$Asset = Set-HuduAsset -asset_id $Asset.id -name $AssetName -company_id $companyid -asset_layout_id $Layout.id -fields $AssetFields
	}

}
