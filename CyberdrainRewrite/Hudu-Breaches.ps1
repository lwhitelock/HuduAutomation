################### Secure Application Model Information ###################
$customerExclude =@("Old Customer 1","Old Customer 2")
$ApplicationId = "Your App ID"
$ApplicationSecret = ConvertTo-SecureString -AsPlainText "Your App Password" -Force
$RefreshToken = "Long refresh token"
################# /Secure Application Model Information ####################
 
################# API Keys #################################################
$ShodanAPIKey = 'Your Shodan Key'
$HaveIBeenPwnedKey = 'Your HIBP Key'
################# /API Keys ################################################
 
################# Hudu Information ######################################
# Get a Hudu API Key from https://yourhududomain.com/admin/api_keys
$HuduAPIKey = "abcdefgh123456789"
# Set the base domain of your Hudu instance without a trailing /
$HuduBaseDomain = "https://your.hudu.domain"
$HuduAssetLayoutName = "Breach - Autodoc"
$TableStyling = "<th>", "<th style=`"background-color:#e96200`">"
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
			label = 'Breaches'
			field_type = 'RichText'
			show_in_list = 'false'
			position = 2
		},
		@{
			label = 'Shodan Info'
			field_type = 'RichText'
			show_in_list = 'false'
			position = 3
		}
	)
	
	Write-Host "Creating New Asset Layout"
	$NewLayout = New-HuduAssetLayout -name $HuduAssetLayoutName -icon "fas fa-user-secret" -color "#e96200" -icon_color "#000000" -include_passwords $false -include_photos $false -include_comments $false -include_files $false -fields $AssetLayoutFields
	$Layout = Get-HuduAssetLayouts -name $HuduAssetLayoutName
	
}

   

write-host "Creating credentials and tokens." -ForegroundColor Green
$credential = New-Object System.Management.Automation.PSCredential($ApplicationId, $ApplicationSecret)
$aadGraphToken = New-PartnerAccessToken -ApplicationId $ApplicationId -Credential $credential -RefreshToken $refreshToken -Scopes 'https://graph.windows.net/.default' -ServicePrincipal
$graphToken = New-PartnerAccessToken -ApplicationId $ApplicationId -Credential $credential -RefreshToken $refreshToken -Scopes 'https://graph.microsoft.com/.default' -ServicePrincipal
$HIBPHeader = @{'hibp-api-key' = $HaveIBeenPwnedKey }
write-host "Connecting to Office365 to get all tenants." -ForegroundColor Green
Connect-MsolService -AdGraphAccessToken $aadGraphToken.AccessToken -MsGraphAccessToken $graphToken.AccessToken
$customers = Get-MsolPartnerContract -All
foreach ($Customer in $Customers) {
	#Check if customer should be excluded
	if (-Not ($customerExclude -contains $customer.name)){
		#First lets check for the company
		#Check if they are in Hudu before doing any unnessisary work
		$defaultdomain = $customer.DefaultDomainName
		$hududomain = Get-HuduWebsites -name "https://$defaultdomain"
		if ($($hududomain.id.count) -gt 0) {
			$CustomerDomains = Get-MsolDomain -TenantId $Customer.TenantId
			write-host "  Retrieving Breach Info for $($customer.name)" -ForegroundColor Green
			$UserList = get-msoluser -all -TenantId $Customer.TenantId
			$HIBPList = foreach ($User in $UserList) {
				try {
					$Breaches = $null
					$Breaches = Invoke-RestMethod -Uri "https://haveibeenpwned.com/api/v3/breachedaccount/$($user.UserPrincipalName)?truncateResponse=false" -Headers $HIBPHeader -UserAgent 'Hudu PowerShell Breach Script'
				}
				catch {
					if ($_.Exception.Response.StatusCode.value__ -eq '404') {  } else { write-error "$($_.Exception.message)" }
				}
				start-sleep 1.5
				foreach ($Breach in $Breaches) {
					[PSCustomObject]@{
						Username              = $user.UserPrincipalName
						'Name'                = $Breach.name
						'Domain name'         = $breach.Domain
						'Date'                = $Breach.Breachdate
						'Verified by experts' = if ($Breach.isverified) { 'Yes' } else { 'No' }
						'Leaked data'         = $Breach.DataClasses -join ', '
						'Description'         = $Breach.Description
					}
				}
			}		
			$PreContent = '<p>A "breach" is an incident where data is inadvertently exposed in a vulnerable system, usually due to insufficient access controls or security weaknesses in the software. HIBP aggregates breaches and enables people to assess where their personal data has been exposed.</p><br>'
			$BreachListRaw = $HIBPList | ConvertTo-Html -Fragment | Out-String			
			$BreachListHTML = $PreContent + $BreachListRaw 
			write-host "Getting Shodan information for $($Customer.name)'s domains."
			$ShodanInfo = foreach ($Domain in $CustomerDomains.Name) {
				$ShodanQuery = (Invoke-RestMethod -Uri "https://api.shodan.io/shodan/host/search?key=$($ShodanAPIKey)&query=$Domain" -UserAgent 'CyberDrain.com PowerShell Breach Script').matches
				foreach ($FoundItem in $ShodanQuery) {
					[PSCustomObject]@{
						'Searched for'    = $Domain
						'Found Product'   = $FoundItem.product
						'Found open port' = $FoundItem.port
						'Found IP'        = $FoundItem.ip_str
						'Found Domain'    = $FoundItem.domain
					}
	
				}
			}
			
			
			
			if (!$ShodanInfo) { 
				$ShodanHTML = "<h2>Shodan Information</h2><br>Shodan is a search engine, but one designed specifically for internet connected devices. It scours the invisible parts of the Internet most people wont ever see. Any internet exposed connected device can show up in a search.<br><p>No information found for domains on Shodan</p>"
			} else {
				$ShodanRawHTML = $ShodanInfo | ConvertTo-Html -Fragment -PreContent "<h2>Shodan Information</h2><br>Shodan is a search engine, but one designed specifically for internet connected devices. It scours the invisible parts of the Internet most people wont ever see. Any internet exposed connected device can show up in a search.<br>" | Out-String
				$ShodanHTML = ($ShodanRawHTML -replace $TableStyling)

			}
			
			
			$AssetFields = @{
					'tenant_name' = $customer.DefaultDomainName
					'breaches'    = [System.Web.HttpUtility]::HtmlDecode($BreachListHTML -replace $TableStyling)
					'shodan_info' = $ShodanHTML
				}
			
			$assetName = "$($customer.DefaultDomainName) - Breaches"
			write-host "   Uploading Breach Info $($customer.name) into Hudu" -foregroundColor green
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
