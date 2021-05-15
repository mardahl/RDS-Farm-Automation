<#
        .SYNOPSIS
        Adds required Network Policy to NPS server, as required my Azure MFA NPS Extention

        .DESCRIPTION
        Adds an RD Gateway CAP policy, limiting access to specific computers and users.
        The script tries to make nice output, instead of hammering you with NETSH errors.
        For debugging you would look at the data contained withing each run of the $NETSHResult variable.

        .PARAMETER Name
        Specifies the file name.
        
        .INPUTS
        None.

        .EXAMPLE
        C:\PS> extension "File" "doc"
        File.doc

        .LINK
        Online version: https://github.com/mardahl/RDS-Farm-Automation/
        
        .AUTHOR
        Michael Mardahl (iphase.dk / @michael_mardahl on twitter)
#>

###################
# Config
###################

#Add SID's of your security groups here
$machineGroupSID = "S-1-5-21-34150xxxx69-176xxxxx79-37185xxx76-xxxxx5"
$userGroupSID = "S-1-5-21-341xxxx7169-176xxxxx79-371xxx5976-xxxxx4"

###################
# Execution
###################
#Change default NPS rule #1

#Force default policies processing order to a higher value because otherwise we cant add a new primary policy with processing order 1
$defaultNPSrule = 'netsh NPS set np name = "Connections to Microsoft Routing and Remote Access server" processingorder = "4"'
#Execute NETSH 
$NETSHResult = cmd.exe /c "$defaultNPSrule"
#Check for errors
if ($NETSHResult.Length -gt 2){
    Write-Warning "Could not change processing priority for 'Connections to Microsoft Routing and Remote Access server' on $($env:COMPUTERNAME)"
} else {
    Write-Verbose "Changed Network Policy 'Connections to Microsoft Routing and Remote Access server' processing order to 4 on $($env:COMPUTERNAME)" -Verbose
}

#Change default NPS rule #2

#Force default policies processing order to a higher value because otherwise we cant add a new primary policy with processing order 1
$defaultNPSrule = 'netsh NPS set np name = "Connections to other access servers" processingorder = "5"'
#Execute NETSH 
$NETSHResult = cmd.exe /c "$defaultNPSrule"
#Check for errors
if ($NETSHResult.Length -gt 2){
    Write-Warning "Could not change processing priority for 'Connections to other access servers' on $($env:COMPUTERNAME)"
} else {
    Write-Verbose "Changed Network Policy 'Connections to other access servers' processing order to 5 on $($env:COMPUTERNAME)" -Verbose
}

#Create new NPS rule

#Build values for NETSH (very sensitive!)
#Machine Security Group (SID ONLY!)
$cond1 = 'conditionid = "0x1fb4" conditiondata = "{0}"' -f $machineGroupSID
#User security Group (SID ONLY!)
$cond2 = 'conditionid = "0x1fb5" conditiondata = "{0}"' -f $userGroupSID
#Time and day restrictions
$cond3 = 'conditionid = "0x1006" conditiondata = "0 00:00-24:00; 1 00:00-24:00; 2 00:00-24:00; 3 00:00-24:00; 4 00:00-24:00; 5 00:00-24:00; 6 00:00-24:00" '
#Ignore-User-Dialin-Properties
$proid1 = 'profileid = "0x1005" profiledata = "TRUE"'
#NP-Allow-Dial-in
$proid2 = 'profileid = "0x100f" profiledata = "TRUE"'
#NP-Authentication-Type (Configured as required for Azure MFA NPS Extention!)
$proid3 = 'profileid = "0x1009" profiledata = "0x3" profiledata = "0x9" profiledata = "0x4" profiledata = "0xa" profiledata = "0x7"'
#Framed-Protocol
$proid4 = 'profileid = "0x7" profiledata = "0x1"'
#Service-Type
$proid5 = 'profileid = "0x6" profiledata = "0x2"'
#NETSH NPS Command
$npsadd = 'netsh NPS add np name = ""RDG_CAP"" state = "ENABLE" processingorder = "1" policysource = "0"'

#Execute NETSH 
$NETSHResult = cmd.exe /c "$npsadd $cond1 $cond2 $cond3 $proid1 $proid2 $proid3 $proid4 $proid5"
#Check for errors
if ($NETSHResult.Length -gt 2){
    Write-Warning "Could not add RDS_CAP Network Policy to $($env:COMPUTERNAME)"
} else {
    Write-Verbose "Added RDS_CAP network policy to $($env:COMPUTERNAME)" -Verbose
}

Write-Verbose "Finished RDS_CAP setup on $($env:COMPUTERNAME)" -Verbose 

