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
    if ($value -eq "") {
        $module.FailJson("Cannot set Chocolatey config as an empty string when state=present, use state=absent instead")
    }
    # make sure bool values are lower case
    if ($value -ceq "True" -or $value -ceq "False") {
        $value = $value.ToLower()
    }
}

Function Get-ChocolateyConfig {
    param($choco_app)

    # 'choco config list -r' does not display an easily parsable config entries
    # It contains config/sources/feature in the one command, and is in the
    # structure 'configKey = configValue | description', if the key or value
    # contains a = or |, it will make it quite hard to easily parse it,
    # compared to reading an XML file that already delimits these values
    $choco_config_path = "$(Split-Path -LiteralPath (Split-Path -LiteralPath $choco_app.Path))\config\chocolatey.config"
    if (-not (Test-Path -LiteralPath $choco_config_path)) {
        $module.FailJson("Expecting Chocolatey config file to exist at '$choco_config_path'")
    }

    try {
        [xml]$choco_config = Get-Content -LiteralPath $choco_config_path
    }
    catch {
        $module.FailJson("Failed to parse Chocolatey config file at '$choco_config_path': $($_.Exception.Message)")
    }

    $config_info = @{}
    foreach ($config in $choco_config.chocolatey.config.GetEnumerator()) {
        $config_info."$($config.key)" = $config.value
    }

    return , $config_info
}

Function Remove-ChocolateyConfig {
    param(
        $choco_app,
        $name
    )
    $command = Argv-ToString -arguments @($choco_app.Path, "config", "unset", "--name", $name)
    $res = Run-Command -command $command
    if ($res.rc -ne 0) {
        $module.FailJson("Failed to unset Chocolatey config for '$name': $($res.stderr)")
    }
}

function Set-ChocolateyConfig {
    param(
        $choco_app,
        $name,
        $value
    )
    $command = Argv-ToString -arguments @($choco_app.Path, "config", "set", "--name", $name, "--value", $value)
    $res = Run-Command -command $command
    if ($res.rc -ne 0) {
        $module.FailJson("Failed to set Chocolatey config for '$name' to '$value': $($res.stderr)")
    }
}

$choco_app = Get-Command -Name choco.exe -CommandType Application -ErrorAction SilentlyContinue
if ($null -eq $choco_app) {
    $choco_dir = $env:ChocolateyInstall
    if ($null -eq $choco_dir) {
        $choco_dir = "$env:SYSTEMDRIVE\ProgramData\Chocolatey"
    }
    $choco_app = Get-Command -Name "$choco_dir\bin\choco.exe" -CommandType Application -ErrorAction SilentlyContinue
}
if (-not $choco_app) {
    $module.FailJson("Failed to find Chocolatey installation, make sure choco.exe is in the PATH env value")
}

$config_info = Get-ChocolateyConfig -choco_app $choco_app
if ($name -notin $config_info.Keys) {
    $module.FailJson("The Chocolatey config '$name' is not an existing config value, check the spelling. Valid config names: $($config_info.Keys -join ', ')")
}

if ($module.DiffMode) {
    $module.Diff.before = $config.$name
}

if ($state -eq "absent" -and $config_info.$name -ne "") {
    if (-not $module.CheckMode) {
        Remove-ChocolateyConfig -choco_app $choco_app -name $name
    }
    $module.Result.changed = $true
    # choco.exe config set is not case sensitive, it won't make a change if the
    # value is the same but doesn't match
}
elseif ($state -eq "present" -and $config_info.$name -ne $value) {
    if (-not $module.CheckMode) {
        Set-ChocolateyConfig -choco_app $choco_app -name $name -value $value
    }
    $module.Result.changed = $true
    if ($module.DiffMode) {
        $module.Diff.after = $value
    }
}

$module.ExitJson()
