$file = "f:\Nyx\engines\MASTER_ENGINE_DOCUMENTATION.md"
[string]$content = [System.IO.File]::ReadAllText($file, [System.Text.Encoding]::UTF8)
$newContent = $content.Replace("`nyx`n", "`nny`n")

# Handle edge cases
if ($newContent.StartsWith("yx`n")) {
    $newContent = $newContent.Substring(2)
    $newContent = "ny`n" + $newContent
}

[System.IO.File]::WriteAllText($file, $newContent, [System.Text.Encoding]::UTF8)
Write-Output "Done"
