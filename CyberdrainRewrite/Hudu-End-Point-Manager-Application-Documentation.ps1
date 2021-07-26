################### Secure Application Model Information ###################
$customerExclude = @('Example Customer1', 'Example Customer2')
$ApplicationId = 'Your App ID'
$ApplicationSecret = ConvertTo-SecureString -AsPlainText 'Your App Secret' -Force
$RefreshToken = 'Long Refresh Token'
$TenantID = 'Your Tenant ID'
$upn = 'UserWhoCreatedApp@domain.com'
################# /Secure Application Model Information ####################

################# Hudu Information ######################################
# Get a Hudu API Key from https://yourhududomain.com/admin/api_keys
$HuduAPIKey = 'abcdefghij12345566788'
# Set the base domain of your Hudu instance without a trailing /
$HuduBaseDomain = "https://your.hudu.domain
# EPM = End Point Manager = Intune
$HuduAssetLayoutName = "M365 EPM Applications - Autodoc"
$TableStyling = "<th>", "<th style=`"background-color:#00adef`">"
################# /Hudu Information #####################################

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
			label = 'Tenant name'
			field_type = 'Text'
			show_in_list = 'true'
			position = 1
		},
		@{
			label = 'Tenant ID'
			field_type = 'Email'
			show_in_list = 'false'
			position = 2
		},
		@{
			label = 'Application info'
			field_type = 'RichText'
			show_in_list = 'false'
			position = 3
		}
	)

	Write-Host "Creating New Asset Layout"
	$NewLayout = New-HuduAssetLayout -name $HuduAssetLayoutName -icon "fas fa-mobile" -color "#00adef" -icon_color "#000000" -include_passwords $false -include_photos $false -include_comments $false -include_files $false -fields $AssetLayoutFields
	$Layout = Get-HuduAssetLayouts -name $HuduAssetLayoutName

}


write-host "Generating token to log into Azure AD. Grabbing all tenants" -ForegroundColor Green

$credential = New-Object System.Management.Automation.PSCredential($ApplicationId, $ApplicationSecret)
$Baseuri = "https://graph.microsoft.com/beta"
$aadGraphToken = New-PartnerAccessToken -ApplicationId $ApplicationId -Credential $credential -RefreshToken $refreshToken -Scopes 'https://graph.windows.net/.default' -ServicePrincipal -Tenant $tenantID
$graphToken = New-PartnerAccessToken -ApplicationId $ApplicationId -Credential $credential -RefreshToken $refreshToken -Scopes 'https://graph.microsoft.com/.default' -ServicePrincipal -Tenant $tenantID
Connect-AzureAD -AadAccessToken $aadGraphToken.AccessToken -AccountId $upn -MsAccessToken $graphToken.AccessToken -TenantId $tenantID | Out-Null
$tenants = Get-AzureAdContract -All:$true
Disconnect-AzureAD

foreach ($Tenant in $Tenants) {
	#Check if customer should be excluded
	if (-Not ($customerExclude -contains $Tenant.DisplayName)){
		#First lets check for the company
		#Check if they are in Hudu before doing any unnessisary work
		$defaultdomain = $Tenant.DefaultDomainName
		$hududomain = Get-HuduWebsites -name "https://$defaultdomain"
		if ($($hududomain.id.count) -gt 0) {
			$CustAadGraphToken = New-PartnerAccessToken -ApplicationId $ApplicationId -Credential $credential -RefreshToken $refreshToken -Scopes "https://graph.windows.net/.default" -ServicePrincipal -Tenant $tenant.CustomerContextId
			$CustGraphToken = New-PartnerAccessToken -ApplicationId $ApplicationId -Credential $credential -RefreshToken $refreshToken -Scopes "https://graph.microsoft.com/.default" -ServicePrincipal -Tenant $tenant.CustomerContextId
			Connect-AzureAD -AadAccessToken $CustAadGraphToken.AccessToken -AccountId $upn -MsAccessToken $CustGraphToken.AccessToken -TenantId $tenant.CustomerContextId | out-null
			write-host "Starting documentation process for $($Tenant.Displayname)" -ForegroundColor Green
			$Header = @{
				Authorization = "Bearer $($CustGraphToken.AccessToken)'
			}

			write-host 'Grabbing all applications for $($Tenant.Displayname).' -ForegroundColor Green
			write-host '$bbing Application Assignment for $($Application.displayname)" -ForegroundColor Green
				$GroupsRequired = foreach ($ApplicationAssign in $Application.assignments | where-object { $_.intent -eq "Required" }) {
					(Invoke-RestMethod -Uri "$baseuri/groups/$($Applicationassign.target.groupId)" -Headers $Header -Method get -ContentType "application/json").value.displayName
				}
				$GroupsAvailable = foreach ($ApplicationAssign in $Application.assignments | where-object { $_.intent -eq "Available" }) {
					(Invoke-RestMethod -Uri "$baseuri/groups/$($Applicationassign.target.groupId)" -Headers $Header -Method get -ContentType "application/json").value.displayName
				}
				[pscustomobject]@{
					Displayname               = $Application.Displayname
					description               = $Application.description
					Publisher                 = $application.Publisher
					"Featured Application"    = $application.IsFeatured
					Notes                     = $Application.notes
					"Application is assigned" = $application.isassigned
					"Install Command"         = $Application.InstallCommandLine
					"Uninstall Command"       = $Application.Uninstallcommandline
					"Architectures"           = $Application.applicableArchitectures
					"Created on"              = $Application.createdDateTime
					"Last Modified"           = $Application.LastModifieddatetime
					"Privacy Information URL" = $Application.PrivacyInformationURL
					"Information URL"         = $Application.PrivacyInformationURL
					"Required for group"      = $GroupsRequired -join "`n'"
					"Available to group"      = $GroupsAvailable -join "`n"
				}

			}
			$AppHTML = ($applications | convertto-html -Fragment | out-string) -replace $TableStyling

			$AssetFields = @{
					'tenant_name' 		= 	$tenant.DisplayName
					'tenant_id'    		= 	$tenant.CustomerContextId
					'application_info' 	= 	$AppHTML
				}


			$assetName = "$($Tenant.DefaultDomainName) - Apps"
			write-host "   Uploading App Info $($Tenant.name) into Hudu" -foregroundColor green
			$companyid = $hududomain.company_id
			#Check if there is already an asset
			$Asset = Get-HuduAssets -name $assetName -companyid $companyid -assetlayoutid $Layout.id

			#If the Asset does not exist, we edit the body to be in the form of a new asset, if not, we just upload.
			if (!$Asset) {
				Write-Host "Creating new Asset"
				$Asset = New-HuduAsset -name $assetName -company_id $companyid -asset_layout_id $Layout.id -fields $AssetFields
			}
			else {
				Write-Host "Updating Asset"
				$Asset = Set-HuduAsset -asset_id $Asset.id -name $assetName -company_id $companyid -asset_layout_id $layout.id -fields $AssetFields
			}

		} else {
			write-host "https://$defaultdomain Not found in Hudu. Please add as a website under the relevant customer" -ForegroundColor Red
		}
	}
}

