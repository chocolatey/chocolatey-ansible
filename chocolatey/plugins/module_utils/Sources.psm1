#Requires -Module Ansible.ModuleUtils.ArgvParser
#Requires -Module Ansible.ModuleUtils.CommandUtil

#AnsibleRequires -PowerShell ..module_utils.Common

function Get-ChocolateySource {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.CommandInfo]
        $ChocoCommand
    )

    $configFolder = Split-Path -LiteralPath (Split-Path -LiteralPath $ChocoCommand.Path)
    $configPath = "$configFolder\config\chocolatey.config"

    if (-not (Test-Path -LiteralPath $configPath)) {
        $message = "Expecting Chocolatey config file to exist at '$configPath'"
        Assert-TaskFailed -Message $message
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
        $message = "Failed to parse Chocolatey config file at '$configPath': $($_.Exception.Message)"
        Assert-TaskFailed -Message $message -Exception $_
    }

    foreach ($sourceNode in $configXml.chocolatey.sources.GetEnumerator()) {
        $sourceInfo = @{
            name     = $sourceNode.id
            source   = $sourceNode.value
            disabled = [System.Convert]::ToBoolean($sourceNode.disabled)
        }

        $attributeList = @(
            @{ attribute = 'user'; type = [string]; name = 'source_username' }
            @{ attribute = 'priority'; type = [int] }
            @{ attribute = 'certificate'; type = [string] }
            @{ attribute = 'bypassProxy'; type = [bool]; name = 'bypass_proxy' }
            @{ attribute = 'selfService'; type = [bool]; name = 'self_service' }
            @{ attribute = 'adminOnly'; type = [bool]; name = 'admin_only' }
        )

        foreach ($item in $attributeList) {
            $attr = $sourceNode.Attributes.GetNamedItem($item.attribute)
            $property = if ($item.ContainsKey('name')) { $item.name } else { $item.attribute }

            $sourceInfo.$property = if ($null -ne $attr) {
                if ($item.type -eq [bool]) {
                    [bool]::Parse($attr.Value)
                }
                elseif ($item.type -eq [int]) {
                    [int]::Parse($attr.Value)
                }
                else {
                    $attr.Value
                }
            }
            else {
                $null
            }
        }

        $sourceInfo
    }
}

function New-ChocolateySource {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.CommandInfo]
        $ChocoCommand,

        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [string]
        $Source,

        [Parameter()]
        [string]
        $Username,

        [Parameter()]
        [string]
        $Password,

        [Parameter()]
        [string]
        $Certificate,

        [Parameter()]
        [string]
        $CertificatePassword,

        [Parameter()]
        [int]
        $Priority,

        [Parameter()]
        [switch]
        $BypassProxy,

        [Parameter()]
        [switch]
        $AllowSelfService,

        [Parameter()]
        [switch]
        $AdminOnly
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

        if ($AllowSelfService) {
            "--allow-self-service"
        }

        if ($AdminOnly) {
            "--admin-only"
        }

        if ($module.CheckMode) {
            "--what-if"
        }
    )


    $command = Argv-ToString -Arguments $arguments
    $result = Run-Command -Command $command

    if ($result.rc -ne 0) {
        $message = "Failed to add Chocolatey source '$Name': $($result.stderr)"
        Assert-TaskFailed -Message $message -CommandResult $result
    }

    @{
        name               = $Name
        source             = $Source
        disabled           = $false
        source_username    = $Username
        priority           = $Priority
        certificate        = $Certificate
        bypass_proxy       = $BypassProxy.IsPresent
        allow_self_service = $AllowSelfService.IsPresent
        admin_only         = $AdminOnly.IsPresent
    }
}

function Remove-ChocolateySource {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.CommandInfo]
        $ChocoCommand,

        [Parameter(Mandatory = $true)]
        [string]
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
        $message = "Failed to remove Chocolatey source '$Name': $($result.stderr)"
        Assert-TaskFailed -Message $message -CommandResult $result
    }
}
