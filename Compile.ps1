$OFS = "`r`n"
$scriptname = "itt.ps1"
# Variable to sync between runspaces
$sync = [Hashtable]::Synchronized(@{})
$sync.PSScriptRoot = $PSScriptRoot
$sync.configs = @{}

if (Test-Path -Path "$($scriptname)")
{
    Remove-Item -Force "$($scriptname)"
}

Write-output '
################################################################################################################
###                                                                                                          ###
###  This file is automatically generated                                                                    ###
###                                                                                                          ###
################################################################################################################
' | Out-File ./$scriptname -Append -Encoding ascii

(Get-Content .\Scripts\start.ps1).replace('#{replaceme}',"$(Get-Date -Format yy.MM.dd)") | Out-File ./$scriptname -Append -Encoding ascii

Get-ChildItem .\Functions -Recurse -File | ForEach-Object {
    Get-Content $psitem.FullName | Out-File ./$scriptname -Append -Encoding ascii
}

Get-ChildItem .\Database | Where-Object {$psitem.extension -eq ".json"} | ForEach-Object {
    $json = (Get-Content $psitem.FullName -Raw).replace("'", "''")
    $sync.configs.$($psitem.BaseName) = $json | ConvertFrom-Json
    Write-output "`$sync.configs.$($psitem.BaseName) = '$json' `| ConvertFrom-Json" | Out-File ./$scriptname -Append -Encoding default
}

$xaml = (Get-Content .\interface\window.xaml -Raw).replace("'", "''")

# Assuming taps.xaml is in the same directory as main.ps1
$appXamlPath = Join-Path -Path $PSScriptRoot -ChildPath "interface/Controls/taps.xaml"
$StylePath = Join-Path -Path $PSScriptRoot -ChildPath "interface/Themes/style.xaml"
$colorsPath = Join-Path -Path $PSScriptRoot -ChildPath "interface/Themes/colors.xaml"

# Load the XAML content from inputApp.xaml
$appXamlContent = Get-Content -Path $appXamlPath -Raw
$StyleContent = Get-Content -Path $StylePath -Raw
$colorsContent = Get-Content -Path $colorsPath -Raw

# Replace the placeholder in $inputXML with the content of inputApp.xaml
$xaml = $xaml -replace "{{Taps}}", $appXamlContent
$xaml = $xaml -replace "{{Style}}", $StyleContent
$xaml = $xaml -replace "{{Colors}}", $colorsContent

# Create XAML content for checkboxes only
$appCheckboxex = ""
foreach ($a in $sync.configs.applications) {
    $appCheckboxex += @"
<CheckBox Content="$($a.Name)" Tag="$($a.category)" />
"@
}

$tweeaksCheckboxex = ""
foreach ($t in $sync.configs.tweaks) {
    $tweeaksCheckboxex += @"
<CheckBox Content="$($t.Name)" />
"@
}

$xaml = $xaml -replace "{{ee}}", $appCheckboxex
$xaml = $xaml -replace "{{eee}}", $tweeaksCheckboxex

Write-output "`$inputXML =  '$xaml'" | Out-File ./$scriptname -Append -Encoding ascii

Get-Content .\scripts\loadXmal.ps1 | Out-File ./$scriptname -Append -Encoding ascii

Get-ChildItem .\loops -Recurse -File | ForEach-Object {
    Get-Content $psitem.FullName | Out-File ./$scriptname -Append -Encoding ascii
}

Get-Content .\scripts\main.ps1 | Out-File ./$scriptname -Append -Encoding ascii

./itt.ps1