# Add this CSS to Admin -> Design -> Custom CSS
# .custom-fast-fact.custom-fast-fact--warning {
#     background: #f5c086;
# }
#####################################################################
# Get a Hudu API Key from https://yourhududomain.com/admin/api_keys
$HuduAPIKey = "YourHuduAPIKey"
# Set the base domain of your Hudu instance without a trailing /
$HuduBaseDomain = "https://your.hudu.domain"
######################### Autotask Settings ###########################
$AutotaskIntegratorID = 'AutotaskIntegratorID'
$AutotaskAPIUser = 'apiuser@domain.com'
$AutotaskAPISecret = 'autotasksecret'
$ExcludeStatus =
$ExcludeType =
$ExcludeQueue =
$AutotaskRoot = "https://ww16.autotask.net"
$AutoTaskAPIBase = "https://webservices16.autotask.net"
######################################################################
#### Other Settings ####
$CreateAllOverdueTicketsReport = $true
$globalReportName = "Autotask - Overdue Ticket Report"
$folderID = 662
$TableStylingGood = "<th>", "<th style=`"background-color:#aeeab4`">"
$TableStylingBad = "<th>", "<th style=`"background-color:#f8d1d3`">"
#####################################################################
function Get-ATFieldHash {
	Param(
		[Array]$fieldsIn,
		[string]$name
	)
	
	$tempFields = ($fieldsIn.fields | where -filter {$_.name -eq $name}).picklistValues
	$tempValues = $tempFields | where -filter {$_.isActive -eq $true} | select value,label
	$tempHash = @{}
	$tempValues | Foreach {$tempHash[$_.value] = $_.label} 
	
	return $tempHash	
}



#Get the Hudu API Module if not installed
if (Get-Module -ListAvailable -Name HuduAPI) {
		Import-Module HuduAPI 
	} else {
		Install-Module HuduAPI -Force
		Import-Module HuduAPI
	}

if (Get-Module -ListAvailable -Name AutotaskAPI) {
		Import-Module AutotaskAPI 
	} else {
		Install-Module AutotaskAPI -Force
		Import-Module AutotaskAPI
	}
  
  $TicketFilter = "{`"filter`":[{`"op`":`"notin`",`"field`":`"queueID`",`"value`":$ExcludeQueue},{`"op`":`"notin`",`"field`":`"status`",`"value`":$ExcludeStatus},{`"op`":`"notin`",`"field`":`"ticketType`",`"value`":$ExcludeType}]}"
  
#Set Hudu logon information
New-HuduAPIKey $HuduAPIKey
New-HuduBaseUrl $HuduBaseDomain

$headers = @{
			'ApiIntegrationCode' = $AutotaskIntegratorID
			'UserName' = $AutotaskAPIUser
			'Secret' = $AutotaskAPISecret
			}

$fields = Invoke-RestMethod -method get -uri "$AutoTaskAPIBase/ATServicesRest/V1.0/Tickets/entityInformation/fields" `
								-headers $headers -contentType 'application/json'
								

#Get Statuses
$statusValues = Get-ATFieldHash -name "status" -fieldsIn $fields

if (!$ExcludeStatus) {
	Write-Host "ExcludeStatus not set please exclude your closed statuses at least from below in the format of '[1,5,7,9]'"
	$statusValues | ft
	exit
}

#Get Ticket types
$typeValues = Get-ATFieldHash -name "ticketType" -fieldsIn $fields

if (!$ExcludeType) {
	Write-Host "ExcludeType not set please exclude types from below in the format of '[1,5,7,9]"
	$typeValues | ft
	exit
}

#Get Queue Types
$queueValues = Get-ATFieldHash -name "queueID" -fieldsIn $fields

if (!$ExcludeType) {
	Write-Host "ExcludeQueue not set please exclude types from below in the format of '[1,5,7,9]"
	$queueValues | ft
	exit
}

#Get Creator Types
$creatorValues = Get-ATFieldHash -name "creatorType" -fieldsIn $fields

#Get Issue Types
$issueValues = Get-ATFieldHash -name "issueType" -fieldsIn $fields

#Get Priority Types
$priorityValues = Get-ATFieldHash -name "priority" -fieldsIn $fields

#Get Source Types
$sourceValues = Get-ATFieldHash -name "source" -fieldsIn $fields

#Get Sub Issue Types
$subissueValues = Get-ATFieldHash -name "subIssueType" -fieldsIn $fields

#Get Categories
$catValues = Get-ATFieldHash -name "ticketCategory" -fieldsIn $fields


$Creds = New-Object System.Management.Automation.PSCredential($AutotaskAPIUser, $(ConvertTo-SecureString $AutotaskAPISecret -AsPlainText -Force))

Add-AutotaskAPIAuth -ApiIntegrationcode $AutotaskIntegratorID -credentials $Creds

$companies = Get-AutotaskAPIResource -resource Companies -SimpleSearch "isactive eq $true"

$TicketFilter = "{`"filter`":[{`"op`":`"notin`",`"field`":`"queueID`",`"value`":$ExcludeQueue},{`"op`":`"notin`",`"field`":`"status`",`"value`":$ExcludeStatus}]}"
$tickets = Get-AutotaskAPIResource -Resource Tickets -SearchQuery $TicketFilter

$AutotaskExe = "/Autotask/AutotaskExtend/ExecuteCommand.aspx?Code=OpenTicketDetail&TicketNumber="

$GlobalOverdue = New-Object System.Collections.ArrayList

foreach ($company in $companies){
	$custTickets = $tickets | where {$_.companyID -eq $company.id} | select id, ticketNUmber, createdate, title, description, dueDateTime, lastActivityPersonType, lastCustomerVisibleActivityDateTime, priority, source, status, issueType, subIssueType, ticketType
	$outTickets = foreach ($ticket in $custTickets){
		[PSCustomObject]@{
		'Ticket-Number'			           		=	"<a target=`"_blank`" href=`"$($AutotaskRoot)$($AutotaskExe)$($ticket.ticketNumber)`">$($ticket.ticketNumber)</a>"
		'Created'			               		=	$ticket.createdate
		'Title'			                   		=	$ticket.title
		'Due'				               		=	$ticket.dueDateTime
		'Last-Updater'			   				=	$creatorValues["$($ticket.lastActivityPersonType)"]
		'Last-Update'							=	$ticket.lastCustomerVisibleActivityDateTime
		'Priority'			               		=	$priorityValues["$($ticket.priority)"]
		'Source'			               		=	$sourceValues["$($ticket.source)"]
		'Status'		                   		=	$statusValues["$($ticket.status)"]
		'Type'				               		=	$issueValues["$($ticket.issueType)"]
		'Sub-Type'				           		=	$subissueValues["$($ticket.subIssueType)"]
		'Ticket-Type'		              		=	$typeValues["$($ticket.ticketType)"]
		'Company'								=	$company.companyName
		}	
	}
		
		if (@($outTickets).count -gt 0) {
			write-host "Processing $($company.companyName)"
			$Now = Get-Date
			$overdue = @($outTickets | where {$([DateTime]::Parse($_.Due)) -lt $now }).count
			
			$MagicMessage = "$(@($outTickets).count) Open Tickets"			
			
						
			$shade = "success"
					
			if ($overdue -ge 1){
			$shade = "warning"
			$MagicMessage = "$overdue / $(@($outTickets).count) Tickets Overdue"
			$overdueTickets = $outTickets | where {$([DateTime]::Parse($_.Due)) -le $now }
			foreach ($odticket in $overdueTickets) {$null = $GlobalOverdue.add($odticket)}	
			$outTickets = $outTickets | where {$([DateTime]::Parse($_.Due)) -gt $now }
			$overdueHTML = [System.Net.WebUtility]::HtmlDecode(($overdueTickets| select 'Ticket-Number', 'Created', 'Title', 'Due', 'Last-Updater', 'Last-Update', 'Priority', 'Source', 'Status', 'Type', 'Sub-Type', 'Ticket-Type' | convertto-html -fragment | out-string) -replace $TableStylingBad)
			$goodHTML = [System.Net.WebUtility]::HtmlDecode(($outTickets | select 'Ticket-Number', 'Created', 'Title', 'Due', 'Last-Updater', 'Last-Update', 'Priority', 'Source', 'Status', 'Type', 'Sub-Type', 'Ticket-Type' | convertto-html -fragment | out-string) -replace $TableStylingGood)
			$body = "<h2>Overdue Tickets:</h2>$overdueHTML<h2>Tickets:</h2>$goodhtml"
			
			} else {
				$body = [System.Net.WebUtility]::HtmlDecode(($outTickets | select 'Ticket-Number', 'Created', 'Title', 'Due', 'Last-Updater', 'Last-Update', 'Priority', 'Source', 'Status', 'Type', 'Sub-Type', 'Ticket-Type' | convertto-html -fragment | out-string) -replace $TableStylingGood)
			}
	
			if ($overdue -ge 2){
			$shade = "danger"
			}
			
			
			
			$Huduresult = Set-HuduMagicDash -title "Autotask - Open Tickets" -company_name $(($company.companyName).Trim()) -message $MagicMessage -icon "fas fa-chart-pie" -content $body -shade $shade
		} else {
			$Huduresult = Set-HuduMagicDash -title "Autotask - Open Tickets" -company_name $(($company.companyName).Trim()) -message "No Open Tickets" -icon "fas fa-chart-pie" -shade "success"
		}				

}
if ($CreateAllOverdueTicketsReport -eq $true) {
$articleHTML = [System.Net.WebUtility]::HtmlDecode($($GlobalOverdue | select 'Ticket-Number', 'Company', 'Title', 'Due', 'Last-Update', 'Priority', 'Status' | convertto-html -fragment | out-string))
$reportdate = Get-Date
$body = "<h2>Report last updated: $reportDate</h2><figure class=`"table`">$articleHTML</figure>"
#Check if an article already exists


	$article = Get-HuduArticles -name $globalReportName
	if ($article) {
		$result = Set-HuduArticle -name $globalReportName -content $body -folder_id $folderID -article_id $article.id
		Write-Host "Updated Global Report"
	} else {
		$result = New-HuduArticle -name $globalReportName -content $body -folder_id $folderID
		Write-Host "Created Global Report"
	}
}
