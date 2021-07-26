#####################################################################
# Get a Hudu API Key from https://yourhududomain.com/admin/api_keys
$HuduAPIKey = 'Your Hudu API Key'
# Set the base domain of your Hudu instance without a trailing /
$HuduBaseDomain = 'https://your.hudu.domain'
######################### Crewhu Settings ###########################
$CrewHuHuduViewedToken = 'hududocsviewed'
$CrewHuHuduCreatedToken = 'hududocscreated'
$CrewHuAPIToken = 'YourCrewHuAPIToken'
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
$HuduViewed = Get-HuduActivityLogs -start_date (Get-Date).adddays(-7) | Where-Object -filter { $_.action -eq 'viewed' } | Group-Object user_email | Select-Object @{N = 'identificator'; E = { $_.name } }, @{N = 'value'; E = { $_.count } }
$HuduCreated = Get-HuduActivityLogs -start_date (Get-Date).adddays(-7) | Where-Object -filter { $_.action -eq 'created' } | Group-Object user_email | Select-Object @{N = 'identificator'; E = { $_.name } }, @{N = 'value'; E = { $_.count } }

$Viewed = @{
	'metricToken' = $CrewHuHuduViewedToken
	'timeframe'   = 'WK'
	'data'        = $HuduViewed
}

$Created = @{
	'metricToken' = $CrewHuHuduCreatedToken
	'timeframe'   = 'WK'
	'data'        = $HuduCreated
}

$ViewedJSON = $Viewed | ConvertTo-Json -Depth 2
$CreatedJSON = $Created | ConvertTo-Json -Depth 2

Invoke-RestMethod -Method POST -Uri ('https://api.crewhu.com/api/v1/contest/metrics') `
	-Headers @{'X_CREWHU_APITOKEN' = $CrewHuAPIToken } `
	-ContentType 'application/json' `
	-Body $ViewedJSON

Invoke-RestMethod -Method POST -Uri ('https://api.crewhu.com/api/v1/contest/metrics') `
	-Headers @{'X_CREWHU_APITOKEN' = $CrewHuAPIToken } `
	-ContentType 'application/json' `
	-Body $CreatedJSON


