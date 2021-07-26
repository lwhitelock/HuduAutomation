# Based on the original script by Kelvin Tegelaar https://github.com/KelvinTegelaar/AutomaticDocumentation
#####################################################################
# Get a Hudu API Key from https://yourhududomain.com/admin/api_keys
$HuduAPIKey = 'abcdefgh12345667'
# Set the base domain of your Hudu instance without a trailing /
$HuduBaseDomain = 'https://your.hudu.domain'
#Company Name as it appears in Hudu
$CompanyName = 'Company Name'
$HuduAssetLayoutName = 'SQL Server - AutoDoc'
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

	$Layout = Get-HuduAssetLayouts -name $HuduAssetLayoutName

	if (!$Layout) {
		$AssetLayoutFields = @(
			@{
				label        = 'Instance Name'
				field_type   = 'Text'
				show_in_list = 'true'
				position     = 1
			},
			@{
				label        = 'Instance Host'
				field_type   = 'RichText'
				show_in_list = 'true'
				position     = 2
			},
			@{
				label        = 'Instance Settings'
				field_type   = 'RichText'
				show_in_list = 'false'
				position     = 3
			},
			@{
				label        = 'Databases'
				field_type   = 'RichText'
				show_in_list = 'false'
				position     = 4
			}
		)

		Write-Host "Creating New Asset Layout $HuduAssetLayoutName"
		$NewLayout = New-HuduAssetLayout -name $HuduAssetLayoutName -icon 'fas fa-network-wired' -color '#4CAF50' -icon_color '#ffffff' -include_passwords $false -include_photos $false -include_comments $false -include_files $false -fields $AssetLayoutFields
		$Layout = Get-HuduAssetLayouts -name $HuduAssetLayoutName
	}


	$ComputerName = $($Env:COMPUTERNAME)

	#Find the parent asset from serial
	$ParentAsset = Get-HuduAssets -primary_serial (Get-CimInstance win32_bios).serialnumber

	#If count exists we either got 0 or more than 1 either way lets try to match off name
	if ($ParentAsset.count) {
		$ParentAsset = Get-HuduAssets -companyid $company.id -name $ComputerName
	}


	if ($ParentAsset) {
		$LinkedDevice = "<a href=$($ParentAsset.url) >$ComputerName</a>"
	} else {
		$LinkedDevice = $ComputerName
	}

	Import-Module SQLPS
	$Instances = Get-ChildItem "SQLSERVER:\SQL\$($ENV:COMPUTERNAME)"
	foreach ($Instance in $Instances) {
		$databaseList = Get-ChildItem "SQLSERVER:\SQL\$($ENV:COMPUTERNAME)\$($Instance.Displayname)\Databases"
		$Databases = @()
		foreach ($Database in $databaselist) {
			$Databaseobj = New-Object -TypeName PSObject
			$Databaseobj | Add-Member -MemberType NoteProperty -Name 'Name' -Value $Database.Name
			$Databaseobj | Add-Member -MemberType NoteProperty -Name 'Status' -Value $Database.status
			$Databaseobj | Add-Member -MemberType NoteProperty -Name 'RecoveryModel' -Value $Database.RecoveryModel
			$Databaseobj | Add-Member -MemberType NoteProperty -Name 'LastBackupDate' -Value $Database.LastBackupDate
			$Databaseobj | Add-Member -MemberType NoteProperty -Name 'DatabaseFiles' -Value $database.filegroups.files.filename
			$Databaseobj | Add-Member -MemberType NoteProperty -Name 'Logfiles' -Value $database.LogFiles.filename
			$Databaseobj | Add-Member -MemberType NoteProperty -Name 'MaxSize' -Value $database.filegroups.files.MaxSize
			$Databases += $Databaseobj
		}
		$InstanceInfo = $Instance | Select-Object DisplayName, Collation, AuditLevel, BackupDirectory, DefaultFile, DefaultLog, Edition, ErrorLogPath | ConvertTo-Html -Fragment | Out-String
		$Instanceinfo = $instanceinfo -replace '&lt;th>', "&lt;th style=`"background-color:#4CAF50`">"
		$InstanceInfo = $InstanceInfo -replace '&lt;table>', "&lt;table class=`"table table-bordered table-hover`" style=`"width:80%`">"
		$DatabasesHTML = $Databases | ConvertTo-Html -Fragment | Out-String
		$DatabasesHTML = $DatabasesHTML -replace '&lt;th>', "&lt;th style=`"background-color:#4CAF50`">"
		$DatabasesHTML = $DatabasesHTML -replace '&lt;table>', "&lt;table class=`"table table-bordered table-hover`" style=`"width:80%`">"



		$AssetFields = @{
			'instance_name'     = "$($ENV:COMPUTERNAME)\$($Instance.displayname)"
			'instance_settings' = $InstanceInfo
			'databases'         = $DatabasesHTML
			'instance_host'     = $LinkedDevice
		}

		$companyid = $company.id
		$AssetName = "$($ENV:COMPUTERNAME)\$($Instance.displayname)"

		#Check if there is already an asset
		$Asset = Get-HuduAssets -name $AssetName -companyid $companyid -assetlayoutid $Layout.id

		#If the Asset does not exist, we edit the body to be in the form of a new asset, if not, we just upload.
		if (!$Asset) {
			Write-Host 'Creating new Asset'
			$Asset = New-HuduAsset -name $AssetName -company_id $companyid -asset_layout_id $Layout.id -fields $AssetFields
		} else {
			Write-Host 'Updating Asset'
			$Asset = Set-HuduAsset -asset_id $Asset.id -name $AssetName -company_id $companyid -asset_layout_id $layout.id -fields $AssetFields
		}
	}

} else {
	Write-Host "$CompanyName Not found in Hudu." -ForegroundColor Red
}
