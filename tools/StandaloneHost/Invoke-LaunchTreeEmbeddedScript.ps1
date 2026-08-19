<#
    .SYNOPSIS
        Bootstrap that the compiled LaunchTree host runs inside its runspace.

    .DESCRIPTION
        Binds the raw command line of the executable to the parameters the
        embedded script declares, then invokes the script. A compiled host only
        receives an argument array, and splatting an array binds by position
        only, so the parameter names have to be resolved against the script's
        own parameter block.

        The host sets LaunchTreeEmbeddedScript and LaunchTreeArgument before it
        runs this file.
#>

function ConvertTo-LaunchTreeParameterBinding {
    <#
        .SYNOPSIS
            Splits an argument array into named and positional arguments.

        .PARAMETER Script
            Specifies the script whose parameter block defines the names.

        .PARAMETER Argument
            Specifies the raw arguments the executable was started with.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Script,

        [Parameter()]
        [AllowEmptyCollection()]
        [string[]] $Argument = @()
    )

    $scriptAst = [System.Management.Automation.Language.Parser]::ParseInput(
        $Script, [ref] $null, [ref] $null
    )
    $parameterBlock = $scriptAst.ParamBlock
    if (-not $parameterBlock) {
        throw [System.InvalidOperationException]::new(
            'The embedded script declares no parameters.'
        )
    }

    $switchNames = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )
    $arrayNames = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )
    $knownNames = [System.Collections.Generic.List[string]]::new()

    foreach ($parameter in $parameterBlock.Parameters) {
        $parameterName = $parameter.Name.VariablePath.UserPath
        $knownNames.Add($parameterName)

        if ($parameter.StaticType -eq [System.Management.Automation.SwitchParameter]) {
            [void] $switchNames.Add($parameterName)
        } elseif ($parameter.StaticType.IsArray) {
            [void] $arrayNames.Add($parameterName)
        }
    }

    # CmdletBinding accepts the common parameters without declaring them.
    foreach ($commonName in @(
            [System.Management.Automation.PSCmdlet]::CommonParameters +
            [System.Management.Automation.PSCmdlet]::OptionalCommonParameters
        )) {
        $knownNames.Add($commonName)
    }
    foreach ($commonSwitch in @('Verbose', 'Debug', 'WhatIf', 'Confirm')) {
        [void] $switchNames.Add($commonSwitch)
    }

    $named = @{}
    $positional = [System.Collections.Generic.List[string]]::new()
    $index = 0

    while ($index -lt $Argument.Count) {
        $token = $Argument[$index]
        $index++

        if ($token -notmatch '^-{1,2}([A-Za-z_]\w*)(?::(.*))?$') {
            $positional.Add($token)
            continue
        }

        $requestedName = $Matches[1]
        $inlineValue = if ($Matches.Count -gt 2) { $Matches[2] } else { $null }

        $matchedNames = @(
            $knownNames | Where-Object { $_ -eq $requestedName }
        )
        if ($matchedNames.Count -eq 0) {
            $matchedNames = @(
                $knownNames | Where-Object { $_ -like "$requestedName*" }
            )
        }
        if ($matchedNames.Count -ne 1) {
            throw [System.ArgumentException]::new(
                "'-$requestedName' is not a parameter of this executable."
            )
        }

        $parameterName = $matchedNames[0]

        if ($switchNames.Contains($parameterName)) {
            $named[$parameterName] = if ($null -eq $inlineValue) {
                $true
            } else {
                $inlineValue -notin @('$false', 'false', '0')
            }

            continue
        }

        $value = if ($null -ne $inlineValue) {
            $inlineValue
        } elseif ($index -lt $Argument.Count) {
            $Argument[$index++]
        } else {
            throw [System.ArgumentException]::new(
                "'-$parameterName' expects a value."
            )
        }

        # A shell splits a list argument before the script sees it; argv does not.
        $named[$parameterName] = if ($arrayNames.Contains($parameterName)) {
            @($value -split ',')
        } else {
            $value
        }
    }

    @{
        Named      = $named
        Positional = $positional.ToArray()
    }
}

$launchTreeBinding = ConvertTo-LaunchTreeParameterBinding -Script $LaunchTreeEmbeddedScript `
    -Argument $LaunchTreeArgument
$launchTreeNamed = $launchTreeBinding.Named
$launchTreePositional = $launchTreeBinding.Positional

& ([scriptblock]::Create($LaunchTreeEmbeddedScript)) @launchTreeNamed @launchTreePositional
