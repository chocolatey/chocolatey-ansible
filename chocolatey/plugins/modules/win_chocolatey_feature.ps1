#!powershell

# Copyright: (c), 2018 Ansible Project
# Copyright: (c) 2020, Chocolatey Software
# GNU General Public License v3.0+ (see LICENSE or https://www.gnu.org/licenses/gpl-3.0.txt)

#Requires -Module Ansible.ModuleUtils.CommandUtil
#AnsibleRequires -CSharpUtil Ansible.Basic

$ErrorActionPreference = "Stop"

# Documentation: https://docs.ansible.com/ansible/2.10/dev_guide/developing_modules_general_windows.html#windows-new-module-development
$spec = @{
    options = @{
        name = @{ type = "str"; required = $true }
        state = @{ type = "str"; default = "enabled"; choices = "disabled", "enabled" }
    }
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$name = $module.Params.name
$state = $module.Params.state

Function Get-ChocolateyFeatures {
    param($choco_app)

    $res = Run-Command -command "`"$($choco_app.Path)`" feature list -r"
    if ($res.rc -ne 0) {
        $module.FailJson("Failed to list Chocolatey features: $($res.stderr)")
    }
    $feature_info = @{}
    $res.stdout -split "`r`n" | Where-Object { $_ -ne "" } | ForEach-Object {
        $feature_split = $_ -split "\|"
        $feature_info."$($feature_split[0])" = $feature_split[1] -eq "Enabled"
    }

    return , $feature_info
}

Function Set-ChocolateyFeature {
    param(
        $choco_app,
        $name,
        $enabled
    )

    if ($enabled) {
        $state_string = "enable"
    }
    else {
        $state_string = "disable"
    }
    $res = Run-Command -command "`"$($choco_app.Path)`" feature $state_string --name `"$name`""
    if ($res.rc -ne 0) {
        $module.FailJson("Failed to set Chocolatey feature $name to $($state_string): $($res.stderr)")
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

$feature_info = Get-ChocolateyFeatures -choco_app $choco_app
if ($name -notin $feature_info.keys) {
    $module.FailJson("Invalid feature name '$name' specified, valid features are: $($feature_info.keys -join ', ')")
}

$expected_status = $state -eq "enabled"
$feature_status = $feature_info.$name
if ($feature_status -ne $expected_status) {
    if (-not $module.CheckMode) {
        Set-ChocolateyFeature -choco_app $choco_app -name $name -enabled $expected_status
    }

    $module.Result.changed = $true
}

$module.ExitJson()
