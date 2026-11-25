param(
    [string]$Rbxmx = "C:\Users\artem\Desktop\KlinokUpdate.rbxmx",
    [string]$OutDir = "C:\Users\artem\KlinokPamyati\docs\update_sources"
)

$ErrorActionPreference = "Stop"
[xml]$doc = Get-Content -Path $Rbxmx -Encoding UTF8 -Raw

if (Test-Path $OutDir) { Remove-Item $OutDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$script:count = 0
$script:lines = New-Object System.Collections.Generic.List[string]

function Get-ChildItems($node) {
    return $node.ChildNodes | Where-Object { $_.NodeType -eq 'Element' -and $_.Name -eq 'Item' }
}

function Get-PropertyValue($item, [string]$propName) {
    $props = $item.ChildNodes | Where-Object { $_.Name -eq 'Properties' } | Select-Object -First 1
    if (-not $props) { return $null }
    foreach ($p in $props.ChildNodes) {
        if ($p.NodeType -ne 'Element') { continue }
        if ($p.GetAttribute('name') -eq $propName) { return $p }
    }
    return $null
}

function ConvertTo-SafeName([string]$name) {
    $safe = $name -replace '[\\/:*?"<>|]', '_'
    return $safe
}

function Walk($item, [string]$path) {
    $class = $item.GetAttribute('class')
    $nameProp = Get-PropertyValue $item 'Name'
    $name = if ($nameProp) { $nameProp.InnerText } else { $class }
    $sourceProp = Get-PropertyValue $item 'Source'

    $currentPath = if ($path) { Join-Path $path (ConvertTo-SafeName $name) } else { $OutDir }

    if ($sourceProp -and $sourceProp.InnerText.Trim().Length -gt 0) {
        $isScript = $class -in @('Script', 'ModuleScript', 'LocalScript')
        $ext = '.lua'
        if ($isScript) {
            New-Item -ItemType Directory -Force -Path $currentPath | Out-Null
            $file = Join-Path $currentPath "_source$ext"
            [System.IO.File]::WriteAllText($file, $sourceProp.InnerText, (New-Object System.Text.UTF8Encoding($false)))
            $script:count++
            $script:lines.Add("$class|$name|$file")
        }
    } else {
        New-Item -ItemType Directory -Force -Path $currentPath | Out-Null
    }

    foreach ($child in Get-ChildItems $item) {
        Walk $child $currentPath
    }
}

foreach ($item in Get-ChildItems $doc.roblox) {
    Walk $item $null
}

$script:lines | Set-Content -Path (Join-Path $OutDir "_index.txt") -Encoding UTF8
Write-Output "извлечено скриптов: $($script:count)"
Write-Output "index: $(Join-Path $OutDir '_index.txt')"
