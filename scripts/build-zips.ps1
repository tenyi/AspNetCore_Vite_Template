# 打包 12 種 Vite 範本 ZIP
# 後端來源:Net10_Controller_And_Vite / Net10_MinimalAPI_And_Vite / Net10_MVC_And_Vite
# 前端來源:ClientApps/{react-js,react-ts,vue-js,vue-ts}
# 取代:把範例硬編碼的 Net10_* / react-* / vue-* 字串換成 $safeprojectname$
# 動態產生 MyTemplate.vstemplate

[CmdletBinding()]
param(
    [string]$RepoRoot
)

if (-not $RepoRoot) {
    # 自動偵測 repo root:優先用 PSScriptRoot,失敗時用工作目錄
    try {
        $RepoRoot = (Resolve-Path "$PSScriptRoot\..").Path
    } catch {
        $RepoRoot = (Get-Location).Path
    }
}

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

$ptDir       = Join-Path $RepoRoot 'AspNetCore_Vite_Starter\AspNetCore_Vite_Starter\ProjectTemplates'
$clientDir   = Join-Path $RepoRoot 'AspNetCore_Vite_Starter\ClientApps'
$backendDir  = Join-Path $RepoRoot 'AspNetCore_Vite_Starter'

# (frontend, backend) → 要打包的 9 個新組合;vue-ts × 3 個已存在,跳過
$combos = @(
    @{ Frontend = 'react-js'; Backend = 'Controllers' },
    @{ Frontend = 'react-js'; Backend = 'MinimalAPI'  },
    @{ Frontend = 'react-js'; Backend = 'MVC'         },
    @{ Frontend = 'react-ts'; Backend = 'Controllers' },
    @{ Frontend = 'react-ts'; Backend = 'MinimalAPI'  },
    @{ Frontend = 'react-ts'; Backend = 'MVC'         },
    @{ Frontend = 'vue-js';  Backend = 'Controllers' },
    @{ Frontend = 'vue-js';  Backend = 'MinimalAPI'  },
    @{ Frontend = 'vue-js';  Backend = 'MVC'         }
)

# 後端範例資料夾名稱(也是 .csproj 名稱根)
$backendMap = @{
    'Controllers' = 'Net10_Controller_And_Vite'
    'MinimalAPI'  = 'Net10_MinimalAPI_And_Vite'
    'MVC'         = 'Net10_MVC_And_Vite'
}

# 要取代成 $safeprojectname$ 的字串(後端範例名稱 + 前端資料夾名稱)
$tokensToReplace = @(
    'Net10_Controller_And_Vite',
    'Net10_MinimalAPI_And_Vite',
    'Net10_MVC_And_Vite',
    'react-js', 'react-ts', 'vue-js', 'vue-ts'
)

# 副檔名才做字串取代(避免動到二進位檔)
$textExtensions = @(
    '.cs', '.csproj', '.json', '.ts', '.tsx', '.js', '.jsx',
    '.html', '.vue', '.md', '.cshtml', '.props', '.targets',
    '.config', '.svg'
)

# 從現有 ZIP 抽出 __TemplateIcon.png
$templateIconTmp = Join-Path $env:TEMP "__TemplateIcon_$(Get-Random).png"
$sourceZip = Join-Path $ptDir 'Vite_VueTS_And_Net10_Controllers.zip'
$srcArchive = [System.IO.Compression.ZipFile]::OpenRead($sourceZip)
$iconEntry = $srcArchive.Entries | Where-Object { $_.FullName -eq '__TemplateIcon.png' } | Select-Object -First 1
if (-not $iconEntry) { throw "找不到 __TemplateIcon.png 在 $sourceZip" }
[System.IO.Compression.ZipFileExtensions]::ExtractToFile($iconEntry, $templateIconTmp, $true)
$srcArchive.Dispose()

# 動態產生 MyTemplate.vstemplate
function New-Vstemplate {
    param(
        [string]$TemplateName,
        [string]$Description,
        [string]$CsprojFileName,
        [hashtable]$Folders  # key = folder path, value = list of project item names
    )
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('<VSTemplate Version="3.0.0" xmlns="http://schemas.microsoft.com/developer/vstemplate/2005" Type="Project">')
    [void]$sb.AppendLine('  <TemplateData>')
    [void]$sb.AppendLine("    <Name>$TemplateName</Name>")
    [void]$sb.AppendLine("    <Description>$Description</Description>")
    [void]$sb.AppendLine('    <ProjectType>CSharp</ProjectType>')
    [void]$sb.AppendLine('    <SortOrder>1000</SortOrder>')
    [void]$sb.AppendLine('    <CreateNewFolder>true</CreateNewFolder>')
    [void]$sb.AppendLine("    <DefaultName>$TemplateName</DefaultName>")
    [void]$sb.AppendLine('    <ProvideDefaultName>true</ProvideDefaultName>')
    [void]$sb.AppendLine('    <LocationField>Enabled</LocationField>')
    [void]$sb.AppendLine('    <EnableLocationBrowseButton>true</EnableLocationBrowseButton>')
    [void]$sb.AppendLine('    <CreateInPlace>true</CreateInPlace>')
    [void]$sb.AppendLine('    <Icon>__TemplateIcon.png</Icon>')
    [void]$sb.AppendLine('  </TemplateData>')
    [void]$sb.AppendLine('  <TemplateContent>')
    [void]$sb.AppendLine("    <Project TargetFileName=`"`$safeprojectname`$.csproj`"")
    [void]$sb.AppendLine("             File=`"$CsprojFileName`"")
    [void]$sb.AppendLine('             ReplaceParameters="true">')
    foreach ($folder in ($Folders.Keys | Sort-Object)) {
        $items = $Folders[$folder]
        if ($folder -eq '') {
            # 根目錄檔案
            foreach ($item in $items) {
                [void]$sb.AppendLine("      <ProjectItem ReplaceParameters=`"true`" TargetFileName=`"$item`">$item</ProjectItem>")
            }
        } else {
            [void]$sb.AppendLine("      <Folder Name=`"$folder`" TargetFolderName=`"$folder`">")
            foreach ($item in $items) {
                [void]$sb.AppendLine("        <ProjectItem ReplaceParameters=`"true`" TargetFileName=`"$item`">$item</ProjectItem>")
            }
            [void]$sb.AppendLine('      </Folder>')
        }
    }
    [void]$sb.AppendLine('    </Project>')
    [void]$sb.AppendLine('  </TemplateContent>')
    [void]$sb.AppendLine('</VSTemplate>')
    return $sb.ToString()
}

# 收集資料夾結構,轉成 vstemplate 用的 Folders hashtable
function Get-FolderMap {
    param([string]$RootPath)
    $map = [ordered]@{}
    $files = Get-ChildItem -Path $RootPath -Recurse -File
    foreach ($f in $files) {
        $rel = $f.FullName.Substring($RootPath.Length).TrimStart('\','/') -replace '\\', '/'
        $dir = Split-Path -Path $rel -Parent
        if ([string]::IsNullOrEmpty($dir)) { $dir = '' }
        $name = Split-Path -Path $rel -Leaf
        if (-not $map.Contains($dir)) { $map[$dir] = New-Object System.Collections.Generic.List[string] }
        $map[$dir].Add($name) | Out-Null
    }
    return $map
}

# 把字串中的範本標記取代成 $safeprojectname$
function Invoke-TokenReplace {
    param([string]$RootPath, [string[]]$Tokens)
    $files = Get-ChildItem -Path $RootPath -Recurse -File |
        Where-Object { $script:textExtensions -contains $_.Extension.ToLower() }
    foreach ($f in $files) {
        $content = [System.IO.File]::ReadAllText($f.FullName)
        $changed = $false
        foreach ($t in $Tokens) {
            if ($content.Contains($t)) {
                $content = $content.Replace($t, '$safeprojectname$')
                $changed = $true
            }
        }
        if ($changed) {
            [System.IO.File]::WriteAllText($f.FullName, $content, [System.Text.UTF8Encoding]::new($false))
        }
    }
}

# 壓縮目錄成 ZIP(內部路徑用 /)
function Compress-ToZip {
    param(
        [string]$SourceDir,
        [string]$ZipPath
    )
    if (Test-Path $ZipPath) { Remove-Item $ZipPath -Force }
    $archive = [System.IO.Compression.ZipFile]::Open($ZipPath, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        $files = Get-ChildItem -Path $SourceDir -Recurse -File
        foreach ($f in $files) {
            $rel = $f.FullName.Substring($SourceDir.Length).TrimStart('\','/') -replace '\\', '/'
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $f.FullName, $rel, [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
        }
    } finally {
        $archive.Dispose()
    }
}

# 主迴圈
foreach ($combo in $combos) {
    $frontend = $combo.Frontend
    $backend  = $combo.Backend
    $backendName = $backendMap[$backend]
    $backendSrc  = Join-Path $backendDir $backendName
    $frontendSrc = Join-Path $clientDir $frontend

    # 組合 ZIP 顯示名稱
    $prefix = if ($frontend.StartsWith('react-')) { 'React' } else { 'Vue' }
    $ftype  = $frontend.Split('-')[1].ToUpper()    # JS 或 TS
    $templateName = "Vite_${prefix}${ftype}_And_Net10_${backend}"
    $zipPath = Join-Path $ptDir "$templateName.zip"
    $description = "ASP.NET Core 10 ($backend) + $prefix + $ftype + Vite DevServer"

    # 暫存工作目錄
    $workDir = Join-Path $env:TEMP "ViteBuild_$($prefix)$($ftype)_$($backend)"
    if (Test-Path $workDir) { Remove-Item $workDir -Recurse -Force }
    New-Item -ItemType Directory -Path $workDir -Force | Out-Null

    # 1) 複製 __TemplateIcon.png
    Copy-Item $templateIconTmp (Join-Path $workDir '__TemplateIcon.png') -Force

    # 2) 複製後端檔案(平鋪到根,排除 obj/bin/ClientApp)
    Get-ChildItem -Path $backendSrc -Recurse -File |
        Where-Object { $_.FullName -notmatch '[\\/](obj|bin|ClientApp)[\\/]' } |
        ForEach-Object {
            $rel = $_.FullName.Substring($backendSrc.Length).TrimStart('\','/') -replace '\\', '/'
            $dest = Join-Path $workDir $rel
            $destDir = Split-Path $dest -Parent
            if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
            Copy-Item $_.FullName $dest -Force
        }

    # 3) 複製前端到 ClientApp/
    $clientAppDest = Join-Path $workDir 'ClientApp'
    New-Item -ItemType Directory -Path $clientAppDest -Force | Out-Null
    Get-ChildItem -Path $frontendSrc -Force | ForEach-Object {
        if ($_.PSIsContainer) {
            Copy-Item -Path $_.FullName -Destination $clientAppDest -Recurse -Force
        } else {
            Copy-Item -Path $_.FullName -Destination $clientAppDest -Force
        }
    }

    # 4) 字串取代
    Invoke-TokenReplace -RootPath $workDir -Tokens $tokensToReplace

    # 5) 產生 MyTemplate.vstemplate
    $folderMap = Get-FolderMap -RootPath $workDir
    $vstemplate = New-Vstemplate -TemplateName $templateName -Description $description -CsprojFileName "$backendName.csproj" -Folders $folderMap
    [System.IO.File]::WriteAllText((Join-Path $workDir 'MyTemplate.vstemplate'), $vstemplate, [System.Text.UTF8Encoding]::new($false))

    # 6) 壓縮
    Compress-ToZip -SourceDir $workDir -ZipPath $zipPath

    Write-Host "✔ 已建立: $zipPath"
}

# 清理
Remove-Item $templateIconTmp -Force -ErrorAction SilentlyContinue
Get-ChildItem -Path $env:TEMP -Filter "ViteBuild_*" -Directory | ForEach-Object {
    Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "=== 完成,目前 ProjectTemplates 內的 ZIP 數量 ==="
(Get-ChildItem -Path $ptDir -Filter '*.zip').Count
