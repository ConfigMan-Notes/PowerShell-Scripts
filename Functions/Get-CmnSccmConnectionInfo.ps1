Function Get-CmnSccmConnectionInfo {
    <#
    .SYNOPSIS
        Builds SccmConnectionInfo object for use in functions

    .DESCRIPTION
        Builds SccmConnectionInfo object for use in functions. Returns a PSObject with four properties:
            CimSession      CimSession to be used when calling functions
            NameSpace       NameSpace, also to be used when calling functions
            SCCMDBServer    SCCM Database Server Name
            SCCMDB          SCCM Database Name

    .PARAMETER SiteServer
        This is a variable containing name of the site server to connect to.
        
    .PARAMETER logFile
        File for writing logs to (default is c:\temp\eror.log).

    .PARAMETER logEntries
        Set to $true to write to the log file. Otherwise, it will just be write-verbose (default is $false).

    .PARAMETER maxLogSize
        Max size for the log (default is 5MB).

    .PARAMETER maxLogHistory
        Specifies the number of history log files to keep (default is 5).

    .EXAMPLE
        Get-CmnSccmConnectionInfo -siteServer Server1

        Returns
            SccmDbServer : server1.domain.com
            CimSession   : CimSession: server1
            NameSpace    : Root/SMS/Site_S01
            SccmDb       : CM_S01

    .LINK
        http://configman-notes.com

    .NOTES
        Author:	    Jim Parris
        Email:	    Jim@ConfigMan-Notes.com
        Date:	    2019-05-02
        Updated:    
        PSVer:	    3.0
        Version:    1.0.0		
	#>

    [CmdletBinding(ConfirmImpact = 'Low')]

    PARAM(
        [Parameter(Mandatory = $true, HelpMessage = 'This is a variable containing name of the site server to connect to.')]
        [PSObject]$siteServer,

        [Parameter(Mandatory = $false, HelpMessage = 'File for writing logs to (default is c:\temp\eror.log).')]
        [String]$logFile = 'C:\Temp\Error.log',

        [Parameter(Mandatory = $false, HelpMessage = 'Set to $true to write to the log file. Otherwise, it will just be write-verbose (default is $false).')]
        [Boolean]$logEntries = $false,

        [Parameter(Mandatory = $false, HelpMessage = 'Max size for the log (default is 5MB).')]
        [Int]$maxLogSize = 5242880,

        [Parameter(Mandatory = $false, HelpMessage = 'Specifies the number of history log files to keep (default is 5).')]
        [Int]$maxLogHistory = 5
    )

    begin {
        # Build splat for log entries
        $NewLogEntry = @{
            LogFile       = $logFile;
            Component     = 'Get-CmnSccmConnectionInfo';
            logEntries    = $logEntries;
            maxLogSize    = $maxLogSize;
            maxLogHistory = $maxLogHistory;
        }

        # Create a hashtable with your output info
        $returnHashTable = @{ }

        New-CmnLogEntry -entry 'Starting Function' -type 1 @NewLogEntry
        New-CmnLogEntry -entry "siteServer = $siteServer" -type 1 @NewLogEntry
        New-CmnLogEntry -entry "siteCode = $siteCode" -type 1 @NewLogEntry
        New-CmnLogEntry -entry "logFile = $logFile" -type 1 @NewLogEntry
        New-CmnLogEntry -entry "logEntries = $logEntries" -type 1 @NewLogEntry
        New-CmnLogEntry -entry "maxLogSize = $maxLogSize" -type 1 @NewLogEntry
        New-CmnLogEntry -entry "maxLogHistory = $maxLogHistory" -type 1 @NewLogEntry
    }

    process {
        New-CmnLogEntry -entry 'Beginning process loop' -type 1 @NewLogEntry
        try {
            # Establish new CimSession to the site server.
            $cimSession = New-CimSession -ComputerName $siteServer

            # Now, to get the siteCode. We do this in the try/catch area to handle any errors.
            $siteCode = (Get-CimInstance -CimSession $cimSession -ClassName SMS_ProviderLocation -Namespace root\SMS).SiteCode
        }
        catch {
            # We hope this never runs, but if it does, time to write out some logs.
            New-CmnLogEntry -entry "Failed to complete: $error" -type 3 @NewLogEntry
            throw "Failed to complete: $error"
        }

        # Now that we are connected, let's get the database information. First pull from the site what we need
        $DataSourceWMI = $(Get-CimInstance -Class 'SMS_SiteSystemSummarizer' -Namespace "root/sms/site_$siteCode" -CimSession $cimSession -Filter "Role = 'SMS SQL SERVER' and SiteCode = '$siteCode' and ObjectType = 1").SiteObject

        # Now, to clean it up and just get the server name
        $SccmDbServer = $DataSourceWMI -replace '.*\\\\([A-Z0-9_.]+)\\.*', '$+'

        # Finally, the database name.
        $SccmDb = $DataSourceWMI -replace ".*\\([A-Z_0-9]*?)\\$", '$+'

        # Build the returnHashTable.
        $returnHashTable.Add('CimSession', $cimSession)
        $returnHashTable.Add('NameSpace', "Root/SMS/Site_$siteCode")
        $returnHashTable.Add('SccmDbServer', $SccmDbServer)
        $returnHashTable.Add('SccmDb', $SccmDb)
    }

    End {
        New-CmnLogEntry -entry 'Completing Function' -Type 1 @NewLogEntry
        $obj = New-Object -TypeName PSObject -Property $returnHashTable
        $obj.PSObject.TypeNames.Insert(0, 'CMN.SccmConnectionInfo')
        Return $obj	
    }
} # End Get-CmnSccmConnectionInfo