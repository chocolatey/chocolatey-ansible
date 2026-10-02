<#
    .SYNOPSIS
    Summarises ansible-test PowerShell code coverage into the GitHub Actions job summary.

    .DESCRIPTION
    Reads the Cobertura XML written by `ansible-test coverage xml` and writes the overall
    and per-file line coverage to the step summary as a Markdown table.

    Figures are counted from the individual <line> elements rather than read from the
    report's root attributes. ansible-test writes the root `lines-covered` and
    `lines-valid` attributes the wrong way round for PowerShell coverage, so anything
    reading those would report the wrong numbers.

    Only files under `plugins/` are counted. Coverage is collected for every PowerShell
    file under the collection root, which includes helper modules used by the tests
    themselves.

    ansible-test leaves a file out of the report entirely when the tests never load it,
    rather than reporting it as 0%. When -CollectionPath is given, any module or module
    util missing from the report is listed as not measured, so it can't go unnoticed.

    This only reports, and never fails the job.

    .EXAMPLE
    .\Write-CoverageSummary.ps1 -Path ./testresults/reports -Title 'Code Coverage'

    Renders the coverage found under ./testresults/reports into the job summary.

    .EXAMPLE
    .\Write-CoverageSummary.ps1 -Path ./testresults/reports -CollectionPath ./chocolatey -Title 'Code Coverage'

    As above, and also lists any module or module util that the report doesn't include.
#>
[CmdletBinding()]
param(
    # Directory to search for the Cobertura XML files produced by ansible-test.
    [Parameter(Mandatory)]
    [string]
    $Path,

    # Heading to render above the coverage table.
    [Parameter(Mandatory)]
    [string]
    $Title,

    # Root of the collection source, used to find modules and module utils that are
    # missing from the report.
    [Parameter()]
    [string]
    $CollectionPath,

    # Where to write the Markdown summary. Defaults to the GitHub Actions job summary.
    [Parameter()]
    [string]
    $SummaryPath = $env:GITHUB_STEP_SUMMARY
)

$ErrorActionPreference = 'Stop'

$reportFiles = @(
    if (Test-Path -LiteralPath $Path) {
        Get-ChildItem -Path $Path -Recurse -File -Filter '*powershell*.xml'
    }
)

$summary = [System.Collections.Generic.List[string]]::new()
$summary.Add("## $Title")

if ($reportFiles.Count -eq 0) {
    $summary.Add('')
    $summary.Add("No PowerShell coverage reports were found under ``$Path``.")

    if ($SummaryPath) {
        $summary | Add-Content -Path $SummaryPath
    }

    Write-Warning "No PowerShell coverage reports were found under '$Path'."
    return
}

# Keyed by file, then line number, holding the hit count. Merging by line means a file
# that appears in more than one report is still only counted once.
$coverage = @{}

foreach ($file in $reportFiles) {
    foreach ($class in ([xml](Get-Content -Path $file.FullName -Raw)).SelectNodes('//class')) {
        $fileName = $class.filename -replace '\\', '/'

        if (-not $fileName.StartsWith('plugins/')) {
            continue
        }

        if (-not $coverage.ContainsKey($fileName)) {
            $coverage[$fileName] = @{}
        }

        foreach ($line in $class.SelectNodes('lines/line')) {
            $coverage[$fileName][$line.number] += [int]$line.hits
        }
    }
}

function Format-Percent([int] $Covered, [int] $Total) {
    if ($Total -eq 0) {
        return 'n/a'
    }

    '{0:0.0}%' -f ($Covered / $Total * 100)
}

$rows = foreach ($fileName in $coverage.Keys | Sort-Object) {
    $lines = $coverage[$fileName].Values

    [PSCustomObject]@{
        File    = $fileName
        Lines   = $lines.Count
        Covered = @($lines | Where-Object { $_ -gt 0 }).Count
    }
}

$totalLines = [int]($rows | Measure-Object -Property Lines -Sum).Sum
$totalCovered = [int]($rows | Measure-Object -Property Covered -Sum).Sum

$notMeasured = @(
    if ($CollectionPath) {
        $pluginsPath = Join-Path -Path $CollectionPath -ChildPath 'plugins'

        Get-ChildItem -Path "$pluginsPath/modules/*.ps1", "$pluginsPath/module_utils/*.psm1" -File |
            ForEach-Object { "plugins/$($_.Directory.Name)/$($_.Name)" } |
            Where-Object { -not $coverage.ContainsKey($_) } |
            Sort-Object
    }
)

$summary.Add('')
$summary.Add("**$(Format-Percent $totalCovered $totalLines)** line coverage &mdash; $totalCovered of $totalLines lines in $(@($rows).Count) files.")

if ($notMeasured.Count -gt 0) {
    $fileList = ($notMeasured | ForEach-Object { "``$_``" }) -join ', '

    $summary.Add('')
    $summary.Add(":warning: $($notMeasured.Count) file(s) were never loaded by the tests, and so are not included in the figures above: $fileList.")
}

$summary.Add('')
$summary.Add('| File | Lines | Covered | Missed | Coverage |')
$summary.Add('| --- | ---: | ---: | ---: | ---: |')

foreach ($row in $rows) {
    $summary.Add("| ``$($row.File)`` | $($row.Lines) | $($row.Covered) | $($row.Lines - $row.Covered) | $(Format-Percent $row.Covered $row.Lines) |")
}

$summary | ForEach-Object { Write-Host $_ }

if ($SummaryPath) {
    $summary | Add-Content -Path $SummaryPath
}
