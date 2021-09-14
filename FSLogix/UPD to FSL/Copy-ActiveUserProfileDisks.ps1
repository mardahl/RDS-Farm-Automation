<#
.SYNOPSIS
  Copies UPD files that have active users in AD and have been accessed within an adjustable timeframe.
.DESCRIPTION
	This script will take a source path containing User Profile Disks and copy them to the destination path. 
	It will filter the items to copy using Active Directory lookup and a timeframe evaluation.
	This is useful for moving to a new RDS environment, but was designed for when switching from UPD to FSLogix profile containers.
	This is to speed up the process and avoid converting stale profiles to FSLogix.
.REQUIREMENTS
  This script should be run from the file server containing the UPD's for best performance.
	Mapped drives are supported, be sure to execute in the context of the user that has mapped the drives.
	Executing user should have full access to all disks and they should not be locked by a Session Host - use sidder.exe to determine this.
.NOTES
    Version       : 1.1
    Author        : Michael Mardahl
    Twitter       : @michael_mardahl
    Blogging on   : www.msendpointmgr.com
    Creation Date : 10 May 2021
    Updated       : 15 May 2021
    Purpose/Change: Public release of script
    License       : MIT (Leave author credits)
		Ceedtis				: Some parts of this script was found on the internet and modified, it was unclear who the original author was.
    
.EXAMPLE
    Execute script from normal user state state on the fileserver containing the UPD's (After modifying the script variables to suit your needs).
    .\copy-ActiveUserProfileDisks.ps1
    
#>
#Requires -version 5.0

#region declarations
#Path containing existing User Profile Disks
$oldUPDRoot = "Y:\"

#Destination of the User Profile Disk that are determined to be active
$destinationPath = "D:\ActiveProfiles"

#Any profile that has not been accessed in this amount of time will be skipped
$maxAgeMonths = 99
#endregion declarations

#region execute
Start-Transcript -Path "$($env:TEMP)\copylog$((Get-Date).ToString("HHmmss"))."
$StopWatch = [System.Diagnostics.Stopwatch]::StartNew()

# Outputs the current HHmmss value when called. Used to prefix log and console entries
Function ThisHHmmss() {
(Get-Date).ToString("HH:mm:ss")
}

# Stop if the AD module cannot be loaded
If (!(Get-module ActiveDirectory)) {
	try{
		Import-Module ActiveDirectory -ErrorAction Stop
	} catch {
		Write-Host (ThisHHmmss) "AD PowerShell Module not found or could not be loaded" -ForegroundColor Red
		exit 1
	}
}

# Index the UPD VHDX files
$filesobj = Get-ChildItem -Path $oldUPDRoot -File -Filter UVHD-S*.vhdx | Sort Name
$toCopyArr = @()

Write-Host (ThisHHmmss) "NOTE: Skipping files older than $((get-date).AddMonths(-$maxAgeMonths))" -ForegroundColor Cyan
ForEach ($fileobj in $filesobj) {
    #Skip files that are older than the defined max age
    if(
        ($fileobj.LastWriteTime -lt $((get-date).AddMonths(-$maxAgeMonths))) -and ($fileobj.LastAccessTime -lt $((get-date).AddMonths(-$maxAgeMonths)))
    ) {
        Write-Host (ThisHHmmss) $fileobj.Name "is older than the max age - skipping." -ForegroundColor Yellow
        continue
    }

    # Obtain the SID in the filename by removing the UVHD- prefix
    $sid = ($fileobj.Basename).Substring(5)
    If 
    (
        # Only proceed with this file if there is an AD user with this SID
        (Get-ADUser -Filter { SID -eq $sid }) -ne $null
    ) {
        # Obtain Name and SAM values from the user SID
        $userinfo = Get-ADUser -Filter { SID -eq $sid } | Select Name, SamAccountName, UserPrincipalName, SID
        $name = ($userinfo.Name).ToString()
        $sam = ($userinfo.SamAccountName).ToString()
        Write-Host (ThisHHmmss) ": Found account: $name ($sam)" -ForegroundColor Green

        $toCopyArr += $fileobj
    }
    else
    {
        Write-Host (ThisHHmmss) ": Failed to find account for SID: $sid" -ForegroundColor Red
    }
}

Write-Host (ThisHHmmss) ": Found $($toCopyArr.Count) items to copy" -ForegroundColor Yellow

#Copying resulting set of UVHD files  to destination

foreach ($itemObj in $toCopyArr) {

    $sourceFile = Join-Path $oldUPDRoot $itemObj.Name
    $sid = ($itemObj.Basename).Substring(5)
    $userinfo = Get-ADUser -Filter { SID -eq $sid } | Select Name, SamAccountName, UserPrincipalName, SID
    $sam = ($userinfo.SamAccountName).ToString()

    try {
        Copy-Item -Path $sourceFile -Destination $destinationPath -Force -Verbose -ErrorAction Stop
        Write-Host (ThisHHmmss) ": Copied UPD for $sam - Filename : $sourceFile" -ForegroundColor Green
    } catch {
        Write-Host (ThisHHmmss) ": Failed to copy UPD for $sam - Filename : $sourceFile" -ForegroundColor Red
    }
}

$StopWatch.Stop()
Write-Verbose "Elapsed Time: $($StopWatch.Elapsed.TotalMinutes) Minutes" -Verbose
Stop-Transcript
#endregion execute
