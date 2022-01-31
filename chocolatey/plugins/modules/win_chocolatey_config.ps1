#!powershell

# Copyright: (c) 2018, Ansible Project
# Copyright: (c) 2020, Chocolatey Software
# GNU General Public License v3.0+ (see LICENSE or https://www.gnu.org/licenses/gpl-3.0.txt)

#Requires -Module Ansible.ModuleUtils.ArgvParser
#Requires -Module Ansible.ModuleUtils.CommandUtil
#AnsibleRequires -CSharpUtil Ansible.Basic

$ErrorActionPreference = "Stop"

# Documentation: https://docs.ansible.com/ansible/2.10/dev_guide/developing_modules_general_windows.html#windows-new-module-development

$spec = @{
    options = @{
        name = @{ type = "str"; required = $true }
        state = @{ type = "str"; default = "present"; choices = "absent", "present" }
        value = @{ type = "str" }
    }
    required_if = @(
        # Explicit prefix `,` required, Ansible wants a list of lists for `required_if`
        # Read as:
        # ,@( [if] property, [is] value, [require] other_properties, $true_if_only_one_other_is_required ) -- last option is not mandatory
        ,@( 'state', 'present', @( 'value' ) )
    )
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$name = $module.Params.name
$state = $module.Params.state
$value = $module.Params.value

if ($module.DiffMode) {
    $module.Diff.before = $null
    $module.Diff.after = $null
}

if ($state -eq "present") {
    if ([string]::IsNullOrEmpty($value)) {
        $module.FailJson("Cannot set Chocolatey config as an empty string when state=present, use state=absent instead")
    }

    # make sure bool values are lower case
    if ($value -ceq "True" -or $value -ceq "False") {
        $value = $value.ToLower()
    }
}

function Get-ChocolateyConfig {
    param($ChocoCommand)

    # `choco config list -r` does not display easily parsable config entries.
    # It contains config/sources/feature in the same output, and is in the
    # structure `configKey = configValue | description`.
    # If the key or value contains a `=` or `|`, it will make it quite hard to
    # parse it, compared to reading a well-formed XML file with the same values.
    $chocoInstall = Split-Path -LiteralPath (Split-Path -LiteralPath $ChocoCommand.Path)
    $configPath = "$chocoInstall\config\chocolatey.config"

    if (-not (Test-Path -LiteralPath $configPath)) {
        $module.FailJson("Could not find Chocolatey config file at expected path '$configPath'")
    }

    try {
        [xml]$configXml = Get-Content -LiteralPath $configPath
    }
    catch {
        $module.FailJson("Failed to parse Chocolatey config file at '$configPath': $($_.Exception.Message)")
    }

    $config = @{}

    foreach ($node in $configXml.chocolatey.config.GetEnumerator()) {
        $config[$node.key] = $node.value
    }

    $config
}

function Remove-ChocolateyConfig {
    param(
        $ChocoCommand,
        $Name
    )

    $command = Argv-ToString -Arguments @($ChocoCommand.Path, "config", "unset", "--name", $Name)
    $result = Run-Command -Command $command

    if ($result.rc -ne 0) {
        $module.FailJson("Failed to unset Chocolatey config for '$Name': $($result.stderr)")
    }
}

function Set-ChocolateyConfig {
    param(
        $ChocoCommand,
        $Name,
        $Value
    )

    $command = Argv-ToString -Arguments @($ChocoCommand.Path, "config", "set", "--name", $Name, "--value", $Value)
    $result = Run-Command -Command $command

    if ($result.rc -ne 0) {
        $module.FailJson("Failed to set Chocolatey config for '$Name' to '$Value': $($result.stderr)")
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
$config = Get-ChocolateyConfig -ChocoCommand $chocoCommand

if ($name -notin $config.Keys) {
    $module.FailJson("The Chocolatey config '$name' is not an existing config value, check the spelling. Valid config names: $($config.Keys -join ', ')")
}

if ($module.DiffMode) {
    $module.Diff.before = $config.$name
}

if ($state -eq "absent" -and $config.$name -ne "") {
    if (-not $module.CheckMode) {
        Remove-ChocolateyConfig -ChocoCommand $chocoCommand -Name $name
    }

    $module.Result.changed = $true
}
elseif ($state -eq "present" -and $config.$name -ne $value) {
    # choco.exe config set is not case sensitive, it won't make a change if the
    # value is the same but doesn't match, so we skip setting it as well in that
    # case.

    if (-not $module.CheckMode) {
        Set-ChocolateyConfig -ChocoCommand $chocoCommand -Name $name -Value $value
    }

    $module.Result.changed = $true
    if ($module.DiffMode) {
        $module.Diff.after = $value
    }
}

$module.ExitJson()
