#Gerocoding function is from https://www.powershellgallery.com/packages/GoogleMap/1.0.0.3/Content/GoogleMap.psm1 by Prateek Singh
#####################################################################
# Get a Hudu API Key from https://yourhududomain.com/admin/api_keys
$HuduAPIKey = 'abcdefghi12345678'
# Set the base domain of your Hudu instance without a trailing /
$HuduBaseDomain = 'https://your.hudu.domain'
$HuduAssetLayoutName = 'Locations Map'
#####################################################################
# Settings
#THe name of the Asset layout where you sync customer locations to
$HuduLocationAsset = 'Sites'
#Set the name of the customer you would like the map of all customer locations created in.
$HuduMasterCustomer = 'Your Internal Company'
# Google Maps API key. You will need to enable the Geocoding API https://developers.google.com/maps/documentation/geocoding/get-api-key and the Places API https://developers.google.com/maps/documentation/javascript/cloud-setup
$GoogleGeocode_API_Key = 'abcdefghijklmnop123456787'

Function Get-GeoCoding {
	Param(
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)] [String] $Address
	)

	Begin {
		If (!$GoogleGeocode_API_Key) {
			Throw "You need to register and get an API key and save it as environment variable `$GoogleGeocode_API_Key = `"YOUR API KEY`" `nFollow this link and get the API Key - http://developers.google.com/maps/documentation/geocoding/get-api-key `n`n "
		}
	}

	Process {

		Foreach ($Item in $Address) {
			Try {
				$FormattedAddress = $Item.replace(' ', '+')

				$webpage = Invoke-WebRequest "https://maps.googleapis.com/maps/api/geocode/json?address=$FormattedAddress&key=$GoogleGeocode_API_Key" -UseBasicParsing -ErrorVariable EV
				$Results = $webpage.Content | ConvertFrom-Json | Select-Object Results -ExpandProperty Results
				$Status = $webpage.Content | ConvertFrom-Json | Select-Object Status -ExpandProperty Status

				If ($Status -eq 'OK') {

					ForEach ($R in $Results) {
						$AddressComponents = $R.address_components

						$R | Select-Object @{n = 'InputAddress'; e = { $Item } }, `
						@{n = 'Address'; e = { $_.Formatted_address } }, `
						@{n = 'Country'; e = { ($AddressComponents | Where-Object { $_.types -like '*Country*' }).Long_name } }, `
						@{n = 'State'; e = { ($AddressComponents | Where-Object { $_.types -like '*administrative_area_level_1*' }).Long_name } }, `
						@{n = 'PostalCode'; e = { ($AddressComponents | Where-Object { $_.types -like '*postal_code*' }).Long_name } }, `
						@{n = 'Latitude'; e = { '{0:N7}' -f $_.Geometry.Location.Lat } }, `
						@{n = 'Longitude'; e = { '{0:N7}' -f $_.Geometry.Location.Lng } }, `
						@{n = 'Coordinates'; e = { "$('{0:N7}' -f $_.Geometry.Location.Lat),$('{0:N7}' -f $_.Geometry.Location.Lng)" } }
					}
				} Elseif ($Status -eq 'ZERO_RESULTS') {
					'Zero Results Found : Try changing the parameters'
				}
			} Catch {
				'Something went wrong, please try running again.'
				$ev.message
			}
		}
	}
}

Function Generate-HTML {
	Param(
		[Parameter(Mandatory = $true)] [System.Collections.ArrayList] $Addresses
	)

	$first = $true
	foreach ($address in $Addresses) {
		if ($first -eq $true) {
			$markers = $address.marker
			$infoWindows = $address.infoWindow
			$first = $false
		} else {
			$markers = "$markers, $($address.marker)"
			$infoWindows = "$infoWindows, $($address.infoWindow)"
		}

	}

	$html = "<style>
		#map_wrapper {
			height: 430px;
		}

		#map_canvas {
			width: 100%;
			height: 100%;
		}
		</style>
		<div id=`"map_wrapper`">
			<div id=`"map_canvas`" class=`"mapping`"></div>
		</div>

		<script>

		function myMap() {
			var map;
			var bounds = new google.maps.LatLngBounds();
			var mapOptions = {
				mapTypeId: 'roadmap'
			};

			// Display a map on the page
			map = new google.maps.Map(document.getElementById(`"map_canvas`"), mapOptions);
			map.setTilt(45);

			// Multiple Markers
			var markers = [
				$markers
			];

			// Info Window Content
			var infoWindowContent = [
				$infoWindows
			];

			// Display multiple markers on a map
			var infoWindow = new google.maps.InfoWindow(), marker, i;

			// Loop through our array of markers & place each one on the map
			for( i = 0; i < markers.length; i++ ) {
				var position = new google.maps.LatLng(markers[i][1], markers[i][2]);
				bounds.extend(position);
				marker = new google.maps.Marker({
					position: position,
					map: map,
					title: markers[i][0]
				});

				// Allow each marker to have an info window
				google.maps.event.addListener(marker, 'click', (function(marker, i) {
					return function() {
						infoWindow.setContent(infoWindowContent[i][0]);
						infoWindow.open(map, marker);
					}
				})(marker, i));

				// Automatically center the map fitting all markers on the screen
				map.fitBounds(bounds);
			}

		}
		</script>
		<script async defer src=`"https://maps.googleapis.com/maps/api/js?key=$GoogleGeocode_API_Key&callback=myMap`"> </script>
		"

	return $html

}

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

$Layout = Get-HuduAssetLayouts -name $HuduAssetLayoutName
$SiteLayout = Get-HuduAssetLayouts -name $HuduLocationAsset


if (!$Layout) {
	$AssetLayoutFields = @(
		@{
			label        = 'Map'
			field_type   = 'Embed'
			show_in_list = 'false'
			position     = 1
		}
	)

	Write-Host "Creating New Asset Layout $HuduAssetLayoutName"
	$NewLayout = New-HuduAssetLayout -name $HuduAssetLayoutName -icon 'fas fa-map-marked-alt' -color '#00adef' -icon_color '#ffffff' -include_passwords $false -include_photos $false -include_comments $false -include_files $false -fields $AssetLayoutFields
	$Layout = Get-HuduAssetLayouts -name $HuduAssetLayoutName
}

$companies = Get-HuduCompanies
$allAddresses = [System.Collections.ArrayList]@()

foreach ($company in $companies) {
	$companyAddresses = [System.Collections.ArrayList]@()
	$locations = Get-HuduAssets -assetlayoutid $SiteLayout.id -companyid $company.id
	foreach ($location in $locations) {
		if ($location.cards.data.address1) {
			$parsed_address = "$($location.cards.data.address1)"

			if ($location.cards.data.address2) {
				$parsed_address = "$parsed_address, $($location.cards.data.address2)"
			}

			if ($location.cards.data.city) {
				$parsed_address = "$parsed_address, $($location.cards.data.city)"
			}

			if ($location.cards.data.state) {
				$parsed_address = "$parsed_address, $($location.cards.data.state)"
			}

			if ($location.cards.data.postalcode) {
				$parsed_address = "$parsed_address, $($location.cards.data.postalcode)"
			}

			$parsed_address = $parsed_address -replace "'", ''

			$geocoded = $parsed_address | Get-GeoCoding

			if ($($geocoded[0].Latitude)) {
				$addrObject = [pscustomobject]@{
					marker     = "['$($location.company_name) - $($location.name)', $($geocoded[0].Latitude),$($geocoded[0].Longitude)]"
					infoWindow = "['<div class=`"info_content`">' +
								'<h3><a href=$($location.url) target=`"_blank`">$($location.company_name) - $($location.name)</a></h3>' +
								'<p>$parsed_address</p>' +
								'</div>']"
				}

				$null = $allAddresses.add($addrObject)
				$null = $companyAddresses.add($addrObject)
			}
		}
	}

	if ($companyAddresses.count -gt 0) {
		$html = Generate-HTML -Addresses $companyAddresses

		$AssetFields = @{
			'map' = $html
		}


		$companyid = $company.id

		#Swap out # as Hudu doesn't like it when searching
		$AssetName = "$($company.name) - Locations"

		#Check if there is already an asset
		$Asset = Get-HuduAssets -name $AssetName -companyid $companyid -assetlayoutid $Layout.id

		#If the Asset does not exist, we edit the body to be in the form of a new asset, if not, we just upload.
		if (!$Asset) {
			Write-Host 'Creating new Asset'
			$Asset = New-HuduAsset -name $AssetName -company_id $companyid -asset_layout_id $Layout.id -fields $AssetFields
		} else {
			Write-Host 'Updating Asset'
			$Asset = Set-HuduAsset -asset_id $Asset.id -name $AssetName -company_id $companyid -asset_layout_id $Layout.id -fields $AssetFields
		}

	}
}

if ($allAddresses.count -gt 0) {
	$html = Generate-HTML -Addresses $allAddresses

	$AssetFields = @{
		'map' = $html
	}

	$company = get-huducompanies -name $HuduMasterCustomer

	$companyid = $company.id

	#Swap out # as Hudu doesn't like it when searching
	$AssetName = 'All Customer Locations'

	#Check if there is already an asset
	$Asset = Get-HuduAssets -name $AssetName -companyid $companyid -assetlayoutid $Layout.id

	#If the Asset does not exist, we edit the body to be in the form of a new asset, if not, we just upload.
	if (!$Asset) {
		Write-Host 'Creating new Asset'
		$Asset = New-HuduAsset -name $AssetName -company_id $companyid -asset_layout_id $Layout.id -fields $AssetFields
	} else {
		Write-Host 'Updating Asset'
		$Asset = Set-HuduAsset -asset_id $Asset.id -name $AssetName -company_id $companyid -asset_layout_id $Layout.id -fields $AssetFields
	}

}

