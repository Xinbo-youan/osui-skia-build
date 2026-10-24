#Requires -Version 7
# OSUI Skia build (D3D12 + Ganesh + SkParagraph) - hardened for GitHub Actions
# Drop-in replacement for build.ps1. Run from the skia/ repo root on the runner.
$ErrorActionPreference = 'Continue'
if (Get-Variable PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue) {
  $PSNativeCommandUseErrorActionPreference = $false
}
$env:PYTHONUNBUFFERED = '1'
New-Item -ItemType Directory -Force -Path logs | Out-Null
$LOG    = Join-Path (Get-Location) 'logs\build.log'
$STATUS = Join-Path (Get-Location) 'STATUS.md'

function Say([string]$m) {
  $line = "[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $m
  Write-Host $line
  Add-Content -Path $LOG -Value $line -Encoding UTF8
}
function Run([string]$step, [scriptblock]$cmd) {
  Say "STEP> $step"
  & $cmd
  $c = $LASTEXITCODE; if ($null -eq $c) { $c = 0 }
  if ($c -ne 0) { throw "$step exited $c" }
  Say "OK  > $step"
}

try {
  Run 'git-sync-deps' { python tools/git-sync-deps }

  $gnArgs = 'is_official_build=false is_debug=false target_cpu="x64" is_clang=false cc="cl" cxx="cl" skia_enable_ganesh=true skia_use_direct3d=true skia_use_dawn=false skia_use_harfbuzz=true skia_use_icu=true skia_enable_skparagraph=true is_component_build=false'
  Run 'gn gen' { & gn gen out\Rel "--args=$gnArgs" }

  Run 'ninja' { & ninja -C out\Rel skia skparagraph skshaper skunicode }

  Set-Content -Path $STATUS -Value ("STATUS: BUILT " + (Get-Date -Format o)) -Encoding UTF8
  Say 'ALL GOOD'
  exit 0
}
catch {
  Say "FAILED: $_"
  $tail = ''
  if (Test-Path $LOG) { $tail = (Get-Content $LOG -Tail 80 | Out-String) }
  Set-Content -Path $STATUS -Value ("STATUS: FAILED`n" + $tail) -Encoding UTF8
  exit 1
}
