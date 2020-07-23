Function Get-CmnIpRange {
    <#
    .SYNOPSIS 

    .DESCRIPTION
        
    .PARAMETER 

    .PARAMETER logFile
        File for writing logs to (default is C:\Windows\Temp\Error.log).

    .PARAMETER logEntries
        Set to $true to write to the log file. Otherwise, it will just be write-verbose (default is $false).

    .PARAMETER maxLogSize
        Max size for the log (default is 5MB).

    .PARAMETER maxLogHistory
        Specifies the number of history log files to keep (default is 5).

    .EXAMPLE

    .LINK
        http://configman-notes.com

    .NOTES
        Author:	    Jim Parris
        Email:	    Jim@ConfigMan-Notes.com
        PSVer:	    3.0
        Version:    1.0.0		
        Date:	    yyyy-mm-dd
        Updated:		
	#>
 
    [CmdletBinding(ConfirmImpact = 'Low')]

    Param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = 'IP Subnet (using CIDR) to get range of')]
        [ValidatePattern('^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)/\d{1,2}$')]
        [String]$subnet,

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
            LogFile       = $logFile;
            Component     = 'Get-CmnIpRange';
            logEntries    = $logEntries;
            maxLogSize    = $maxLogSize;
            maxLogHistory = $maxLogHistory;
        }

        # Create a hashtable with your output info
        $returnHashTable = @{ }

        # Log variables
        New-CmnLogEntry -entry 'Starting Function' -type 1 @NewLogEntry
        New-CmnLogEntry -entry "subnet = $subnet" -type 1 @NewLogEntry
        New-CmnLogEntry -entry "logFile = $logFile" -type 1 @NewLogEntry
        New-CmnLogEntry -entry "logEntries = $logEntries" -type 1 @NewLogEntry
        New-CmnLogEntry -entry "maxLogSize = $maxLogSize" -type 1 @NewLogEntry
        New-CmnLogEntry -entry "maxLogHistory = $maxLogHistory" -type 1 @NewLogEntry
    }

    process {
        New-CmnLogEntry -entry 'Beginning process loop' -type 1 @NewLogEntry
        
        #Split IP and subnet 
        $IP = ($Subnet -split "\/")[0] 
        $SubnetBits = ($Subnet -split "\/")[1] 
        #Convert IP into binary 
        #Split IP into different octects and for each one, figure out the binary with leading zeros and add to the total 
        New-CmnLogEntry -entry "Converting $IP into binary." -type 1 @NewLogEntry
        $Octets = $IP -split "\." 
        $IPInBinary = @() 
        foreach ($Octet in $Octets) { 
            #convert to binary 
            $OctetInBinary = [convert]::ToString($Octet, 2) 
            #get length of binary string add leading zeros to make octet 
            $OctetInBinary = ("0" * (8 - ($OctetInBinary).Length) + $OctetInBinary) 
            $IPInBinary = $IPInBinary + $OctetInBinary 
            New-CmnLogEntry -entry "$Octet = $OctetInBinary" -type 1 @NewLogEntry
        } 
        $IPInBinary = $IPInBinary -join "" 
        New-CmnLogEntry -entry "$IP in binary is $IPInBinary" -type 1 @NewLogEntry
        New-CmnLogEntry -entry 'Time to get subnet value' -type 1 @NewLogEntry
        $HostBits = 32 - $SubnetBits 
        $NetworkIDInBinary = $IPInBinary.Substring(0, $SubnetBits) 
        $HostIDInBinary = $IPInBinary.Substring($SubnetBits, $HostBits)         
        $HostIDInBinary = $HostIDInBinary -replace "1", "0" 
        #Work out all the host IDs in that subnet by cycling through $i from 1 up to max $HostIDInBinary (i.e. 1s stringed up to $HostBits) 
        $iSubnet = [convert]::ToInt32($HostIDInBinary, 2)
        $iSubnetHostBinary = [convert]::toString($iSubnet, 2)
        $iSubnetInBinary = "$NetworkIDInBinary$("0" * ($HostIDInBinary.Length - $iSubnetHostBinary.Length) + $iSubnetHostBinary)"
        New-CmnLogEntry -entry "Subnet in binary is $iSubnetInBinary" -type 1 @NewLogEntry
        $imin = [convert]::ToInt32($HostIDInBinary, 2) + 1
        $iMinHostBinary = [convert]::ToString($imin, 2)
        $iMinInBinary = "$NetworkIDInBinary$("0" * ($HostIDInBinary.Length - $iMinHostBinary.Length) + $iMinHostBinary)"
        New-CmnLogEntry -entry "First Host Address in binary is $iMinInBinary" -type 1 @NewLogEntry
        $imax = [convert]::ToInt32(("1" * $HostBits), 2) - 1 
        $iMaxHostBinary = [Convert]::ToString($imax, 2)
        $iMaxInBinary = "$NetworkIDInBinary$("0" * ($HostIDInBinary.Length - $iMaxHostBinary.Length) + $iMaxHostBinary)"
        New-CmnLogEntry -entry "Last Host Address in binary is $iMaxHostBinary" -type 1 @NewLogEntry
        $iBroadcast = [convert]::ToInt32(("1" * $HostBits), 2)
        $iBroadcastHostBinary = [Convert]::ToString($iBroadcast, 2)
        $iBroadcastInBinary = "$NetworkIDInBinary$("0" * ($HostIDInBinary.Length - $iBroadcastHostBinary.Length) + $iBroadcastHostBinary)"
        New-CmnLogEntry -entry "Broadcast Address in binary is $iBroadcastInBinary" -type 1 @NewLogEntry
        $returnHashTable.Add('Subnet', (ConvertTo-CmnIpAddress -ipInBinary $iSubnetInBinary -logFIle $logFile -logEntries $logEntries -maxLogSize $maxLogSize -maxLogHistory $maxLogHistory))
        $returnHashTable.Add('Min', (ConvertTo-CmnIpAddress -ipInBinary $iMinInBinary -logFIle $logFile -logEntries $logEntries -maxLogSize $maxLogSize -maxLogHistory $maxLogHistory))
        $returnHashTable.Add('Max', (ConvertTo-CmnIpAddress -ipInBinary $iMaxInBinary -logFIle $logFile -logEntries $logEntries -maxLogSize $maxLogSize -maxLogHistory $maxLogHistory))
        $returnHashTable.Add('Broadcast', (ConvertTo-CmnIpAddress -ipInBinary $iBroadcastInBinary -logFIle $logFile -logEntries $logEntries -maxLogSize $maxLogSize -maxLogHistory $maxLogHistory))
    }

    End {
        $obj = New-Object -TypeName PSObject -Property $returnHashTable
        $obj.PSObject.TypeNames.Insert(0, 'CMN.IpRange')
        New-CmnLogEntry -entry "Returning $obj" -type 1 @NewLogEntry
        New-CmnLogEntry -entry 'Completing Function' -type 1 @NewLogEntry
        Return $obj
    }
} #End Get-CmnIpRange