#!powershell

# Copyright: (c), 2018 Ansible Project
# Copyright: (c) 2020, Chocolatey Software
# GNU General Public License v3.0+ (see LICENSE or https://www.gnu.org/licenses/gpl-3.0.txt)

#Requires -Module Ansible.ModuleUtils.ArgvParser
#Requires -Module Ansible.ModuleUtils.CommandUtil
#AnsibleRequires -CSharpUtil Ansible.Basic

$ErrorActionPreference = "Stop"

# Documentation: https://docs.ansible.com/ansible/2.10/dev_guide/developing_modules_general_windows.html#windows-new-module-development
$spec = @{
    options             = @{
        name  = @{ type = "str"; required = $true }
        state = @{ type = "str"; default = "enabled"; choices = "disabled", "enabled" }
    }
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$name = $module.Params.name
$state = $module.Params.state

function Get-ChocolateyFeature {
    param($ChocoCommand)

    $arguments = @(
        $ChocoCommand.Path
        "feature", "list"
        "-r"
    )

    $command = Argv-ToString -Arguments $arguments
    $result = Run-Command -Command $command

    if ($result.rc -ne 0) {
        $module.FailJson("Failed to list Chocolatey features: $($result.stderr)")
    }

    # Build a hashtable of features where each feature name has a value of `$true` (enabled), or `$false` (disabled)
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
        $ChocoCommand,
        $Name,
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
        $module.FailJson("Failed to set Chocolatey feature $Name to $($stateCommand): $($result.stderr)")
    }
}

function Get-ChocolateyCommand {
    $command = Get-Command -Name choco.exe -CommandType Application -ErrorAction SilentlyContinue

    if (-not $command) {
        $installDir = if ($env:ChocolateyInstall) {
            $env:ChocolateyInstall
        }
        else {
            "$env:SYSTEMDRIVE\ProgramData\Chocolatey"
        }

        $command = Get-Command -Name "$installDir\bin\choco.exe" -CommandType Application -ErrorAction SilentlyContinue

        if (-not $command) {
            $module.FailJson("Failed to find Chocolatey installation, make sure choco.exe is in the PATH env value")
        }
    }

    $command
}

$chocoCommand = Get-ChocolateyCommand
$featureStates = Get-ChocolateyFeature -ChocoCommand $chocoCommand

if ($name -notin $featureStates.Keys) {
    $module.FailJson("Invalid feature name '$name' specified, valid features are: $($featureStates.Keys -join ', ')")
}

$shouldBeEnabled = $state -eq "enabled"
$isEnabled = $featureStates.$name

if ($isEnabled -ne $shouldBeEnabled) {
    if (-not $module.CheckMode) {
        Set-ChocolateyFeature -ChocoCommand $chocoCommand -Name $name -Enabled $shouldBeEnabled
    }

    $module.Result.changed = $true
}

$module.ExitJson()
