param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

$ErrorActionPreference = 'Stop'

function Get-AddonVersion {
    param([string]$AddonXmlPath)

    [xml]$xml = Get-Content -LiteralPath $AddonXmlPath -Raw
    return $xml.addon.version
}

function New-ZipFromFolder {
    param(
        [string]$SourceFolder,
        [string]$DestinationZip,
        [string[]]$ExcludePatterns = @('.git', '.git/*')
    )

    $sourceParent = Split-Path -Path $SourceFolder -Parent
    $sourceName = Split-Path -Path $SourceFolder -Leaf

    if (Test-Path -LiteralPath $DestinationZip) {
        Remove-Item -LiteralPath $DestinationZip -Force
    }

    $tarArgs = @('-a', '-c', '-f', $DestinationZip)
    foreach ($pattern in $ExcludePatterns) {
        $tarArgs += @('--exclude', $pattern)
    }
    $tarArgs += @('-C', $sourceParent, $sourceName)

    & tar @tarArgs
}

$skinRoot = $RepoRoot
$repoAddonRoot = Join-Path $RepoRoot 'repository.jirapatr.thai'
$repoFeedRoot = Join-Path $RepoRoot 'repo\zips'

if (-not (Test-Path -LiteralPath $skinRoot)) {
    throw "Skin root not found: $skinRoot"
}

if (-not (Test-Path -LiteralPath $repoAddonRoot)) {
    throw "Repository addon root not found: $repoAddonRoot"
}

$skinVersion = Get-AddonVersion -AddonXmlPath (Join-Path $skinRoot 'addon.xml')
$repoVersion = Get-AddonVersion -AddonXmlPath (Join-Path $repoAddonRoot 'addon.xml')

$skinFeedDir = Join-Path $repoFeedRoot 'skin.arctic.horizon.2'
New-Item -ItemType Directory -Force -Path $skinFeedDir | Out-Null
New-Item -ItemType Directory -Force -Path $repoFeedRoot | Out-Null

$skinZip = Join-Path $skinFeedDir ("skin.arctic.horizon.2-{0}.zip" -f $skinVersion)
New-ZipFromFolder -SourceFolder $skinRoot -DestinationZip $skinZip -ExcludePatterns @(
    '.git',
    '.git/*',
    'index.html',
    'repo',
    'repo/*',
    'repository.jirapatr.thai',
    'repository.jirapatr.thai/*',
    'tools',
    'tools/*',
    '*.zip'
)

$addonsXmlPath = Join-Path $repoFeedRoot 'addons.xml'
$addonsXmlMd5Path = Join-Path $repoFeedRoot 'addons.xml.md5'

$skinAddonXml = Get-Content -LiteralPath (Join-Path $skinRoot 'addon.xml') -Raw
$addonsXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<addons>
$skinAddonXml
</addons>
"@

Set-Content -LiteralPath $addonsXmlPath -Value $addonsXml -Encoding UTF8

$md5 = [System.Security.Cryptography.MD5]::Create()
try {
    $bytes = [System.IO.File]::ReadAllBytes($addonsXmlPath)
    $hash = ($md5.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') }) -join ''
    Set-Content -LiteralPath $addonsXmlMd5Path -Value $hash -Encoding ASCII
}
finally {
    $md5.Dispose()
}

$repoZip = Join-Path $RepoRoot ("repository.jirapatr.thai-{0}.zip" -f $repoVersion)
New-ZipFromFolder -SourceFolder $repoAddonRoot -DestinationZip $repoZip

function New-IndexHtml {
    param(
        [string]$Path,
        [string]$RepoZipName,
        [string]$RepoZipRelativePath
    )

    $html = @"
<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Jirapatr Thai Repository</title>
</head>
<body>
    <a href="$RepoZipRelativePath">$RepoZipName</a>
</body>
</html>
"@

    Set-Content -LiteralPath $Path -Value $html -Encoding UTF8
}

$indexHtmlPath = Join-Path $RepoRoot 'index.html'
New-IndexHtml -Path $indexHtmlPath -RepoZipName (Split-Path -Path $repoZip -Leaf) -RepoZipRelativePath (Split-Path -Path $repoZip -Leaf)

Write-Host "Built skin zip: $skinZip"
Write-Host "Built repo feed: $addonsXmlPath"
Write-Host "Built repository zip: $repoZip"
Write-Host "Built index page: $indexHtmlPath"
