# Input bindings are passed in via param block.
param($Timer)

# Get the current universal time in the default string format.
$currentUTCtime = (Get-Date).ToUniversalTime()

# The 'IsPastDue' property is 'true' when the current function invocation is later than scheduled.
if ($Timer.IsPastDue) {
    Write-Host "PowerShell timer is running late!"
}

# Write an information log with the current time.
Write-Host "Started M365 to Hudu Magic Dash Sync TIME: $currentUTCtime"

#### M365 Settings ####
$customerExclude = ($Env:CustomerExclude) -split ','
$ApplicationId = $Env:ApplicationID
$ApplicationSecret = ConvertTo-SecureString -AsPlainText $Env:ApplicationSecret -Force
$TenantID = $Env:TenantID
$RefreshToken = $Env:RefreshToken
$upn = $Env:UPN

#### Hudu Settings ####
$HuduAPIKey = $Env:HuduAPIKey
# Set the base domain of your Hudu instance without a trailing /
$HuduBaseDomain = $Env:HuduBaseDomain

##########################          Settings         ############################

$CreateInOverview = $true
$OverviewCompany = 'Overview - M365'

#This will toggle on and off importing domains from M365 to Hudu
$importDomains = $true

#For imported domains this will set if monitoring is enabled or disabled
$monitorDomains = $true

##########################          Settings         ############################

####### License Lookup Hash #########
$LicenseLookup = @{
'SPZA_IW' = 'App Connect Iw'
'AAD_BASIC' = 'Azure Active Directory Basic'
'AAD_PREMIUM' = 'Azure Active Directory Premium P1'
'AAD_PREMIUM_P2' = 'Azure Active Directory Premium P2'
'RIGHTSMANAGEMENT' = 'Azure Information Protection Plan 1'
'MCOCAP' = 'Common Area Phone'
'MCOPSTNC' = 'Communications Credits'
'DYN365_ENTERPRISE_PLAN1' = 'Dynamics 365 Customer Engagement Plan Enterprise Edition'
'DYN365_ENTERPRISE_CUSTOMER_SERVICE' = 'Dynamics 365 For Customer Service Enterprise Edition'
'DYN365_FINANCIALS_BUSINESS_SKU' = 'Dynamics 365 For Financials Business Edition'
'DYN365_ENTERPRISE_SALES_CUSTOMERSERVICE' = 'Dynamics 365 For Sales And Customer Service Enterprise Edition'
'DYN365_ENTERPRISE_SALES' = 'Dynamics 365 For Sales Enterprise Edition'
'DYN365_ENTERPRISE_TEAM_MEMBERS' = 'Dynamics 365 For Team Members Enterprise Edition'
'DYN365_TEAM_MEMBERS' = 'Dynamics 365 Team Members'
'Dynamics_365_for_Operations' = 'Dynamics 365 Unf Ops Plan Ent Edition'
'EMS' = 'Enterprise Mobility + Security E3'
'EMSPREMIUM' = 'Enterprise Mobility + Security E5'
'EXCHANGESTANDARD' = 'Exchange Online (Plan 1)'
'EXCHANGEENTERPRISE' = 'Exchange Online (Plan 2)'
'EXCHANGEARCHIVE_ADDON' = 'Exchange Online Archiving For Exchange Online'
'EXCHANGEARCHIVE' = 'Exchange Online Archiving For Exchange Server'
'EXCHANGEESSENTIALS' = 'Exchange Online Essentials'
'EXCHANGE_S_ESSENTIALS' = 'Exchange Online Essentials'
'EXCHANGEDESKLESS' = 'Exchange Online Kiosk'
'EXCHANGETELCO' = 'Exchange Online Pop'
'INTUNE_A' = 'Intune'
'M365EDU_A1' = 'Microsoft 365 A1'
'M365EDU_A3_FACULTY' = 'Microsoft 365 A3 For Faculty'
'M365EDU_A3_STUDENT' = 'Microsoft 365 A3 For Students'
'M365EDU_A5_FACULTY' = 'Microsoft 365 A5 For Faculty'
'M365EDU_A5_STUDENT' = 'Microsoft 365 A5 For Students'
'O365_BUSINESS' = 'Microsoft 365 Apps For Business'
'SMB_BUSINESS' = 'Microsoft 365 Apps For Business'
'OFFICESUBSCRIPTION' = 'Microsoft 365 Apps For Enterprise'
'MCOMEETADV' = 'Microsoft 365 Audio Conferencing'
'MCOMEETADV_GOC' = 'Microsoft 365 Audio Conferencing For Gcc'
'O365_BUSINESS_ESSENTIALS' = 'Microsoft 365 Business Basic'
'SMB_BUSINESS_ESSENTIALS' = 'Microsoft 365 Business Basic'
'SPB' = 'Microsoft 365 Business Premium'
'O365_BUSINESS_PREMIUM' = 'Microsoft 365 Business Standard'
'SMB_BUSINESS_PREMIUM' = 'Microsoft 365 Business Standard'
'MCOPSTN_5' = 'Microsoft 365 Domestic Calling Plan (120 Minutes)'
'SPE_E3' = 'Microsoft 365 E3'
'SPE_E3_USGOV_DOD' = 'Microsoft 365 E3_Usgov_Dod'
'SPE_E3_USGOV_GCCHIGH' = 'Microsoft 365 E3_Usgov_Gcchigh'
'SPE_E5' = 'Microsoft 365 E5'
'INFORMATION_PROTECTION_COMPLIANCE' = 'Microsoft 365 E5 Compliance'
'IDENTITY_THREAT_PROTECTION' = 'Microsoft 365 E5 Security'
'IDENTITY_THREAT_PROTECTION_FOR_EMS_E5' = 'Microsoft 365 E5 Security For Ems E5'
'M365_F1' = 'Microsoft 365 F1'
'SPE_F1' = 'Microsoft 365 F3'
'M365_G3_GOV' = 'Microsoft 365 Gcc G3'
'MCOEV' = 'Microsoft 365 Phone System'
'PHONESYSTEM_VIRTUALUSER' = 'Microsoft 365 Phone System - Virtual User'
'MCOEV_DOD' = 'Microsoft 365 Phone System For Dod'
'MCOEV_FACULTY' = 'Microsoft 365 Phone System For Faculty'
'MCOEV_GOV' = 'Microsoft 365 Phone System For Gcc'
'MCOEV_GCCHIGH' = 'Microsoft 365 Phone System For Gcchigh'
'MCOEVSMB_1' = 'Microsoft 365 Phone System For Small And Medium Business'
'MCOEV_STUDENT' = 'Microsoft 365 Phone System For Students'
'MCOEV_TELSTRA' = 'Microsoft 365 Phone System For Telstra'
'MCOEV_USGOV_DOD' = 'Microsoft 365 Phone System_Usgov_Dod'
'MCOEV_USGOV_GCCHIGH' = 'Microsoft 365 Phone System_Usgov_Gcchigh'
'WIN_DEF_ATP' = 'Microsoft Defender Advanced Threat Protection'
'CRMSTANDARD' = 'Microsoft Dynamics Crm Online'
'CRMPLAN2' = 'Microsoft Dynamics Crm Online Basic'
'FLOW_FREE' = 'Microsoft Flow Free'
'INTUNE_A_D_GOV' = 'Microsoft Intune Device For Government'
'POWERAPPS_VIRAL' = 'Microsoft Power Apps Plan 2 Trial'
'TEAMS_FREE' = 'Microsoft Team (Free)'
'TEAMS_EXPLORATORY' = 'Microsoft Teams Exploratory'
'IT_ACADEMY_AD' = 'Ms Imagine Academy'
'ENTERPRISEPREMIUM_FACULTY' = 'Office 365 A5 For Faculty'
'ENTERPRISEPREMIUM_STUDENT' = 'Office 365 A5 For Students'
'EQUIVIO_ANALYTICS' = 'Office 365 Advanced Compliance'
'ATP_ENTERPRISE' = 'Office 365 Advanced Threat Protection (Plan 1)'
'STANDARDPACK' = 'Office 365 E1'
'STANDARDWOFFPACK' = 'Office 365 E2'
'ENTERPRISEPACK' = 'Office 365 E3'
'DEVELOPERPACK' = 'Office 365 E3 Developer'
'ENTERPRISEPACK_USGOV_DOD' = 'Office 365 E3_Usgov_Dod'
'ENTERPRISEPACK_USGOV_GCCHIGH' = 'Office 365 E3_Usgov_Gcchigh'
'ENTERPRISEWITHSCAL' = 'Office 365 E4'
'ENTERPRISEPREMIUM' = 'Office 365 E5'
'ENTERPRISEPREMIUM_NOPSTNCONF' = 'Office 365 E5 Without Audio Conferencing'
'DESKLESSPACK' = 'Office 365 F3'
'ENTERPRISEPACK_GOV' = 'Office 365 Gcc G3'
'MIDSIZEPACK' = 'Office 365 Midsize Business'
'LITEPACK' = 'Office 365 Small Business'
'LITEPACK_P2' = 'Office 365 Small Business Premium'
'WACONEDRIVESTANDARD' = 'Onedrive For Business (Plan 1)'
'WACONEDRIVEENTERPRISE' = 'Onedrive For Business (Plan 2)'
'POWER_BI_STANDARD' = 'Power Bi (Free)'
'POWER_BI_ADDON' = 'Power Bi For Office 365 Add-On'
'POWER_BI_PRO' = 'Power Bi Pro'
'PROJECTCLIENT' = 'Project For Office 365'
'PROJECTESSENTIALS' = 'Project Online Essentials'
'PROJECTPREMIUM' = 'Project Online Premium'
'PROJECTONLINE_PLAN_1' = 'Project Online Premium Without Project Client'
'PROJECTPROFESSIONAL' = 'Project Online Professional'
'PROJECTONLINE_PLAN_2' = 'Project Online With Project For Office 365'
'SHAREPOINTSTANDARD' = 'Sharepoint Online (Plan 1)'
'SHAREPOINTENTERPRISE' = 'Sharepoint Online (Plan 2)'
'MCOIMP' = 'Skype For Business Online (Plan 1)'
'MCOSTANDARD' = 'Skype For Business Online (Plan 2)'
'MCOPSTN2' = 'Skype For Business Pstn Domestic And International Calling'
'MCOPSTN1' = 'Skype For Business Pstn Domestic Calling'
'MCOPSTN5' = 'Skype For Business Pstn Domestic Calling (120 Minutes)'
'MCOPSTNEAU2' = 'Telstra Calling For O365'
'TOPIC_EXPERIENCES' = 'Topic Experiences'
'VISIOONLINE_PLAN1' = 'Visio Online Plan 1'
'VISIOCLIENT' = 'Visio Online Plan 2'
'VISIOCLIENT_GOV' = 'Visio Plan 2 For Gov'
'WIN10_PRO_ENT_SUB' = 'Windows 10 Enterprise E3'
'WIN10_VDA_E3' = 'Windows 10 Enterprise E3'
'WIN10_VDA_E5' = 'Windows 10 Enterprise E5'
'WINDOWS_STORE' = 'Windows Store For Business'
'RMSBASIC' = 'Azure Information Protection Basic'
'UNIVERSAL_PRINT_M365' = 'Universal Print'
}

### Start ###

import-module HuduAPI
import-module AzureAD.Standard.Preview
Import-module PartnerCenter -UseWindowsPowerShell


#Login to Hudu
New-HuduAPIKey $HuduAPIKey
New-HuduBaseUrl $HuduBaseDomain

#Connect to your Azure AD Account.
$credential = New-Object System.Management.Automation.PSCredential($ApplicationId, $ApplicationSecret)
$aadGraphToken = New-PartnerAccessToken -ApplicationId $ApplicationId -Credential $credential -RefreshToken $refreshToken -Scopes 'https://graph.windows.net/.default' -ServicePrincipal -Tenant $tenantID 
$graphToken = New-PartnerAccessToken -ApplicationId $ApplicationId -Credential $credential -RefreshToken $refreshToken -Scopes 'https://graph.microsoft.com/.default' -ServicePrincipal -Tenant $tenantID 
Connect-AzureAD -AadAccessToken $aadGraphToken.AccessToken -AccountId $UPN -MsAccessToken $graphToken.AccessToken -TenantId $tenantID | Out-Null
$Customers = Get-AzureADContract -All:$true
Disconnect-AzureAD


foreach ($customer in $customers) {	
	#Check if customer should be excluded
	if (-Not ($customerExclude -contains $customer.DisplayName)){
	write-host "#############################################"
	write-host "Starting $($customer.DisplayName)"

	$CustAadGraphToken = New-PartnerAccessToken -ApplicationId $ApplicationId -Credential $credential -RefreshToken $refreshToken -Scopes "https://graph.windows.net/.default" -ServicePrincipal -Tenant $customer.CustomerContextId
    $CustGraphToken = New-PartnerAccessToken -ApplicationId $ApplicationId -Credential $credential -RefreshToken $refreshToken -Scopes "https://graph.microsoft.com/.default" -ServicePrincipal -Tenant $customer.CustomerContextId
    write-host "Connecting to $($customer.Displayname)" -foregroundColor green
    Connect-AzureAD -AadAccessToken $CustAadGraphToken.AccessToken -AccountId $upn -MsAccessToken $CustGraphToken.AccessToken -TenantId $customer.CustomerContextId | out-null
	
	
	#Check if they are in Hudu before doing any unnessisary work
	$defaultdomain = $customer.DefaultDomainName
	$hududomain = Get-HuduWebsites -name "https://$defaultdomain"
	if ($($hududomain.id.count) -gt 0) {
		
		#Create a table to send into Hudu
		$CustomerLinks = "<div class=`"nasa__content`"> 
        <div class=`"nasa__block`"><button class=`"button`" onclick=`"window.open('https://portal.office.com/Partner/BeginClientSession.aspx?CTID=$($customer.CustomerContextId)&CSDEST=o365admincenter')`"><h3><i class=`"fas fa-cogs`">&nbsp;&nbsp;&nbsp;</i>M365 Admin Portal</h3></button></div>
        <div class=`"nasa__block`"><button class=`"button`" onclick=`"window.open('https://outlook.office365.com/ecp/?rfr=Admin_o365&exsvurl=1&delegatedOrg=$($Customer.DefaultDomainName)')`"><h3><i class=`"fas fa-mail-bulk`">&nbsp;&nbsp;&nbsp;</i>Exchange Admin Portal</h3></button></div>
        <div class=`"nasa__block`"><button class=`"button`" onclick=`"window.open('https://aad.portal.azure.com/$($Customer.DefaultDomainName)')`" ><h3><i class=`"fas fa-users-cog`">&nbsp;&nbsp;&nbsp;</i>Azure Active Directory</h3></button></div>
		<div class=`"nasa__block`"><button class=`"button`" onclick=`"window.open('https://endpoint.microsoft.com/$($customer.DefaultDomainName)/')`"><h3><i class=`"fas fa-laptop`">&nbsp;&nbsp;&nbsp;</i>Endpoint Management</h3></button></td></div>
									
		<div class=`"nasa__block`"><button class=`"button`" onclick=`"window.open('https://portal.office.com/Partner/BeginClientSession.aspx?CTID=$($Customer.CustomerContextId)&CSDEST=MicrosoftCommunicationsOnline')`"><h3><i class=`"fab fa-skype`">&nbsp;&nbsp;&nbsp;</i>Sfb Portal</h3></button></div>
        <div class=`"nasa__block`"><button class=`"button`" onclick=`"window.open('https://admin.teams.microsoft.com/?delegatedOrg=$($Customer.DefaultDomainName)')`"><h3><i class=`"fas fa-users`">&nbsp;&nbsp;&nbsp;</i>Teams Portal</h3></button></div>
        <div class=`"nasa__block`"><button class=`"button`" onclick=`"window.open('https://portal.azure.com/$($customer.DefaultDomainName)')`"><h3><i class=`"fas fa-server`">&nbsp;&nbsp;&nbsp;</i>Azure Portal</h3></button></div>
        <div class=`"nasa__block`"><button class=`"button`" onclick=`"window.open('https://account.activedirectory.windowsazure.com/usermanagement/multifactorverification.aspx?tenantId=$($Customer.CustomerContextId)&culture=en-us&requestInitiatedContext=users')`" ><h3><i class=`"fas fa-key`">&nbsp;&nbsp;&nbsp;</i>MFA Portal (Read Only)</h3></button></div>
		
		</div>"
		
		#Get all users
		$Users = Get-AzureADUser -All:$true

		#Grab licensed users		
		$licensedUsers = $Users | where-object {$null -ne $_.AssignedLicenses.SkuId} | Sort-Object UserPrincipalName
		
		$company_name = $hududomain[0].company_name
		$company_id = $hududomain[0].company_id
		
		
		#Grab extra info to put into Hudu
		$AdminUsers = (Get-AzureADDirectoryRole | Where-Object { $_.Displayname -match "Administrator" } | Get-AzureADDirectoryRoleMember | Select-Object @{N='Name';E={"<a target='_blank' href='https://aad.portal.azure.com/$($Customer.DefaultDomainName)/#blade/Microsoft_AAD_IAM/UserDetailsMenuBlade/Profile/userId/$($_.ObjectId)'>$($_.DisplayName) - $($_.UserPrincipalName)</a>"}} -unique).name -join "<br/>"
        
		$customerDomains = (Get-AzureADDomain | Where-Object {$_.IsVerified -eq $True}).Name -join ', ' | Out-String
        
        $detailstable = "<div class='nasa__block'>
							<header class='nasa__block-header'>
							<h1><i class='fas fa-info-circle icon'></i>Basic Info</h1>
							 </header>
								<main>
								<article>
								<div class='basic_info__section'>
								<h2>Tenant Name</h2>
								<p>
									$($customer.DisplayName)
								</p>
								</div>
								<div class='basic_info__section'>
								<h2>Tenant ID</h2>
								<p>
									$($customer.CustomerContextId)
								</p>
								</div>
								<div class='basic_info__section'>
								<h2>Default Domain</h2>
								<p>
									$defaultdomain
								</p>
								</div>
								<div class='basic_info__section'>
								<h2>Customer Domains</h2>
								<p>
									$customerDomains
								</p>
								</div>
								<div class='basic_info__section'>
								<h2>Admin Users</h2>
								<p>
									$AdminUsers
								</p>
								</div>
						</article>
						</main>
						</div>
"
		
		
		$Licenses = Get-AzureADSubscribedSku

	
		# Get the license overview for the tenant
		if ($Licenses) {
			$pre = "<div class=`"nasa__block`"><header class='nasa__block-header'>
			<h1><i class='fas fa-info-circle icon'></i>Current Licenses</h1>
			 </header>"
			
			$post = "</div>"

			$licenseOut = $Licenses | where-object {$_.PrepaidUnits.Enabled -gt 0} | Select-Object @{N='License Name';E={$($LicenseLookup.$($_.SkuPartNumber))}},@{N='Active';E={$_.PrepaidUnits.Enabled}}, @{N='Consumed';E={$_.ConsumedUnits}}, @{N='Unused';E={$_.PrepaidUnits.Enabled - $_.ConsumedUnits}}
			$licenseHTML = $licenseOut | ConvertTo-Html -PreContent $pre -PostContent $post -Fragment | Out-String
		}
		
		# Get all devices from Intune
		$Header = @{
			Authorization = "Bearer $($CustGraphToken.AccessToken)"
		}
		
		$graphApiVersion = "v1.0"
		$Resource = "deviceManagement/managedDevices"
		$uri = "https://graph.microsoft.com/$graphApiVersion/$Resource"
		try {
			$devices = (Invoke-RestMethod -Uri $uri -Headers $Header -Method Get).value
		} catch {
			$devices = ""
		}


		# Get the details of each licensed user in the tenant
		if ($licensedUsers) {
			$pre = "<div class=`"nasa__block`"><header class='nasa__block-header'>
			<h1><i class='fas fa-users icon'></i>Licensed Users</h1>
			 </header>"

			$post = "</div>"
		
			$OutputUsers = foreach ($user in $licensedUsers) {
				$userDevices = ($devices | Where-Object {$_.userPrincipalName -eq $user.UserPrincipalName} | Select-Object @{N='Name';E={"<a target='_blank' href=https://endpoint.microsoft.com/$($customer.DefaultDomainName)/#blade/Microsoft_Intune_Devices/DeviceSettingsBlade/overview/mdmDeviceId/$($_.id)>$($_.deviceName) ($($_.operatingSystem))"}}).name -join "<br/>"
				$aliases = (($user.ProxyAddresses | Where-Object {$_ -cnotmatch "SMTP" -and $_ -notmatch ".onmicrosoft.com"}) -replace "SMTP:", " ") -join "<br/>"
				$userLicenses = $user.AssignedLicenses.SkuID | ForEach-Object {
					$UserLic = $_
					$SkuPartNumber = ($Licenses | Where-Object {$_.SkuId -eq $UserLic}).SkuPartNumber
					$lookedUP = $LicenseLookup.$SkuPartNumber
					if ($lookedUp){
						"$LookedUp <br />"
						} Else {
						"$SkuPartNumber <br />"
						}
				} | Out-String

				[PSCustomObject]@{
					"Display Name" = $user.DisplayName
					"Addresses" = "<strong>$($user.UserPrincipalName)</strong><br/>$aliases"
					"EPM Devices" = $userDevices
					"Assigned Licenses" = $userLicenses
					"Options" = "<a target=`"_blank`" href=https://aad.portal.azure.com/$($Customer.DefaultDomainName)/#blade/Microsoft_AAD_IAM/UserDetailsMenuBlade/Profile/userId/$($user.ObjectId)>Azure AD</a>"
				}
			}

			$licensedUserHTML = $OutputUsers | ConvertTo-Html -PreContent $pre -PostContent $post -Fragment | ForEach-Object {$tmp = $_ -replace "&lt;","<"; $tmp -replace "&gt;",">";} | Out-String

	    }
	
	 

	#Build the output
	$body = "<div class='nasa__block'>
			<header class='nasa__block-header'>
			<h1><i class='fas fa-cogs icon'></i>Administrative Portals</h1>
	 		</header>
			<div>$CustomerLinks</div> 
			<br/>
			</div>
			<br/>
			<div class=`"nasa__content`">
			 $detailstable
			 $licenseHTML
			 </div>
			 <br/>
			 <div class=`"nasa__content`">
			 $licensedUserHTML
			 </div>"
      
   	
	$null = Set-HuduMagicDash -title "Microsoft 365 - $($hududomain[0].company_name)" -company_name $company_name -message "$($licensedUsers.count) Licensed Users" -icon "fab fa-microsoft" -content $body -shade "success"	
	
	if ($CreateInOverview -eq $true){
		$null = Set-HuduMagicDash -title "$($hududomain[0].company_name)" -company_name $OverviewCompany -message "$($licensedUsers.count) Licensed Users" -icon "fab fa-microsoft" -content $body -shade "success"	
    }
	
	
	write-host "https://$defaultdomain Found in Hudu and MagicDash updated for $($hududomain[0].company_name)"  -ForegroundColor Green	
		
	#Import Domains if enabled
	if ($importDomains) {
		$domainstoimport = Get-AzureADDomain
		foreach ($imp in $domainstoimport) {
			$impdomain = $imp.name
			$huduimpdomain = Get-HuduWebsites -name "https://$impdomain"
				if ($($huduimpdomain.id.count) -gt 0) {
					write-host "https://$impdomain Found in Hudu"  -ForegroundColor Green
				} else {
					if ($monitorDomains) {
						$null = New-HuduWebsite -name "https://$impdomain" -notes $HuduNotes -paused "false" -companyid $company_id -disabledns "false" -disablessl "false" -disablewhois "false"
						write-host "https://$impdomain Created in Hudu with Monitoring"  -ForegroundColor Green
					} else {
						$null = New-HuduWebsite -name "https://$impdomain" -notes $HuduNotes -paused "true" -companyid $company_id -disabledns "true" -disablessl "true" -disablewhois "true"
						write-host "https://$impdomain Created in Hudu with Monitoring"  -ForegroundColor Green
					}

				}		
		}
      
	}
    } else {
		write-host "https://$defaultdomain Not found in Hudu please add it to the correct client"  -ForegroundColor Red	
	}

	Disconnect-AzureAD

	}
}	
