$script:resourceModulePath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$script:modulesFolderPath = Join-Path -Path $script:resourceModulePath -ChildPath 'Modules'
$script:localizationModulePath = Join-Path -Path $script:modulesFolderPath -ChildPath 'xWebAdministration.Common'

Import-Module -Name (Join-Path -Path $script:localizationModulePath -ChildPath 'xWebAdministration.Common.psm1')

# Localized messages
data LocalizedData
{
    # culture="en-US"
    ConvertFrom-StringData -StringData @'
        VerboseGetTargetResult                     = Get-TargetResource has been run.
        VerboseSetTargetUpdateLogPath              = LogPath is not in the desired state and will be updated.
        VerboseSetTargetUpdateLogFlags             = LogFlags do not match and will be updated.
        VerboseSetTargetUpdateLogPeriod            = LogPeriod is not in the desired state and will be updated.
        VerboseSetTargetUpdateLogTruncateSize      = TruncateSize is not in the desired state and will be updated.
        VerboseSetTargetUpdateLoglocalTimeRollover = LoglocalTimeRollover is not in the desired state and will be updated.
        VerboseSetTargetUpdateLogFormat            = LogFormat is not in the desired state and will be updated
        VerboseSetTargetUpdateLogTargetW3C         = LogTargetW3C is not in the desired state and will be updated
        VerboseSetTargetUpdateLogCustomFields      = LogCustomFields is not in the desired state and will be updated.
        VerboseTestTargetUpdateLogCustomFields     = LogCustomFields is not in the desired state and will be updated.
        VerboseTestTargetFalseLogPath              = LogPath does match desired state.
        VerboseTestTargetFalseLogFlags             = LogFlags does not match desired state.
        VerboseTestTargetFalseLogPeriod            = LogPeriod does not match desired state.
        VerboseTestTargetFalseLogTruncateSize      = LogTruncateSize does not match desired state.
        VerboseTestTargetFalseLoglocalTimeRollover = LoglocalTimeRollover does not match desired state.
        VerboseTestTargetFalseLogFormat            = LogFormat does not match desired state.
        VerboseTestTargetFalseLogTargetW3C         = LogTargetW3C does not match desired state.
        WarningLogPeriod                           = LogTruncateSize has is an input as will overwrite this desired state.
        WarningIncorrectLogFormat                  = LogFormat is not W3C, as a result LogFlags will not be used.
'@
}

<#
    .SYNOPSIS
        This will return a hashtable of results about the given LogPath
#>
function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [String] $LogPath
    )

    Assert-Module

    $currentLogSettings = Get-WebConfiguration `
        -filter '/system.applicationHost/sites/siteDefaults/Logfile'

    Write-Verbose -Message ($LocalizedData.VerboseGetTargetResult)

    $cimLogCustomFields = @(ConvertTo-CimLogCustomFields -InputObject $currentLogSettings.logFile.customFields.Collection)

    $logFlagsArray = $null
    if ($currentLogSettings.LogExtFileFlags -is [System.String])
    {
        $logFlagsArray = [System.String[]] $currentLogSettings.LogExtFileFlags.Split(',')
    }

    return @{
        LogPath              = $currentLogSettings.directory
        LogFlags             = $logFlagsArray
        LogPeriod            = $currentLogSettings.period
        LogTruncateSize      = $currentLogSettings.truncateSize
        LoglocalTimeRollover = $currentLogSettings.localTimeRollover
        LogFormat            = $currentLogSettings.logFormat
        LogTargetW3C         = $currentLogSettings.logTargetW3C
        LogCustomFields      = $cimLogCustomFields
    }
}

<#
    .SYNOPSIS
        This will set the desired state

    .PARAMETER LogPath
        Path to the logfile

    .PARAMETER LogFlags
        Specifies flags to check
        Limited to the set: ('Date','Time','ClientIP','UserName','SiteName','ComputerName','ServerIP','Method','UriStem','UriQuery','HttpStatus','Win32Status','BytesSent','BytesRecv','TimeTaken','ServerPort','UserAgent','Cookie','Referer','ProtocolVersion','Host','HttpSubStatus')

    .PARAMETER LogPeriod
        Specifies the log period.
        Limited to the set: ('Hourly','Daily','Weekly','Monthly','MaxSize')

    .PARAMETER LogTruncateSize
        Specifies log truncate size
        Limited to the range (1048576 - 4294967295)

    .PARAMETER LoglocalTimeRollover
        Sets log local time rollover

    .PARAMETER LogFormat
        Specifies log format
        Limited to the set: ('IIS','W3C','NCSA')

    .PARAMETER LogTargetW3C
        Specifies W3C log format
        Limited to the set: ('File','ETW','File,ETW')

    .PARAMETER LogCustomField
        A CimInstance collection of what state the LogCustomField should be.

#>
function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [String] $LogPath,

        [Parameter()]
        [ValidateSet('Date','Time','ClientIP','UserName','SiteName','ComputerName','ServerIP','Method','UriStem','UriQuery','HttpStatus','Win32Status','BytesSent','BytesRecv','TimeTaken','ServerPort','UserAgent','Cookie','Referer','ProtocolVersion','Host','HttpSubStatus')]
        [String[]] $LogFlags,

        [Parameter()]
        [ValidateSet('Hourly','Daily','Weekly','Monthly','MaxSize')]
        [String] $LogPeriod,

        [Parameter()]
        [ValidateScript({
            ([ValidateRange(1048576, 4294967295)] $valueAsUInt64 = [UInt64]::Parse($_))
        })]
        [String] $LogTruncateSize,

        [Parameter()]
        [Boolean] $LoglocalTimeRollover,

        [Parameter()]
        [ValidateSet('IIS','W3C','NCSA')]
        [String] $LogFormat,

        [Parameter()]
        [ValidateSet('File','ETW','File,ETW')]
        [String] $LogTargetW3C,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $LogCustomFields
    )

        Assert-Module

        $currentLogState = Get-TargetResource -LogPath $LogPath

        # Update LogFormat if needed
        if ($PSBoundParameters.ContainsKey('LogFormat') -and `
            ($LogFormat -ne $currentLogState.LogFormat))
        {
            Write-Verbose -Message ($LocalizedData.VerboseSetTargetUpdateLogFormat)
            Set-WebConfigurationProperty '/system.applicationHost/sites/siteDefaults/logfile' `
                -Name logFormat `
                -Value $LogFormat
        }

        # Update LogPath if needed
        if ($PSBoundParameters.ContainsKey('LogPath') -and ($LogPath -ne $currentLogState.LogPath))
        {
            Write-Verbose -Message ($LocalizedData.VerboseSetTargetUpdateLogPath)
            Set-WebConfigurationProperty '/system.applicationHost/sites/siteDefaults/logfile' `
                -Name directory `
                -Value $LogPath
        }

        # Update Logflags if needed; also sets logformat to W3C
        if ($PSBoundParameters.ContainsKey('LogFlags') -and `
            (-not (Compare-LogFlags -LogFlags $LogFlags)))
        {
            Write-Verbose -Message ($LocalizedData.VerboseSetTargetUpdateLogFlags)
            Set-WebConfigurationProperty '/system.Applicationhost/Sites/SiteDefaults/logfile' `
                -Name logFormat `
                -Value 'W3C'
            Set-WebConfigurationProperty '/system.Applicationhost/Sites/SiteDefaults/logfile' `
                -Name logExtFileFlags `
                -Value ($LogFlags -join ',')
        }

        # Update Log Period if needed
        if ($PSBoundParameters.ContainsKey('LogPeriod') -and `
            ($LogPeriod -ne $currentLogState.LogPeriod))
        {
            if ($PSBoundParameters.ContainsKey('LogTruncateSize'))
                {
                    Write-Verbose -Message ($LocalizedData.WarningLogPeriod)
                }
            Write-Verbose -Message ($LocalizedData.VerboseSetTargetUpdateLogPeriod)
            Set-WebConfigurationProperty '/system.Applicationhost/Sites/SiteDefaults/logfile' `
                -Name period `
                -Value $LogPeriod
        }

        # Update LogTruncateSize if needed
        if ($PSBoundParameters.ContainsKey('LogTruncateSize') -and `
            ($LogTruncateSize -ne $currentLogState.LogTruncateSize))
        {
            Write-Verbose -Message ($LocalizedData.VerboseSetTargetUpdateLogTruncateSize)
            Set-WebConfigurationProperty '/system.Applicationhost/Sites/SiteDefaults/logfile' `
                -Name truncateSize `
                -Value $LogTruncateSize
            Set-WebConfigurationProperty '/system.Applicationhost/Sites/SiteDefaults/logfile' `
                -Name period `
                -Value 'MaxSize'
        }

        # Update LoglocalTimeRollover if needed
        if ($PSBoundParameters.ContainsKey('LoglocalTimeRollover') -and `
            ($LoglocalTimeRollover -ne `
             ([System.Convert]::ToBoolean($currentLogState.LoglocalTimeRollover))))
        {
            Write-Verbose -Message ($LocalizedData.VerboseSetTargetUpdateLoglocalTimeRollover)
            Set-WebConfigurationProperty '/system.Applicationhost/Sites/SiteDefaults/logfile' `
                -Name localTimeRollover `
                -Value $LoglocalTimeRollover
        }

        # Update LogTargetW3C if needed
        if ($PSBoundParameters.ContainsKey('LogTargetW3C') -and `
            ($LogTargetW3C -ne $currentLogState.LogTargetW3C))
        {
            Write-Verbose -Message ($LocalizedData.VerboseSetTargetUpdateLogTargetW3C)
            Set-WebConfigurationProperty '/system.applicationHost/sites/siteDefaults/logfile' `
                -Name logTargetW3C `
                -Value $LogTargetW3C
        }

         # Update LogCustomFields if neeed
    if ($PSBoundParameters.ContainsKey('LogCustomFields') -and `
         (-not (Test-LogCustomField -LogCustomField $LogCustomFields)))
    {
         Write-Verbose -Message ($LocalizedData.VerboseSetTargetUpdateLogCustomFields)

         Set-LogCustomField -LogCustomField $LogCustomFields
    }
}

<#
    .SYNOPSIS
        This tests the desired state. If the state is not correct it will return $false.
        If the state is correct it will return $true

    .PARAMETER LogPath
        Path to the logfile

    .PARAMETER LogFlags
        Specifies flags to check
        Limited to the set: ('Date','Time','ClientIP','UserName','SiteName','ComputerName','ServerIP','Method','UriStem','UriQuery','HttpStatus','Win32Status','BytesSent','BytesRecv','TimeTaken','ServerPort','UserAgent','Cookie','Referer','ProtocolVersion','Host','HttpSubStatus')

    .PARAMETER LogPeriod
        Specifies the log period.
        Limited to the set: ('Hourly','Daily','Weekly','Monthly','MaxSize')

    .PARAMETER LogTruncateSize
        Specifies log truncate size
        Limited to the range (1048576 - 4294967295)

    .PARAMETER LoglocalTimeRollover
        Sets log local time rollover

    .PARAMETER LogFormat
        Specifies log format
        Limited to the set: ('IIS','W3C','NCSA')

    .PARAMETER LogTargetW3C
        Specifies W3C log format
        Limited to the set: ('File','ETW','File,ETW')

    .PARAMETER LogCustomField
        A CimInstance collection of what state the LogCustomField should be.

#>
function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [String] $LogPath,

        [Parameter()]
        [ValidateSet('Date','Time','ClientIP','UserName','SiteName','ComputerName','ServerIP','Method','UriStem','UriQuery','HttpStatus','Win32Status','BytesSent','BytesRecv','TimeTaken','ServerPort','UserAgent','Cookie','Referer','ProtocolVersion','Host','HttpSubStatus')]
        [String[]] $LogFlags,

        [Parameter()]
        [ValidateSet('Hourly','Daily','Weekly','Monthly','MaxSize')]
        [String] $LogPeriod,

        [Parameter()]
        [ValidateScript({
            ([ValidateRange(1048576, 4294967295)] $valueAsUInt64 = [UInt64]::Parse($_))
        })]
        [String] $LogTruncateSize,

        [Parameter()]
        [Boolean] $LoglocalTimeRollover,

        [Parameter()]
        [ValidateSet('IIS','W3C','NCSA')]
        [String] $LogFormat,

        [Parameter()]
        [ValidateSet('File','ETW','File,ETW')]
        [String] $LogTargetW3C,

        [Parameter()]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $LogCustomFields
    )

        Assert-Module

        $currentLogState = Get-TargetResource -LogPath $LogPath

        # Check LogFormat
        if ($PSBoundParameters.ContainsKey('LogFormat'))
        {
            # Warn if LogFlags are passed in and Current LogFormat is not W3C
            if ($PSBoundParameters.ContainsKey('LogFlags') -and `
                $LogFormat -ne 'W3C')
            {
                Write-Verbose -Message ($LocalizedData.WarningIncorrectLogFormat)
            }

            # Warn if LogFlags are passed in and Desired LogFormat is not W3C
            if ($PSBoundParameters.ContainsKey('LogFlags') -and `
                $currentLogState.LogFormat -ne 'W3C')
            {
                Write-Verbose -Message ($LocalizedData.WarningIncorrectLogFormat)
            }

            # Check LogFormat
            if ($LogFormat -ne $currentLogState.LogFormat)
            {
                Write-Verbose -Message ($LocalizedData.VerboseTestTargetFalseLogFormat)
                return $false
            }
        }

        # Check LogFlags
        if ($PSBoundParameters.ContainsKey('LogFlags') -and `
            (-not (Compare-LogFlags -LogFlags $LogFlags)))
        {
            Write-Verbose -Message ($LocalizedData.VerboseTestTargetFalseLogFlags)
            return $false
        }

        # Check LogPath
        if ($PSBoundParameters.ContainsKey('LogPath') -and `
            ($LogPath -ne $currentLogState.LogPath))
        {
            Write-Verbose -Message ($LocalizedData.VerboseTestTargetFalseLogPath)
            return $false
        }

        # Check LogPeriod
        if ($PSBoundParameters.ContainsKey('LogPeriod') -and `
            ($LogPeriod -ne $currentLogState.LogPeriod))
        {
            if ($PSBoundParameters.ContainsKey('LogTruncateSize'))
            {
                Write-Verbose -Message ($LocalizedData.WarningLogPeriod)
            }

            Write-Verbose -Message ($LocalizedData.VerboseTestTargetFalseLogPeriod)
            return $false
        }

        # Check LogTruncateSize
        if ($PSBoundParameters.ContainsKey('LogTruncateSize') -and `
            ($LogTruncateSize -ne $currentLogState.LogTruncateSize))
        {
            Write-Verbose -Message ($LocalizedData.VerboseTestTargetFalseLogTruncateSize)
            return $false
        }

        # Check LoglocalTimeRollover
        if ($PSBoundParameters.ContainsKey('LoglocalTimeRollover') -and `
            ($LoglocalTimeRollover -ne `
             ([System.Convert]::ToBoolean($currentLogState.LoglocalTimeRollover))))
        {
            Write-Verbose -Message ($LocalizedData.VerboseTestTargetFalseLoglocalTimeRollover)
            return $false
        }

        # Check LogTargetW3C
        if ($PSBoundParameters.ContainsKey('LogTargetW3C') -and `
            ($LogTargetW3C -ne $currentLogState.LogTargetW3C))
        {
            Write-Verbose -Message ($LocalizedData.VerboseTestTargetFalseLogTargetW3C)
            return $false
        }

         # Check LogCustomFields if neeed
        if ($PSBoundParameters.ContainsKey('LogCustomFields') -and `
            (-not (Test-LogCustomField -LogCustomFields $LogCustomFields)))
        {
         Write-Verbose -Message ($LocalizedData.VerboseTestTargetUpdateLogCustomFields)
         return $false
        }

        return $true

}

#region Helper functions

<#
    .SYNOPSIS
        Helper function used to validate the logflags status.
        Returns False if the loglfags do not match and true if they do

    .PARAMETER LogFlags
        Specifies flags to check
#>
function Compare-LogFlags
{
    [CmdletBinding()]
    [OutputType([Boolean])]
    param
    (
        [Parameter()]
        [ValidateSet('Date','Time','ClientIP','UserName','SiteName','ComputerName','ServerIP','Method','UriStem','UriQuery','HttpStatus','Win32Status','BytesSent','BytesRecv','TimeTaken','ServerPort','UserAgent','Cookie','Referer','ProtocolVersion','Host','HttpSubStatus')]
        [String[]] $LogFlags
    )

    $currentLogFlags = (Get-WebConfigurationProperty `
                        -Filter '/system.Applicationhost/Sites/SiteDefaults/logfile' `
                        -Name LogExtFileFlags) -split ',' | `
                        Sort-Object

    $proposedLogFlags = $LogFlags -split ',' | Sort-Object

    if (Compare-Object -ReferenceObject $currentLogFlags `
                       -DifferenceObject $proposedLogFlags)
    {
        return $false
    }

    return $true

}
<#
    .SYNOPSIS
        Converts IIS custom log field collection to instances of the MSFT_xLogCustomField CIM class.

    .PARAMETER InputObject
        Specifies input object passed in

#>
function ConvertTo-CimLogCustomFields
{
    [CmdletBinding()]

    [OutputType([Microsoft.Management.Infrastructure.CimInstance])]
     param
     (
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [AllowNull()]
        [Object[]] $InputObject
     )

    $cimClassName = 'MSFT_xLogCustomField'
    $cimNamespace = 'root/microsoft/Windows/DesiredStateConfiguration'
    $cimCollection = New-Object -TypeName 'System.Collections.ObjectModel.Collection`1[Microsoft.Management.Infrastructure.CimInstance]'

    foreach ($customField in $InputObject)
    {
        $cimProperties = @{
            LogFieldName = $customField.LogFieldName
            SourceName   = $customField.SourceName
            SourceType   = $customField.SourceType
        }

        $cimCollection += (New-CimInstance -ClassName $cimClassName `
            -Namespace $cimNamespace `
            -Property $cimProperties `
            -ClientOnly)
    }

    return $cimCollection
 }

 <#
    .SYNOPSIS
        Helper function used to set the LogCustomField for a website.

    .PARAMETER LogCustomField
        A CimInstance collection of what the LogCustomField should be.
#>
function Set-LogCustomField
{
    [CmdletBinding()]
    param
    (

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $LogCustomField
    )

    $setCustomFields = @()

    foreach ($customField in $LogCustomField)
    {
        $setCustomFields += @{
            logFieldName = $customField.LogFieldName
            sourceName   = $customField.SourceName
            sourceType   = $customField.SourceType
        }
    }

    <#
        Set-WebConfigurationProperty updates logfile.customFields.
    #>

    Set-WebConfigurationProperty -PSPath 'MACHINE/WEBROOT/APPHOST' -Filter "system.applicationHost/Sites/SiteDefaults/logFile/customFields" -Name "." -Value $setCustomFields
}

<#
    .SYNOPSIS
        Helper function used to test the LogCustomField state for a website.

    .PARAMETER LogCustomField
        A CimInstance collection of what state the LogCustomField should be.
#>
function Test-LogCustomField
{
    [CmdletBinding()]
    [OutputType([Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $LogCustomFields
    )

    $inDesiredSate = $true

    foreach ($customField in $LogCustomFields)
    {
        $filterString = "/system.Applicationhost/Sites/SiteDefaults/logFile/customFields/add[@logFieldName='{0}']" -f $customField.LogFieldName
        $presentCustomField = Get-WebConfigurationProperty -Filter $filterString -Name "."

        if ($presentCustomField)
        {
            $sourceNameMatch = $customField.SourceName -eq $presentCustomField.sourceName
            $sourceTypeMatch = $customField.SourceType -eq $presentCustomField.sourceType
            if (-not ($sourceNameMatch -and $sourceTypeMatch))
            {
                $inDesiredSate = $false
            }
        }
        else
        {
            $inDesiredSate = $false
        }
    }

    return $inDesiredSate
}

#endregion

Export-ModuleMember -function *-TargetResource
