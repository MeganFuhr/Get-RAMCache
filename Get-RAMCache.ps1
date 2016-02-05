param(
	[Parameter(Mandatory=$true)]
	[string[]]$toEmail,
	
	[ValidateScript({Test-Connection -ComputerName $_ -Quiet -Count 1})]
	[Parameter(Mandatory=$true)]
	[string]$PVS,
	
	[ValidateScript({Test-Connection -ComputerName $_ -Quiet -Count 1})]
	[Parameter(Mandatory=$true)]
	[string]$DDC,
	
	[Parameter(Mandatory=$true)]
	[string]$fromEmail,

	[ValidateScript({Test-Connection -ComputerName $_ -Quiet -Count 1})]
	[Parameter(Mandatory=$true)]
	[string]$SMTP
	)

begin{ 
 Import-Module .\Module\PVS_Modules.psm1

#Add Snapins
AddSnapins

#Connect to the PVS server
Connect-PVS -PVS $PVS

#Get-SiteName
[string]$Site = Get-SiteName | Select SiteName -ExpandProperty SiteName

#Get all Device Collections
$collections = Get-DeviceCollections

#Set Variables
$Out = @()
$row = @()
$threshold = 90
$domain = (Get-ADDomain | Select Name -ExpandProperty Name) + "\"

#Begin getting RAM Cache information
foreach ($collection in $collections) {
	#Convert Collection Name to string for us in MCLI-GET command
 	[string]$z = $collection.collectionName
	
	#Create table header with Device Collection Name ($z)
 	$emailbody += "<table border=3 style=width:45%>"
 	$emailbody += "<th colspan=3>$z</th>"
	$emailbody += "<tr><th>Server</th><th>Percent</th><th>Maintenance Mode</th></tr>"
	
	#Get list of target devices in current Device Collection and convert to an object
 	$devices = 'Mcli-Get Device -p CollectionName=$z,SiteName=$site -f DeviceName' | ToObject
	
	#Get the RAM Cache status of each server
 		foreach ($device in $devices) {	
			
			#Convert DeviceName object to a string	
			[string]$y=$device.deviceName
			
			#Query RAM Cache percent utilized on current server
			$b = mcli-get deviceinfo -p devicename=$y -f Status	
			
			#Select the row (4) and split the results selecting just the percentage (1) and assigning it to a variable
			[int]$c = $b[4].Split(",")[1]
		
			if ($c -ge $threshold) {
				Set-BrokerSharedDesktop -MachineName ($domain+$y) -InMaintenanceMode $true
				$status = Get-BrokerMachine -AdminAddress $DDC -MachineName ($domain+$y) | Select InMaintenanceMode -ExpandProperty InMaintenanceMode
			}
			else {
				$status = Get-BrokerMachine -AdminAddress $DDC -MachineName ($domain+$y) | Select InMaintenanceMode -ExpandProperty InMaintenanceMode
			}
			
			#Create new hash to hold desired attributes
			$row = New-Object PSObject -Property @{
       			Server = $y
        		RAMCache = ("{0:D2}" -f $c)
				Status = $status
				}
			
			#Add $row to table
			$out += $row | Select Server, RAMCache, Status
			
			$test=@()
			}#End Devices loop
		
		#Order contents of $out by descending RAM cache
		$out = $out | Sort-Object -Property RAMCache -Descending
		
		#Add each row to the table
		Foreach ($item in $Out) {
		$emailbody+="<tr><td>$($item.Server)</td><td>$($item.RAMCache)</td><td>$($item.Status)</td></tr>"
		}#End adding devices and RAM cache to table
		
	#End table
	$Out=@()
	$row = @()
	$emailbody += "</table><br>"
		
}#End Collections Loop


Send-MailMessage -To $toEmail -From $fromEmail -Subject ($Site + " RAM Cache Report") -BodyAsHtml $emailbody -SmtpServer $SMTP

}#End Begin
