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

$running = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like '*godot*' -or $_.ProcessName -like 'summer*' }
if ($running) {
  Write-Host 'These Godot / Summer Engine processes are still running in the background:' -ForegroundColor Yellow
  $running | ForEach-Object { Write-Host ("   {0}  (id {1})" -f $_.ProcessName, $_.Id) }
  Write-Host 'If the editor window is closed, these are just background helpers.' -ForegroundColor Yellow
  $ans = Read-Host 'Type Y to close them and continue, or anything else to stop'
  if ($ans -ne 'Y' -and $ans -ne 'y') { exit 1 }
  $running | Stop-Process -Force -ErrorAction SilentlyContinue
  Start-Sleep -Seconds 2
}
if (Test-Path -LiteralPath $B) { Write-Host "Backup folder already exists: $B  (rename or remove it first)" -ForegroundColor Red; exit 1 }
EnsureDir $B
$plan = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'plan.json') -Raw -Encoding UTF8 | ConvertFrom-Json
Log ("Size before: {0} MB" -f (SizeMB $P))

# 1. Remove the candy_crusade/assets shortcut (link only - never its target)
$link = Full 'candy_crusade/assets'
if (Test-Path -LiteralPath $link) {
  $item = Get-Item -LiteralPath $link -Force
  if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { cmd /c rmdir "`"$link`"" | Out-Null; Log 'Removed candy_crusade/assets link' }
  else { Move-Item -LiteralPath $link -Destination (Join-Path $B 'candy_crusade_assets_folder'); Log 'candy_crusade/assets was a real folder - moved to backup' }
}

# 2. Old assets/ (Candy Crusade 3D models, regions, ui) -> assets/candy_crusade/
$assets = Full 'assets'
$tmp = Full '_cc_tmp'
Rename-Item -LiteralPath $assets -NewName '_cc_tmp'
EnsureDir $assets
Move-Item -LiteralPath $tmp -Destination (Join-Path $assets 'candy_crusade')
Log 'Moved assets/* -> assets/candy_crusade/'

# 3. Move every used asset (plus its .import / .uid) into the new layout
$moved = 0
foreach ($m in $plan.moves) {
  $src = Full $m.src; $dst = Full $m.dst
  if (-not (Test-Path -LiteralPath $src)) { Log "MISSING source: $($m.src)"; continue }
  EnsureDir (Split-Path -Parent $dst)
  Move-Item -LiteralPath $src -Destination $dst
  foreach ($ext in '.import', '.uid') {
    if (Test-Path -LiteralPath ($src + $ext)) { Move-Item -LiteralPath ($src + $ext) -Destination ($dst + $ext) }
  }
  $moved++
}
Log "Moved $moved used assets"

# 4. Everything else that is not part of the game -> backup
foreach ($rel in $plan.to_backup) {
  $src = Full $rel
  if (-not (Test-Path -LiteralPath $src)) { continue }
  $dst = Join-Path $B ($rel -replace '/', '\')
  EnsureDir (Split-Path -Parent $dst)
  Move-Item -LiteralPath $src -Destination $dst
  Log "Backed up: $rel"
}
# keep export credentials (signing settings) in a fresh .godot folder
$cred = Join-Path $B '.godot\export_credentials.cfg'
if (Test-Path -LiteralPath $cred) { EnsureDir (Full '.godot'); Copy-Item -LiteralPath $cred -Destination (Full '.godot\export_credentials.cfg') }

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
$log | Set-Content -LiteralPath (Join-Path $B 'cleanup_log.txt') -Encoding UTF8
try { Move-Item -LiteralPath $PSScriptRoot -Destination (Join-Path $B '_cleanup') } catch { Write-Host 'Could not move _cleanup folder - delete it manually.' }
Write-Host 'DONE' -ForegroundColor Green
