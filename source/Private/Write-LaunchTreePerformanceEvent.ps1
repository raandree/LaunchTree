function Write-LaunchTreePerformanceEvent {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [PSCustomObject] $Configuration,

        [Parameter(Mandatory)]
        [ValidateSet('Startup', 'Interaction', 'WorkingSetMB')]
        [string] $Metric,

        [Parameter(Mandatory)]
        [ValidateRange(0, [double]::MaxValue)]
        [double] $Value
    )

    $contract = switch ($Metric) {
        Startup {
            @{ Threshold = 500; EventId = 1501; Unit = 'ms' }
        }
        Interaction {
            @{ Threshold = 100; EventId = 1502; Unit = 'ms' }
        }
        WorkingSetMB {
            @{ Threshold = 200; EventId = 1503; Unit = 'MB' }
        }
    }
    if ($Value -le $contract.Threshold) {
        return $false
    }

    $eventParameters = @{
        Configuration = $Configuration
        EventId       = $contract.EventId
        Level         = 'Warning'
        Operation     = 'Performance'
        Message       = '{0} measured {1:N2} {2}; budget is {3} {2}.' -f (
            $Metric,
            $Value,
            $contract.Unit,
            $contract.Threshold
        )
        ErrorCode     = "${Metric}BudgetExceeded"
    }
    Write-LaunchTreeEvent @eventParameters
}