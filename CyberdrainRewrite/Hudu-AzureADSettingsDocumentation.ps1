# Based on the original script by Kelvin Tegelaar https://github.com/KelvinTegelaar/AutomaticDocumentation
#####################################################################
# Get a Hudu API Key from https://yourhududomain.com/admin/api_keys
$HuduAPIKey = "abcdefght1234567890"
# Set the base domain of your Hudu instance without a trailing /
$HuduBaseDomain = "https://your.hudu.domain"
$HuduAssetLayoutName = "Azure AD - AutoDoc"
#####################################################################
########################## Azure AD ###########################
$customerExclude =@("Example Customer 1","Example Customer 2")
$ApplicationId = "Your-App-ID"
$ApplicationSecret = ConvertTo-SecureString -AsPlainText "Your App Secret" -Force
$TenantID = "Your Tenant ID"
$RefreshToken = "Long refresh token"
$ExchangeRefreshToken = "Long Exchange Refresh Token"
$upn = 'The user upn you created the app with'
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
 
#Connect to your Azure AD Account.
$credential = New-Object System.Management.Automation.PSCredential($ApplicationId, $ApplicationSecret)
$aadGraphToken = New-PartnerAccessToken -ApplicationId $ApplicationId -Credential $credential -RefreshToken $refreshToken -Scopes 'https://graph.windows.net/.default' -ServicePrincipal -Tenant $tenantID 
$graphToken = New-PartnerAccessToken -ApplicationId $ApplicationId -Credential $credential -RefreshToken $refreshToken -Scopes 'https://graph.microsoft.com/.default' -ServicePrincipal -Tenant $tenantID 
Connect-AzureAD -AadAccessToken $aadGraphToken.AccessToken -AccountId $UPN -MsAccessToken $graphToken.AccessToken -TenantId $tenantID | Out-Null
$Customers = Get-AzureADContract -All:$true
Disconnect-AzureAD


$Layout = Get-HuduAssetLayouts -name $HuduAssetLayoutName

if (!$Layout) { 
	$AssetLayoutFields = @(
		@{
			label = 'Primary Domain Name'
			field_type = 'Text'
			show_in_list = 'true'
			position = 1
		},
		@{
			label = 'Users'
			field_type = 'RichText'
			show_in_list = 'false'
			position = 2
		},
		@{
			label = 'Guest Users'
			field_type = 'RichText'
			show_in_list = 'false'
			position = 3
		},
		@{
			label = 'Domain admins'
			field_type = 'RichText'
			show_in_list = 'false'
			position = 4
		},
		@{
			label = 'Applications'
			field_type = 'RichText'
			show_in_list = 'false'
			position = 5
		},
		@{
			label = 'Devices'
			field_type = 'RichText'
			show_in_list = 'false'
			position = 6
		},
		@{
			label = 'Domains'
			field_type = 'RichText'
			show_in_list = 'false'
			position = 7
		}
	)
	
	Write-Host "Creating New Asset Layout"
	$NewLayout = New-HuduAssetLayout -name $HuduAssetLayoutName -icon "fas fa-sitemap" -color "#00adef" -icon_color "#000000" -include_passwords $false -include_photos $false -include_comments $false -include_files $false -fields $AssetLayoutFields
	$Layout = Get-HuduAssetLayouts -name $HuduAssetLayoutName
	
}

foreach ($Customer in $Customers) {
	#Check if customer should be excluded
	if (-Not ($customerExclude -contains $customer.DisplayName)){
		#First lets check for the company
		#Check if they are in Hudu before doing any unnessisary work
		$defaultdomain = $customer.DefaultDomainName
		$hududomain = Get-HuduWebsites -name "https://$defaultdomain"
		if ($($hududomain.id.count) -gt 0) {
			write-host "Processing $($customer.Displayname)" -foregroundColor green
			$CustAadGraphToken = New-PartnerAccessToken -ApplicationId $ApplicationId -Credential $credential -RefreshToken $refreshToken -Scopes "https://graph.windows.net/.default" -ServicePrincipal -Tenant $customer.CustomerContextId
			$CustGraphToken = New-PartnerAccessToken -ApplicationId $ApplicationId -Credential $credential -RefreshToken $refreshToken -Scopes "https://graph.microsoft.com/.default" -ServicePrincipal -Tenant $customer.CustomerContextId
			Connect-AzureAD -AadAccessToken $CustAadGraphToken.AccessToken -AccountId $upn -MsAccessToken $CustGraphToken.AccessToken -TenantId $customer.CustomerContextId | out-null
			
			$Users = Get-AzureADUser -All:$true
			$Applications = Get-AzureADApplication -All:$true
			$Devices = Get-AzureADDevice -all:$true
			$customerdomains = get-azureaddomain
			$AdminUsers = Get-AzureADDirectoryRole | Where-Object { $_.Displayname -like "*Administrator"} | Get-AzureADDirectoryRoleMember
			$PrimaryDomain = ($customerdomains | Where-Object { $_.IsDefault -eq $true }).name
			
			Disconnect-AzureAD
			
			$TableHeader = "<table style=`"width: 100%; border-collapse: collapse; border: 1px solid black;`">"
			$Whitespace = "<br/>"
			$TableStyling = "<th>", "<th style=`"background-color:#00adef; border: 1px solid black;`">"
			
			$NormalUsers = $users | Where-Object { $_.UserType -eq "Member" } | Select-Object DisplayName, mail, @{n="ProxyAddresses";e={$_.ProxyAddresses -join "`r`n"}} | ConvertTo-Html -Fragment | Out-String
			$NormalUsers = $TableHeader + ($NormalUsers -replace $TableStyling) + $Whitespace
			$GuestUsers = $users | Where-Object { $_.UserType -ne "Member" } | Select-Object DisplayName, mail | ConvertTo-Html -Fragment | Out-String
			$GuestUsers =  $TableHeader + ($GuestUsers -replace $TableStyling) + $Whitespace
			$AdminUsers = $AdminUsers | Select-Object Displayname, mail | ConvertTo-Html -Fragment | Out-String
			$AdminUsers = $TableHeader + ($AdminUsers  -replace $TableStyling) + $Whitespace
			$Devices = $Devices | select-object DisplayName, DeviceOSType, DEviceOSversion, ApproximateLastLogonTimeStamp | ConvertTo-Html -Fragment | Out-String
			$Devices =  $TableHeader + ($Devices -replace $TableStyling) + $Whitespace
			$HTMLDomains = $customerdomains | Select-Object Name, IsDefault, IsInitial, Isverified | ConvertTo-Html -Fragment | Out-String
			$HTMLDomains = $TableHeader + ($HTMLDomains -replace $TableStyling) + $Whitespace
			$Applications = $Applications | Select-Object Displayname, AvailableToOtherTenants,PublisherDomain | ConvertTo-Html -Fragment | Out-String
			$Applications = $TableHeader + ($Applications -replace $TableStyling) + $Whitespace
			
			
			# Populate Asset Fields
			$AssetFields = @{
				'primary_domain_name' = $PrimaryDomain
				'users'               = $NormalUsers
				'guest_users'         = $GuestUsers
				'domain_admins'       = $AdminUsers
				'applications'        = $Applications
				'devices'             = $Devices
				'domains'             = $HTMLDomains
			}
		
			
		
			$companyid = $hududomain.company_id
			#Check if there is already an asset	
			$Asset = Get-HuduAssets -name $PrimaryDomain -companyid $companyid -assetlayoutid $Layout.id
	
			#If the Asset does not exist, we edit the body to be in the form of a new asset, if not, we just upload.
			if (!$Asset) {
				Write-Host "Creating new Asset"
				$Asset = New-HuduAsset -name $PrimaryDomain -company_id $companyid -asset_layout_id $Layout.id -fields $AssetFields	
			}
			else {
				Write-Host "Updating Asset"
				$Asset = Set-HuduAsset -asset_id $Asset.id -name $PrimaryDomain -company_id $companyid -asset_layout_id $layout.id -fields $AssetFields	
			}
														
		} else {
			write-host "https://$defaultdomain Not found in Hudu. Please add as a website under the relevant customer" -ForegroundColor Red
		}
	}
}
