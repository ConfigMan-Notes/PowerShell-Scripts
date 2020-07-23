Function ConvertTo-CmnIpAddress {
    <#
    .SYNOPSIS 
        Converts binary IP address to dotted decimal notation

    .DESCRIPTION
        Converts binary IP address to dotted decimal notation
        
    .PARAMETER ipInBinary
        IP Address in binary

    .PARAMETER logFile
        File for writing logs to (default is C:\Windows\Temp\Error.log).

    .PARAMETER logEntries
        Set to $true to write to the log file. Otherwise, it will just be write-verbose (default is $false).

    .PARAMETER maxLogSize
        Max size for the log (default is 5MB).

    .PARAMETER maxLogHistory
        Specifies the number of history log files to keep (default is 5).
        
    .EXAMPLE
        ConvertTo-CmnIpAddress -ipInBinary '10000100101000101110011111111100'
        Returns:
        132.162.231.252

    .LINK
        http://configman-notes.com

    .NOTES
        Author:	    Jim Parris
        Email:	    Jim@ConfigMan-Notes
        Date:	    2018-12-26
        PSVer:	    2.0/3.0
        Updated:    2020-07-23 Comments
        Version:    1.0.0		
	#>
 
    [CmdletBinding(ConfirmImpact = 'Low')]

    Param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = 'IP Address (in Binary) to convert')]
        [ValidatePattern('^[01]{32}')]
        [string]$ipInBinary,

        [Parameter(Mandatory = $false, HelpMessage = 'File for writing logs to (default is C:\Windows\Temp\Error.log).')]
        [String]$logFile = 'C:\Temp\Error.log',

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
            LogFile       = $logFile;
            Component     = 'ConvertTo-CmnIpAddress';
            logEntries    = $logEntries;
            maxLogSize    = $maxLogSize;
            maxLogHistory = $maxLogHistory;
        }

        # Log variables
        New-CMNLogEntry -entry 'Starting Function' -type 1 @NewLogEntry
        New-CMNLogEntry -entry "ipAddress = $ipAddress" -type 1 @NewLogEntry
        New-CMNLogEntry -entry "ipInBinary = $ipInBinary" -type 1 @NewLogEntry
        New-CMNLogEntry -entry "logFile = $logFile" -type 1 @NewLogEntry
        New-CMNLogEntry -entry "logEntries = $logEntries" -type 1 @NewLogEntry
        New-CMNLogEntry -entry "maxLogSize = $maxLogSize" -type 1 @NewLogEntry
        New-CMNLogEntry -entry "maxLogHistory = $maxLogHistory" -type 1 @NewLogEntry
    }

    process {
        New-CMNLogEntry -entry 'Beginning process loop' -type 1 @NewLogEntry
        # Create variable to store IP address
        $ip = @()

        New-CMNLogEntry -entry 'Looping throught to convert the numbers' -type 1 @NewLogEntry
        For ($x = 1 ; $x -le 4 ; $x++) { 
            #Work out start character position 
            $StartCharNumber = ($x - 1) * 8 
            #Get octet in binary 
            $ipOctetInBinary = $ipInBinary.Substring($StartCharNumber, 8) 
            #Convert octet into decimal 
            $ipOctetInDecimal = [convert]::ToInt32($ipOctetInBinary, 2)
            New-CMNLogEntry -entry "Octet $x ($ipOctetInBinary) = $ipOctetInDecimal" -type 1 @NewLogEntry
            #Add octet to IP  
            $ip += $ipOctetInDecimal
        } 
        #Separate by . 
        $ip = $ip -join "."
    }

    end {
        # Done! Log and return result
        New-CMNLogEntry -entry "Returning $ip" -type 1 @NewLogEntry
        New-CMNLogEntry -entry 'Completing Function' -Type 1 @NewLogEntry
        Return $ip
    }
} #End ConvertTo-CmnIpAddress