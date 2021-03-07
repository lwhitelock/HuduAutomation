# Based on the original script by Kelvin Tegelaar https://github.com/KelvinTegelaar/AutomaticDocumentation
#####################################################################
# Run this Script after Hudu-Unifi-Documentation.ps1
#
# Get a Hudu API Key from https://yourhududomain.com/admin/api_keys
$HuduAPIKey = "abcdefgh123456788"
# Set the base domain of your Hudu instance without a trailing /
$HuduBaseDomain = "https://your.hudu.domain"
#This is the name of layout from the Hudu-Unifi-Documentation.ps1 script
$HuduSiteLayoutName = "Unifi - AutoDoc"
#This is the namne of the layout that will be used by this script
$HuduAssetLayoutName = "Unifi Device - AutoDoc"
$UnifiBaseUri = "https://unifi.yourdomain.com:8443/api"
$UnifiUser = "PSAPIUser"
$UnifiPassword = "APIUserPassword"
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

$SiteLayout = Get-HuduAssetLayouts -name $HuduSiteLayoutName
if (!$SiteLayout) {
	Write-Host "Please run the Hudu-Unifi-Documentation.ps1 first to create the Unifi site layout or check the name in HuduSiteLayoutName"
	exit
}

$Layout = Get-HuduAssetLayouts -name $HuduAssetLayoutName
		
if (!$Layout) { 
	$AssetLayoutFields = @(
		@{
			label = 'Device Name'
			field_type = 'Text'
			show_in_list = 'true'
			position = 1
		},
		@{
			label = 'IP'
			field_type = 'Text'
			show_in_list = 'true'
			position = 1
		},
		@{
			label = 'MAC'
			field_type = 'Text'
			show_in_list = 'true'
			position = 1
		},
		@{
			label = 'Type'
			field_type = 'Text'
			show_in_list = 'true'
			position = 1
		},
		@{
			label = 'Model'
			field_type = 'Text'
			show_in_list = 'true'
			position = 1
		},
		@{
			label = 'Version'
			field_type = 'Text'
			show_in_list = 'true'
			position = 1
		},
		@{
			label = 'Serial Number'
			field_type = 'Text'
			show_in_list = 'true'
			position = 1
		},
		@{
			label = 'Site'
			field_type = 'AssetLink'
			show_in_list = 'true'
			position = 1
			linkable_id = $SiteLayout.id
		},
		@{
			label = 'Management URL'
			field_type = 'RichText'
			show_in_list = 'true'
			position = 1
		},
		@{
			label = 'Device Stats'
			field_type = 'RichText'
			show_in_list = 'false'
			position = 2
		}
	)
	
	Write-Host "Creating New Asset Layout $HuduAssetLayoutName"
	$NewLayout = New-HuduAssetLayout -name $HuduAssetLayoutName -icon "fas fa-network-wired" -color "#4CAF50" -icon_color "#ffffff" -include_passwords $false -include_photos $false -include_comments $false -include_files $false -fields $AssetLayoutFields
	$Layout = Get-HuduAssetLayouts -name $HuduAssetLayoutName
}


$unifiAllModels = @"
[{"c":"BZ2","t":"uap","n":"UniFi AP"},{"c":"BZ2LR","t":"uap","n":"UniFi AP-LR"},{"c":"U2HSR","t":"uap","n":"UniFi AP-Outdoor+"},
{"c":"U2IW","t":"uap","n":"UniFi AP-In Wall"},{"c":"U2L48","t":"uap","n":"UniFi AP-LR"},{"c":"U2Lv2","t":"uap","n":"UniFi AP-LR v2"},
{"c":"U2M","t":"uap","n":"UniFi AP-Mini"},{"c":"U2O","t":"uap","n":"UniFi AP-Outdoor"},{"c":"U2S48","t":"uap","n":"UniFi AP"},
{"c":"U2Sv2","t":"uap","n":"UniFi AP v2"},{"c":"U5O","t":"uap","n":"UniFi AP-Outdoor 5G"},{"c":"U7E","t":"uap","n":"UniFi AP-AC"},
{"c":"U7EDU","t":"uap","n":"UniFi AP-AC-EDU"},{"c":"U7Ev2","t":"uap","n":"UniFi AP-AC v2"},{"c":"U7HD","t":"uap","n":"UniFi AP-HD"},
{"c":"U7SHD","t":"uap","n":"UniFi AP-SHD"},{"c":"U7NHD","t":"uap","n":"UniFi AP-nanoHD"},{"c":"UCXG","t":"uap","n":"UniFi AP-XG"},
{"c":"UXSDM","t":"uap","n":"UniFi AP-BaseStationXG"},{"c":"UCMSH","t":"uap","n":"UniFi AP-MeshXG"},{"c":"U7IW","t":"uap","n":"UniFi AP-AC-In Wall"},
{"c":"U7IWP","t":"uap","n":"UniFi AP-AC-In Wall Pro"},{"c":"U7MP","t":"uap","n":"UniFi AP-AC-Mesh-Pro"},{"c":"U7LR","t":"uap","n":"UniFi AP-AC-LR"},
{"c":"U7LT","t":"uap","n":"UniFi AP-AC-Lite"},{"c":"U7O","t":"uap","n":"UniFi AP-AC Outdoor"},{"c":"U7P","t":"uap","n":"UniFi AP-Pro"},
{"c":"U7MSH","t":"uap","n":"UniFi AP-AC-Mesh"},{"c":"U7PG2","t":"uap","n":"UniFi AP-AC-Pro"},{"c":"p2N","t":"uap","n":"PicoStation M2"},
{"c":"US8","t":"usw","n":"UniFi Switch 8"},{"c":"US8P60","t":"usw","n":"UniFi Switch 8 POE-60W"},{"c":"US8P150","t":"usw","n":"UniFi Switch 8 POE-150W"},
{"c":"S28150","t":"usw","n":"UniFi Switch 8 AT-150W"},{"c":"USC8","t":"usw","n":"UniFi Switch 8"},{"c":"US16P150","t":"usw","n":"UniFi Switch 16 POE-150W"},
{"c":"S216150","t":"usw","n":"UniFi Switch 16 AT-150W"},{"c":"US24","t":"usw","n":"UniFi Switch 24"},{"c":"US24P250","t":"usw","n":"UniFi Switch 24 POE-250W"},
{"c":"US24PL2","t":"usw","n":"UniFi Switch 24 L2 POE"},{"c":"US24P500","t":"usw","n":"UniFi Switch 24 POE-500W"},{"c":"S224250","t":"usw","n":"UniFi Switch 24 AT-250W"},
{"c":"S224500","t":"usw","n":"UniFi Switch 24 AT-500W"},{"c":"US48","t":"usw","n":"UniFi Switch 48"},{"c":"US48P500","t":"usw","n":"UniFi Switch 48 POE-500W"},
{"c":"US48PL2","t":"usw","n":"UniFi Switch 48 L2 POE"},{"c":"US48P750","t":"usw","n":"UniFi Switch 48 POE-750W"},{"c":"S248500","t":"usw","n":"UniFi Switch 48 AT-500W"},
{"c":"S248750","t":"usw","n":"UniFi Switch 48 AT-750W"},{"c":"US6XG150","t":"usw","n":"UniFi Switch 6XG POE-150W"},{"c":"USXG","t":"usw","n":"UniFi Switch 16XG"},
{"c":"UGW3","t":"ugw","n":"UniFi Security Gateway 3P"},{"c":"UGW4","t":"ugw","n":"UniFi Security Gateway 4P"},{"c":"UGWHD4","t":"ugw","n":"UniFi Security Gateway HD"},
{"c":"UGWXG","t":"ugw","n":"UniFi Security Gateway XG-8"},{"c":"UP4","t":"uph","n":"UniFi Phone-X"},{"c":"UP5","t":"uph","n":"UniFi Phone"},
{"c":"UP5t","t":"uph","n":"UniFi Phone-Pro"},{"c":"UP7","t":"uph","n":"UniFi Phone-Executive"},{"c":"UP5c","t":"uph","n":"UniFi Phone"},
{"c":"UP5tc","t":"uph","n":"UniFi Phone-Pro"},{"c":"UP7c","t":"uph","n":"UniFi Phone-Executive"}]
"@ | ConvertFrom-Json


 
write-host "Start documentation process." -foregroundColor green
 
 
$UniFiCredentials = @{
    username = $UnifiUser
    password = $UnifiPassword
    remember = $true
} | ConvertTo-Json
 
write-host "Logging in to Unifi API." -ForegroundColor Green
try {
    Invoke-RestMethod -Uri "$UnifiBaseUri/login" -Method POST -Body $uniFiCredentials -SessionVariable websession
}
catch {
    write-host "Failed to log in on the Unifi API. Error was: $($_.Exception.Message)" -ForegroundColor Red
}
write-host "Collecting sites from Unifi API." -ForegroundColor Green
try {
    $sites = (Invoke-RestMethod -Uri "$UnifiBaseUri/self/sites" -WebSession $websession).data
}
catch {
    write-host "Failed to collect the sites. Error was: $($_.Exception.Message)" -ForegroundColor Red
}
 
foreach ($site in $sites) {
	#First we will see if there is an Asset that matches the site name with this Asset Layout
	Write-Host "Attempting to map $($site.desc)"
	$SiteAsset = Get-HuduAssets -name $($site.desc) -assetlayoutid $SiteLayout.id
	if (!$SiteAsset) {
			Write-Host "A Site in Hudu could not be matched to the site. Please create a blank Unifi site asset (created with the other Unifi Sync script), with a name of `"$($site.desc)`" under the company in Hudu you wish to map this site to."  -ForegroundColor Red
			continue
	}
	
	$Companyid = $SiteAsset.company_id
		
	
	$unifiDevices = Invoke-RestMethod -Uri "$UnifiBaseUri/s/$($site.name)/stat/device" -WebSession $websession
	foreach ($device in $unifiDevices.data) {
					
		$LoadHTML = ($device.sys_stats | convertto-html -as list -frag | out-string)
		$ResourceHTML = ($device.'system-stats' | convertto-html -as list -frag | out-string)
		
		$StatsHTML = $ResourceHTML + $LoadHTML
		
		$model = ($unifiAllModels | where-object {$_.c -eq $device.model} | select n).n
		
		if (!$model) {
			$model = "Unknown - $($device.model)"
		} else {
			$model = "$model - $($device.model)"
		}
		
		if (!$($device.name)){
			$devicename = "$model - $($device.mac)"
		} else {
		$devicename = $device.name
		}
		
		$UnifiRoot = $UnifiBaseUri.trim("/api")
	
		$AssetFields = @{
					'device_name'  		= $device.name
					'ip'    			= $device.ip
					'mac'           	= $device.mac
					'type'          	= $device.type
					'model'         	= $model
					'version'       	= $device.version
					'serial_number' 	= $device.serial
					'site'				= $SiteAsset.id
					'management_url'	= "<a href=`"$UniFiRoot/manage/site/$($site.name)/devices/list/1/100`" >$UniFiRoot/manage/site/$($site.name)/devices/list/1/100</a>"
					'device_stats' 		= $StatsHTML
				}
	
    
		Write-Host "Pushing $devicename to Hudu"
		$AssetName = $devicename
		
		#Check if there is already an asset	
		$Asset = Get-HuduAssets -name $AssetName -companyid $companyid -assetlayoutid $Layout.id
		
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
 
