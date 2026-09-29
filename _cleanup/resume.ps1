# Pearly Whites Challenge - project cleanup
# Moves the game into a clean layout and moves everything removed into a backup folder
# next to the project (nothing is permanently deleted).
$ErrorActionPreference = 'Stop'
$P = Split-Path -Parent $PSScriptRoot                     # project root
$B = Join-Path (Split-Path -Parent $P) 'Pearly Whites Challenge - removed backup'
$log = New-Object System.Collections.Generic.List[string]
function Log($m) { $log.Add($m); Write-Host $m }
function Full($rel) { Join-Path $P ($rel -replace '/', '\') }
function EnsureDir($path) { if (-not (Test-Path -LiteralPath $path)) { New-Item -ItemType Directory -Path $path -Force | Out-Null } }
function SizeMB($path) {
  $s = (Get-ChildItem -LiteralPath $path -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
  [math]::Round($s / 1MB, 1)
}

$plan = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'plan.json') -Raw -Encoding UTF8 | ConvertFrom-Json
EnsureDir $B
Write-Host 'Resuming cleanup (steps 1-3 already done)...'

# 4b. Move the remaining folders to backup. robocopy moves file by file, so a folder
#     that Windows/Explorer is holding open can't block it.
foreach ($rel in 'public', '.godot') {
  $src = Full $rel
  if (-not (Test-Path -LiteralPath $src)) { continue }
  $dst = Join-Path $B $rel
  try { Move-Item -LiteralPath $src -Destination $dst -ErrorAction Stop; Log "Backed up: $rel"; continue } catch { }
  robocopy "$src" "$dst" /E /MOVE /R:2 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
  if (Test-Path -LiteralPath $src) {
    $left = @(Get-ChildItem -LiteralPath $src -Recurse -Force -File -ErrorAction SilentlyContinue)
    if ($left.Count -eq 0) { Remove-Item -LiteralPath $src -Recurse -Force -ErrorAction SilentlyContinue }
    if (Test-Path -LiteralPath $src) { Log ("Backed up $rel, but {0} files/empty folders were locked and stayed behind - delete '$rel' by hand after closing Explorer windows" -f $left.Count) }
    else { Log "Backed up: $rel" }
  } else { Log "Backed up: $rel" }
}
$cred = Join-Path $B '.godot\export_credentials.cfg'
if (Test-Path -LiteralPath $cred) { EnsureDir (Full '.godot'); Copy-Item -LiteralPath $cred -Destination (Full '.godot\export_credentials.cfg') -Force }

# 5. Update res:// paths in scripts, scenes, resources and import files
$map = New-Object System.Collections.Hashtable ([StringComparer]::Ordinal)
$mapNoGodot = New-Object System.Collections.Hashtable ([StringComparer]::Ordinal)
foreach ($e in $plan.map) { $map[$e.from] = $e.to; if (-not $e.from.StartsWith('res://.godot')) { $mapNoGodot[$e.from] = $e.to } }
function MakePattern($h) { ($h.Keys | Sort-Object Length -Descending | ForEach-Object { [regex]::Escape($_) }) -join '|' }
$patAll = MakePattern $map; $patImp = MakePattern $mapNoGodot
$enc = New-Object System.Text.UTF8Encoding($false)
$changed = 0
Get-ChildItem -Path $P -Recurse -File -Force -Include *.gd, *.tscn, *.tres, *.import, *.cfg, project.godot |
  Where-Object { $_.FullName -notlike (Join-Path $P '.godot\*') -and $_.FullName -notlike (Join-Path $P '_cleanup\*') } |
  ForEach-Object {
    $f = $_.FullName
    $t = [IO.File]::ReadAllText($f)
    if ($_.Extension -eq '.import') { $pat = $patImp; $h = $mapNoGodot } else { $pat = $patAll; $h = $map }
    $n = [regex]::Replace($t, $pat, [Text.RegularExpressions.MatchEvaluator] { param($mm) $h[$mm.Value] })
    if ($n -ne $t) { [IO.File]::WriteAllText($f, $n, $enc); $changed++ }
  }
Log "Updated paths in $changed files"

# 6. Godot-only .gitignore
[IO.File]::WriteAllText((Full '.gitignore'), ".godot/`n/android/build/`n*.tmp`n", $enc)

Log ("Size after: {0} MB   (backup: {1} MB)" -f (SizeMB $P), (SizeMB $B))
$log | Set-Content -LiteralPath (Join-Path $B 'cleanup_log_part2.txt') -Encoding UTF8
try { Move-Item -LiteralPath $PSScriptRoot -Destination (Join-Path $B '_cleanup') } catch { Write-Host 'Could not move _cleanup folder - delete it manually.' }
Write-Host 'DONE' -ForegroundColor Green
