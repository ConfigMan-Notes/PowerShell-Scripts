Function ConvertTo-CmnIpAddress {
    <#
    .SYNOPSIS 
        Converts binary IP address to dotted decimal notation

    .DESCRIPTION
        Converts binary IP address to dotted decimal notation
        This function also requires New-CmnLogEntry
        
    .PARAMETER ipInBinary
        IP Address in binary

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
        ConvertTo-CmnIpAddress -ipInBinary '10000100101000101110011111111100'
        Returns:
        132.162.231.252

    .LINK
        http://configman-notes.com

    .NOTES
        Author:	    Jim Parris
        Email:	    Jim@ConfigMan-Notes
        Version:    1.2.0
        Date:	    2018-12-26
        Updated:    2024-08-14 Logic fix - removed redundant variable assignment		
	#>
  
    [CmdletBinding()]

    Param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = 'IP Address (in Binary) to convert')]
        [ValidatePattern('^[01]{32}')]
        [string]$ipInBinary,

        [Parameter(Mandatory = $false, HelpMessage = 'File for writing logs to (default is C:\Windows\Temp\<ScriptName>.log).')]
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
  
        #Build splat for log entries
        $NewLogEntry = @{
            LogFile       = $logFile
            Component     = 'ConvertTo-CmnIpAddress'
            logEntries    = $logEntries
            maxLogSize    = $maxLogSize
            maxLogHistory = $maxLogHistory
        }

        # Log variables
        New-CMNLogEntry @NewLogEntry -type 1 -entry 'Starting Function'
        New-CMNLogEntry @NewLogEntry -type 1 -entry "ipInBinary    = $ipInBinary"
        New-CMNLogEntry @NewLogEntry -type 1 -entry "logFile       = $logFile"
        New-CMNLogEntry @NewLogEntry -type 1 -entry "logEntries    = $logEntries"
        New-CMNLogEntry @NewLogEntry -type 1 -entry "maxLogSize    = $maxLogSize"
        New-CMNLogEntry @NewLogEntry -type 1 -entry "maxLogHistory = $maxLogHistory"
        New-CmnLogEntry @NewLogEntry -type 1 -entry "writeOutput   = $writeOutput"
    }

    process {
        New-CMNLogEntry @NewLogEntry -type 1 -entry 'Beginning process loop'
        # Create variable to store IP address
        $ip = @()

        New-CMNLogEntry @NewLogEntry -type 1 -entry 'Looping throught to convert the numbers'
        For ($x = 1 ; $x -le 4 ; $x++) { 
            #Work out start character position 
            $StartCharNumber = ($x - 1) * 8 
            #Get octet in binary 
            $ipOctetInBinary = $ipInBinary.Substring($StartCharNumber, 8) 
            #Convert octet into decimal 
            $ipOctetInDecimal = [convert]::ToInt32($ipOctetInBinary, 2)
            New-CMNLogEntry @NewLogEntry -type 1 -entry "Octet $x ($ipOctetInBinary) = $ipOctetInDecimal"
            #Add octet to IP  
            $ip += $ipOctetInDecimal
        } 
        #Separate by . 
        $ip = $ip -join '.'
    }

    end {
        New-CmnLogEntry @NewLogEntry -type 1 -entry 'Beginning end loop'
        $obj = New-Object -TypeName PSObject -Property @{
            IPAddress = $ip
        }
        $obj.PSObject.TypeNames.Insert(0, 'Cmn.IPAddress')
        New-CMNLogEntry @NewLogEntry -type 1 -entry "Returning $obj"
        New-CmnLogEntry @NewLogEntry -type 1 -entry 'Completing Function'
        Return $obj
    }
}