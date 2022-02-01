#Requires -Module Ansible.ModuleUtils.ArgvParser
#Requires -Module Ansible.ModuleUtils.CommandUtil

#AnsibleRequires -PowerShell ..module_utils.Common

function Get-ChocolateyFeature {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.CommandInfo]
        $ChocoCommand
    )

    $arguments = @(
        $ChocoCommand.Path
        "feature", "list"
        "-r"
    )

    $command = Argv-ToString -Arguments $arguments
    $result = Run-Command -Command $command

    if ($result.rc -ne 0) {
        $message = "Failed to list Chocolatey features: $($result.stderr)"
        Assert-TaskFailed -Message $message -CommandResult $result
    }

    # Build a hashtable of features where each feature name has a value of
    # either `$true` (enabled), or `$false` (disabled)
    $features = @{}
    $result.stdout -split "\r?\n" |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object {
            $name, $state, $null = $_ -split "\|"
            $features.$name = $state -eq "Enabled"
        }

    $features
}

function Set-ChocolateyFeature {
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.CommandInfo]
        $ChocoCommand,

        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [switch]
        $Enabled
    )

    $stateCommand = if ($Enabled) { "enable" } else { "disable" }
    $arguments = @(
        $ChocoCommand.Path
        "feature", $stateCommand
        "--name", $Name
    )

    $command = Argv-ToString -Arguments $arguments
    $result = Run-Command -Command $command

    if ($result.rc -ne 0) {
        $message = "Failed to set Chocolatey feature $Name to $($stateCommand): $($result.stderr)"
        Assert-TaskFailed -Message $message -CommandResult $result
    }
}
