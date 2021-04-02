#####################################################################
# Get a Hudu API Key from https://yourhududomain.com/admin/api_keys
$HuduAPIKey = "abcdefghijklmn1234556789"
# Set the base domain of your Hudu instance without a trailing /
$HuduBaseDomain = "https://your.hudu.domain"
$HuduAssetLayoutName = "M365 Azure AD Apps"
#####################################################################
########################## Azure AD ###########################
$customerExclude =@("Example Customer 1","Example Customer 2")
$ApplicationId = "Your APP ID"
$ApplicationSecret = ConvertTo-SecureString -AsPlainText "Your App Secret" -Force
$TenantID = "Your Tenant ID"
$RefreshToken = "Your Long Refresh Token"
$ExchangeRefreshToken = "Your Long Exchange Refresh Token"
$upn = 'user-who-created-app@domain.com'
#####################################################################
# Enable sending alerts on dns change to a teams webhook
$enableTeamsAlerts = $false
$teamsWebhook = "https://yourteamswebhookurl.com/1234567898"
# Enable sending alerts on dns change to an email address
$enableEmailAlerts = $false
$mailTo = "toemail@domain.com"
$mailFrom = "fromemail@domain.com"
$mailServer = "mail.domain.com"
$mailPort = "25"
$mailUseSSL = $true
$mailUser = "user"
$mailPass = "pass"
#####################################################################
function Send-TeamsAlert {
	Param (
	[PSCustomObject]$JSONBody
	)
	
	if ($enableTeamsAlerts) {
				
		$TeamMessageBody = ConvertTo-Json $JSONBody -Depth 100
						
		$parameters = @{
			"URI"         = $teamsWebhook
			"Method"      = 'POST'
			"Body"        = $TeamMessageBody
			"ContentType" = 'application/json'
		}
		
		$result = Invoke-RestMethod @parameters
		
	}	
}

function Send-EmailAlert {
	Param (
	[string]$body,
	[string]$mailSubject
	)
	if ($enableEmailAlerts){					
		$password = ConvertTo-SecureString $mailPass -AsPlainText -Force
		$mailcred = New-Object System.Management.Automation.PSCredential ($mailUser, $password)
		
		$sendMailParams = @{
			From = $mailFrom
			To = $mailTo
			Subject = $mailSubject
			Body = $body
			SMTPServer = $mailServer
			UseSsl = $mailUseSSL
			Credential = $mailcred
		}
		
	
		Send-MailMessage @sendMailParams -BodyAsHtml
	}
}

function Check-PermChange {
	Param (
	[string]$currentPerm = '',
	[string]$newPerm = '',
	[string]$permType = '',
	[string]$appName = '',
	[string]$companyName = ''
	)
	$Comp = Compare-Object -ReferenceObject $($currentPerm -split "`n") -DifferenceObject $($newPerm -split "`n")
		if ($Comp){
			# Send Teams Alert
			$removed = ($Comp | where-object -filter {$_.SideIndicator -eq "<="}).InputObject | out-string
			$newperms = ($Comp | where-object -filter {$_.SideIndicator -eq "=>"}).InputObject | out-string
			
			$outText = ""
			if ($removed){
				$outText = "<h3>Removed Permissions</h3><table>$removed</table>"
			}
			if ($newperms){
				$outText = "$outText<h3>New Permissions</h3><table>$newperms</table>"
			}
			
			$JSONBody = [PSCustomObject][Ordered]@{
					"@type"      = "MessageCard"
					"@context"   = "http://schema.org/extensions"
					"summary"    = "$companyName - $appName - Azure AD App $permType permission change detected"
					"themeColor" = '0078D7'
					"sections"   = @(
						@{
							"activityTitle"    = "$companyName - $appName - Azure AD App $permType permission change detected"
							"markdown" = $true
						},
						@{
							"startGroup" = $true
							"text" = $outText
							
						}
					)
				}
				
			Send-TeamsAlert -JSONBody $JSONBody
			
			
			
			$oldVal = ($Comp | where-object -filter {$_.SideIndicator -eq "<="}).InputObject | out-string
			$newVal = ($Comp | where-object -filter {$_.SideIndicator -eq "=>"}).InputObject | out-string
			$mailSubject = "$companyName - $appName - Azure AD App $permType permission change detected"
			$body = "
				<style>
				table{
					border-collapse: collapse;
					margin: 5px 0;
					font-size: 0.8em;
					font-family: sans-serif;
					min-width: 400px;
					box-shadow: 0 0 20px rgba(0, 0, 0, 0.15);
				}
				h2, p{
					font-size: 0.8em;
					font-family: sans-serif;
				}
				th, td {
					padding: 5px 5px;
					max-width: 400px;
					width:auto;
				}
				thead tr {
					background-color: #009879;
					color: #ffffff;
					text-align: left;
				}
				tr {
					border-bottom: 1px solid #dddddd;
				}
				tr:nth-of-type(even) {
					background-color: #f3f3f3;
				}
				</style>
				<h3>$mailSubject</h3>
				$outText
				</table>
				"
					
				
			Send-EmailAlert -mailSubject $mailSubject -body $body
			
		}
}


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
			label = 'Logo'
			field_type = 'RichText'
			show_in_list = 'false'
			position = 1
		},
		@{
			label = 'Homepage'
			field_type = 'RichText'
			show_in_list = 'false'
			position = 2
		},
		@{
			label = 'Publisher Domain'
			field_type = 'RichText'
			show_in_list = 'false'
			position = 3
		},
		@{
			label = 'OAuth2 Permissions'
			field_type = 'RichText'
			show_in_list = 'false'
			position = 4
		},
		@{
			label = 'App Permissions'
			field_type = 'RichText'
			show_in_list = 'false'
			position = 5
		},
		@{
			label = 'Delegated Permissions'
			field_type = 'RichText'
			show_in_list = 'false'
			position = 6
		},
		@{
			label = 'Granted Date'
			field_type = 'Text'
			show_in_list = 'false'
			position = 7
		}
	)
	
	Write-Host "Creating New Asset Layout $HuduAssetLayoutName"
	$NewLayout = New-HuduAssetLayout -name $HuduAssetLayoutName -icon "fas fa-sitemap" -color "#00adef" -icon_color "#ffffff" -include_passwords $false -include_photos $false -include_comments $false -include_files $false -fields $AssetLayoutFields
	$Layout = Get-HuduAssetLayouts -name $HuduAssetLayoutName
}

 
#Connect to your Azure AD Account.
$credential = New-Object System.Management.Automation.PSCredential($ApplicationId, $ApplicationSecret)
$aadGraphToken = New-PartnerAccessToken -ApplicationId $ApplicationId -Credential $credential -RefreshToken $refreshToken -Scopes 'https://graph.windows.net/.default' -ServicePrincipal -Tenant $tenantID 
$graphToken = New-PartnerAccessToken -ApplicationId $ApplicationId -Credential $credential -RefreshToken $refreshToken -Scopes 'https://graph.microsoft.com/.default' -ServicePrincipal -Tenant $tenantID 
Connect-AzureAD -AadAccessToken $aadGraphToken.AccessToken -AccountId $UPN -MsAccessToken $graphToken.AccessToken -TenantId $tenantID | Out-Null
$Customers = Get-AzureADContract -All:$true
Disconnect-AzureAD

#Login to Hudu
New-HuduAPIKey $HuduAPIKey
New-HuduBaseUrl $HuduBaseDomain


foreach ($Customer in $Customers) {
	#Check if customer should be excluded
	if (-Not ($customerExclude -contains $customer.DisplayName)){
		$Applications = ''
		#First lets check for the company
		#Check if they are in Hudu before doing any unnessisary work
		$defaultdomain = $customer.DefaultDomainName
		$hududomain = Get-HuduWebsites -name "https://$defaultdomain"
		if ($($hududomain.id.count) -gt 0) {
			write-host "Processing $($customer.Displayname)" -foregroundColor green
			$CustAadGraphToken = New-PartnerAccessToken -ApplicationId $ApplicationId -Credential $credential -RefreshToken $refreshToken -Scopes "https://graph.windows.net/.default" -ServicePrincipal -Tenant $customer.CustomerContextId
			$CustGraphToken = New-PartnerAccessToken -ApplicationId $ApplicationId -Credential $credential -RefreshToken $refreshToken -Scopes "https://graph.microsoft.com/.default" -ServicePrincipal -Tenant $customer.CustomerContextId
			Connect-AzureAD -AadAccessToken $CustAadGraphToken.AccessToken -AccountId $upn -MsAccessToken $CustGraphToken.AccessToken -TenantId $customer.CustomerContextId | out-null
			
			
			$Applications = Get-AzureADApplication -All:$true
			foreach ($app in $Applications){
				$allsp = Get-AzureADServicePrincipal -All $true 					
				write-host "$($app.displayName)" -foregroundColor green
				$appName = $app.DisplayName
				if ($appName){
				
					$appsp = Get-AzureADServicePrincipal -All $true | Where-Object {$_.AppId -eq $app.AppId}
					
					$AppDelegatedDate = ""
					$grantedDate = ""
					
					if ($appsp.ObjectId){
						$AppDelegatedDate = ((Get-AzureADServiceAppRoleAssignedTo -ObjectId $appsp.ObjectId).CreationTimestamp)| Sort-Object {[DateTime]$_} | Select -First 1 | Out-String
					}
					
					if ($AppDelegatedDate -eq ""){
						$AppDelegatedDate = "Unknown"
					}
					
					$DelegatedPermissions = [System.Collections.ArrayList]@()
					$AppPermissions = [System.Collections.ArrayList]@()
					$OAuth2Permissions = [System.Collections.ArrayList]@()
					
					
					foreach ($oauth in $app.Oauth2Permissions){
						$perm = $oauth | select @{N='Permission'; E={$_.value}}, @{N='Name'; E={$_.AdminConsentDisplayName}}, @{N='Description'; E={$_.AdminConsentDescription}}
						$null = $OAuth2Permissions.add($perm)
					}
					
					foreach ($reqperm in $App.requiredResourceAccess){
						$sp = $allsp | Where-Object {$_.AppId -eq $reqperm.ResourceAppId}
						foreach ($permission in $($reqperm.ResourceAccess)){
							if ($permission.type -eq "Scope") {
								$perm = $sp.Oauth2Permissions | Where-Object {$_.Id -eq $permission.id} | select @{N='Permission'; E={$_.value}}, @{N='Name'; E={$_.AdminConsentDisplayName}}, @{N='Description'; E={$_.AdminConsentDescription}}
								$null = $DelegatedPermissions.add($perm)
								
							}
							if ($permission.type -eq "Role") {
								$perm = $sp.AppRoles | Where-Object {$_.Id -eq $permission.id} | select @{N='Permission'; E={$_.value}}, @{N='Name'; E={$_.DisplayName}}, @{N='Description'; E={$_.Description}}
								$null = $AppPermissions.add($perm)
							}
												
						}
					}
					
					
					$OAuthHTML = ($OAuth2Permissions | ConvertTo-Html -Fragment | Out-String) -replace "[^a-zA-Z0-9. ,&`"-@<>/#_;]", ''
					$OAuthHTML = $OAuthHTML -replace "&#39;", ''
										
					$AppHTML = ($AppPermissions | ConvertTo-Html -Fragment | Out-String) -replace "[^a-zA-Z0-9. ,&`"-@<>/#_;]", ''
					$AppHTML = $AppHTML -replace "&#39;", ''
										
					$DelegatedHTML = ($DelegatedPermissions | ConvertTo-Html -Fragment | Out-String) -replace "[^a-zA-Z0-9. ,&`"-@<>/#_;]", ''
					$DelegatedHTML = $DelegatedHTML -replace "&#39;", ''
										
					if ($($app.AppLogoURL)){
						$LogoHTML = "<img src=`"$($app.AppLogoURL)`"></img>"
					} else {
						$LogoHTML = ''
					}
					
					$AssetFields = @{
								'logo' 	= $LogoHTML
								'homepage'   = $($app.Homepage)
								'publisher_domain'   = $($app.PublisherDomain)
								'oauth2_permissions'   = $OAuthHTML
								'app_permissions'   = $AppHTML
								'delegated_permissions' = $DelegatedHTML
								'granted_date' = $AppDelegatedDate
							}
							
				
					
					$companyid = $hududomain.company_id
					$companyName = $hududomain.company_name
							
					#Swap out # as Hudu doesn't like it when searching
					$AssetName = $appName
					
					#Check if there is already an asset	
					$Asset = Get-HuduAssets -name $AssetName -companyid $companyid -assetlayoutid $Layout.id
					
					#If the Asset does not exist, we edit the body to be in the form of a new asset, if not, we just upload.
					if (!$Asset) {
						Write-Host "Creating new Asset"
						$outText = ""
						if (($OAuthHTML | measure-object -line).lines -gt 2){
						$outText = "OAuth Permissions: $OAuthHTML"
						}
						
						if (($AppHTML | measure-object -line).lines -gt 2){
						write-host "AppHTML"
						$outText = "$outText App Permissions: $AppHTML"
						}
						
						if (($DelegatedHTML | measure-object -line).lines -gt 2){			
						$outText = "$outText Delegated Permissions: $DelegatedHTML"
						}
						
						$JSONBody = [PSCustomObject][Ordered]@{
							"@type"      = "MessageCard"
							"@context"   = "http://schema.org/extensions"
							"summary"    = "$companyName - $appName - Azure AD - New Application Detected"
							"themeColor" = '0078D7'
							"sections"   = @(
								@{
									"activityTitle"    = "$companyName - $appName - Azure AD: New Application Detected"
									"markdown" = $true
								},
								@{
									"startGroup" = $true
									"text" = $outText
									
								}
							)
						}
							
						Send-TeamsAlert -JSONBody $JSONBody
						Write-Host "Sent Teams Alert"
						
						
						$mailSubject = "$companyName - $appName - Azure AD: New Application Detected"
						$body = "
							<style>
							table{
								border-collapse: collapse;
								margin: 5px 0;
								font-size: 0.8em;
								font-family: sans-serif;
								min-width: 400px;
								box-shadow: 0 0 20px rgba(0, 0, 0, 0.15);
							}
							h2, p{
								font-size: 0.8em;
								font-family: sans-serif;
							}
							th, td {
								padding: 5px 5px;
								max-width: 400px;
								width:auto;
							}
							thead tr {
								background-color: #009879;
								color: #ffffff;
								text-align: left;
							}
							tr {
								border-bottom: 1px solid #dddddd;
							}
							tr:nth-of-type(even) {
								background-color: #f3f3f3;
							}
							</style>
							<h3>$mailSubject</h3>
							$outText
							"
								
							
						Send-EmailAlert -mailSubject $mailSubject -body $body
						Write-Host "Sent Email Alert"
							
						$Asset = New-HuduAsset -name $AssetName -company_id $companyid -asset_layout_id $Layout.id -fields $AssetFields
						Write-Host "Created Asset"
					}
					else {
						$oauth_cur_value = ($Asset.fields | where-object -filter {$_.label -eq "OAuth2 Permissions"}).value
						$app_cur_value = ($Asset.fields | where-object -filter {$_.label -eq "App Permissions"}).value
						$del_cur_value = ($Asset.fields | where-object -filter {$_.label -eq "Delegated Permissions"}).value
						
						
						Check-PermChange -currentPerm $oauth_cur_value -newPerm $OAuthHTML -permType "OAuth2" -appName $AssetName -companyName $hududomain.company_name
						Check-PermChange -currentPerm $app_cur_value -newPerm $AppHTML -permType "App" -appName $AssetName -companyName $hududomain.company_name
						Check-PermChange -currentPerm $del_cur_value -newPerm $DelegatedHTML -permType "Delegated" -appName $AssetName -companyName $hududomain.company_name
						
						
								
						Write-Host "Updating Asset"
						$Asset = Set-HuduAsset -asset_id $Asset.id -name $AssetName -company_id $companyid -asset_layout_id $Layout.id -fields $AssetFields	
					}
				}
			}
			
			Disconnect-AzureAD
		}
	}
}
