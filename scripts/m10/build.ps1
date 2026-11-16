param(
    [Parameter(Mandatory)][string]$Go,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [ValidateSet('Normal', 'TypeC')][string]$Mode = 'Normal'
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
$Go = (Resolve-Path -LiteralPath $Go).Path
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$output = [IO.Path]::GetFullPath($OutputDirectory, (Get-Location).Path)
if (Test-Path -LiteralPath $output) { throw "Choose a new output directory: $output" }
New-Item -ItemType Directory -Path $output | Out-Null
Push-Location $repo
try {
    $env:CGO_ENABLED = '0'
    $env:GOOS = 'windows'
    $env:GOARCH = 'amd64'
    $env:GOAMD64 = 'v1'
    $env:GOWORK = 'off'
    $env:GOFLAGS = ''
    $env:GOTOOLCHAIN = 'local'
    $dependency = 'github.com/nya-owo/mygo@v0.7.1-0.20261107230755-f7032a2cc755'
    $module = & $Go mod download -json $dependency | ConvertFrom-Json
    if ($module.Sum -ne 'h1:l5ULjFyV4tzxx++/dohqYPlvgSc0lue6pjFD7giQOFM=') { throw 'Unexpected MyGo module checksum' }
    $mygo = Join-Path $output 'mygo'
    Copy-Item -LiteralPath $module.Dir -Destination $mygo -Recurse
    Get-ChildItem -LiteralPath $mygo -File -Recurse -Force | ForEach-Object { $_.IsReadOnly = $false }
    git -C $mygo apply --check (Join-Path $PSScriptRoot 'mygo.patch')
    git -C $mygo apply (Join-Path $PSScriptRoot 'mygo.patch')
    $modfile = Join-Path $output 'm10.mod'
    Copy-Item go.mod $modfile
    Copy-Item go.sum (Join-Path $output 'm10.sum')
    & $Go mod edit "-modfile=$modfile" "-replace=github.com/egoist/mygo=$mygo"
    $exeName = 'Rhine-M10.exe'
    $tags = @()
    if ($Mode -eq 'TypeC') {
        $exeName = 'Rhine-M10-TypeC.exe'
        $tags = @('-tags=m10typec')
    }
    $exe = Join-Path $output $exeName
    $buildArguments = @('build', "-modfile=$modfile", '-ldflags=-H=windowsgui', '-trimpath') + $tags + @('-o', $exe, '.')
    & $Go @buildArguments
    Copy-Item -LiteralPath resources -Destination $output -Recurse
    $resources = Get-ChildItem (Join-Path $output 'resources') -File -Recurse | Sort-Object FullName | ForEach-Object {
        @{ path = [IO.Path]::GetRelativePath($output, $_.FullName); sha256 = (Get-FileHash -LiteralPath $_.FullName).Hash }
    }
    @{
        commit = git rev-parse HEAD
        trackedChanges = @(git status --porcelain --untracked-files=no)
        dependency = $dependency
        dependencyChecksum = $module.Sum
        patchSha256 = (Get-FileHash (Join-Path $PSScriptRoot 'mygo.patch')).Hash
        toolchain = & $Go version
        environment = @{ CGO_ENABLED = '0'; GOOS = 'windows'; GOARCH = 'amd64'; GOAMD64 = 'v1'; GOWORK = 'off'; GOFLAGS = ''; GOTOOLCHAIN = 'local' }
        buildArguments = $buildArguments
        artifact = $exeName
        sha256 = (Get-FileHash -LiteralPath $exe).Hash
        resources = @($resources)
    } | ConvertTo-Json -Depth 6 | Set-Content -Encoding utf8 (Join-Path $output 'manifest.json')
} finally {
    Pop-Location
}
