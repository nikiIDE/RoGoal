$ErrorActionPreference = 'Stop'
$ProjectDirectory = Split-Path -Parent $PSScriptRoot
$Source = Join-Path $ProjectDirectory 'RoGoal.rbxmx'
$TargetDirectory = Join-Path $env:LOCALAPPDATA 'Roblox\Plugins'

if (-not (Test-Path -LiteralPath $Source)) {
    throw 'RoGoal.rbxmx was not found. Run python scripts/build_plugin.py first.'
}

# Reject malformed exports before Studio attempts to load them.
$PluginXml = New-Object System.Xml.XmlDocument
$PluginXml.Load($Source)
if ($PluginXml.DocumentElement.Name -ne 'roblox' -or $PluginXml.DocumentElement.GetAttribute('version') -ne '4') {
    throw 'Invalid Roblox XML plugin format.'
}

$SharedDefinitions = @{}
foreach ($definition in $PluginXml.SelectNodes('/roblox/SharedStrings/SharedString')) {
    $SharedDefinitions[$definition.GetAttribute('md5')] = $true
}
foreach ($reference in $PluginXml.SelectNodes('//Properties/SharedString')) {
    if (-not $SharedDefinitions.ContainsKey($reference.InnerText.Trim())) {
        throw 'Plugin is corrupt: an instance references a missing SharedString definition. Rebuild the plugin.'
    }
}

if (-not $PluginXml.SelectSingleNode('/roblox/Item[@class="Model"]/Item[@class="Script"]')) {
    throw 'Plugin is invalid: the main Script was not found.'
}

New-Item -ItemType Directory -Path $TargetDirectory -Force | Out-Null
$OtherVersions = @(Get-ChildItem -LiteralPath $TargetDirectory -Filter 'CursorBridgeV2*.rbxmx' -File |
    Where-Object { $_.Name -ne 'RoGoal.rbxmx' })
if ($OtherVersions.Count -gt 0) {
    Write-Warning 'Other Cursor Bridge plugin files were found. Remove old variants to avoid duplicate toolbar buttons:'
    foreach ($Item in $OtherVersions) { Write-Warning "  $($Item.FullName)" }
}
$Target = Join-Path $TargetDirectory 'RoGoal.rbxmx'
Copy-Item -LiteralPath $Source -Destination $Target -Force
Write-Host "RoGoal installed at $Target"
Write-Host 'Restart Roblox Studio and use Plugins > RoGoal.'
