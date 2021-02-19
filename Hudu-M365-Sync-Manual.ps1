#
# M365 to Hudu Sync
# More details can be found here https://mspp.io/microsoft-365-hudu-magic-dash-and-website-sync
# Based on Scripts from https://www.cyberdrain.com/documenting-with-powershell-using-powershell-to-create-faster-partner-portal/
# and https://gcits.com/knowledge-base/sync-office-365-tenant-info-itglue/
#
##########################          Settings         ############################
# Get a Hudu API Key from https://yourhududomain.com/admin/api_keys
$HuduAPIKey = "abcdefght39fdfgfgdg"

# Set the base domain of your Hudu instance without a trailing /
$HuduBaseDomain = "https://your.hudu.domain"

#This allows you to exlude clients by their name in M365
$customerExclude =@("Example Customer","Example Customer 2")

#This will toggle on and off importing domains from M365 to Hudu
$importDomains = $true

#For imported domains this will set if monitoring is enabled or disabled
$monitorDomains = $true

##########################          Settings         ############################

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
   
Connect-MsolService
$customers = Get-MsolPartnerContract -All
foreach ($customer in $customers) {	
	#Check if customer should be excluded
	if (-Not ($customerExclude -contains $customer.name)){
	write-host "#############################################"
	write-host "Starting $($customer.name)"
	
	
	#Check if they are in Hudu before doing any unnessisary work
	$defaultdomain = $customer.DefaultDomainName
	$hududomain = Get-HuduWebsites -name "https://$defaultdomain"
	if ($($hududomain.id.count) -gt 0) {
		
		#Create a table to send into Hudu
		$CustomerLinks = "<table style=`"width:400px; border: 1px solid black;`">	 
        <tr><td><i class=`"fas fa-cogs`">&nbsp;&nbsp;&nbsp;</i><a target=`"_blank`" href=`"https://portal.office.com/Partner/BeginClientSession.aspx?CTID=$($customer.TenantId)&CSDEST=o365admincenter`">M365 Admin Portal</a></td>
        <td><i class=`"fas fa-mail-bulk`">&nbsp;&nbsp;&nbsp;</i><a target=`"_blank`" href=`"https://outlook.office365.com/ecp/?rfr=Admin_o365&exsvurl=1&delegatedOrg=$($Customer.DefaultDomainName)`">Exchange Admin Portal</a></td></tr>
        <tr><td><i class=`"fas fa-users-cog`">&nbsp;&nbsp;&nbsp;</i><a target=`"_blank`" href=`"https://aad.portal.azure.com/$($Customer.DefaultDomainName)`" >Azure Active Directory</a></td>
        <td><i class=`"fas fa-key`">&nbsp;&nbsp;&nbsp;</i><a target=`"_blank`" href=`"https://account.activedirectory.windowsazure.com/usermanagement/multifactorverification.aspx?tenantId=$($Customer.tenantid)&culture=en-us&requestInitiatedContext=users`" >MFA Portal (Read Only)</a></td></tr>
        <tr><td><i class=`"fab fa-skype`">&nbsp;&nbsp;&nbsp;</i><a target=`"_blank`" href=`"https://portal.office.com/Partner/BeginClientSession.aspx?CTID=$($Customer.TenantId)&CSDEST=MicrosoftCommunicationsOnline`">Sfb Portal</a></td>
        <td><i class=`"fas fa-users`">&nbsp;&nbsp;&nbsp;</i><a target=`"_blank`" href=`"https://admin.teams.microsoft.com/?delegatedOrg=$($Customer.DefaultDomainName)`">Teams Portal</a></td></tr>
        <tr><td><i class=`"fas fa-server`">&nbsp;&nbsp;&nbsp;</i><a target=`"_blank`" href=`"https://portal.azure.com/$($customer.DefaultDomainName)`">Azure Portal</a></td>
        <td><i class=`"fas fa-laptop`">&nbsp;&nbsp;&nbsp;</i><a target=`"_blank`" href=`"https://endpoint.microsoft.com/$($customer.DefaultDomainName)/`">Endpoint Management</a></td></tr>
		</table>"
	
		#Grab a count of licensed users so we have something to show on the badge		
		$msusers = Get-MsolUser -TenantID $customer.tenantid -All | where {$_.isLicensed -eq $true}
		$company_name = $hududomain[0].company_name
		$company_id = $hududomain[0].company_id
		
		
		#Grab extra info to put into Hudu
        $companyInfo = Get-MsolCompanyInformation -TenantId $customer.TenantId
		$customerDomains = (Get-MsolDomain -TenantId $customer.tenantid | Where-Object {$_.status -contains "Verified"}).Name -join ', ' | Out-String
		$detailstable = "<table style=`"width:600px; border: 1px solid black;`"><tr><td>Tenant Name</td><td>$($customer.Name)</td></tr>
						<tr><td>Tenant ID</td><td>$($customer.TenantId)</td></tr>
						<tr><td>Default Domain</td><td>$defaultdomain</td></tr>
						<tr><td>Customer Domains</td><td>$customerDomains</td></tr>
						</table>"
		
		
		$Licenses = $null
		$Licenses = Get-MsolAccountSku -TenantId $customer.TenantId
		if ($Licenses) {
        $licenseTableTop = "<br/><table style=`"width:600px; border: 1px solid black;`"><thead><tr><th>License Name</th><th>Active</th><th>Consumed</th><th>Unused</th></tr></thead><tbody><tr><td>"
        $licenseTableBottom = "</td></tr></tbody></table>"
        $licensesColl = @()
        foreach ($license in $licenses) {
            $licenseString = "$($license.SkuPartNumber)</td><td>$($license.ActiveUnits) active</td><td>$($license.ConsumedUnits) consumed</td><td>$($license.ActiveUnits - $license.ConsumedUnits) unused"
            $licensesColl += $licenseString
        }
        if ($licensesColl) {
            $licenseString = $licensesColl -join "</td></tr><tr><td>"
        }
        $licenseTable = "{0}{1}{2}" -f $licenseTableTop, $licenseString, $licenseTableBottom
		}
      
		$licensedUsers = $null
		$licensedUserTable = $null
		$licensedUsers = get-msoluser -TenantId $customer.TenantId -All | Where-Object {$_.islicensed} | Sort-Object UserPrincipalName
		if ($licensedUsers) {
			$licensedUsersTableTop = "<br/><table style=`"width:80%; border: 1px solid black;`"><thead><tr><th>Display Name</th><th>Addresses</th><th>Assigned Licenses</th></tr></thead><tbody><tr><td>"
			$licensedUsersTableBottom = "</td></tr></tbody></table>"
			$licensedUserColl = @()
			foreach ($user in $licensedUsers) {
             	$aliases = (($user.ProxyAddresses | Where-Object {$_ -cnotmatch "SMTP" -and $_ -notmatch ".onmicrosoft.com"}) -replace "SMTP:", " ") -join "<br/>"
				$licensedUserString = "$($user.DisplayName)</td><td><strong>$($user.UserPrincipalName)</strong><br/>$aliases</td><td>$(($user.Licenses.accountsku.skupartnumber) -join "<br/>")"
				$licensedUserColl += $licensedUserString
			}
			if ($licensedUserColl) {
				$licensedUserString = $licensedUserColl -join "</td></tr><tr><td>"
			}
        $licensedUserTable = "{0}{1}{2}" -f $licensedUsersTableTop, $licensedUserString, $licensedUsersTableBottom
        }
	
	#Build the output
	$body = "<div class=`"nasa-block`"><h2>Administration Portals</h2> $CustomerLinks</div> 
			 <div class=`"nasa-block`"><h2>Tenant Details</h2> $detailstable</div>
			 <div class=`"nasa-block`"><h2>Current Licenses</h2> $licenseTable</div>
			 <div class=`"nasa-block`"><h2>Licensed Users</h2> $licensedUserTable</div>"
      
   	
	$result = Set-HuduMagicDash -title "Microsoft 365 - $($hududomain[0].company_name)" -company_name $company_name -message "$($msusers.count) Licensed Users" -icon "fab fa-microsoft" -content $body -shade "success"	
		write-host "https://$defaultdomain Found in Hudu and MagicDash updated for $($hududomain[0].company_name)"  -ForegroundColor Green	
		
	#Import Domains if enabled
	if ($importDomains) {
		$domainstoimport = Get-MsolDomain -TenantId $customer.tenantid
		foreach ($imp in $domainstoimport) {
			$impdomain = $imp.name
			$huduimpdomain = Get-HuduWebsites -name "https://$impdomain"
				if ($($huduimpdomain.id.count) -gt 0) {
					write-host "https://$impdomain Found in Hudu"  -ForegroundColor Green
				} else {
					if ($monitorDomains) {
						$result = New-HuduWebsite -name "https://$impdomain" -notes $HuduNotes -paused "false" -companyid $company_id -disabledns "false" -disablessl "false" -disablewhois "false"
						write-host "https://$impdomain Created in Hudu with Monitoring"  -ForegroundColor Green
					} else {
						$result = New-HuduWebsite -name "https://$impdomain" -notes $HuduNotes -paused "true" -companyid $company_id -disabledns "true" -disablessl "true" -disablewhois "true"
						write-host "https://$impdomain Created in Hudu with Monitoring"  -ForegroundColor Green
					}

				}		
		}
      
	}
    } else {
		write-host "https://$defaultdomain Not found in Hudu please add it to the correct client"  -ForegroundColor Red	
	}
	}
}	

      

  
