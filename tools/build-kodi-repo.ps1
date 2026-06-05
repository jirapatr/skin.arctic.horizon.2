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
        [string]$SkinZipRelativePath,
        [string]$FeedRelativePath
    )

    $html = @"
<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Jirapatr Thai Repository</title>
    <style>
        :root {
            color-scheme: dark;
            --bg: #0d1117;
            --panel: #161b22;
            --text: #e6edf3;
            --muted: #8b949e;
            --accent: #58a6ff;
            --border: #30363d;
        }
        * { box-sizing: border-box; }
        body {
            margin: 0;
            min-height: 100vh;
            display: grid;
            place-items: center;
            background: radial-gradient(circle at top, #17324f, var(--bg) 65%);
            color: var(--text);
            font: 16px/1.5 Arial, Helvetica, sans-serif;
        }
        main {
            width: min(720px, calc(100vw - 32px));
            padding: 28px;
            background: rgba(22, 27, 34, 0.92);
            border: 1px solid var(--border);
            border-radius: 18px;
            box-shadow: 0 20px 60px rgba(0, 0, 0, 0.35);
        }
        h1 {
            margin: 0 0 8px;
            font-size: 2rem;
            line-height: 1.1;
        }
        p {
            margin: 0 0 18px;
            color: var(--muted);
        }
        .links {
            display: grid;
            gap: 12px;
        }
        a {
            display: block;
            padding: 14px 16px;
            color: var(--text);
            text-decoration: none;
            background: #0f1720;
            border: 1px solid var(--border);
            border-radius: 12px;
        }
        a:hover { border-color: var(--accent); }
        code {
            color: #c9d1d9;
            background: rgba(255,255,255,0.06);
            padding: 2px 6px;
            border-radius: 6px;
        }
        .hint {
            margin-top: 18px;
            font-size: 0.95rem;
            color: var(--muted);
        }
    </style>
</head>
<body>
    <main>
        <h1>Jirapatr Thai Repository</h1>
        <p>Use this page as the Kodi source URL, then install the repository ZIP below.</p>
        <div class="links">
            <a href="$RepoZipName">Download repository ZIP</a>
            <a href="$FeedRelativePath">Browse Kodi feed</a>
            <a href="$SkinZipRelativePath">Download skin ZIP</a>
        </div>
        <p class="hint">Kodi source URL: <code>https://jirapatr.github.io/skin.arctic.horizon.2/</code></p>
    </main>
</body>
</html>
"@

    Set-Content -LiteralPath $Path -Value $html -Encoding UTF8
}

$indexHtmlPath = Join-Path $RepoRoot 'index.html'
New-IndexHtml -Path $indexHtmlPath -RepoZipName (Split-Path -Path $repoZip -Leaf) -SkinZipRelativePath ('repo/zips/skin.arctic.horizon.2/' + (Split-Path -Path $skinZip -Leaf)) -FeedRelativePath 'repo/zips/addons.xml'

Write-Host "Built skin zip: $skinZip"
Write-Host "Built repo feed: $addonsXmlPath"
Write-Host "Built repository zip: $repoZip"
Write-Host "Built index page: $indexHtmlPath"
