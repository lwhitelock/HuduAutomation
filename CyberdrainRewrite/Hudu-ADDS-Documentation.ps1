# Based on the original script by Kelvin Tegelaar https://github.com/KelvinTegelaar/AutomaticDocumentation
#####################################################################
#
# Active Directory Details to Hudu
#
# Get a Hudu API Key from https://yourhududomain.com/admin/api_keys
$HuduAPIKey = "abcdefgh12345678"
# Set the base domain of your Hudu instance without a trailing /
$HuduBaseDomain = "https://your.hudu.com"
#Company Name as it appears in Hudu
$CompanyName = "Example Company"
$HuduAssetLayoutName = "Active Directory - AutoDoc"
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
  
Function Get-RegistryValue
{
	# Gets the specified registry value or $Null if it is missing
	[CmdletBinding()]
	Param
	(
		[String] $path, 
		[String] $name, 
		[String] $ComputerName
	)

	If($ComputerName -eq $env:computername -or $ComputerName -eq "LocalHost")
	{
		$key = Get-Item -LiteralPath $path -EA 0
		If($key)
		{
			Return $key.GetValue($name, $Null)
		}
		Else
		{
			Return $Null
		}
	}

	#path needed here is different for remote registry access
	$path1 = $path.SubString( 6 )
	$path2 = $path1.Replace( '\', '\\' )

	$registry = $null
	try
	{
		## use the Remote Registry service
		$registry = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey(
			[Microsoft.Win32.RegistryHive]::LocalMachine,
			$ComputerName ) 
	}
	catch
	{
		#$e = $error[ 0 ]
		#3.06, remove the verbose message as it confised some people
		#wv "Could not open registry on computer $ComputerName ($e)"
	}

	$val = $null
	If( $registry )
	{
		$key = $registry.OpenSubKey( $path2 )
		If( $key )
		{
			$val = $key.GetValue( $name )
			$key.Close()
		}

		$registry.Close()
	}

	Return $val
}

Function GetBasicDCInfo {
	Param
	(
		[Parameter( Mandatory = $true )]
		[String] $dn	## distinguishedName of a DC
	)

	$DCName  = $dn.SubString( 0, $dn.IndexOf( '.' ) )
	$SrvName = $dn.SubString( $dn.IndexOf( '.' ) + 1 )

	$Results = Get-ADDomainController -Identity $DCName -Server $SrvName -EA 0

   	If($? -and $Null -ne $Results)
	{
		$GC       = $Results.IsGlobalCatalog.ToString()
		$ReadOnly = $Results.IsReadOnly.ToString()
		$IPv4Address = $Results.IPv4Address -join ", "
        $IPv6Address = $Results.IPv6Address -join ", "
		$ServerOS = $Results.OperatingSystem
		$tmp = Get-RegistryValue "HKLM:\software\microsoft\windows nt\currentversion" "installationtype" $DCName
		If( $null -eq $tmp ) { $ServerCore = 'Unknown' }
		ElseIf( $tmp -eq 'Server Core') { $ServerCore = 'Yes' }
		Else { $ServerCore = 'No' }
	}
	Else
	{
		$GC          = 'Unable to retrieve status'
		$ReadOnly    = $GC
		$ServerOS    = $GC
		$ServerCore  = $GC
        $IPv4Address  = $GC
        $IPv6Address  = $GC
	}

	$obj = [PSCustomObject] @{ 
		DCName       = $DCName
		GC           = $GC
		ReadOnly     = $ReadOnly
		ServerOS     = $ServerOS
		ServerCore   = $ServerCore
        IPv4Address  = $IPv4Address
        IPv6Address  = $IPv6Address
	}
    
	Return $obj
}

Function GetTimeServerRegistryKeys {
	Param
	(
		[String] $DCName
	)

	$AnnounceFlags = Get-RegistryValue "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Config" "AnnounceFlags" $DCName
	If( $null -eq $AnnounceFlags )
	{
		## DCName can't be contacted or DCName is an appliance with no registry
		$AnnounceFlags = 'n/a'
		$MaxNegPhaseCorrection = 'n/a'
		$MaxPosPhaseCorrection = 'n/a'
		$NtpServer = 'n/a'
		$NtpType = 'n/a'
		$SpecialPollInterval = 'n/a'
		$VMICTimeProviderEnabled = 'n/a'
		$NTPSource = 'Cannot retrieve data from registry'
	}
	Else
	{
		$MaxNegPhaseCorrection = Get-RegistryValue "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Config" "MaxNegPhaseCorrection" $DCName
		$MaxPosPhaseCorrection = Get-RegistryValue "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Config" "MaxPosPhaseCorrection" $DCName
		$NtpServer = Get-RegistryValue "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters" "NtpServer" $DCName
		$NtpType = Get-RegistryValue "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters" "Type" $DCName
		$SpecialPollInterval = Get-RegistryValue "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\TimeProviders\NtpClient" "SpecialPollInterval" $DCName
		$VMICTimeProviderEnabled = Get-RegistryValue "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\TimeProviders\VMICTimeProvider" "Enabled" $DCName
		$NTPSource = Invoke-Command -ComputerName $DCName {w32tm /query /computer:$DCName /source}
	}

	If( $VMICTimeProviderEnabled -eq 'n/a' )
	{
		$VMICEnabled = 'n/a'
	}
	ElseIf( $VMICTimeProviderEnabled -eq 0 )
	{
		$VMICEnabled = 'Disabled'
	}
	Else
	{
		$VMICEnabled = 'Enabled'
	}
	
	$obj = [PSCustomObject] @{
		DCName                = $DCName.Substring(0, $_.IndexOf( '.'))
		TimeSource            = $NTPSource
		AnnounceFlags         = $AnnounceFlags
		MaxNegPhaseCorrection = $MaxNegPhaseCorrection
		MaxPosPhaseCorrection = $MaxPosPhaseCorrection
		NtpServer             = $NtpServer
		NtpType               = $NtpType
		SpecialPollInterval   = $SpecialPollInterval
		VMICTimeProvider      = $VMICEnabled
	}
    Return $obj
}

function Get-WinADForestInformation {
    $Data = @{ }
    $ForestInformation = $(Get-ADForest)
    $Data.Forest = $ForestInformation
    $Data.RootDSE = $(Get-ADRootDSE -Properties *)
    $Data.ForestName = $ForestInformation.Name
    $Data.ForestNameDN = $Data.RootDSE.defaultNamingContext
    $Data.Domains = $ForestInformation.Domains
    $Data.ForestInformation = @{
        'Forest Name'             = $ForestInformation.Name
        'Root Domain'             = $ForestInformation.RootDomain
        'Forest Functional Level' = $ForestInformation.ForestMode
        '# of Domains'            = ($ForestInformation.Domains).Count
        'Sites Count'             = ($ForestInformation.Sites).Count
        'Forest Domains'          = ($ForestInformation.Domains) -join ", "
        'Sites'                   = ($ForestInformation.Sites) -join ", "
    }
      
    $Data.UPNSuffixes = Invoke-Command -ScriptBlock {
        $UPNSuffixList  =  [PSCustomObject] @{ 
                "Primary UPN" = $ForestInformation.RootDomain
                "UPN Suffixes"   = $ForestInformation.UPNSuffixes -join ","
            }  
        return $UPNSuffixList
    }
      
    $Data.GlobalCatalogs = $ForestInformation.GlobalCatalogs
    $Data.SPNSuffixes = $ForestInformation.SPNSuffixes
      
    $Data.Sites = Invoke-Command -ScriptBlock {
      $Sites = [System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest().Sites | Sort-Object         
        $SiteData = foreach ($Site in $Sites) {          
          [PSCustomObject] @{ 
                "Site Name" = $site.Name
                "Subnets"   = ($site.Subnets | Sort-Object)  -join ", "
                "Servers" = ($Site.Servers) -join ", "
            }  
        }
        Return $SiteData
    }
      
        
    $Data.FSMO = Invoke-Command -ScriptBlock {
        [PSCustomObject] @{ 
            "Domain" = $ForestInformation.RootDomain
            "Role"   = 'Domain Naming Master'
            "Holder" = $ForestInformation.DomainNamingMaster
        }
 
        [PSCustomObject] @{ 
            "Domain" = $ForestInformation.RootDomain
            "Role"   = 'Schema Master'
            "Holder" = $ForestInformation.SchemaMaster
        }
          
        foreach ($Domain in $ForestInformation.Domains) {
            $DomainFSMO = Get-ADDomain $Domain | Select-Object PDCEmulator, RIDMaster, InfrastructureMaster
 
            [PSCustomObject] @{ 
                "Domain" = $Domain
                "Role"   = 'PDC Emulator'
                "Holder" = $DomainFSMO.PDCEmulator
            } 
 
             
            [PSCustomObject] @{ 
                "Domain" = $Domain
                "Role"   = 'Infrastructure Master'
                "Holder" = $DomainFSMO.InfrastructureMaster
            } 
 
            [PSCustomObject] @{ 
                "Domain" = $Domain
                "Role"   = 'RID Master'
                "Holder" = $DomainFSMO.RIDMaster
            } 
 
        }
          
        Return $FSMO
    }
      
    $Data.OptionalFeatures = Invoke-Command -ScriptBlock {
        $OptionalFeatures = $(Get-ADOptionalFeature -Filter * )
        $Optional = @{
            'Recycle Bin Enabled'                          = ''
            'Privileged Access Management Feature Enabled' = ''
        }
        ### Fix Optional Features
        foreach ($Feature in $OptionalFeatures) {
            if ($Feature.Name -eq 'Recycle Bin Feature') {
                if ("$($Feature.EnabledScopes)" -eq '') {
                    $Optional.'Recycle Bin Enabled' = $False
                }
                else {
                    $Optional.'Recycle Bin Enabled' = $True
                }
            }
            if ($Feature.Name -eq 'Privileged Access Management Feature') {
                if ("$($Feature.EnabledScopes)" -eq '') {
                    $Optional.'Privileged Access Management Feature Enabled' = $False
                }
                else {
                    $Optional.'Privileged Access Management Feature Enabled' = $True
                }
            }
        }
        return $Optional
        ### Fix optional features
    }
    return $Data
}
  
$TableHeader = "<table style=`"width: 100%; border-collapse: collapse; border: 1px solid black;`">"
$Whitespace = "<br/>"
$TableStyling = "<th>", "<th align=`"left`" style=`"background-color:#00adef; border: 1px solid black;`">"
  
$RawAD = Get-WinADForestInformation
  
$ForestRawInfo = new-object PSCustomObject -property $RawAD.ForestInformation | convertto-html -Fragment | Select-Object -Skip 1
$ForestToc = "<div id=`"forest_summary`"></div>"
$ForestNice = $ForestToc + $TableHeader + ($ForestRawInfo -replace $TableStyling) + $Whitespace
  
$SiteRawInfo = $RawAD.Sites | Select-Object 'Site Name', Servers, Subnets | ConvertTo-Html -Fragment | Select-Object -Skip 1
$SiteHeader = "<p id=`"site_summary`"><i>AD Forest Physical Structure.</i></p>"
$SiteNice = $SiteHeader + $TableHeader + ($SiteRawInfo -replace $TableStyling) + $Whitespace

$DomainsRawInfo = $(Get-WinADForestInformation).Domains | ForEach-Object { Get-ADDomain $_  | Select Name, NetBIOSName, DomainMode } | ConvertTo-Html -Fragment | Select-Object -Skip 1
$DomainsHeader = "<p id=`"domains_summary`"><i>AD Forest Logical Structure.</i></p>"
$DomainsNice = $DomainsHeader + $TableHeader + ($DomainsRawInfo -replace $TableStyling) + $Whitespace

$OptionalRawFeatures = new-object PSCustomObject -property $RawAD.OptionalFeatures | convertto-html -Fragment | Select-Object -Skip 1
$OptionalFeaturesToc = "<div id=`"optional_features`"></div>"
$OptionalNice = $OptionalFeaturesToc + $TableHeader + ($OptionalRawFeatures -replace $TableStyling) + $Whitespace
  
$UPNRawFeatures = $RawAD.UPNSuffixes |  convertto-html -Fragment -as list| Select-Object -Skip 1
$UPNToc = "<div id=`"upn_suffixes`"></div>"
$UPNNice = $UPNToc + $TableHeader + ($UPNRawFeatures -replace $TableStyling) + $Whitespace
  
$DCRawFeatures = $RawAD.GlobalCatalogs| Sort-Object | ForEach-Object { GetBasicDCInfo $_ } | convertto-html -Fragment | Select-Object -Skip 1
$DCToc = "<div id=`"domain_controllers`"></div>"
$DCNice = $DCTocStart + $TableHeader + ($DCRawFeatures -replace $TableStyling) + $Whitespace

$DCRawNTPconfig = $RawAD.GlobalCatalogs | Sort-Object | ForEach-Object { (GetTimeServerRegistryKeys $_) } | convertto-html -Fragment  | Select-Object -Skip 1
$NTPToc = "<div id=`"ntp_configuration`"></div>"
$DCNTPconfigNice = $NTPToc + $TableHeader + ($DCRawNTPconfig -replace $TableStyling) + $Whitespace

$FSMORawFeatures = $RawAD.FSMO | convertto-html -Fragment | Select-Object -Skip 1
$FSMOToc = "<div id=`"fsmo_roles`"></div>"
$FSMONice = $FSMOToc + $TableHeader + ($FSMORawFeatures -replace $TableStyling) + $Whitespace
  
$ForestFunctionalLevel = $RawAD.RootDSE.forestFunctionality
$DomainFunctionalLevel = $RawAD.RootDSE.domainFunctionality
$domaincontrollerMaxLevel = $RawAD.RootDSE.domainControllerFunctionality
  
$passwordpolicyraw = Get-ADDefaultDomainPasswordPolicy | Select-Object ComplexityEnabled, PasswordHistoryCount, LockoutDuration, LockoutThreshold, MaxPasswordAge, MinPasswordAge | convertto-html -Fragment -As List | Select-Object -skip 1
$passwordpolicyheader = "<tr><th>Policy</th><th><b>Setting</b></th></tr>"
$passwordToc = "<div id=`"default_password_policies`"></div>"
$passwordpolicyNice = $passwordToc + $TableHeader + ($passwordpolicyheader -replace $TableStyling) + ($passwordpolicyraw -replace $TableStyling) + $Whitespace
  
$adminsraw = Get-ADGroupMember "Domain Admins" | Select-Object SamAccountName, Name | convertto-html -Fragment | Select-Object -Skip 1
$adminsToc = "<div id=`"domain_admins`"></div>"
$adminsnice = $adminsToc + $TableHeader + ($adminsraw -replace $TableStyling) + $Whitespace
  
$TotalUsers = (Get-AdUser -filter *).count
$EnabledUsers = (Get-AdUser -filter * | Where-Object { $_.enabled -eq $true }).count
$DisabledUSers = (Get-AdUser -filter * | Where-Object { $_.enabled -eq $false }).count
$DomainAdminUsers = (Get-ADGroupMember -Identity "Domain Admins").count
$EnterpriseAdminUsers = (Get-ADGroupMember -Identity "Enterprise Admins").count
$SchemaAdminUsers = (Get-ADGroupMember -Identity "Schema Admins").count
$AdminCountUsers = (Get-ADUser -LDAPFilter "(admincount=1)").count
$UsersCountObj = [PSCustomObject] @{ 
    'Total'             = $TotalUsers
    'Enabled'           = $EnabledUsers
    'Disabled'          = $DisabledUSers
    'Domain Admins'     = $DomainAdminUsers
    'Enterprise Admins' = $EnterpriseAdminUsers
    'Schema Admins'     = $SchemaAdminUsers
    'AdminCount users'  = $AdminCountUsers
}

$userTotalsRaw = $UsersCountObj | convertto-html -Fragment | Select-Object -Skip 1
$userTotalsToc = "<div id=`"user_count`"></div>"
$userTotalsNice = $userTotalsToc + $TableHeader + ($userTotalsRaw -replace $TableStyling) + $Whitespace

$currentDate = Get-Date -Format "dddd dd/MM/yyyy HH:mm K"
$toc = '<h2><center>
			<a href="#forest_summary">FOREST SUMMARY</a>&nbsp;&nbsp;|&nbsp;&nbsp;
			<a href="#site_summary">SITE SUMMARY</a>&nbsp;&nbsp;|&nbsp;&nbsp;
			<a href="#domains_summary">DOMAIN SUMMARY</a>&nbsp;&nbsp;|&nbsp;&nbsp;
			<a href="#domain_controllers">DOMAIN CONTROLLERS</a>&nbsp;&nbsp;|&nbsp;&nbsp;
			<a href="#ntp_configuration">NTP CONFIGURATION</a>&nbsp;&nbsp;|&nbsp;&nbsp;
			<a href="#fsmo_roles">FSMO ROLES</a>&nbsp;&nbsp;|&nbsp;&nbsp;
			<a href="#optional_features">OPTIONAL FEATURES</a>&nbsp;&nbsp;|&nbsp;&nbsp;
			<a href="#upn_suffixes">UPN SUFFIXES</a>&nbsp;&nbsp;|&nbsp;&nbsp;
			<a href="#default_password_policies">DEFAULT PASSWORD POLICIES</a>&nbsp;&nbsp;|&nbsp;&nbsp;
			<a href="#user_count">USER COUNT</a>&nbsp;&nbsp;|&nbsp;&nbsp;
			<a href="#domain_admins">DOMAIN ADMINS</a> 
		</center></h2><br />'

# Setup the fields for the Asset 
$AssetFields = @{

            'last_updated'               = $currentDate
			'toc'						= $toc
            'forest_name'               = $RawAD.ForestName
            'forest_summary'            = $ForestNice
            'site_summary'              = $SiteNice
            'domains_summary'            = $DomainsNice
            'domain_controllers'        = $DCNice
            'ntp_configuration'         = $DCNTPconfigNice
            'fsmo_roles'                = $FSMONice
            'optional_features'         = $OptionalNice
            'upn_suffixes'              = $UPNNice
            'default_password_policies' = $passwordpolicyNice
            'domain_admins'             = $adminsnice
            'user_count'                = $userTotalsNice
        }
 
# Checking if the FlexibleAsset exists. If not, create a new one.
$Layout = Get-HuduAssetLayouts -name $HuduAssetLayoutName

if (!$Layout) { 

$AssetLayoutFields = @(
		@{
			label = 'Last Updated'
			field_type = 'Text'
			show_in_list = 'true'
			position = 1
		},
		@{
			label = 'TOC'
			field_type = 'RichText'
			show_in_list = 'false'
			position = 2
		},
		@{
			label = 'Forest Name'
			field_type = 'Text'
			show_in_list = 'true'
			position = 3
		},
		@{
			label = 'Forest Summary'
			field_type = 'RichText'
			show_in_list = 'false'
			position = 4
		},
		@{
			label = 'Site Summary'
			field_type = 'RichText'
			show_in_list = 'false'
			position = 5
		},
		@{
			label = 'Domains Summary'
			field_type = 'RichText'
			show_in_list = 'false'
			position = 6
		},
        @{
			label = 'Domain Controllers'
			field_type = 'RichText'
			show_in_list = 'false'
			position = 7
		},
		@{
			label = 'NTP Configuration'
			field_type = 'RichText'
			show_in_list = 'false'
			position = 8
		},        
		@{
			label = 'FSMO Roles'
			field_type = 'RichText'
			show_in_list = 'false'
			position = 9
		},
		@{
			label = 'Optional Features'
			field_type = 'RichText'
			show_in_list = 'false'
			position = 10
		},
		@{
			label = 'UPN Suffixes'
			field_type = 'RichText'
			show_in_list = 'false'
			position = 11
		},
		@{
			label = 'Default Password Policies'
			field_type = 'RichText'
			show_in_list = 'false'
			position = 12
		},
		@{
			label = 'User Count'
			field_type = 'RichText'
			show_in_list = 'false'
			position = 13
		},
		@{
			label = 'Domain Admins'
			field_type = 'RichText'
			show_in_list = 'false'
			position = 14
		}
	)
	
	Write-Host "Creating New Asset Layout"
	$NewLayout = New-HuduAssetLayout -name $HuduAssetLayoutName -icon "fas fa-sitemap" -color "#00adef" -icon_color "#000000" -include_passwords $false -include_photos $false -include_comments $false -include_files $false -fields $AssetLayoutFields
	$Layout = Get-HuduAssetLayouts -name $HuduAssetLayoutName
}


$Company = Get-HuduCompanies -name $CompanyName.Replace('&','%26')
if ($company) {	
	#Upload data to Hudu
	$Asset = Get-HuduAssets -name $RawAD.ForestName -companyid $company.id -assetlayoutid $layout.id
	
	#If the Asset does not exist, we edit the body to be in the form of a new asset, if not, we just upload.
	if (!$Asset) {
		Write-Host "Creating new Asset"
		$Asset = New-HuduAsset -name $RawAD.ForestName -company_id $company.id -asset_layout_id $layout.id -fields $AssetFields	
	}
	else {
    Write-Host "Updating Asset"
    $Asset = Set-HuduAsset -asset_id $Asset.id -name $RawAD.ForestName -company_id $company.id -asset_layout_id $layout.id -fields $AssetFields	
	}

} else {
	Write-Host "$CompanyName was not found in Hudu"
}
