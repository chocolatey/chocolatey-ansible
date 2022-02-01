#!powershell

# Copyright: (c) 2018, Ansible Project
# Copyright: (c) 2020, Chocolatey Software
# GNU General Public License v3.0+ (see LICENSE or https://www.gnu.org/licenses/gpl-3.0.txt)

#Requires -Module Ansible.ModuleUtils.ArgvParser
#Requires -Module Ansible.ModuleUtils.CommandUtil
#AnsibleRequires -CSharpUtil Ansible.Basic

# Documentation: https://docs.ansible.com/ansible/2.10/dev_guide/developing_modules_general_windows.html#windows-new-module-development
$spec = @{
    options             = @{
        name                 = @{ type = "str"; required = $true }
        state                = @{ type = "str"; default = "present"; choices = "absent", "disabled", "present" }
        admin_only           = @{ type = "bool" }
        allow_self_service   = @{ type = "bool" }
        bypass_proxy         = @{ type = "bool" }
        certificate          = @{ type = "str" }
        certificate_password = @{ type = "str"; no_log = $true }
        priority             = @{ type = "int" }
        source               = @{ type = "str" }
        source_username      = @{ type = "str" }
        source_password      = @{ type = "str"; no_log = $true }
        update_password      = @{ type = "str"; default = "always"; choices = "always", "on_create" }
    }
    supports_check_mode = $true
    required_together   = @(
        # Explicit `,` prefix required to prevent the array unrolling, Ansible requires nested arrays here.
        , @( 'source_username', 'source_password' )
    )
    required_by         = @{
        'certificate_password' = 'certificate'
    }
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$name = $module.Params.name
$state = $module.Params.state

$admin_only = $module.Params.admin_only
$allow_self_service = $module.Params.allow_self_service
$bypass_proxy = $module.Params.bypass_proxy
$certificate = $module.Params.certificate
$certificate_password = $module.Params.certificate_password
$priority = $module.Params.priority
$source = $module.Params.source
$source_username = $module.Params.source_username
$source_password = $module.Params.source_password
$update_password = $module.Params.update_password

if ($module.DiffMode) {
    $module.Diff.before = @{}
    $module.Diff.after = @{}
}

function Get-ChocolateySource {
    param($ChocoCommand)

    $configFolder = Split-Path -LiteralPath (Split-Path -LiteralPath $ChocoCommand.Path)
    $configPath = "$configFolder\config\chocolatey.config"

    if (-not (Test-Path -LiteralPath $configPath)) {
        $module.FailJson("Expecting Chocolatey config file to exist at '$configPath'")
    }

    # would prefer to enumerate the existing sources with an actual API but the
    # only stable interface is choco.exe source list and that does not output
    # the sources in an easily parsable list. Using -r will split each entry by
    # | like a psv but does not quote values that have a | already in it making
    # it inadequete for our tasks. Instead we will parse the chocolatey.config
    # file and get the values from there
    try {
        [xml]$configXml = Get-Content -LiteralPath $configPath
    }
    catch {
        $module.FailJson("Failed to parse Chocolatey config file at '$configPath': $($_.Exception.Message)", $_)
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

function New-ChocolateySource {
    param(
        $ChocoCommand,
        $Name,
        $Source,
        $Username,
        $Password,
        $Certificate,
        $CertificatePassword,
        $Priority,
        [switch]$BypassProxy,
        [switch]$AllowSelfService,
        [switch]$AdminOnly
    )
    $arguments = @(
        # Add the base arguments
        $ChocoCommand.Path
        "source", "add"
        "--name", $Name
        "--source", $Source

        # Add optional arguments from user input
        if ($null -ne $Username) {
            "--user", $Username
            "--password", $Password
        }

        if ($null -ne $Certificate) {
            "--cert", $Certificate

            if ($null -ne $CertificatePassword) {
                "--certpassword", $CertificatePassword
            }
        }

        if ($null -ne $Priority) {
            "--priority", $Priority
        }
        else {
            $Priority = 0
        }

        if ($BypassProxy) {
            "--bypass-proxy"
        }
        else {
            $BypassProxy = $false
        }

        if ($AllowSelfService) {
            "--allow-self-service"
        }
        else {
            $AllowSelfService = $false
        }

        if ($AdminOnly) {
            "--admin-only"
        }
        else {
            $AdminOnly = $false
        }

        if ($module.CheckMode) {
            "--what-if"
        }
    )


    $command = Argv-ToString -Arguments $arguments
    $result = Run-Command -Command $command

    if ($result.rc -ne 0) {
        $module.Result.rc = $result.rc
        $module.Result.stdout = $result.stdout
        $module.Result.stderr = $result.stderr
        $module.FailJson("Failed to add Chocolatey source '$Name': $($result.stderr)")
    }

    @{
        name               = $Name
        source             = $Source
        disabled           = $false
        source_username    = $Username
        priority           = $Priority
        certificate        = $Certificate
        bypass_proxy       = $BypassProxy
        allow_self_service = $AllowSelfService
        admin_only         = $AdminOnly
    }
}

function Remove-ChocolateySource {
    param(
        $ChocoCommand,
        $Name
    )

    $arguments = @(
        $ChocoCommand.Path
        "source", "remove"
        "--name", $Name

        if ($module.CheckMode) {
            "--what-if"
        }
    )
    $command = Argv-ToString -Arguments $arguments
    $result = Run-Command -Command $command

    if ($result.rc -ne 0) {
        $module.FailJson("Failed to remove Chocolatey source '$Name': $($result.stderr)")
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

$targetSource = Get-ChocolateySource -ChocoCommand $ChocoCommand | Where-Object { $_.name -eq $name }

if ($module.DiffMode) {
    if ($null -ne $targetSource) {
        $before = $targetSource.Clone()
    }
    else {
        $before = @{}
    }

    $module.Diff.before = $before
}

if ($state -eq "absent" -and $null -ne $targetSource) {
    Remove-ChocolateySource -ChocoCommand $ChocoCommand -Name $name
    $module.Result.changed = $true
}
elseif ($state -in ("disabled", "present")) {
    $change = $false

    if ($null -eq $targetSource) {
        if ($null -eq $source) {
            $module.FailJson("The source option must be set when creating a new source")
        }

        $change = $true
    }
    else {
        if ($null -ne $source -and $source -ne $targetSource.source) {
            $change = $true
        }

        if ($null -ne $source_username -and $source_username -ne $targetSource.source_username) {
            $change = $true
        }

        if ($null -ne $source_password -and $update_password -eq "always") {
            $change = $true
        }

        if ($null -ne $certificate -and $certificate -ne $targetSource.certificate) {
            $change = $true
        }

        if ($null -ne $certificate_password -and $update_password -eq "always") {
            $change = $true
        }

        if ($null -ne $priority -and $priority -ne $targetSource.priority) {
            $change = $true
        }

        if ($null -ne $bypass_proxy -and $bypass_proxy -ne $targetSource.bypass_proxy) {
            $change = $true
        }

        if ($null -ne $allow_self_service -and $allow_self_service -ne $targetSource.allow_self_service) {
            $change = $true
        }

        if ($null -ne $admin_only -and $admin_only -ne $targetSource.admin_only) {
            $change = $true
        }

        if ($change) {
            Remove-ChocolateySource -ChocoCommand $chocoCommand -Name $Name
            $module.Result.changed = $true
        }
    }

    if ($change) {
        $sourceParams = @{
            ChocoCommand = $chocoCommand
            Name = $name
            Source = $source
            Username = $source_username
            Password = $source_password
            Certificate = $certificate
            CertificatePassword = $certificate_password
            Priority = $priority
            BypassProxy = $bypass_proxy
            AllowSelfService = $allow_self_service
            AdminOnly = $admin_only
        }

        $targetSource = New-ChocolateySource @sourceParams
        $module.Result.changed = $true
    }

    # enable/disable the source if necessary
    $action = $null

    if ($state -ne "disabled" -and $targetSource.disabled) {
        $action = "enable"
    }
    elseif ($state -eq "disabled" -and (-not $targetSource.disabled)) {
        $action = "disable"
    }

    if ($null -ne $action) {
        $arguments = @(
            $chocoCommand.Path
            "source", $action
            "--name", $name

            if ($module.CheckMode) {
                "--what-if"
            }
        )

        $command = Argv-ToString -Arguments $arguments
        $result = Run-Command -Command $command

        if ($result.rc -ne 0) {
            $module.FailJson("Failed to $action Chocolatey source '$name': $($result.stderr)")
        }

        $targetSource.disabled = ($action -eq "disable")
        $module.Result.changed = $true
    }

    if ($module.DiffMode) {
        $module.Diff.after = $targetSource
    }
}

# finally remove the diff if there was no change
if ($module.DiffMode -and -not $module.Result.changed) {
    $module.Diff.before = @{}
    $module.Diff.after = @{}
}

$module.ExitJson()
