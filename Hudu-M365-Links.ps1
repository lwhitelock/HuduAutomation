#
# This script will add customer's M365 primary domains to their Hudu Client
# It is an interactive script so uses standard M365 Authentication rather than the secure app model
# More details can be found here https://mspp.io/microsoft-365-hudu-magic-dash-and-website-sync
#

############ Settings ##########
# Get a Hudu API Key from https://yourhududomain.com/admin/api_keys
$HuduAPIKey = 'abcdefght39fdfgfgdg'

# Set the base domain of your Hudu instance without a trailing /
$HuduBaseDomain = 'https://your.hudu.domain'

# The notes that are added to the site in Hudu
$HuduNotes = 'M365 Primary Domain - Used for integration mapping'

# List of customers to exclude by their M365 names, you can also skip them manually while running
$customerExclude = @('Example Company 1', 'Example Company 2')

############ Settings ##########


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

#Grabs all the companies from Hudu for later
$HuduCompanies = Get-HuduCompanies

#Connect to MS
Connect-MsolService

#Get all current customers
$MSCustomers = Get-MsolPartnerContract -All | Sort-Object name

#Loop through customers in M365
foreach ($customer in $MSCustomers) {
	if (-Not ($customerExclude -contains $customer.name)) {
		Write-Host '##########################################'
		$defaultdomain = $customer.DefaultDomainName

		#Check is the default domain is already in Hudu
		$domain = Get-HuduWebsites -name "https://$defaultdomain"

		if ($($domain.id.count) -gt 0) {
			Write-Host "Domain $defaultdomain matched"
		} else {
			#If its not in Hudu check if a company name matches
			$hudusearch = $HuduCompanies | Where-Object { $_.name -eq $customer.Name }
			if ($hudusearch) {
				#If we find a domain lets check it is the right one before creating
				Write-Host "Customer: $($customer.Name) Found in Hudu. Domain to match: $defaultdomain" -ForegroundColor Green
				$reply = Read-Host -Prompt 'Apply this match [y/n]'
				if ($reply -match '[yY]') {
					New-HuduWebsite -name "https://$defaultdomain" -notes $HuduNotes -paused 'true' -companyid $hudusearch.id -disabledns 'true' -disablessl 'true' -disablewhois 'true'
					Write-Host "Mapping added for $defaultdomain to $($customer.Name)"
				}
			} else {
				#We didn't find a domain or company and so lets ask who is is supposed to before while giving the option to skip
				$found = $false
				do {
					Write-Host "No company name or Domain has been found to match for $defaultdomain" -ForegroundColor Red
					$CompanyName = Read-Host "Please enter the Company Name exactly as it appears in Hudu or 'N' to skip"
					if ($CompanyName -eq 'N' ) {
						$found = $true
					} else {
						#Check that the company does exist, not that we don't trust people....
						$hudusearch = $HuduCompanies | Where-Object { $_.name -eq $CompanyName }
						if ($hudusearch) {
							New-HuduWebsite -name "https://$defaultdomain" -notes $HuduNotes -paused 'true' -companyid $hudusearch.id -disabledns 'true' -disablessl 'true' -disablewhois 'true'
							Write-Host "Mapping added for $defaultdomain to $CompanyName"
							$found = $true
						} else {
							Write-Host 'Customer was not found please check the name matches Hudu Exactly'
						}

					}
				} while (!$found)
			}
		}
	}
}
