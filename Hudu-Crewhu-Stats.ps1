#####################################################################
# Get a Hudu API Key from https://yourhududomain.com/admin/api_keys
$HuduAPIKey = "Your Hudu API Key"
# Set the base domain of your Hudu instance without a trailing /
$HuduBaseDomain = "https://your.hudu.domain"
######################### Crewhu Settings ###########################
$CrewHuHuduViewedToken = "hududocsviewed"
$CrewHuHuduCreatedToken = "hududocscreated"
$CrewHuAPIToken = "YourCrewHuAPIToken"
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

#Get Hudu Data
$HuduViewed = Get-HuduActivityLogs -start_date (get-date).adddays(-7) | where -filter {$_.action -eq "viewed"} |group user_email | select @{N="identificator"; E={$_.name}}, @{N='value'; E={$_.count}}
$HuduCreated = Get-HuduActivityLogs -start_date (get-date).adddays(-7) | where -filter {$_.action -eq "created"} |group user_email | select @{N="identificator"; E={$_.name}}, @{N='value'; E={$_.count}}

$Viewed = @{
				'metricToken' =  $CrewHuHuduViewedToken
				'timeframe' = 'WK'
				'data' = $HuduViewed
}

$Created = @{
				'metricToken' =  $CrewHuHuduCreatedToken
				'timeframe' = 'WK'
				'data' = $HuduCreated
}

$ViewedJSON = $Viewed | ConvertTo-JSON -Depth 2
$CreatedJSON = $Created | ConvertTo-JSON -Depth 2

Invoke-RestMethod -method POST -uri ("https://api.crewhu.com/api/v1/contest/metrics") `
			-headers @{'X_CREWHU_APITOKEN' = $CrewHuAPIToken} `
			-ContentType 'application/json' `
			-Body $ViewedJSON
			
Invoke-RestMethod -method POST -uri ("https://api.crewhu.com/api/v1/contest/metrics") `
			-headers @{'X_CREWHU_APITOKEN' = $CrewHuAPIToken} `
			-ContentType 'application/json' `
			-Body $CreatedJSON


