function New-CmnLogEntry {
    <#
    .SYNOPSIS
        Writes log entry that can be read by CMTrace.exe

    .DESCRIPTION
        If you set 'logEntries' to $true, it writes log entries to a file. If the file is larger then MaxFileSize, it will rename it to
        *yyyymmdd-HHmmss.log and start a new file. You can specify if it's an (1) informational, (2) warning, or (3) error message as well.
        It will also add time zone information, so if you have machines in multiple time zones, you can convert to UTC and make sure you know
        exactly when things happened.
        
        Will always write the entry verbose for troubleshooting

    .PARAMETER entry
        This is the text that is the log entry.

    .PARAMETER type
        Defines the type of message, 1 = Informational (default), 2 = Warning, and 3 = Error.

    .PARAMETER component
        Specifies the Component information. This could be the name of the function or thread, or whatever you like, to further help identify what is being logged.

    .PARAMETER logFile
        File for writing logs to (default is C:\Windows\temp\error.log).

    .PARAMETER logEntries
        Set to $true to write to the log file. Otherwise, it will just be write-verbose (default is $false).

    .PARAMETER maxLogSize
        Max size for the log (default is 5MB).

    .PARAMETER maxLogHistory
        Specifies the number of history log files to keep (default is 5).

    .EXAMPLE
        New-CmnLogEntry -entry "Machine $computerName needs a restart." -type 2 -component 'Installer' -logFile $logFile -logEntries -MaxLogSize 10485760

        This will add a warning entry, after expanding $computerName from the compontent Installer to the logfile and roll it over if it exceeds 10MB

    .LINK
        http://configman-notes.com

    .NOTES
        Author:     James Parris
        Contact:    jim@ConfigMan-Notes.com
        Created:    2016-03-22
        Updated:    2017-03-01  Added log rollover
                    2018-10-23  Added Write-Verbose
                                Added adjustment in TimeZond for Daylight Savings Time
                                Corrected time format for renaming logs because I'm an idiot and put 3 digits in the minute field.
        PSVer:	    3.0
        Version:    2.0
    #>
    
    [CmdletBinding(ConfirmImpact = 'Low')]
    Param
    (
        [Parameter(Mandatory = $true, HelpMessage = 'This is the text that is the log entry.')]
        [String]$entry,

        [Parameter(Mandatory = $true, HelpMessage = 'Defines the type of message, 1 = Informational (default), 2 = Warning, and 3 = Error.')]
        [ValidateSet(1, 2, 3)]
        [INT32]$type,

        [Parameter(Mandatory = $true, HelpMessage = 'Specifies the Component information. This could be the name of the function or thread, or whatever you like, to further help identify what is being logged.')]
        [String]$component,

        [Parameter(Mandatory = $false, HelpMessage = 'File for writing logs to (default is C:\Windows\temp\error.log).')]
        [String]$logFile = 'C:\Windows\temp\error.log',

        [Parameter(Mandatory = $false, HelpMessage = 'Set to $true to write to the log file. Otherwise, it will just be write-verbose (default is $false).')]
        [Boolean]$logEntries = $false,

        [Parameter(Mandatory = $false, HelpMessage = 'Max size for the log (default is 5MB).')]
        [Int]$maxLogSize = 5242880,

        [Parameter(Mandatory = $false, HelpMessage = 'Specifies the number of history log files to keep (default is 5).')]
        [Int]$maxLogHistory = 5
    )

    # Get Timezone info
    $now = Get-Date
    $tzInfo = [System.TimeZoneInfo]::Local
    
    # Get Timezone Offset
    $tzOffset = $tzInfo.BaseUTcOffset.Negate().TotalMinutes
    
    # If it's daylight savings time, we need to adjust
    if ($tzInfo.IsDaylightSavingTime($now)) {
        $tzAdjust = ((($tzInfo.GetAdjustmentRules()).DaylightDelta).TotalMinutes)[0]
        $tzOffset -= $tzAdjust
    }

    # Now, to figure out the format. if the timezone adjustment is posative, we need to represent it as +###
    if ($tzOffset -ge 0) {
        $tzOffset = "$(Get-Date -Format "HH:mm:ss.fff")+$($tzOffset)"
    }
    # Otherwise, we need to represent it as -###
    else {
        $tzOffset = "$(Get-Date -Format "HH:mm:ss.fff")$tzOffset"
    }

    # Create entry line, properly formatted
    $cmEntry = "<![LOG[{0}]LOG]!><time=""{2}"" date=""{1}"" component=""{5}"" context="""" type=""{4}"" thread=""{3}"">" -f $entry, (Get-Date -Format "MM-dd-yyyy"), $tzOffset, $pid, $type, $component

    if ($PSBoundParameters['logEntries']) {
        # Now, see if we need to roll the log
        if (Test-Path $logFile) {
            # File exists, now to check the size
            if ((Get-Item -Path $logFile).Length -gt $MaxLogSize) {
                # Rename file
                $backupLog = ($logFile -replace '\.log$', '') + "-$(Get-Date -Format "yyyymmdd-HHmmss").log"
                Rename-Item -Path $logFile -NewName $backupLog -Force
                # Get filter information
                # First, we do a regex search, and just get the text before the .log and after the \
                $logFile -match '(\w*).log' | Out-Null
                # Now, we add a trailing * for the filter
                $logFileName = "$($Matches[1])*"
                # Get the path for the log so we know where to search
                $logPath = Split-Path -Path $logFile
                # And we remove any extra rollover logs.
                Get-ChildItem -Path $logPath -Filter $logFileName | Where-Object { $_.Name -notin (Get-ChildItem -Path $logPath -Filter $logFileName | Sort-Object -Property LastWriteTime -Descending | Select-Object -First $maxLogHistory).name } | Remove-Item
            }
        }
        # Finally, we write the entry
        $cmEntry | Out-File $logFile -Append -Encoding ascii
    }
    # Also, we write verbose, just incase that's turned on.
    Write-Verbose $entry
} # End New-CmnLogEntry