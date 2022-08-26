#
# Make sure your Partner app has delegated and app API permissions for the graph API DeviceManagementManagedDevices.Read.All with admin permissions granted
#
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
'ADV_COMMS' = 'Advanced Communications'
'CDSAICAPACITY' = 'Ai Builder Capacity Add-On'
'SPZA_IW' = 'App Connect Iw'
'MCOMEETADV' = 'Microsoft 365 Audio Conferencing'
'AAD_BASIC' = 'Azure Active Directory Basic'
'AAD_PREMIUM' = 'Azure Active Directory Premium P1'
'AAD_PREMIUM_P2' = 'Azure Active Directory Premium P2'
'RIGHTSMANAGEMENT' = 'Azure Information Protection Plan 1'
'SMB_APPS' = 'Business Apps (Free)'
'MCOCAP' = 'Common Area Phone'
'MCOCAP_GOV' = 'Common Area Phone For Gcc'
'CDS_DB_CAPACITY' = 'Common Data Service Database Capacity'
'CDS_DB_CAPACITY_GOV' = 'Common Data Service Database Capacity For Government'
'CDS_LOG_CAPACITY' = 'Common Data Service Log Capacity'
'MCOPSTNC' = 'Communications Credits'
'CRMSTORAGE' = 'Dynamics 365 - Additional Database Storage (Qualified Offer)'
'CRMINSTANCE' = 'Dynamics 365 - Additional Production Instance (Qualified Offer)'
'CRMTESTINSTANCE' = 'Dynamics 365 - Additional Non-Production Instance (Qualified Offer)'
'SOCIAL_ENGAGEMENT_APP_USER ' = 'Dynamics 365 Ai For Market Insights (Preview)'
'DYN365_ASSETMANAGEMENT' = 'Dynamics 365 Asset Management Addl Assets'
'DYN365_BUSCENTRAL_ADD_ENV_ADDON' = 'Dynamics 365 Business Central Additional Environment Addon'
'DYN365_BUSCENTRAL_DB_CAPACITY' = 'Dynamics 365 Business Central Database Capacity'
'DYN365_BUSCENTRAL_ESSENTIAL' = 'Dynamics 365 Business Central Essentials'
'DYN365_FINANCIALS_ACCOUNTANT_SKU' = 'Dynamics 365 Business Central External Accountant'
'PROJECT_MADEIRA_PREVIEW_IW_SKU' = 'Dynamics 365 Business Central For Iws'
'DYN365_BUSCENTRAL_PREMIUM' = 'Dynamics 365 Business Central Premium'
'DYN365_ENTERPRISE_PLAN1' = 'Dynamics 365 Customer Engagement Plan'
'DYN365_CUSTOMER_INSIGHTS_VIRAL ' = 'Dynamics 365 Talent: Attract '
'Dynamics_365_Customer_Service_Enterprise_viral_trial ' = 'Dynamics 365 Customer Service Enterprise Viral Trial '
'DYN365_AI_SERVICE_INSIGHTS' = 'Dynamics 365 Customer Service Insights Trial'
'FORMS_PRO' = 'Dynamics 365 Customer Voice Trial'
'DYN365_CUSTOMER_SERVICE_PRO' = 'Dynamics 365 Customer Service Professional'
'Forms_Pro_AddOn' = 'Dynamics 365 Customer Voice Additional Responses'
'Forms_Pro_USL' = 'Dynamics 365 Customer Voice Usl'
'CRM_ONLINE_PORTAL' = 'Dynamics 365 Enterprise Edition - Additional Portal (Qualified Offer)'
'Dynamics_365_Field_Service_Enterprise_viral_trial ' = 'Dynamics 365 Field Service Viral Trial '
'DYN365_FINANCE' = 'Dynamics 365 Finance'
'DYN365_ENTERPRISE_CUSTOMER_SERVICE' = 'Dynamics 365 For Customer Service Enterprise Edition'
'DYN365_FINANCIALS_BUSINESS_SKU' = 'Dynamics 365 For Financials Business Edition'
'DYN365_ENTERPRISE_SALES_CUSTOMERSERVICE' = 'Dynamics 365 For Sales And Customer Service Enterprise Edition'
'DYN365_ENTERPRISE_SALES' = 'Dynamics 365 For Sales Enterprise Edition'
'DYN365_BUSINESS_MARKETING ' = 'Dynamics 365 Marketing Business Edition '
'DYN365_REGULATORY_SERVICE ' = 'Dynamics 365 Regulatory Service - Enterprise Edition Trial '
'Dynamics_365_Sales_Premium_Viral_Trial ' = 'Dynamics 365 Sales Premium Viral Trial '
'D365_SALES_PRO ' = 'Dynamics 365 For Sales Professional'
'D365_SALES_PRO_IW ' = 'Dynamics 365 For Sales Professional Trial '
'D365_SALES_PRO_ATTACH' = 'Dynamics 365 Sales Professional Attach To Qualifying Dynamics 365 Base Offer'
'DYN365_SCM' = 'Dynamics 365 For Supply Chain Management'
'SKU_Dynamics_365_for_HCM_Trial' = 'Dynamics 365 For Talent'
'DYN365_ENTERPRISE_TEAM_MEMBERS' = 'Dynamics 365 For Team Members Enterprise Edition'
'GUIDES_USER' = 'Dynamics 365 Guides'
'Dynamics_365_for_Operations_Devices' = 'Dynamics 365 Operations - Device'
'Dynamics_365_for_Operations_Sandbox_Tier2_SKU' = 'Dynamics 365 Operations - Sandbox Tier 2:Standard Acceptance Testing'
'Dynamics_365_for_Operations_Sandbox_Tier4_SKU' = 'Dynamics 365 Operations - Sandbox Tier 4:Standard Performance Testing'
'DYN365_ENTERPRISE_P1_IW' = 'Dynamics 365 P1 Trial For Information Workers'
'MICROSOFT_REMOTE_ASSIST' = 'Dynamics 365 Remote Assist'
'MICROSOFT_REMOTE_ASSIST_HOLOLENS' = 'Dynamics 365 Remote Assist Hololens'
'D365_SALES_ENT_ATTACH' = 'Dynamics 365 Sales Enterprise Attach To Qualifying Dynamics 365 Base Offer'
'DYNAMICS_365_ONBOARDING_SKU' = 'Dynamics 365 Talent: Onboard'
'DYN365_TEAM_MEMBERS' = 'Dynamics 365 Team Members'
'Dynamics_365_for_Operations' = 'Dynamics 365 Unf Ops Plan Ent Edition'
'EMS' = 'Enterprise Mobility + Security E3'
'EMSPREMIUM' = 'Enterprise Mobility + Security E5'
'EMS_GOV' = 'Enterprise Mobility + Security G3 Gcc'
'EMSPREMIUM_GOV' = 'Enterprise Mobility + Security G5 Gcc'
'EOP_ENTERPRISE_PREMIUM' = 'Exchange Enterprise Cal Services (Eop Dlp)'
'EXCHANGESTANDARD' = 'Exchange Online (Plan 1)'
'EXCHANGESTANDARD_GOV' = 'Exchange Online (Plan 1) For Gcc'
'EXCHANGEENTERPRISE' = 'Exchange Online (Plan 2)'
'EXCHANGEARCHIVE_ADDON' = 'Exchange Online Archiving For Exchange Online'
'EXCHANGEARCHIVE' = 'Exchange Online Archiving For Exchange Server'
'EXCHANGEESSENTIALS' = 'Exchange Online Essentials (Exo P1 Based)'
'EXCHANGE_S_ESSENTIALS' = 'Exchange Online Essentials'
'EXCHANGEDESKLESS' = 'Exchange Online Kiosk'
'EXCHANGETELCO' = 'Exchange Online Pop'
'EOP_ENTERPRISE' = 'Exchange Online Protection'
'INTUNE_A' = 'Intune'
'AX7_USER_TRIAL' = 'Microsoft Dynamics Ax7 User Trial'
'MFA_STANDALONE' = 'Microsoft Azure Multi-Factor Authentication'
'THREAT_INTELLIGENCE' = 'Microsoft Defender For Office 365 (Plan 2)'
'M365EDU_A1' = 'Microsoft 365 A1'
'M365EDU_A3_FACULTY' = 'Microsoft 365 A3 For Faculty'
'M365EDU_A3_STUDENT' = 'Microsoft 365 A3 For Students'
'M365EDU_A3_STUUSEBNFT' = 'Microsoft 365 A3 For Students Use Benefit'
'M365EDU_A3_STUUSEBNFT_RPA1' = 'Microsoft 365 A3 - Unattended License For Students Use Benefit'
'M365EDU_A5_FACULTY' = 'Microsoft 365 A5 For Faculty'
'M365EDU_A5_STUDENT' = 'Microsoft 365 A5 For Students'
'M365EDU_A5_STUUSEBNFT' = 'Microsoft 365 A5 For Students Use Benefit'
'M365EDU_A5_NOPSTNCONF_STUUSEBNFT' = 'Microsoft 365 A5 Without Audio Conferencing For Students Use Benefit'
'O365_BUSINESS' = 'Microsoft 365 Apps For Business'
'OFFICESUBSCRIPTION' = 'Microsoft 365 Apps For Enterprise'
'OFFICESUBSCRIPTION_FACULTY' = 'Microsoft 365 Apps For Faculty'
'MCOMEETADV_GOC' = 'Microsoft 365 Audio Conferencing For Gcc'
'O365_BUSINESS_ESSENTIALS' = 'Microsoft 365 Business Basic'
'O365_BUSINESS_PREMIUM' = 'Microsoft 365 Business Standard'
'SMB_BUSINESS_PREMIUM' = 'Microsoft 365 Business Standard - Prepaid Legacy'
'SPB' = 'Microsoft 365 Business Premium'
'BUSINESS_VOICE_MED2' = 'Microsoft 365 Business Voice'
'BUSINESS_VOICE_MED2_TELCO' = 'Microsoft 365 Business Voice (Us)'
'BUSINESS_VOICE_DIRECTROUTING' = 'Microsoft 365 Business Voice (Without Calling Plan) '
'BUSINESS_VOICE_DIRECTROUTING_MED' = 'Microsoft 365 Business Voice (Without Calling Plan) For Us'
'MCOPSTN_5' = 'Microsoft 365 Domestic Calling Plan (120 Minutes)'
'MCOPSTN_1_GOV' = 'Microsoft 365 Domestic Calling Plan For Gcc'
'SPE_E3' = 'Microsoft 365 E3'
'SPE_E3_RPA1' = 'Microsoft 365 E3 - Unattended License'
'SPE_E3_USGOV_DOD' = 'Microsoft 365 E3_Usgov_Dod'
'SPE_E3_USGOV_GCCHIGH' = 'Microsoft 365 E3_Usgov_Gcchigh'
'SPE_E5' = 'Microsoft 365 E5'
'DEVELOPERPACK_E5' = 'Microsoft 365 E5 Developer (Without Windows And Audio Conferencing)'
'INFORMATION_PROTECTION_COMPLIANCE' = 'Microsoft 365 E5 Compliance'
'IDENTITY_THREAT_PROTECTION' = 'Microsoft 365 E5 Security'
'IDENTITY_THREAT_PROTECTION_FOR_EMS_E5' = 'Microsoft 365 E5 Security For Ems E5'
'SPE_E5_NOPSTNCONF' = 'Microsoft 365 E5 Without Audio Conferencing '
'M365_F1' = 'Microsoft 365 F1'
'SPE_F1' = 'Microsoft 365 F3'
'M365_F1_GOV' = 'Microsoft 365 F3 Gcc'
'SPE_F5_SECCOMP ' = 'Microsoft 365 F5 Security + Compliance Add-On '
'FLOW_FREE' = 'Microsoft Flow Free'
'M365_E5_SUITE_COMPONENTS' = 'Microsoft 365 E5 Suite Features'
'M365_G3_GOV' = 'Microsoft 365 G3 Gcc'
'MCOEV' = 'Microsoft 365 Phone System'
'MCOEV_DOD' = 'Microsoft 365 Phone System For Dod'
'MCOEV_FACULTY' = 'Microsoft 365 Phone System For Faculty'
'MCOEV_GOV' = 'Microsoft 365 Phone System For Gcc'
'MCOEV_GCCHIGH' = 'Microsoft 365 Phone System For Gcchigh'
'MCOEVSMB_1' = 'Microsoft 365 Phone System For Small And Medium Business'
'MCOEV_STUDENT' = 'Microsoft 365 Phone System For Students'
'MCOEV_TELSTRA' = 'Microsoft 365 Phone System For Telstra'
'MCOEV_USGOV_DOD' = 'Microsoft 365 Phone System_Usgov_Dod'
'MCOEV_USGOV_GCCHIGH' = 'Microsoft 365 Phone System_Usgov_Gcchigh'
'PHONESYSTEM_VIRTUALUSER' = 'Microsoft 365 Phone System - Virtual User'
'PHONESYSTEM_VIRTUALUSER_GOV' = 'Microsoft 365 Phone System - Virtual User For Gcc'
'M365_SECURITY_COMPLIANCE_FOR_FLW' = 'Microsoft 365 Security And Compliance For Firstline Workers'
'MICROSOFT_BUSINESS_CENTER' = 'Microsoft Business Center'
'ADALLOM_STANDALONE' = 'Microsoft Cloud App Security'
'WIN_DEF_ATP' = 'Microsoft Defender For Endpoint'
'MDATP_Server' = 'Microsoft Defender For Endpoint Server'
'CRMPLAN2' = 'Microsoft Dynamics Crm Online Basic'
'ATA' = 'Microsoft Defender For Identity'
'ATP_ENTERPRISE_GOV' = 'Microsoft Defender For Office 365 (Plan 1) Gcc '
'THREAT_INTELLIGENCE_GOV' = 'Microsoft Defender For Office 365 (Plan 2) Gcc'
'CRMSTANDARD' = 'Microsoft Dynamics Crm Online'
'IT_ACADEMY_AD' = 'Ms Imagine Academy'
'INTUNE_A_D' = 'Microsoft Intune Device'
'INTUNE_A_D_GOV' = 'Microsoft Intune Device For Government'
'POWERAPPS_DEV ' = 'Microsoft Power Apps For Developer '
'POWERAPPS_VIRAL' = 'Microsoft Power Apps Plan 2 Trial'
'FLOW_P2' = 'Microsoft Power Automate Plan 2'
'INTUNE_SMB' = 'Microsoft Intune Smb'
'POWERFLOW_P2' = 'Microsoft Power Apps Plan 2 (Qualified Offer)'
'STREAM' = 'Microsoft Stream'
'STREAM_P2' = 'Microsoft Stream Plan 2'
'STREAM_STORAGE' = 'Microsoft Stream Storage Add-On (500 Gb)'
'TEAMS_FREE' = 'Microsoft Teams (Free)'
'TEAMS_EXPLORATORY' = 'Microsoft Teams Exploratory'
'MEETING_ROOM' = 'Microsoft Teams Rooms Standard'
'MS_TEAMS_IW' = 'Microsoft Teams Trial'
'EXPERTS_ON_DEMAND' = 'Microsoft Threat Experts - Experts On Demand'
'OFFICE365_MULTIGEO' = 'Multi-Geo Capabilities In Office 365'
'NONPROFIT_PORTAL' = 'Nonprofit Portal'
'STANDARDWOFFPACK_FACULTY' = 'Office 365 A1 For Faculty'
'STANDARDWOFFPACK_IW_FACULTY' = 'Office 365 A1 Plus For Faculty'
'STANDARDWOFFPACK_STUDENT ' = 'Office 365 A1 For Students '
'STANDARDWOFFPACK_IW_STUDENT' = 'Office 365 A1 Plus For Students'
'ENTERPRISEPACKPLUS_FACULTY' = 'Office 365 A3 For Faculty'
'ENTERPRISEPACKPLUS_STUDENT' = 'Office 365 A3 For Students'
'ENTERPRISEPREMIUM_FACULTY' = 'Office 365 A5 For Faculty'
'ENTERPRISEPREMIUM_STUDENT' = 'Office 365 A5 For Students'
'EQUIVIO_ANALYTICS' = 'Office 365 Advanced Compliance'
'EQUIVIO_ANALYTICS_GOV' = 'Office 365 Advanced Compliance For Gcc'
'ATP_ENTERPRISE' = 'Microsoft Defender For Office 365 (Plan 1)'
'SHAREPOINTSTORAGE_GOV' = 'Office 365 Extra File Storage For Gcc'
'TEAMS_COMMERCIAL_TRIAL' = 'Microsoft Teams Commercial Cloud'
'ADALLOM_O365' = 'Office 365 Cloud App Security'
'SHAREPOINTSTORAGE' = 'Office 365 Extra File Storage'
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
'STANDARDPACK_GOV' = 'Office 365 G1 Gcc'
'ENTERPRISEPACK_GOV' = 'Office 365 G3 Gcc'
'ENTERPRISEPREMIUM_GOV' = 'Office 365 G5 Gcc'
'MIDSIZEPACK' = 'Office 365 Midsize Business'
'LITEPACK' = 'Office 365 Small Business'
'LITEPACK_P2' = 'Office 365 Small Business Premium'
'WACONEDRIVESTANDARD' = 'Onedrive For Business (Plan 1)'
'WACONEDRIVEENTERPRISE' = 'Onedrive For Business (Plan 2)'
'POWERAPPS_INDIVIDUAL_USER' = 'Powerapps And Logic Flows'
'POWERAPPS_PER_APP_IW' = 'Powerapps Per App Baseline Access'
'POWERAPPS_PER_APP' = 'Power Apps Per App Plan'
'POWERAPPS_PER_USER' = 'Power Apps Per User Plan'
'POWERAPPS_PER_USER_GCC' = 'Power Apps Per User Plan For Government'
'POWERAPPS_P1_GOV' = 'Powerapps Plan 1 For Government'
'POWERAPPS_PORTALS_LOGIN_T2_GCC' = 'Power Apps Portals Login Capacity Add-On Tier 2 (10 Unit Min) For Government'
'POWERAPPS_PORTALS_PAGEVIEW_GCC' = 'Power Apps Portals Page View Capacity Add-On For Government'
'FLOW_BUSINESS_PROCESS' = 'Power Automate Per Flow Plan'
'FLOW_PER_USER' = 'Power Automate Per User Plan'
'FLOW_PER_USER_DEPT' = 'Power Automate Per User Plan Dept'
'FLOW_PER_USER_GCC' = 'Power Automate Per User Plan For Government'
'POWERAUTOMATE_ATTENDED_RPA' = 'Power Automate Per User With Attended Rpa Plan'
'POWERAUTOMATE_UNATTENDED_RPA' = 'Power Automate Unattended Rpa Add-On'
'POWER_BI_INDIVIDUAL_USER' = 'Power Bi'
'POWER_BI_STANDARD' = 'Power Bi (Free)'
'POWER_BI_ADDON' = 'Power Bi For Office 365 Add-On'
'PBI_PREMIUM_P1_ADDON' = 'Power Bi Premium P1'
'PBI_PREMIUM_PER_USER' = 'Power Bi Premium Per User'
'PBI_PREMIUM_PER_USER_ADDON' = 'Power Bi Premium Per User Add-On'
'PBI_PREMIUM_PER_USER_DEPT' = 'Power Bi Premium Per User Dept'
'POWER_BI_PRO' = 'Power Bi Pro'
'POWER_BI_PRO_CE' = 'Power Bi Pro Ce'
'POWER_BI_PRO_DEPT' = 'Power Bi Pro Dept'
'POWERBI_PRO_GOV' = 'Power Bi Pro For Gcc'
'VIRTUAL_AGENT_BASE' = 'Power Virtual Agent'
'CCIBOTS_PRIVPREV_VIRAL' = 'Power Virtual Agents Viral Trial'
'PROJECTCLIENT' = 'Project For Office 365'
'PROJECTESSENTIALS' = 'Project Online Essentials'
'PROJECTESSENTIALS_GOV' = 'Project Online Essentials For Gcc'
'PROJECTPREMIUM' = 'Project Online Premium'
'PROJECTONLINE_PLAN_1' = 'Project Online Premium Without Project Client'
'PROJECTONLINE_PLAN_2' = 'Project Online With Project For Office 365'
'PROJECT_P1' = 'Project Plan 1'
'PROJECT_PLAN1_DEPT' = 'Project Plan 1 (For Department)'
'PROJECTPROFESSIONAL' = 'Project Plan 3'
'PROJECT_PLAN3_DEPT' = 'Project Plan 3 (For Department)'
'PROJECTPROFESSIONAL_GOV' = 'Project Plan 3 For Gcc'
'PROJECTPREMIUM_GOV' = 'Project Plan 5 For Gcc'
'RIGHTSMANAGEMENT_ADHOC' = 'Rights Management Adhoc'
'RMSBASIC' = 'Rights Management Service Basic Content Protection'
'DYN365_IOT_INTELLIGENCE_ADDL_MACHINES' = 'Sensor Data Intelligence Additional Machines Add-In For Dynamics 365 Supply Chain Management'
'DYN365_IOT_INTELLIGENCE_SCENARIO' = 'Sensor Data Intelligence Scenario Add-In For Dynamics 365 Supply Chain Management'
'SHAREPOINTSTANDARD' = 'Sharepoint Online (Plan 1)'
'SHAREPOINTENTERPRISE' = 'Sharepoint Online (Plan 2)'
'Intelligent_Content_Services' = 'Sharepoint Syntex'
'MCOIMP' = 'Skype For Business Online (Plan 1)'
'MCOSTANDARD' = 'Skype For Business Online (Plan 2)'
'MCOPSTN2' = 'Skype For Business Pstn Domestic And International Calling'
'MCOPSTN1' = 'Skype For Business Pstn Domestic Calling'
'MCOPSTN5' = 'Skype For Business Pstn Domestic Calling (120 Minutes)'
'MCOPSTNPP' = 'Skype For Business Pstn Usage Calling Plan'
'MCOTEAMS_ESSENTIALS' = 'Teams Phone With Calling Plan'
'MTR_PREM' = 'Teams Rooms Premium'
'MCOPSTNEAU2' = 'Telstra Calling For O365'
'UNIVERSAL_PRINT' = 'Universal Print'
'VISIO_PLAN1_DEPT' = 'Visio Plan 1'
'VISIO_PLAN2_DEPT' = 'Visio Plan 2'
'VISIOONLINE_PLAN1' = 'Visio Online Plan 1'
'VISIOCLIENT' = 'Visio Online Plan 2'
'VISIOCLIENT_GOV' = 'Visio Plan 2 For Gcc'
'TOPIC_EXPERIENCES' = 'Viva Topics'
'WIN_ENT_E5' = 'Windows 10/11 Enterprise E5 (Original)'
'WIN10_ENT_A3_FAC' = 'Windows 10 Enterprise A3 For Faculty'
'WIN10_ENT_A3_STU' = 'Windows 10 Enterprise A3 For Students'
'WIN10_PRO_ENT_SUB' = 'Windows 10 Enterprise E3'
'WIN10_VDA_E5' = 'Windows 10 Enterprise E5'
'WINE5_GCC_COMPAT' = 'Windows 10 Enterprise E5 Commercial (Gcc Compatible)'
'CPC_B_2C_4RAM_64GB' = 'Windows 365 Business 2 Vcpu 4 Gb 64 Gb'
'CPC_B_4C_16RAM_128GB_WHB' = 'Windows 365 Business 4 Vcpu 16 Gb 128 Gb (With Windows Hybrid Benefit)'
'CPC_E_2C_4GB_64GB' = 'Windows 365 Enterprise 2 Vcpu 4 Gb 64 Gb'
'CPC_E_2C_8GB_128GB ' = 'Windows 365 Enterprise 2 Vcpu, 8 Gb, 128 Gb '
'CPC_LVL_2 ' = 'Windows 365 Enterprise 2 Vcpu, 8 Gb, 128 Gb (Preview) '
'CPC_LVL_3' = 'Windows 365 Enterprise 4 Vcpu, 16 Gb, 256 Gb (Preview) '
'WINDOWS_STORE' = 'Windows Store For Business'
'WSFB_EDU_FACULTY ' = 'Windows Store For Business Edu Faculty'
'WORKPLACE_ANALYTICS' = 'Microsoft Workplace Analytics'
}

### Start ###

import-module HuduAPI
import-module AzureAD.Standard.Preview
Import-module PartnerCenterLW


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
