# Based on the original script by Kelvin Tegelaar https://github.com/KelvinTegelaar/AutomaticDocumentation
#####################################################################
# Get a Hudu API Key from https://yourhududomain.com/admin/api_keys
$HuduAPIKey = "abcdefgh123445667"
# Set the base domain of your Hudu instance without a trailing /
$HuduBaseDomain = "https://your.hudu.domain"
#Company Name as it appears in Hudu
$CompanyName = "Company Name"
$NewAdminUsername = "NewAdminUser"
$ChangeAdminUsername = $true
#####################################################################


if (Get-Module -ListAvailable -Name HuduAPI) {
		Import-Module HuduAPI 
	} else {
		Install-Module HuduAPI -Force
		Import-Module HuduAPI
	}
  
#Set Hudu logon information
New-HuduAPIKey $HuduAPIKey
New-HuduBaseUrl $HuduBaseDomain

		$Company = Get-HuduCompanies -name $CompanyName
		if ($company) {	
			#This is the data we'll be sending to Hudu
		
			$ComputerName = $($Env:COMPUTERNAME)
			
			#Find the parent asset from serial
			$ParentAsset = Get-HuduAssets -primary_serial (get-ciminstance win32_bios).serialnumber
			
			#If count exists we either got 0 or more than 1 either way lets try to match off name
			if ($ParentAsset.count){
				$ParentAsset = Get-HuduAssets -companyid $company.id -name $ComputerName
			}
		
		add-type -AssemblyName System.Web
		#This is the process we'll be perfoming to set the admin account.
		$LocalAdminPassword = [System.Web.Security.Membership]::GeneratePassword(24,5)
		If($ChangeAdminUsername -eq $false) {
		Set-LocalUser -name "Administrator" -Password ($LocalAdminPassword | ConvertTo-SecureString -AsPlainText -Force) -PasswordNeverExpires:$true
		} else {
		$ExistingNewAdmin = get-localuser | Where-Object {$_.Name -eq $NewAdminUsername}
		if(!$ExistingNewAdmin){
		write-host "Creating new user" -ForegroundColor Yellow
		New-LocalUser -Name $NewAdminUsername -Password ($LocalAdminPassword | ConvertTo-SecureString -AsPlainText -Force) -PasswordNeverExpires:$true
		Add-LocalGroupMember -Group Administrators -Member $NewAdminUsername
		Disable-LocalUser -Name "Administrator"
		}
		else{
			write-host "Updating admin password" -ForegroundColor Yellow
		set-localuser -name $NewAdminUsername -Password ($LocalAdminPassword | ConvertTo-SecureString -AsPlainText -Force)
		}
		}
		if($ChangeAdminUsername -eq $false ) { $username = "Administrator" } else { $Username = $NewAdminUsername }



		$PasswordObjectName = "$($Env:COMPUTERNAME) - Local Administrator Account"
		$notes = "Local Admin Password for $($Env:COMPUTERNAME)"
		# See if a password already exists
		$password = Get-HuduPasswords -name $PasswordObjectName -companyid $company.id 
	
		if ($password) {
			Write-Host "Updated Password"
			$password = set-hudupassword -id $password.id -company_id $company.id -passwordable_type "Asset" -passwordable_id $ParentAsset.id -in_portal $false -password $LocalAdminPassword -description $notes -name $PasswordObjectName -username $username
		} else {
			Write-Host "Created Password"
			$password = new-hudupassword -company_id $company.id -passwordable_type "Asset" -passwordable_id $ParentAsset.id -in_portal $false -password $LocalAdminPassword -description $notes -name $PasswordObjectName -username $username
		}



} else {
	Write-Host "$CompanyName was not found in Hudu"
}
