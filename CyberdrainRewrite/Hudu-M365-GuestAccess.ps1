# Based on the original script by Kelvin Tegelaar https://github.com/KelvinTegelaar/AutomaticDocumentation
#####################################################################
# Get a Hudu API Key from https://yourhududomain.com/admin/api_keys
$HuduAPIKey = "abcdefgh12344456778c"
# Set the base domain of your Hudu instance without a trailing /
$HuduBaseDomain = "https://your.hudu.domain"
$HuduAssetLayoutName = "M365 Guest logbook - AutoDoc"
#####################################################################
########################## Azure AD ###########################
$customerExclude =@("Example Cuystomer 1","Example Customer 2")
$ApplicationId = "Your app ID"
$ApplicationSecret = ConvertTo-SecureString -AsPlainText "Your App Secret" -Force
$TenantID = "Your Tenant ID"
$RefreshToken = "Long Refresh Token"
$ExchangeRefreshToken = "Long Exchange Refresh Token"
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
			label = 'Guest'
			field_type = 'Text'
			show_in_list = 'true'
			position = 1
		},
		@{
			label = 'Actions'
			field_type = 'RichText'
			show_in_list = 'false'
			position = 2
		}
	)
	
	Write-Host "Creating New Asset Layout $HuduAssetLayoutName"
	$NewLayout = New-HuduAssetLayout -name $HuduAssetLayoutName -icon "fas fa-user-friends" -color "#00adef" -icon_color "#ffffff" -include_passwords $false -include_photos $false -include_comments $false -include_files $false -fields $AssetLayoutFields
	$Layout = Get-HuduAssetLayouts -name $HuduAssetLayoutName
}


$credential = New-Object System.Management.Automation.PSCredential($ApplicationId, $ApplicationSecret)
$aadGraphToken = New-PartnerAccessToken -ApplicationId $ApplicationId -Credential $credential -RefreshToken $refreshToken -Scopes 'https://graph.windows.net/.default' -ServicePrincipal -Tenant $tenantID
$graphToken = New-PartnerAccessToken -ApplicationId $ApplicationId -Credential $credential -RefreshToken $refreshToken -Scopes 'https://graph.microsoft.com/.default' -ServicePrincipal -Tenant $tenantID
Connect-MsolService -AdGraphAccessToken $aadGraphToken.AccessToken -MsGraphAccessToken $graphToken.AccessToken
$customers = Get-MsolPartnerContract -All

foreach ($customer in $customers) {
	#Check if customer should be excluded
	if (-Not ($customerExclude -contains $customer.Name)){
		#First lets check for the company
		#Check if they are in Hudu before doing any unnessisary work
		$defaultdomain = $customer.DefaultDomainName
		$hududomain = Get-HuduWebsites -name "https://$defaultdomain"
		if ($($hududomain.id.count) -gt 0) {
			
			$domains = Get-MsolDomain -TenantId $customer.TenantId
			$token = New-PartnerAccessToken -ApplicationId 'a0c73c16-a7e3-4564-9a95-2bdf47383716' -RefreshToken $ExchangeRefreshToken -Scopes 'https://outlook.office365.com/.default' -Tenant $customer.TenantId
			$tokenValue = ConvertTo-SecureString "Bearer $($token.AccessToken)" -AsPlainText -Force
			$credential = New-Object System.Management.Automation.PSCredential($upn, $tokenValue)
			$customerId = $customer.DefaultDomainName
			$session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri "https://ps.outlook.com/powershell-liveid?DelegatedOrg=$($customerId)&BasicAuthToOAuthConversion=true" -Credential $credential -Authentication Basic -AllowRedirection
			$null = Import-PSSession $session -allowclobber -DisableNameChecking -CommandName "Search-unifiedAuditLog", "Get-AdminAuditLogConfig"
			$GuestUsers = get-msoluser -TenantId $customer.TenantId -all | Where-Object { $_.Usertype -eq "guest" }
			if (!$GuestUsers) { 
				Write-Host "No guests for $($customer.name)" -ForegroundColor Yellow
				continue 
			}
			$startDate = (Get-Date).AddDays(-31)
			$endDate = (Get-Date)
			Write-Host "Retrieving logs for $($customer.name)" -ForegroundColor Blue
			foreach ($guest in $GuestUsers) {
				$Logs = do {
					$log = Search-unifiedAuditLog -SessionCommand ReturnLargeSet -SessionId $customer.name -UserIds $guest.userprincipalname -ResultSize 5000 -StartDate $startDate -EndDate $endDate
					$log
					Write-Host "    Retrieved $($log.count) logs for user $($guest.UserPrincipalName)" -ForegroundColor Green
				}while ($Log.count % 5000 -eq 0 -and $log.count -ne 0)
				if ($logs) {
					$AuditData = $logs.AuditData | ForEach-Object { ConvertFrom-Json $_ }
					
					$AssetFields = @{
						'guest' 	= $guest.userprincipalname
						'actions'   = ($AuditData | select-object CreationTime, Operation, ClientIP, UserID, SiteURL, SourceFilename, UserAgent | convertto-html -Fragment | Out-String)
					}
					
			#end of commands
			
			
			write-output "Uploading O365 guest $($guest.userprincipalname) into Hudu"
			$companyid = $hududomain.company_id
			
			#Swap out # as Hudu doesn't like it when searching
			$AssetName = $guest.userprincipalname -replace "#EXT#", "-EXT"
			
			#Check if there is already an asset	
			$Asset = Get-HuduAssets -name $AssetName -companyid $companyid -assetlayoutid $Layout.id
	
			#If the Asset does not exist, we edit the body to be in the form of a new asset, if not, we just upload.
			if (!$Asset) {
				Write-Host "Creating new Asset"
				$Asset = New-HuduAsset -name $AssetName -company_id $companyid -asset_layout_id $Layout.id -fields $AssetFields	
			}
			else {
				Write-Host "Updating Asset"
				$Asset = Set-HuduAsset -asset_id $Asset.id -name $AssetName -company_id $companyid -asset_layout_id $layout.id -fields $AssetFields	
			}
				}
			} 
			
			Remove-PSSession $session
			
		} else {
			write-host "https://$defaultdomain Not found in Hudu. Please add as a website under the relevant customer" -ForegroundColor Red
		}
	}
} 
