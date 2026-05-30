$ErrorActionPreference = 'Stop'

$site = Split-Path -Parent $MyInvocation.MyCommand.Path
$indexPath = Join-Path $site 'index.html'
$cssPath = Join-Path $site 'styles.css'
$outPath = Join-Path $site 'agrevo-portal-standalone.html'

function Get-MimeType([string]$path) {
  switch ([System.IO.Path]::GetExtension($path).ToLowerInvariant()) {
    '.png' { return 'image/png' }
    '.jpg' { return 'image/jpeg' }
    '.jpeg' { return 'image/jpeg' }
    '.webp' { return 'image/webp' }
    '.gif' { return 'image/gif' }
    '.svg' { return 'image/svg+xml' }
    '.ico' { return 'image/x-icon' }
    default { return 'application/octet-stream' }
  }
}

function Get-DataUri([string]$relativePath) {
  $clean = $relativePath.Trim('"', "'")
  $abs = Join-Path $site $clean
  if (-not (Test-Path -LiteralPath $abs)) {
    return $relativePath
  }

  $mime = Get-MimeType $abs
  $bytes = [System.IO.File]::ReadAllBytes($abs)
  return 'data:' + $mime + ';base64,' + [System.Convert]::ToBase64String($bytes)
}

$html = [System.IO.File]::ReadAllText($indexPath, [System.Text.Encoding]::UTF8)
$css = [System.IO.File]::ReadAllText($cssPath, [System.Text.Encoding]::UTF8)

$css = [regex]::Replace($css, 'url\(([''"]?)(assets/[^)''"]+)\1\)', {
  param($match)
  return "url('" + (Get-DataUri $match.Groups[2].Value) + "')"
})

$html = [regex]::Replace($html, '<link rel="stylesheet" href="styles\.css"\s*/?>', "<style>`n$css`n</style>")
$html = [regex]::Replace($html, 'src="(assets/[^"]+)"', {
  param($match)
  return 'src="' + (Get-DataUri $match.Groups[1].Value) + '"'
})

$html = $html -replace '<!-- Standalone generated: .*? -->\s*', ''
$html = $html -replace '<head>', "<head>`n  <!-- Standalone generated: images and CSS are embedded for file sharing. Source: 01_portal/site/index.html -->"

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($outPath, $html, $utf8NoBom)

Get-Item -LiteralPath $outPath | Select-Object FullName, Length, LastWriteTime
