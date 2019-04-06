#Convert PVS output to object
function ToObject {
    param(
     [Parameter(
          Position=0,
          Mandatory=$false,
          ValueFromPipeline=$true,
          ValueFromPipelineByPropertyName=$true)
    ]
    [Alias('Command')]
    [string]$cmd
    )

     $collection = @()
     $item = $null

     switch -regex (Invoke-Expression $cmd)
     {
          "^Record\s#\d+$"
          {
                if ($item) {$collection += $item}
                $item = New-Object System.Object
          }
          "^(?<name>\w+):\s(?<value>.*)"
          {
                if ($Matches.Name -ne "Executing")
                {
                     $item | Add-Member -Type NoteProperty -Name $Matches.Name -Value $Matches.Value
                }
          }
     }
    if ($item) {$collection += $item}
	return $collection
}

#Get Site Name
function Get-SiteName {
	'Mcli-Get Site -f SiteName' | ToObject
}

#Get List of Device Collections and convert to object
function Get-DeviceCollections {
	'Mcli-Get Collection -f CollectionName' | ToObject
}

#Connect to PVS Server
function Connect-PVS {
	[CmdletBinding()]
	param(
	[ValidateScript({Test-Connection -ComputerName $_ -Quiet -Count 1})]
	[Parameter(Mandatory=$true)]
		[string]$PVS 
	)
	
	Mcli-Run SetupConnection -p server=$PVS,port=54321
}

#Add the required snapins
function AddSnapIns {
try 
{
	Add-PSSnapin Citrix.* -ErrorAction SilentlyContinue
	Add-PSSnapIn mclipssnapin -ErrorAction SilentlyContinue
	Import-module ActiveDirectory -ErrorAction SilentlyContinue
	
}
catch {return}
}

#Get devices from each device collection
function Get-Devices {
	[CmdletBinding()]
	param(
	
		[Parameter(Mandatory=$true,
		ValueFromPipeline=$True)]
		[object]$Collection

	)
	begin {
	[string]$Site = Get-SiteName | Select SiteName -ExpandProperty SiteName
	
	
foreach ($item in $collection) {	
	[string]$z=$item.CollectionName
	'Mcli-Get Device -p CollectionName=$z,SiteName=$site -f DeviceName,CollectionName' | ToObject
		}
	}
}
