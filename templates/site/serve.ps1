# Serves dist/ on http://localhost:8080 for local preview. Stop with Ctrl+C.
param([int]$Port = 8080)
$dist = Join-Path $PSScriptRoot 'dist'
$types = @{ '.html' = 'text/html; charset=utf-8'; '.css' = 'text/css'; '.js' = 'text/javascript'; '.svg' = 'image/svg+xml'; '.png' = 'image/png'; '.woff2' = 'font/woff2'; '.txt' = 'text/plain; charset=utf-8' }
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()
Write-Host "Serving $dist on http://localhost:$Port/"
while ($listener.IsListening) {
  $ctx = $listener.GetContext()
  $path = [Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath).TrimStart('/')
  $file = Join-Path $dist $path
  if (Test-Path $file -PathType Container) { $file = Join-Path $file 'index.html' }
  if (-not (Test-Path $file -PathType Leaf)) { $file = Join-Path $dist '404.html'; $ctx.Response.StatusCode = 404 }
  $bytes = [IO.File]::ReadAllBytes($file)
  $ext = [IO.Path]::GetExtension($file)
  $ctx.Response.ContentType = $(if ($types[$ext]) { $types[$ext] } else { 'application/octet-stream' })
  $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
  $ctx.Response.Close()
}
