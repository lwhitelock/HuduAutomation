# Based on the original script by Kelvin Tegelaar https://github.com/KelvinTegelaar/AutomaticDocumentation
#####################################################################
# Get a Hudu API Key from https://yourhududomain.com/admin/api_keys
$HuduAPIKey = "Abcdefghijk1233445567"
# Set the base domain of your Hudu instance without a trailing /
$HuduBaseDomain = "https://your.hudu.domain"
#Company Name as it appears in Hudu
$CompanyName = "Company machine is in"
#####################################################################

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

# Get the Hudu Company we are working without
$Company = Get-HuduCompanies -name $CompanyName
if ($company) {	
	#This is the data we'll be sending to Hudu

	$BitlockVolumes = Get-BitLockerVolume
	$ComputerName = $($Env:COMPUTERNAME)
	
	#Find the parent asset from serial
	$ParentAsset = Get-HuduAssets -primary_serial (get-ciminstance win32_bios).serialnumber
	
	#If count exists we either got 0 or more than 1 either way lets try to match off name
	if ($ParentAsset.count){
		$ParentAsset = Get-HuduAssets -companyid $company.id -name $ComputerName
	}
		
			
	foreach($BitlockVolume in $BitlockVolumes) {
		$PasswordObjectName = "$($Env:COMPUTERNAME) - $($BitlockVolume.MountPoint) - BitLocker"
		$name = $PasswordObjectName
		$BLKey = [string]$BitlockVolume.KeyProtector.recoverypassword
		$BLUser
		$Notes = "Bitlocker key for $($Env:COMPUTERNAME)"
		
		# See if a password already exists
		$password = Get-HuduPasswords -name $PasswordObjectName -companyid $company.id 
	
		if ($password) {
			Write-Host "Updated Password"
			$password = set-hudupassword -id $password.id -company_id $company.id -passwordable_type "Asset" -passwordable_id $ParentAsset.id -in_portal $false -password $BLKey -description $notes -name $PasswordObjectName
		} else {
			Write-Host "Created Password"
			$password = new-hudupassword -company_id $company.id -passwordable_type "Asset" -passwordable_id $ParentAsset.id -in_portal $false -password $BLKey -description $notes -name $PasswordObjectName
		}
			
	}
		
} else {
	Write-Host "$CompanyName was not found in Hudu"
}
