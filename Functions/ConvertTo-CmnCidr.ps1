Function ConvertTo-CmnCidr {
    <#
    .SYNOPSIS 
        Converts IP address and subnet mask to a CIDR address

    .DESCRIPTION
        Converts IP address and subnet mask in put to a CIDR address.
        This function als requires New-CmnLogEntry

    .PARAMETER ipAddress
        IP Address in dotted decimal notation

    .PARAMETER subnetMask
        Subnet mask in dotted decimal notation

    .PARAMETER logFile
        File for writing logs to (default is C:\Windows\Temp\Error.log).

    .PARAMETER logEntries
        Set to $true to write to the log file. Otherwise, it will just be New-CMNLogEntry -Entry (default is $false).

    .PARAMETER maxLogSize
        Max size for the log (default is 5MB).

    .PARAMETER maxLogHistory
        Specifies the number of history log files to keep (default is 5).
    
    .EXAMPLE
        ConvertTo-CmnCidr -ipAddress 192.168.0.1 -subnetMask 255.255.240.0
        will return 192.168.0.1/20

    .LINK
        http://configman-notes.com

    .NOTES
        Author:	    Jim Parris
        Email:	    Jim@ConfigMan-Notes
        PSVer:	    2.0/3.0
        Version:    1.0.0
        Date:       2018-12-26
        Updated:    2020-07-10 Cleanup/comment
	#>
 
    [CmdletBinding(ConfirmImpact = 'Low')]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = 'IP Address in dotted decimal notation')]
        [ValidatePattern('^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$')]
        [string]$ipAddress,
        
        [Parameter(Mandatory = $true, HelpMessage = 'Subnet mask in dotted decimal notation')]
        [ValidatePattern('^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$')]
        [String]$subnetMask,

        [Parameter(Mandatory = $false, HelpMessage = 'File for writing logs to (default is C:\Windows\Temp\Error.log).')]
        [String]$logFile = 'C:\Windows\Temp\Error.log',

        [Parameter(Mandatory = $false, HelpMessage = 'Set to $true to write to the log file. Otherwise, it will just be write-verbose (default is $false).')]
        [Boolean]$logEntries = $false,

        [Parameter(Mandatory = $false, HelpMessage = 'Max size for the log (default is 5MB).')]
        [Int]$maxLogSize = 5242880,

        [Parameter(Mandatory = $false, HelpMessage = 'Specifies the number of history log files to keep (default is 5).')]
        [Int]$maxLogHistory = 5
    )

    begin {
        #Build splat for log entries
        $NewLogEntry = @{
            logFile       = $logFile;
            component     = 'ConvertTo-CmnCidr';
            logEntries    = $logEntries;
            maxLogSize    = $MaxLogSize;
            maxLogHistory = $maxLogHistory;
        }

        # Log variables
        New-CMNLogEntry -entry 'Starting Function' -type 1 @NewLogEntry
        New-CMNLogEntry -entry "ipAddress = $ipAddress" -type 1 @NewLogEntry
        New-CMNLogEntry -entry "subnetMask = $subnetMask" -type 1 @NewLogEntry
        New-CMNLogEntry -entry "logFile = $logFile" -type 1 @NewLogEntry
        New-CMNLogEntry -entry "logEntries = $logEntries" -type 1 @NewLogEntry
        New-CMNLogEntry -entry "maxLogSize = $maxLogSize" -type 1 @NewLogEntry
        New-CMNLogEntry -entry "maxLogHistory = $maxLogHistory" -type 1 @NewLogEntry
    }

    process {
        New-CMNLogEntry -entry 'Beginning process loop' -type 1 @NewLogEntry
        # Get each octet seperate
        $octets = $subnetMask -split "\." 
        $subnetInBinary = @()

        # Let's convert the octets to binary
        foreach ($octet in $octets) { 
            # Convert to binary 
            $octetInBinary = [convert]::ToString($octet, 2) 
            # Get length of binary string add leading zeros to make octet 
            $octetInBinary = ("0" * (8 - ($octetInBinary).Length) + $octetInBinary) 
            # Add to variable
            $subnetInBinary = $subnetInBinary + $octetInBinary 
        } 
        $subnetInBinary = $subnetInBinary -join "" 
        New-CMNLogEntry -Entry "Subnet = $subnetInBinary" -type 1 @NewLogEntry

        # Now, let's make sure it's a valid subnet mask
        $x = 0
        while ($subnetInBinary.Substring($x, 1) -eq '1') {
            $x++
        }
        $networkBits = $x

        # OK, now we've got all the 1's, let's make sure the rest are 0's!
        do {
            if ($subnetInBinary.Substring($x, 1) -ne '0') {
                # No good, time to alert!
                $errorMessage = "The mask $subnetMask is invalid"
                New-CMNLogEntry -entry $errorMessage -type 3 @NewLogEntry
                throw $errorMessage
            } 
            $x++ 
        } while ($x -lt 32)
    }

    End {
        # Done! Log and send back the results
        $results = "$ipAddress/$networkBits"
        New-CMNLogEntry -entry "Returning $results" -type 1 @NewLogEntry
        New-CMNLogEntry -entry 'Completing Function' -type 1 @NewLogEntry
        Return $results
    }
} #End ConvertTo-CmnCidr