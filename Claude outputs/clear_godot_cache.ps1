$godotFolder = "C:\Users\temie\Documents\Personal Life\Pearly White\Challenge\App\Pearly Whites Challenge\.godot"

if (Test-Path $godotFolder) {
    Remove-Item -Path $godotFolder -Recurse -Force
    Write-Host "Deleted Godot cache folder: $godotFolder"
    Write-Host "Godot will rebuild the cache when you reopen the project."
} else {
    Write-Host "Godot cache folder not found at: $godotFolder"
}
