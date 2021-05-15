<#
.SYNOPSIS
  Deploy FSLogix software and acces restrictins to all Session hosts in a collection automatically
.DESCRIPTION
  This script will execute on each Session host in a colection and download the latest FSLogix package from the internet.
	After installation it will configure which AD Group is enabled for FSLogix (usually a group that allso has access to the session colection it self).
	The script could be used to ensure that new collection members have the correct FSLogix baseline configuration or as part of a switchover from UPD to FSL profles.
	The member servers will be rebooted once installaton completes.
.REQUIREMENTS
  This script should be run from the primary RD Connection Broker server as an administrative user that has access to all session hosts.
  Session hosts must have internet access to download the installer, and PSRemoting must be enabled.
.NOTES
    Version       : 1.1
    Author        : Michael Mardahl
    Twitter       : @michael_mardahl
    Blogging on   : www.msendpointmgr.com
    Creation Date : 11 May 2020
    Updated       : 15 May 2021
    Purpose/Change: Public release of script
    License       : MIT (Leave author credits)
    
.EXAMPLE
    Execute script from elevated state on the Session Broker (Efter modifyring the script variables to suit your needs).
    .\Invoke-FSLogixDeployToCollection.ps1
    
#>

#Requires -version 5.0
#Requires -Module RemoteDesktop
#Requires -RunAsAdministrator

#The collection that should be set up for FSLogix
$collectionName = "FSL-Desktop"

#Get all session hosts in the colection
$rdshArray = Get-RDSessionCollection -CollectionName $collectionName  | %{Get-RDSessionHost $_.CollectionName | Select-Object SessionHost -ExpandProperty SessionHost}

#Execute on each member server
foreach ($server in $rdshArray) {
    Invoke-Command -ComputerName $server -ScriptBlock {
        Write-Verbose "Connected to $($env:COMPUTERNAME)" -Verbose

        #Which group to allow access to RDS Servers using FSL (Default is everyone)
        $AccessGroup = "DOMAIN\SecurityGroup-Users-FSLogixProfileEnabled" #set to $false for default
				
				#FSLogix Download URL
        $url = "https://aka.ms/fslogix_download"

        Push-Location $env:TEMP
        # create temp with zip extension (or Expand will complain)
        $tmp = ".\fslogix.zip"
				
        #Download if installer is missing
        if (-not (Test-Path $(Resolve-Path -Path ".\FSLOGIX"))){
            Write-Verbose "FSLogix installer missing in temp, downloading..." -Verbose
            Invoke-WebRequest -OutFile $tmp $url
            #extract to same folder 
            Write-Verbose "Extracting FSLogix from zip..." -Verbose
            $tmp | Expand-Archive -DestinationPath .\FSLOGIX -Force
        } else {
            Write-Verbose "FSLogix installer exists in temp, skipping download..." -Verbose
        }
        Write-Verbose "Installing FSLogix Agent on $($env:COMPUTERNAME) from $(Resolve-Path -Path ".\FSLOGIX\x64\Release\FSLogixAppsSetup.exe")" -Verbose
        Start-Process $(Resolve-Path -Path ".\FSLOGIX\x64\Release\FSLogixAppsSetup.exe") -ArgumentList '/install /norestart /quiet' -Wait

        Pop-Location
				
				if($AccessGroup) {
        #Restrict access group memberships
					Remove-LocalGroupMember -Group "FSLogix Profile Include List" -Member "Everyone" -Verbose
					Remove-LocalGroupMember -Group "FSLogix ODFC Include List" -Member "Everyone" -Verbose
					Add-LocalGroupMember -Group "FSLogix Profile Include List" -Member $AccessGroup -Verbose
					Add-LocalGroupMember -Group "FSLogix ODFC Include List" -Member $AccessGroup -Verbose
				}
				
        Write-Verbose "Rebooting $($env:COMPUTERNAME) in 10 seconds" -Verbose
        shutdown /r /t 010

    }
}
