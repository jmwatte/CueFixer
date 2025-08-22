<#
.SYNOPSIS
Run heuristics engine against fixture corpus and produce a CSV report.

.OUTPUTS
CSV file `heuristic-eval.csv` in current directory.
#>
param(
    [string]$FixturesPath = '.\Tests\Fixtures',
    [string]$OutCsv = '.\heuristic-eval.csv'
)

$results = @()

$fixtures = Get-ChildItem -Path $FixturesPath -Filter *.cue -File -Recurse
foreach ($f in $fixtures) {
    $lines = Get-Content -LiteralPath $f.FullName
    $filesInFolder = Get-ChildItem -LiteralPath $f.DirectoryName -File
    $candidates = Invoke-HeuristicsEngine -CueFilePath $f.FullName -CueLines $lines -CueFolderFiles $filesInFolder -Context @{ validAudioExts = @('.mp3','.flac','.wav','.ape') }

    $results += [PSCustomObject]@{
        Fixture = $f.FullName
        Candidates = ($candidates | Measure-Object).Count
    }
}

$results | Export-Csv -Path $OutCsv -NoTypeInformation -Force
Write-Verbose "Wrote $OutCsv"





