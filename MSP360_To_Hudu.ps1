#
#
# MSP360 / Cloudberry to Hudu
#
#
######## Settings ########
### API Settings

#Get MSP360 API Credentials from here https://mspbackups.com/AP/Settings.aspx
$msp360_user = "ABC1234ABC"
$msp360_pass = "ABCDEFG12345ABCDEFG"

# Get a Hudu API Key from https://yourhududomain.com/admin/api_keys
$HuduAPIKey = "abcdEFG12345abcde"
# Set the base domain of your Hudu instance without a trailing /
$HuduBaseDomain = "https://your.hudu.domain"

### Script Settings

# Name the asset layout to use
$HuduAssetLayoutName = "MSP360 Backups"

# Set if you would like to create an Article in your global KB with a global report of all jobs
$createGlobalReport = $true

# Global Report Name - Make sure this is unique
$globalReportName = "MSP 360 Backup Report"

# Set the folder ID of the folder you would like it created in. Quote out the line if you want it in the root folder
# The folder ID is shown in the URL when you browse into it
$folderID = 120

# The script can update assets in each customer in two ways, it can either create one asset per job and
# just update that each time it runs. Or it can create one asset per job per last start time.
# This lets you choose to have a historical job record or just a record of jobs.
$createJobsWithHistory = $true

# Choose to create a magic dash tracking last succesful job(s)
$createMagicDash = $true


####### End Settings ########

if (Get-Module -ListAvailable -Name HuduAPI) {
		Import-Module HuduAPI 
	} else {
		Install-Module HuduAPI -Force
		Import-Module HuduAPI
	}

if (Get-Module -ListAvailable -Name MSP360) {
		Import-Module MSP360 
	} else {
		Install-Module MSP360 -Force
		Import-Module MSP360
	}
	
#Login for Hudu
New-HuduAPIKey $HuduAPIKey
New-HuduBaseUrl $HuduBaseDomain

#Login for MSP360
Set-MBSAPICredential -UserName $msp360_user -Password $msp360_pass

#Setup the fields for the asset layout in case we need to create it
$AssetLayoutFields = @(
		@{
			label = 'Plan Name'
			field_type = 'Text'
			position = 1
		},
		@{
			label = 'Computer Name'
			field_type = 'Text'
			position = 2
		},
		@{
			label = 'Plan Type'
			field_type = 'Text'
			position = 3
		},
		@{
			label = 'Last Start'
			field_type = 'Text'
			position = 4
		},
		@{
			label = 'Next Start'
			field_type = 'Text'
			position = 5
		},
		@{
			label = 'Status'
			field_type = 'Text'
			position = 6
		},
		@{
			label = 'Files Copied'
			field_type = 'Number'
			position = 7
		},
		@{
			label = 'Files Failed'
			field_type = 'Number'
			position = 8
		},
		@{
			label = 'Data Copied'
			field_type = 'Number'
			position = 9
		},
		@{
			label = 'Duration'
			field_type = 'Text'
			position = 10
		},
		@{
			label = 'Total Data'
			field_type = 'Number'
			position = 11
		},
		@{
			label = 'Files Scanned'
			field_type = 'Number'
			position = 12
		},
		@{
			label = 'Files to Backup'
			field_type = 'Number'
			position = 13
		},
		@{
			label = 'Error Message'
			field_type = 'Embed'
			position = 14
		},
		@{
			label = 'Detailed Report'
			field_type = 'Embed'
			position = 15
		}
		
	)



#Check if the asset layout has been created and make it if it hasn't
$layout = Get-HuduAssetLayouts -name $HuduAssetLayoutName

if (!$layout) {
	Write-Host "Creating Layout"
	New-HuduAssetLayout -name $HuduAssetLayoutName -icon "fas fa-retweet" -color "#fe9620" -icon_color "#ffffff" -include_passwords $false -include_photos $false -include_comments $false -include_files $false -fields $AssetLayoutFields
	$layout = Get-HuduAssetLayouts -name $HuduAssetLayoutName
	}

$jobsummary = @()

# Grab the details of backup jobs from MSP360 and loop through them
$BackupJobs = Get-MBSAPIMonitoring

#Loop through backup job creating / updating assets
foreach ($job in $BackupJobs) {
	
	#First lets check for the company
	$company = Get-HuduCompanies -Name $job.CompanyName
	if ($company) {
			Write-Host "Company $($job.CompanyName) found in Hudu" -ForegroundColor Green		
			
			#Check if there is a detailed report and if there is download it
			$reportlink = $job.DetailedReportLink
			if ($reportlink){
			$detailedReport = Invoke-WebRequest $reportlink
			}
			
			#Make data human readable
			$DataCopied = $job.DataCopied / 1024 / 1024 / 1024
			$DataToBackup = $job.DataToBackup / 1024 / 1024 / 1024
			$TotalData = $job.TotalData / 1024 / 1024 / 1024
					
			# We will build an object of what to output so we can reuse for the summary article
			$processedJob = New-Object -TypeName PSObject -Property @{
					PlanName = $job.PlanName
					CompanyID = $Company.id
					CompanyName = $Company.name
					ComputerName = $job.ComputerName
					LastStart = $job.LastStart
					NextStart = $job.NextStart
					Status = $job.Status
					ErrorMessage = $job.ErrorMessage
					FilesCopied = $job.FilesCopied
					FilesFailed = $job.FilesFailed
					DataCopied = $DataCopied
					Duration = $job.Duration
					DataToBackup = $DataToBackup
					TotalData = $TotalData
					FilesScanned = $job.FilesScanned
					FilesToBackup = $job.FilesToBackup
					PlanType = $job.PlanType
					ReportLink = $reportlink
					CompanySlug = $company.slug
			
			}
			
						
			#Make the fields array, no nulls and converted to string
			$job_fields = @()
			
			if ($processedJob.PlanName) {
				$job_fields += @{
					asset_layout_field_id = $(Get-HuduAssetLayoutFieldID -name 'Plan Name' -asset_layout_id $layout.id)
					value = $($processedJob.PlanName).toString()
				}
			}
			if ($processedJob.ComputerName) {
				$job_fields += @{
					asset_layout_field_id = $(Get-HuduAssetLayoutFieldID -name 'Computer Name' -asset_layout_id $layout.id)
					value = $($processedJob.ComputerName).toString()
				}
			}
			if ($processedJob.PlanType) {
				$job_fields += @{
					asset_layout_field_id = $(Get-HuduAssetLayoutFieldID -name 'Plan Type' -asset_layout_id $layout.id)
					value = $($processedJob.PlanType).toString()
				}
			}
			if ($processedJob.LastStart) {
				$job_fields += @{
					asset_layout_field_id = $(Get-HuduAssetLayoutFieldID -name 'Last Start' -asset_layout_id $layout.id)
					value = $($processedJob.LastStart).toString()
				}
			}
			if ($processedJob.NextStart) {
				$job_fields += @{
					asset_layout_field_id = $(Get-HuduAssetLayoutFieldID -name 'Next Start' -asset_layout_id $layout.id)
					value = $($processedJob.NextStart).toString()
				}
			}
			$job_fields += @{
				asset_layout_field_id = $(Get-HuduAssetLayoutFieldID -name 'Status' -asset_layout_id $layout.id)
				value = $($processedJob.Status).toString()
			}
			if ($processedJob.FilesCopied) {
				$job_fields += @{
					asset_layout_field_id = $(Get-HuduAssetLayoutFieldID -name 'File Copied' -asset_layout_id $layout.id)
					value = $($processedJob.FilesCopied).toString()
				}
			}
			if ($processedJob.FilesFailed) {
				$job_fields += @{
					asset_layout_field_id = $(Get-HuduAssetLayoutFieldID -name 'Files Failed' -asset_layout_id $layout.id)
					value = $($processedJob.FilesFailed).toString()
				}
			}
			if ($processedJob.DataCopied) {
				$job_fields += @{
					asset_layout_field_id = $(Get-HuduAssetLayoutFieldID -name 'Data Copied' -asset_layout_id $layout.id)
					value = $($processedJob.DataCopied).toString()
				}
			}
			if ($processedJob.Duration) {
				$job_fields += @{
					asset_layout_field_id = $(Get-HuduAssetLayoutFieldID -name 'Duration' -asset_layout_id $layout.id)
					value = $($processedJob.Duration).toString()
				}
			}
			if ($processedJob.TotalData) {
				$job_fields += @{
					asset_layout_field_id = $(Get-HuduAssetLayoutFieldID -name 'Total Data' -asset_layout_id $layout.id)
					value = $($processedJob.TotalData).toString()
				}
			}
			if ($processedJob.FilesScanned) {
				$job_fields += @{
					asset_layout_field_id = $(Get-HuduAssetLayoutFieldID -name 'Files Scanned' -asset_layout_id $layout.id)
					value = $($processedJob.FilesScanned).toString()
				}
			}
			if ($processedJob.FilesToBackup) {
				$job_fields += @{
					asset_layout_field_id = $(Get-HuduAssetLayoutFieldID -name 'Files to Backup' -asset_layout_id $layout.id)
					value = $($processedJob.FilesToBackup).toString()
				}
			}
			if ($processedJob.ErrorMessage) {
				$job_fields += @{
					asset_layout_field_id = $(Get-HuduAssetLayoutFieldID -name 'Error Message' -asset_layout_id $layout.id)
					value = $($processedJob.ErrorMessage).toString()
				}
			}
			if ($detailedReport) {
				$job_fields += @{
					asset_layout_field_id = $(Get-HuduAssetLayoutFieldID -name 'Detailed Report' -asset_layout_id $layout.id)
					value = $($detailedReport).toString()
				}
			}
					
			
			#Check if doing per job or per run
			if ($createJobsWithHistory){
				$assetName = "$($processedJob.ComputerName) - $($processedJob.PlanName) - $($processedJob.LastStart)"
			} else {
				$assetName = "$($processedJob.ComputerName) - $($processedJob.PlanName)"
			}
			
			
			#Check if it already exists
				$asset = get-huduassets -name $assetName
				if ($asset) {
					$asset = Set-HuduAsset -name $assetName -company_id $company.id -asset_layout_id $layout.id -fields $job_fields -asset_id $asset.id
					Write-Host "Asset Updated $assetName"
				} else {
					$asset = New-HuduAsset -name $assetName -company_id $company.id -asset_layout_id $layout.id -fields $job_fields
					Write-Host "Asset Created $assetName"
				}				
	
				$processedJob | add-member -NotePropertyName "asset_slug" -NotePropertyValue $asset.asset.slug
							
			$jobsummary += $processedJob

	} else {
	write-host "Company $($job.CompanyName) Not found in Hudu. Please rename in MSP360" -ForegroundColor Red
	}
	
	
}


# Process Magic Dash
if ($createMagicDash) {
	$companiesprocessed = $jobsummary | select CompanyName -unique

	foreach ($company in $companiesprocessed) {
		$i = 0
		$faili = 0
		$jobs = $jobsummary | where CompanyName -eq $company.CompanyName
		$shade = "success"
		$magichtml = "<table><tr><th>Job Name</th><th>Status</th></tr>"
		foreach ($job in $jobs) {
			$i++
			$magichtml += "<tr><td><a href=`"$($HuduBaseDomain)/a/$($job.asset_slug)`">$($job.ComputerName) - $($job.PlanName) - $($job.LastStart)</a></td><td>$($job.Status)</td></tr>"
			$status = $job.Status
			if (!($status -in @("Running","Success"))){
				$shade = "danger"
				$faili++
			}
		}
		$magichtml += "</table>"
		$message = "$($i-$faili) / $i Successful"
		$result = Set-HuduMagicDash -title "MSP360 Backups - $($company.CompanyName)" `
					-company_name $company.CompanyName -message $message `
					-icon "fas fa-retweet" -content $magichtml -shade $shade	
		write-host "$($company.CompanyName) Magic Dash Updated"
	}
	
	
}


# Create Global Report Article
if ($createGlobalReport) {
	
	write-host "Generating Global Report"
	
	$table = "<figure class=`"table`"><table><tbody><tr><th>Plan Name</th><th>Company Name</th><th>Computer Name</th><th>Last Start</th><th>Status</th>"
	foreach ($job in $jobsummary) {
		
		#Set status color
		if (($job.status -eq "Success")){
			$status = "<span style=`"color:hsl(120, 75%, 60%);`"><i class=`"fas fa-check-circle`"></i>&nbsp;&nbsp;&nbsp;<strong>$($job.status)</strong></span>"
		} elseif ($job.status -eq "Running") {
			$status ="<i class=`"fas fa-retweet`"></i>&nbsp;&nbsp;&nbsp;$($job.status )"
		} else {
			$status = "<span style=`"color:hsl(0, 75%, 60%);`"><i class=`"fas fa-times-circle`"></i>&nbsp;&nbsp;&nbsp;<strong>$($job.status)</strong></span>"
		}
		
		#Check if there is a computer asset we can link to.
		$computer = get-huduassets -name $job.ComputerName
		if ($computer) {
			$computerlink = "<a href=`"$($HuduBaseDomain)/a/$($computer.slug)`">$($job.ComputerName)</a>"
		} else {
			$computerlink = "$($job.ComputerName)"
		}
		
		$table += "<tr><td><a href=`"$($HuduBaseDomain)/a/$($job.asset_slug)`">$($job.PlanName)</a></td>
					<td><a href=`"$($HuduBaseDomain)/c/$($job.companyslug)`">$($job.companyname)</a></td>
					<td>$computerlink</td>
					<td>$($job.laststart)</td>
					<td>$status</td></tr>"
		
		
	}
	
	$table += "</tbody></table></figure>"
	
	#Check if an article already exists
	$article = Get-HuduArticles -name $globalReportName
	if ($article) {
		$result = Set-HuduArticle -name $globalReportName -content $table -folder_id $folderID -article_id $article.id
		Write-Host "Updated Global Report"
	} else {
		$result = New-HuduArticle -name $globalReportName -content $table -folder_id $folderID
		Write-Host "Created Global Report"
	}
	
}

	
	
		

