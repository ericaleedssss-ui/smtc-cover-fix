param(
    [Parameter(Mandatory=$true)][string]$QtRoot,
    [Parameter(Mandatory=$true)][string]$NodeRoot,
    [string]$PortableMsvcRoot,
    [string]$CMakeBin,
    [string]$NinjaBin,
    [string]$Python = 'python',
    [switch]$CheckUi,
    [switch]$Share
)

$ErrorActionPreference = 'Stop'
$migrationRoot = Split-Path -Parent $PSScriptRoot
$applicationRoot = Join-Path $migrationRoot 'app'
function Invoke-Checked([string]$Executable, [string[]]$Arguments) {
    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Executable exited with code $LASTEXITCODE" }
}

# A Visual Studio x64 Developer PowerShell already provides INCLUDE/LIB/PATH.
# The optional portable compiler uses the same headers/libraries without a
# machine-wide install. Only this process and its children receive these vars.
if ($PortableMsvcRoot) {
    $vcFolder = Get-ChildItem -LiteralPath (Join-Path $PortableMsvcRoot 'VC/Tools/MSVC') -Directory |
        Sort-Object Name -Descending | Select-Object -First 1
    $sdkRoot = Join-Path $PortableMsvcRoot 'Windows Kits/10'
    $sdkFolder = Get-ChildItem -LiteralPath (Join-Path $sdkRoot 'Lib') -Directory |
        Sort-Object Name -Descending | Select-Object -First 1
    $redistFolder = Get-ChildItem -LiteralPath (Join-Path $PortableMsvcRoot 'VC/Redist/MSVC') -Directory |
        Sort-Object Name -Descending | Select-Object -First 1
    $sdkVersion = $sdkFolder.Name
    $env:INCLUDE = (@((Join-Path $vcFolder.FullName 'include')) +
        @('ucrt','shared','um','winrt','cppwinrt' | ForEach-Object { Join-Path $sdkRoot "Include/$sdkVersion/$_" })) -join ';'
    $env:LIB = @((Join-Path $vcFolder.FullName 'lib/x64'),
        (Join-Path $sdkRoot "Lib/$sdkVersion/ucrt/x64"),
        (Join-Path $sdkRoot "Lib/$sdkVersion/um/x64")) -join ';'
    $env:PATH = @((Join-Path $vcFolder.FullName 'bin/Hostx64/x64'),
        (Join-Path $sdkRoot "bin/$sdkVersion/x64"), $env:PATH) -join ';'
    $env:VCINSTALLDIR = (Join-Path $PortableMsvcRoot 'VC') + '\'
    $env:VCToolsInstallDir = $vcFolder.FullName + '\'
    $env:VCToolsRedistDir = $redistFolder.FullName + '\'
    $env:WindowsSdkDir = $sdkRoot + '\'
    $env:WindowsSDKVersion = $sdkVersion + '\'
    $env:VSCMD_ARG_TGT_ARCH = 'x64'
}
$env:PATH = (@((Join-Path $QtRoot 'bin'), $NodeRoot, $CMakeBin, $NinjaBin, $env:PATH) |
    Where-Object { $_ }) -join ';'
$env:QT_ROOT = $QtRoot
$env:RHINE_NODE_BINARY = Join-Path $NodeRoot 'node.exe'
$env:RHINE_NODE_LICENSE = Join-Path $NodeRoot 'LICENSE'
$env:RHINE_VERSION = 'v1.2.0'
$env:RHINE_BUILD_TYPE = 'Release'
$env:PYTHON = $Python
$env:PYTHONIOENCODING = 'utf-8'
$env:CMAKE_BUILD_PARALLEL_LEVEL = '6'
$nodeBinary = Join-Path $NodeRoot 'node.exe'
$npmScript = Join-Path $NodeRoot 'node_modules/npm/bin/npm-cli.js'
foreach ($file in @($nodeBinary,$npmScript,$env:RHINE_NODE_LICENSE,(Join-Path $QtRoot 'lib/cmake/Qt6/Qt6Config.cmake'))) {
    if (-not (Test-Path -LiteralPath $file)) { throw "Build dependency missing: $file" }
}
if (-not (Get-Command cl.exe -ErrorAction SilentlyContinue)) { throw 'Use an x64 Developer shell or provide PortableMsvcRoot.' }

Push-Location -LiteralPath $applicationRoot
try {
    Invoke-Checked $Python @((Join-Path $PSScriptRoot 'verify-source.py'), '--stamp',
        (Join-Path $PSScriptRoot 'results/local-source.json'))
    Invoke-Checked $Python @((Join-Path $PSScriptRoot 'check-integrations.py'))
    Invoke-Checked $nodeBinary @($npmScript,'ci','--ignore-scripts','--no-audit','--no-fund')
    Invoke-Checked $nodeBinary @($npmScript,'run','build')
    Invoke-Checked $nodeBinary @($npmScript,'test')
    if ($CheckUi) {
        $env:QSG_RHI_BACKEND='d3d11'
        $env:QSG_RHI_PREFER_SOFTWARE_RENDERER='1'
        Invoke-Checked $Python @((Join-Path $PSScriptRoot 'run-ui-check.py'),'--output',
            (Join-Path $PSScriptRoot 'results/local-ui'))
    }
    if ($Share) {
        Invoke-Checked $nodeBinary @($npmScript,'run','share')
        Invoke-Checked $Python @((Join-Path $PSScriptRoot 'verify-package.py'),
            '--app','output/windows/RHINE MUSIC DATABASE',
            '--zip','output/RhineMusicDatabase-v1.2.0-Windows-x64.zip',
            '--report',(Join-Path $PSScriptRoot 'results/local-package.json'))
    }
} finally { Pop-Location }
