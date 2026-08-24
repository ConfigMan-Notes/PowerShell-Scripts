function New-CmnLogEntry {
    <#
        .SYNOPSIS
            Writes log Entry that can be read by CMTrace.exe

        .DESCRIPTION
            If you set 'LogEntries' to $true, it writes log entries to a file. If the file is larger then MaxFileSize, it will rename it to
            *yyyymmdd-HHmmss.log and start a new file. You can specify if it's an (1) informational, (2) warning, or (3) error message as well.
            It will also add time zone information, so if you have machines in multiple time zones, you can convert to UTC and make sure you know exactly
            when things happened.
            
            Will write to output if you specify the WriteOutput parameter

        .PARAMETER Entry
            This is the text that is the log Entry.

        .PARAMETER Type
            Defines the type of message, 1 = Informational (default), 2 = Warning, and 3 = Error.

        .PARAMETER Component
            Specifies the Component information. This could be the name of the function or thread, or whatever you like, to further help
            identify what is being logged.

        .PARAMETER Now
            Date/time to stamp the log Entry with. Defaults to the current date/time (Get-Date) if not specified.

        .PARAMETER LogFile
            File for writing logs to. Defaults to $env:ProgramData\ConfigMan-Notes\Logs\<callerscript>.log if not specified.

        .PARAMETER LogEntries
            Write log entries to the log file. Default is $true.

        .PARAMETER MaxLogSize
            Max size for the log (default is 5MB).

        .PARAMETER MaxLogHistory
            Specifies the number of history log files to keep (default is 5).

        .PARAMETER WriteOutput
            Write Output to screen also. Default is $false

        .EXAMPLE
            New-CmnLogEntry -Entry "Machine $computerName needs a restart." -Type 2 -Component 'Installer' -LogFile $LogFile -LogEntries -MaxLogSize 10485760

            This will add a warning Entry, after expanding $computerName from the component Installer to the Logfile and roll it over if it exceeds 10MB

        .LINK
            http://configman-notes.com

        .NOTES
            Author:     Jim Parris
            Email:      Jim@ConfigMan-Notes.com
            Version:    2.0.2.2
            Created:    2016-03-22
            Updated:    2017-03-01  Added log rollover.
                        2018-10-23  Added Write-Verbose; added adjustment in TimeZone for Daylight
                                    Savings Time; corrected time format for renaming logs.
                        2022-07-01  Changed Write-Verbose to WriteOutput.
                        2024-01-10  Changed Write-Output to Write-Host to prevent errors; color
                                    coded messages.
                        2024-02-24  Cleaned up comments.
                        2026-05-26  Fixed missing $NewLogEntry hash table.
                        2026-05-30  Fixed 'kNow' typo in description.
                        2026-05-31  Added check to see if filename was renamed. Also added -ErrorAction to SilentlyContinue for this command
                        2026-06-03  Fixed Get-Date calls building TzOffset to use -Date $Now so the
                                    log entry time reflects the $Now parameter, not the current clock.
                        2026-06-29  Added dynamic default for $LogFile based on $PSCommandPath;
                                    replaced manual DST timezone math with GetUtcOffset(); fixed
                                    rollover regex to use GetFileNameWithoutExtension(); eliminated
                                    double Get-ChildItem in log cleanup; changed $WriteOutput from
                                    [Boolean] to [switch]; changed $LogEntries from [Boolean] to
                                    [switch]; removed unreachable default branch from switch statement.
                        2026-06-29  Changed $LogEntries default to $true.
                        2026-08-13  Corrected comment-based help to match current parameters/behavior
    #>

    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, HelpMessage = 'This is the text that is the log Entry.')]
        [String]$Entry,

        [Parameter(Mandatory = $false, HelpMessage = 'Defines the Type of message, 1 = Informational (default), 2 = Warning, and 3 = Error.')]
        [ValidateSet(1, 2, 3)]
        [INT32]$Type = 1,

        [Parameter(Mandatory = $true, HelpMessage = 'Specifies the Component information. This could be the name of the function or thread, or whatever you like, to further help identify what is being logged.')]
        [String]$Component,

        [Parameter(Mandatory = $false, HelpMessage = 'Date of Entry')]
        [datetime]$Now = (Get-Date),

        [Parameter(Mandatory = $false, HelpMessage = 'File for writing logs to. Defaults to $env:ProgramData\ConfigMan-Notes\Logs\<callerscript>.log if not specified.')]
        [String]$LogFile,

        [Parameter(Mandatory = $false, HelpMessage = 'Set to write log entries to the log file. Default is $true.')]
        [switch]$LogEntries = $true,

        [Parameter(Mandatory = $false, HelpMessage = 'Max size for the log (default is 5MB).')]
        [Int]$MaxLogSize = 5242880,

        [Parameter(Mandatory = $false, HelpMessage = 'Specifies the number of history log files to keep (default is 5).')]
        [Int]$MaxLogHistory = 5,

        [Parameter(Mandatory = $false, HelpMessage = 'Writes output to screen also. Default is $false')]
        [switch]$WriteOutput
    )

    if (-not $LogFile) {
        $LogFile = "$($env:ProgramData)\ConfigMan-Notes\Logs\$((Split-Path -Path $PSCommandPath -Leaf).Replace('psm1', 'log').Replace('ps1', 'log'))"
    }

    # Build splat for log entries
    $NewLogEntry = @{
        LogFile       = $LogFile
        LogEntries    = $LogEntries
        Component     = 'New-CmnLogEntry'
        MaxLogSize    = $MaxLogSize
        MaxLogHistory = $MaxLogHistory
        WriteOutput   = $WriteOutput
    }

    # Make sure directory for log exists
    $LogDir = Split-Path -Path $LogFile
    if (-not (Test-Path -Path $LogDir)) { 
        Set-CmnPath @NewLogEntry -path $LogDir
    }
    # GetUtcOffset handles DST automatically; negate because CMTrace uses positive = west of UTC
    $TzOffsetMinutes = -([System.TimeZoneInfo]::Local.GetUtcOffset($Now).TotalMinutes)
    if ($TzOffsetMinutes -ge 0) {
        $TzOffset = "$(Get-Date -Date $Now -Format 'HH:mm:ss.fff')+$TzOffsetMinutes"
    }
    else {
        $TzOffset = "$(Get-Date -Date $Now -Format 'HH:mm:ss.fff')$TzOffsetMinutes"
    }

    # Create Entry line, properly formatted
    $CmEntry = '<![LOG[{0}]LOG]!><time="{2}" date="{1}" component="{5}" context="" type="{4}" thread="{3}">' -f $Entry, (Get-Date $Now -Format 'MM-dd-yyyy'), $TzOffset, $pid, $Type, $Component

    if ($LogEntries) {
        # Now, see if we need to roll the log
        if (Test-Path $LogFile) {
            # File exists, Now to check the size
            if ((Get-Item -Path $LogFile).Length -gt $MaxLogSize) {
                # Rename file
                $BackupLog = ($LogFile -replace '\.log$', '') + "-$(Get-Date -Format 'yyyymmdd-HHmmss').log"
                $isRenamed = $false
                do {
                    Rename-Item -Path $LogFile -NewName $BackupLog -Force -ErrorAction SilentlyContinue
                    $isRenamed = Test-Path -Path $BackupLog -ErrorAction SilentlyContinue
                    if (-not $isRenamed) {
                        Start-Sleep -Seconds 5 
                    }
                } until ($isRenamed)
                $LogFileName = [IO.Path]::GetFileNameWithoutExtension($LogFile) + '*'
                $LogPath = Split-Path -Path $LogFile
                # And we remove any extra rollover logs.
                $AllLogs = Get-ChildItem -Path $LogPath -Filter $LogFileName
                $KeepLogs = ($AllLogs | Sort-Object -Property LastWriteTime -Descending | Select-Object -First $MaxLogHistory).Name
                $AllLogs | Where-Object { $_.Name -notin $KeepLogs } | Remove-Item
            } # End if
        } # End if

        # Finally, we write the Entry
        $CmEntry | Out-File $LogFile -Append -Encoding ascii
    } # End if

    # Write to screen if requested
    if ($WriteOutput) {
        switch ($Type) {
            1 {
                Write-Host $Entry -ForegroundColor Green
            }
            2 {
                Write-Host $Entry -ForegroundColor Yellow
            }
            3 {
                Write-Host $Entry -ForegroundColor Red
            }
        }
    } # End if
    # Also, we write verbose, just in case that's turned on.
    Write-Verbose $Entry
}
