<#
.SYNOPSIS
  Push FSLogix Rule Sets to all Session hosts automatically

.DESCRIPTION
  This script can take a "Master" FSLogix App Masking rule set from a location that you define, and push it to all members of an RDS Farm.
  Anything not contained in the Master will be deleted.
  Can be run as a scheduled task once it has been confirmed interactively that all session hosts are enabled for remoting from the master.

.REQUIREMENTS
  This script must be run from the primary RD Connection Broker server, and be placed in 'c:\rds'
  All FSLogix App Masking rule sets must be placed in the "Master" folder 'c:\rds\FSLogix Rule Sets'

.NOTES
    Version       : 1.2
    Author        : Michael Mardahl
    Twitter       : @michael_mardahl
    Blogging on   : www.msendpointmgr.com
    Creation Date : 11 May 2020
    Updated       : 12 April 2021
    Purpose/Change: Public release of script
    License       : MIT (Leave author credits)
    
.EXAMPLE
    Execute script from elevated state on the Session Broker
    .\update-farmAppMaskingRuleSet.ps1
    
#>

#Requires -version 5.0
#Requires -Module RemoteDesktop
#Requires -RunAsAdministrator


##########################################################################################
#
# Configuration section
#
##########################################################################################
#region declarations


$Vendor = "Microsoft"
$Product = "Remote Desktop FSLogix Rule Sets Deploy"
$time = (get-date -f dd-MM-yy-hhmm).ToString()
$LogPath = "c:\rds\$Vendor $Product $Version $time.log"

## don't change below ##
$StopWatch = [System.Diagnostics.Stopwatch]::StartNew()
try {
$fixTranscriptCrash = Stop-Transcript -ErrorAction SilentlyContinue | Out-Null
} catch {}
try {Start-Transcript $LogPath -Force -ErrorAction Stop} catch {write-error $_;exit 1}

#endregion declarations
##########################################################################################
#
#region Functions section
#
##########################################################################################
#region functions
Push-Location c:\rds

function Test-PsRemoting {
    ### TEST PS REMOTING
    #http://www.leeholmes.com/blog/2009/11/20/testing-for-powershell-remoting-test-psremoting/
    param(
        [Parameter(Mandatory = $true)]
        $computername
    )
   
    try
    {
        $errorActionPreference = "Stop"
        $result = Invoke-Command -ComputerName $computername { 1 }
    }
    catch
    {
        Write-Verbose $_
        return $false
    }
   
    ## I've never seen this happen, but if you want to be
    ## thorough....
    if($result -ne 1)
    {
        Write-Verbose "Remoting to $computerName returned an unexpected result."
        return $false
    }
    return $true   
} #end Test-PsRemoting

#endregion functions
####################################################################################################################################################################################
#
# Execute section
#
####################################################################################################################################################################################
#region execute

###########################################################################################
#
# Testing section
#
###########################################################################################
#region testing

#Importing RDS PS Module
Import-Module RemoteDesktop

#Build Session Host array
$rdshArray = Get-RDSessionCollection | %{Get-RDSessionHost $_.CollectionName | Select-Object SessionHost -ExpandProperty SessionHost}

#region Testing Servers PS remoting capabilities
Write-Verbose "Testing PSRemoting access on all servers..." -Verbose
$statusOK = $true

foreach($TestMulti in $rdshArray){
    $status = Test-PsRemoting -computername $TestMulti
    "$TestMulti;$status"
    if(-not ($status)) {
        $statusOK = $false
    }
}
    
if (-not ($statusOK)){
    Write-Host "PSRemoting test failed on one or more servers! Check the list above for ones that say 'false'." -ForegroundColor Red
    Stop-Transcript
    exit 1
} else {
    Write-Host "PSRemoting test completed with success!" -ForegroundColor Green
}


#endregion testing
########################################################################################################################################
#
# end testing section
#
########################################################################################################################################

Write-Verbose "Starting $Vendor $Product" -Verbose

# Import the RemoteDesktop Module
Import-Module RemoteDesktop

#Get rule files
$ruleFiles = Get-ChildItem '.\FSLogix Rule Sets'

#region fslogixrulesdeploy
foreach ($server in $rdshArray) {

    Write-Verbose "Deploying Rule Sets to $server..." -Verbose
    $destination = New-PSSession $server

    #copy rules
    foreach ($file in $ruleFiles) {
        Copy-Item "$($file.FullName)" -ToSession $destination "C:\Program Files\FSLogix\Apps\Rules\" -Force
    }

    #Cleanup deleted rules
    Write-Verbose "Remove abandoned rules..." -verbose
    Invoke-Command -Session $destination -ArgumentList $ruleFiles -ScriptBlock {
        $existingRules = Get-ChildItem  'C:\Program Files\FSLogix\Apps\Rules\'
        $newRules = $args
        foreach ($rule in $existingRules) {
            if($newRules.Name -NotContains $rule.Name) {
                Write-Verbose "$($rule.Name) is not in master Rule set - DELETING!" -Verbose
                Remove-Item $rule.FullName -Force
            }
        }
    }

    #Cleanup sessions
    Remove-PSSession $destination
    Remove-Variable $destination

    Write-Verbose "Completed deploying to $server..." -Verbose

}
#endregion fslogixrulesdeploy

$StopWatch.Stop()
Write-Verbose "Elapsed Time: $($StopWatch.Elapsed.TotalMinutes) Minutes" -Verbose
Write-Verbose "Stop logging" -Verbose
Stop-Transcript
Write-Host "Rule Set Deployment completed." -ForegroundColor Green
Pop-Location
#endregion execute
