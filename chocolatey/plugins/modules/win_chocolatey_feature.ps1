#!powershell

# Copyright: (c), 2018 Ansible Project
# Copyright: (c) 2020, Chocolatey Software
# GNU General Public License v3.0+ (see LICENSE or https://www.gnu.org/licenses/gpl-3.0.txt)

#Requires -Module Ansible.ModuleUtils.ArgvParser
#Requires -Module Ansible.ModuleUtils.CommandUtil

#AnsibleRequires -CSharpUtil Ansible.Basic

#AnsibleRequires -PowerShell ..module_utils.Common
#AnsibleRequires -PowerShell ..module_utils.Features

$ErrorActionPreference = "Stop"

# Documentation: https://docs.ansible.com/ansible/2.10/dev_guide/developing_modules_general_windows.html#windows-new-module-development
$spec = @{
    options             = @{
        name  = @{ type = "str"; required = $true }
        state = @{ type = "str"; default = "enabled"; choices = "disabled", "enabled" }
    }
    supports_check_mode = $true
}

$module = New-AnsibleModule -Specifications $spec -Arguments $args

$name = $module.Params.name
$state = $module.Params.state

$chocoCommand = Get-ChocolateyCommand
$featureStates = Get-ChocolateyFeature -ChocoCommand $chocoCommand

if ($name -notin $featureStates.Keys) {
    $message = "Invalid feature name '$name' specified, valid features are: $($featureStates.Keys -join ', ')"
    Assert-TaskFailed -Message $message
}

$shouldBeEnabled = $state -eq "enabled"
$isEnabled = $featureStates.$name

if ($isEnabled -ne $shouldBeEnabled) {
    if (-not $module.CheckMode) {
        Set-ChocolateyFeature -ChocoCommand $chocoCommand -Name $name -Enabled:$shouldBeEnabled
    }

    $module.Result.changed = $true
}

$module.ExitJson()
