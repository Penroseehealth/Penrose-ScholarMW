$ErrorActionPreference = 'Stop'
$projectRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$assets = Join-Path (Split-Path -Parent $PSScriptRoot) 'assets\smartboard'
New-Item -ItemType Directory -Force -Path $assets | Out-Null
$files = @(
  'index.html',
  'engine.js',
  'features.js',
  'questions.js',
  'annotate.js',
  'demo.js',
  'smartboard-bridge.js'
)
foreach ($file in $files) {
  Copy-Item -Force (Join-Path $projectRoot $file) (Join-Path $assets $file)
}
Write-Output "Smartboard assets copied from $projectRoot"
