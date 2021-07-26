# Based on the original script by Kelvin Tegelaar https://github.com/KelvinTegelaar/AutomaticDocumentation
#####################################################################
# Get a Hudu API Key from https://yourhududomain.com/admin/api_keys
$HuduAPIKey = 'abcdefghi12345656'
# Set the base domain of your Hudu instance without a trailing /
$HuduBaseDomain = 'https://your.hudu.domain'
$HuduAssetLayoutName = 'M365 Teams - AutoDoc'
$TableStyling = '<th>', "<th style=`"background-color:#464775; color: white;`">"
#####################################################################
########################## Azure AD ###########################
$customerExclude = @('Example Customer1', 'Example Customer2')
$ApplicationId = 'Your APP ID'
$ApplicationSecret = 'Your App Secret'
$TenantID = 'Your Tenant ID'
$RefreshToken = 'Your Long Refresh Token'
$ExchangeRefreshToken = 'Your Long Exchange Refresh Token'
$upn = 'UserWhoCreatedApp@domain.com'
########################## Azure AD ###########################

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

$Layout = Get-HuduAssetLayouts -name $HuduAssetLayoutName

if (!$Layout) {
	$AssetLayoutFields = @(
		@{
			label        = 'Team Name'
			field_type   = 'Text'
			show_in_list = 'true'
			position     = 1
		},
		@{
			label        = 'Team URL'
			field_type   = 'Text'
			show_in_list = 'false'
			position     = 2
		},
		@{
			label        = 'Team Message settings'
			field_type   = 'RichText'
			show_in_list = 'false'
			position     = 3
		},
		@{
			label        = 'Team Member settings'
			field_type   = 'RichText'
			show_in_list = 'false'
			position     = 4
		},
		@{
			label        = 'Team Guest settings'
			field_type   = 'RichText'
			show_in_list = 'false'
			position     = 5
		},
		@{
			label        = 'Team Fun Settings'
			field_type   = 'RichText'
			show_in_list = 'false'
			position     = 6
		},
		@{
			label        = 'Team Owners'
			field_type   = 'RichText'
			show_in_list = 'false'
			position     = 7
		},
		@{
			label        = 'Team Members'
			field_type   = 'RichText'
			show_in_list = 'false'
			position     = 8
		},
		@{
			label        = 'Team Guests'
			field_type   = 'RichText'
			show_in_list = 'false'
			position     = 9
		}
	)

	Write-Host "Creating New Asset Layout $HuduAssetLayoutName"
	$NewLayout = New-HuduAssetLayout -name $HuduAssetLayoutName -icon 'fas fa-users' -color '#464775' -icon_color '#ffffff' -include_passwords $false -include_photos $false -include_comments $false -include_files $false -fields $AssetLayoutFields
	$Layout = Get-HuduAssetLayouts -name $HuduAssetLayoutName
}


Write-Host 'Creating credentials and tokens.' -ForegroundColor Green

$credential = New-Object System.Management.Automation.PSCredential($ApplicationId, ($ApplicationSecret | ConvertTo-SecureString -AsPlainText -Force))
$aadGraphToken = New-PartnerAccessToken -ApplicationId $ApplicationId -Credential $credential -RefreshToken $refreshToken -Scopes 'https://graph.windows.net/.default' -ServicePrincipal
$graphToken = New-PartnerAccessToken -ApplicationId $ApplicationId -Credential $credential -RefreshToken $refreshToken -Scopes 'https://graph.microsoft.com/.default' -ServicePrincipal

Write-Host 'Creating body to request Graph access for each client.' -ForegroundColor Green
$body = @{
	'resource'      = 'https://graph.microsoft.com'
	'client_id'     = $ApplicationId
	'client_secret' = $ApplicationSecret
	'grant_type'    = 'client_credentials'
	'scope'         = 'openid'
}

Connect-MsolService -AdGraphAccessToken $aadGraphToken.AccessToken -MsGraphAccessToken $graphToken.AccessToken
$customers = Get-MsolPartnerContract -All
foreach ($Customer in $Customers) {
	#Check if customer should be excluded
	if (-Not ($customerExclude -contains $customer.Name)) {
		#First lets check for the company
		#Check if they are in Hudu before doing any unnessisary work
		$defaultdomain = $customer.DefaultDomainName
		$hududomain = Get-HuduWebsites -name "https://$defaultdomain"
		if ($($hududomain.id.count) -gt 0) {
			$CustomerDomains = Get-MsolDomain -TenantId $Customer.TenantId
			$ClientToken = Invoke-RestMethod -Method post -Uri "https://login.microsoftonline.com/$($customer.tenantid)/oauth2/token" -Body $body -ErrorAction Stop
			$headers = @{ 'Authorization' = "Bearer $($ClientToken.access_token)" }
			Write-Host "Starting documentation process for $($customer.name)." -ForegroundColor Green
			$AllTeamsURI = "https://graph.microsoft.com/beta/groups?`$filter=resourceProvisioningOptions/Any(x:x eq 'Team')&`$top=999"
			$Teams = (Invoke-RestMethod -Uri $AllTeamsURI -Headers $Headers -Method Get -ContentType 'application/json').value
			foreach ($Team in $Teams) {
				$Settings = (Invoke-RestMethod -Uri "https://graph.microsoft.com/beta/Teams/$($team.id)" -Headers $Headers -Method Get -ContentType 'application/json')
				$Members = (Invoke-RestMethod -Uri "https://graph.microsoft.com/beta/groups/$($team.id)/members?`$top=999" -Headers $Headers -Method Get -ContentType 'application/json').value
				$Owners = (Invoke-RestMethod -Uri "https://graph.microsoft.com/beta/groups/$($team.id)/Owners?`$top=999" -Headers $Headers -Method Get -ContentType 'application/json').value


				$AssetFields = @{
					'team_name'             = $settings.displayname
					'team_url'              = $settings.webUrl
					'team_message_settings' = ($settings.messagingSettings | ConvertTo-Html -Fragment -As list | Out-String) -replace $TableStyling
					'team_member_settings'  = ($Settings.memberSettings | ConvertTo-Html -Fragment -As list | Out-String) -replace $TableStyling
					'team_guest_settings'   = ($Settings.guestSettings | ConvertTo-Html -Fragment -As list | Out-String) -replace $TableStyling
					'team_fun_settings'     = ($settings.funSettings | ConvertTo-Html -Fragment -As list | Out-String) -replace $TableStyling
					'team_owners'           = ($Owners | Select-Object Displayname, UserPrincipalname | ConvertTo-Html -Fragment | Out-String) -replace $TableStyling
					'team_members'          = ($Members | Where-Object { $_.UserType -eq 'Member' } | Select-Object Displayname, UserPrincipalname | ConvertTo-Html -Fragment | Out-String) -replace $TableStyling
					'team_guests'           = ($Members | Where-Object { $_.UserType -eq 'Guest' } | Select-Object Displayname, UserPrincipalname | ConvertTo-Html -Fragment | Out-String) -replace $TableStyling
				}



				Write-Output "Uploading M365 Team $($settings.displayname) into Hudu"
				$companyid = $hududomain.company_id

				#Swap out # as Hudu doesn't like it when searching
				$AssetName = $settings.displayname

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
			}

		} else {
			Write-Host "https://$defaultdomain Not found in Hudu. Please add as a website under the relevant customer" -ForegroundColor Red
		}
	}
}
