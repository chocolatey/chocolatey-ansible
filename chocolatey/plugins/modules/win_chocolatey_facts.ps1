#!powershell

# Copyright: (c) 2018, Ansible Project
# Copyright: (c) 2018, Simon Baerlocher <s.baerlocher@sbaerlocher.ch>
# Copyright: (c) 2018, ITIGO AG <opensource@itigo.ch>
# Copyright: (c) 2020, Chocolatey Software
# GNU General Public License v3.0+ (see LICENSE or https://www.gnu.org/licenses/gpl-3.0.txt)

#Requires -Module Ansible.ModuleUtils.ArgvParser
#Requires -Module Ansible.ModuleUtils.CommandUtil
#AnsibleRequires -CSharpUtil Ansible.Basic

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0

# Documentation: https://docs.ansible.com/ansible/2.10/dev_guide/developing_modules_general_windows.html#windows-new-module-development
$spec = @{
    options = @{}
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

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

function Get-ChocolateyFeature {
    param($ChocoCommand)

    $command = Argv-ToString -Arguments $ChocoCommand.Path, "feature", "list", "-r"
    $result = Run-Command -Command $command

    if ($result.rc -ne 0) {
        $module.Result.stdout = $result.stdout
        $module.Result.stderr = $result.stderr
        $module.Result.rc = $result.rc
        $module.FailJson("Failed to list Chocolatey features, see stderr")
    }

    $features = @{}
    $result.stdout -split "\r?\n" |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object {
            $name, $value, $null = $_ -split "\|"
            $features.$name = $value -eq "Enabled"
        }

    $features
}

function Get-ChocolateyConfig {
    param($ChocoCommand)

    $configPath = "$(Split-Path -LiteralPath (Split-Path -LiteralPath $ChocoCommand.Path))\config\chocolatey.config"

    if (-not (Test-Path -LiteralPath $configPath)) {
        $module.FailJson("Expecting Chocolatey config file to exist at '$configPath'")
    }

    try {
        [xml]$configXml = Get-Content -LiteralPath $configPath
    }
    catch {
        $module.FailJson("Failed to parse Chocolatey config file at '$configPath': $($_.Exception.Message)")
    }

    $config = @{}

    foreach ($node in $configXml.chocolatey.config.GetEnumerator()) {
        # try to parse as a bool, then an int, fallback to string

        $value = try {
            [System.Boolean]::Parse($node.value)
        }
        catch {
            try {
                [System.Int32]::Parse($node.value)
            }
            catch {
                $node.value
            }
        }

        $config.$($node.key) = $value
    }

    $config
}

function Get-ChocolateyPackages {
    param($ChocoCommand)

    $command = Argv-ToString -Arguments $ChocoCommand.Path, "list", "--local-only", "--limit-output", "--all-versions"
    $result = Run-Command -Command $command

    if ($result.rc -ne 0) {
        $module.Result.stdout = $result.stdout
        $module.Result.stderr = $result.stderr
        $module.Result.rc = $result.rc
        $module.FailJson("Failed to list Chocolatey Packages, see stderr")
    }

    $result.stdout.Split("`r`n", [System.StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object {
        $package, $version, $null = $_ -split "\|"

        @{
            package = $package
            version = $version
        }
    }
}

function Get-ChocolateySources {
    param($ChocoCommand)

    $configPath = "$(Split-Path -LiteralPath (Split-Path -LiteralPath $ChocoCommand.Path))\config\chocolatey.config"
    if (-not (Test-Path -LiteralPath $configPath)) {
        $module.FailJson("Expecting Chocolatey config file to exist at '$configPath'")
    }

    try {
        [xml]$configXml = Get-Content -LiteralPath $configPath
    }
    catch {
        $module.FailJson("Failed to parse Chocolatey config file at '$configPath': $($_.Exception.Message)")
    }

    foreach ($sourceNode in $configXml.chocolatey.sources.GetEnumerator()) {
        $username = $sourceNode.Attributes.GetNamedItem("user")

        if ($null -ne $username) {
            $username = $username.Value
        }

        # 0.9.9.9+
        $priority = $sourceNode.Attributes.GetNamedItem("priority")

        if ($null -ne $priority) {
            $priority = [int]$priority.Value
        }

        # 0.9.10+
        $certificate = $sourceNode.Attributes.GetNamedItem("certificate")

        if ($null -ne $certificate) {
            $certificate = $certificate.Value
        }

        # 0.10.4+
        $bypassProxy = $sourceNode.Attributes.GetNamedItem("bypassProxy")

        if ($null -ne $bypassProxy) {
            $bypassProxy = [System.Convert]::ToBoolean($bypassProxy.Value)
        }

        $allowSelfService = $sourceNode.Attributes.GetNamedItem("selfService")

        if ($null -ne $allowSelfService) {
            $allowSelfService = [System.Convert]::ToBoolean($allowSelfService.Value)
        }

        # 0.10.8+
        $adminOnly = $sourceNode.Attributes.GetNamedItem("adminOnly")

        if ($null -ne $adminOnly) {
            $adminOnly = [System.Convert]::ToBoolean($adminOnly.Value)
        }

        @{
            name               = $sourceNode.id
            source             = $sourceNode.value
            disabled           = [System.Convert]::ToBoolean($sourceNode.disabled)
            source_username    = $username
            priority           = $priority
            certificate        = $certificate
            bypass_proxy       = $bypassProxy
            allow_self_service = $allowSelfService
            admin_only         = $adminOnly
        }
    }
}

$chocoCommand = Get-ChocolateyCommand

$module.Result.ansible_facts = @{
    ansible_chocolatey = @{
        config   = @{}
        feature  = @{}
        sources  = @()
        packages = @()
    }
}

$chocolateyFacts = $module.Result.ansible_facts.ansible_chocolatey
$chocolateyFacts.config = Get-ChocolateyConfig -ChocoCommand $chocoCommand
$chocolateyFacts.feature = Get-ChocolateyFeature -ChocoCommand $chocoCommand
$chocolateyFacts.sources = @(Get-ChocolateySources -ChocoCommand $chocoCommand)
$chocolateyFacts.packages = @(Get-ChocolateyPackages -ChocoCommand $chocoCommand)

# Return result
$module.ExitJson()
