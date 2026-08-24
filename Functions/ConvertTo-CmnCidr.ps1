Function ConvertTo-CmnCidr {
    <#
    .SYNOPSIS 
        Converts IP address and subnet mask to a CIDR address

    .DESCRIPTION
        Converts IP address and subnet mask to a CIDR address.
        This function also requires New-CmnLogEntry

    .PARAMETER ipAddress
        IP Address in dotted decimal notation

    .PARAMETER subnetMask
        Subnet mask in dotted decimal notation

    .PARAMETER logFile
        File for writing logs to (default is C:\Windows\Temp\<ScriptName>.log).

    .PARAMETER logEntries
        Set to $true to write to the log file. Otherwise, it will just be write-verbose (default is $false).

    .PARAMETER component
        This is a placeholder so you can use @NewLogEntry hash table in calling scripts

    .PARAMETER maxLogSize
        Max size for the log (default is 5MB).

    .PARAMETER maxLogHistory
        Specifies the number of history log files to keep (default is 5).

    .PARAMETER WriteOutput
        Write Output to screen also. Default is $false
    
    .EXAMPLE
        ConvertTo-CmnCidr -ipAddress 192.168.0.1 -subnetMask 255.255.240.0
        will return 192.168.0.1/20

    .LINK
        http://configman-notes.com

    .NOTES
        Author:   Jim Parris
        Email:    Jim@ConfigMan-Notes.com
        Version:  1.2.0
        Date:     2018-12-26
        Updated:  2024-08-14 Fixed subnet mask validation logic to prevent Index Out Of Bounds errors on boundary cases (e.g., /32).
	#>
 
    [CmdletBinding(ConfirmImpact = 'Low')]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, HelpMessage = 'IP Address in dotted decimal notation')]
        [ValidatePattern('^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$')]
        [string]$ipAddress,
        
        [Parameter(Mandatory = $true, HelpMessage = 'Subnet mask in dotted decimal notation')]
        [ValidatePattern('^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$')]
        [String]$subnetMask,

        [Parameter(Mandatory = $false, HelpMessage = 'File for writing logs to (default is C:\Windows\Temp\Dell\<ScriptName>.log).')]
        [String]$logFile,

        [Parameter(Mandatory = $false, HelpMessage = 'Set to $true to write to the log file. Otherwise, it will just be write-verbose (default is $false).')]
        [Boolean]$logEntries = $false,

        [Parameter(Mandatory = $false, HelpMessage = 'This is a placeholder so you can use @NewLogEntry hash table in calling scripts')]
        [string]$component,

        [Parameter(Mandatory = $false, HelpMessage = 'Max size for the log (default is 5MB).')]
        [Int]$maxLogSize = 5242880,

        [Parameter(Mandatory = $false, HelpMessage = 'Specifies the number of history log files to keep (default is 5).')]
        [Int]$maxLogHistory = 5,

        [Parameter(Mandatory = $false, HelpMessage = 'Writes output to screen also. Default is $false')]
        [boolean]$writeOutput = $false
    )

    begin {
        # Ensure we have log file name
        if ($null -eq $logFile -or $logFile -eq '') {
            $logPath = "$($env:WinDir)\Temp\"
            $logName = (Split-Path -Path $PSCommandPath -Leaf).Replace('ps1', 'log')
            $logFile = "$($logPath)$($logName)"
        }
 
        # Build splat for log entries
        $NewLogEntry = @{
            logFile       = $logFile
            logEntries    = $logEntries
            component     = 'ConvertTo-CmnCidr'
            maxLogSize    = $maxLogSize
            maxLogHistory = $maxLogHistory
            writeOutput   = $writeOutput
        }
		
        # Log Variables
        New-CmnLogEntry @NewLogEntry -type 1 -entry 'Starting Function'
        New-CmnLogEntry @NewLogEntry -type 1 -entry "ipaddress     = $ipaddress"
        New-CmnLogEntry @NewLogEntry -type 1 -entry "subnetmask    = $subnetMask"
        New-CmnLogEntry @NewLogEntry -type 1 -entry "logFile       = $logFile"
        New-CmnLogEntry @NewLogEntry -type 1 -entry "logEntries    = $logEntries"
        New-CmnLogEntry @NewLogEntry -type 1 -entry "maxLogSize    = $maxLogSize"
        New-CmnLogEntry @NewLogEntry -type 1 -entry "maxLogHistory = $maxLogHistory"
        New-CmnLogEntry @NewLogEntry -type 1 -entry "writeOutput   = $writeOutput"
    }

    process {
        New-CmnLogEntry @NewLogEntry -type 1 -entry 'Beginning process loop'
        # Get each octet separate
        $octets = $subnetMask -split '\.' 
        $subnetInBinary = @()

        # Let's convert the octets to binary
        foreach ($octet in $octets) { 
            # Convert to binary 
            $octetInBinary = [convert]::ToString($octet, 2) 
            # Get length of binary string add leading zeros to make octet 
            $octetInBinary = ('0' * (8 - ($octetInBinary).Length) + $octetInBinary) 
            # Add to variable
            $subnetInBinary = $subnetInBinary + $octetInBinary 
        } 
        $subnetInBinary = $subnetInBinary -join '' 
        New-CMNLogEntry @NewLogEntry -type 1 -Entry "Subnet = $subnetInBinary"

        # Now, let's make sure it's a valid subnet mask
        $x = 0
        while ($x -lt 32 -and $subnetInBinary.Substring($x, 1) -eq '1') {
            $x++
        }
        $networkBits = $x

        # OK, now we've got all the 1's, let's make sure the rest are 0's!
        while ($x -lt 32) {
            if ($subnetInBinary.Substring($x, 1) -ne '0') {
                # No good, time to alert!
                $errorMessage = "The mask $subnetMask is invalid"
                New-CMNLogEntry @NewLogEntry -type 3 -entry $errorMessage
                throw $errorMessage
            } 
            $x++ 
        }
    }

    End {
        New-CmnLogEntry @NewLogEntry -type 1 -entry 'Beginning end loop'
        # Done! Log and send back the results
        $results = "$ipAddress/$networkBits"
        $obj = New-Object -TypeName PSObject -Property @{
            CidrAddress = $results
        }
        $obj.PSObject.TypeNames.Insert(0, 'CMN.CiderAddress')
        New-CMNLogEntry @NewLogEntry -type 1 -entry "Returning $obj"
        New-CMNLogEntry @NewLogEntry -type 1 -entry 'Completing Function'
        Return $obj
    }
}
