# Builds the site and checks that every internal link and file reference in dist/ points to a file that exists.
# CI checks more (the HTML, notes and placeholders: site-check.yml in Melderskin/.github); this is the fast local part.
#   pwsh ./test.ps1    or    bash test.sh
Set-Location $PSScriptRoot
pwsh -NoProfile -File ./build.ps1
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$dist = (Resolve-Path dist).Path
$broken = 0; $pages = 0
foreach ($page in Get-ChildItem $dist -Recurse -Filter *.html) {
  $pages++
  $html = Get-Content -Raw $page.FullName
  foreach ($m in [regex]::Matches($html, '(?:href|src)="([^"#?]+)')) {
    $ref = $m.Groups[1].Value
    if ($ref -match '^(?:[a-z]+:|//)') { continue }  # another site, mailto:, data: ...
    $base = if ($ref.StartsWith('/')) { $dist } else { $page.DirectoryName }
    $target = Join-Path $base ([Uri]::UnescapeDataString($ref.TrimStart('/')))
    if (Test-Path $target -PathType Container) { $target = Join-Path $target 'index.html' }
    if (-not (Test-Path $target -PathType Leaf)) {
      Write-Host "broken: $([IO.Path]::GetRelativePath($dist, $page.FullName) -replace "\\", "/") -> $ref" -ForegroundColor Red
      $broken++
    }
  }
}
if (-not $pages) { Write-Host 'test: dist/ has no pages.' -ForegroundColor Red; exit 1 }
if ($broken) { Write-Host "test: $broken broken internal link(s) in $pages pages." -ForegroundColor Red; exit 1 }
Write-Host "test: $pages pages, every internal link points to a file." -ForegroundColor Green
