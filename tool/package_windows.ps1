$ErrorActionPreference = 'Stop'

$version = '1.3.0'
$build = '8'
$productPrefix = "Airmonlink-Business-Manager-$version-Build$build"

$releaseDirectory = Get-ChildItem -Path 'build/windows' -Directory -Recurse |
    Where-Object {
        $_.Name -eq 'Release' -and
        (Test-Path (Join-Path $_.FullName 'airmonlink_business_manager.exe'))
    } |
    Select-Object -First 1

if (-not $releaseDirectory) {
    throw 'The Windows Release directory was not found.'
}

$required = @(
    'airmonlink_business_manager.exe',
    'flutter_windows.dll',
    'data\flutter_assets'
)

foreach ($relativePath in $required) {
    $candidate = Join-Path $releaseDirectory.FullName $relativePath
    if (-not (Test-Path $candidate)) {
        throw "The Windows release is incomplete: $relativePath is missing."
    }
}

$outputDirectory = Join-Path (Get-Location) 'dist'
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null

$stageDirectory = Join-Path ([System.IO.Path]::GetTempPath()) (
    'airmonlink-business-manager-portable-' + [System.Guid]::NewGuid().ToString('N')
)

try {
    New-Item -ItemType Directory -Path $stageDirectory -Force | Out-Null
    Copy-Item -Path (Join-Path $releaseDirectory.FullName '*') `
        -Destination $stageDirectory -Recurse -Force

    @"
Airmonlink Business Manager
Version $version
Build $build

This portable package stores application data in the Windows application-support
directory. Keep backups of business data and protect backup passwords.
"@ | Set-Content (Join-Path $stageDirectory 'README-PORTABLE.txt') -Encoding utf8

    $zipPath = Join-Path $outputDirectory "$productPrefix-Portable.zip"
    if (Test-Path $zipPath) {
        Remove-Item $zipPath -Force
    }

    Compress-Archive -Path (Join-Path $stageDirectory '*') `
        -DestinationPath $zipPath -CompressionLevel Optimal

    if (-not (Test-Path $zipPath) -or (Get-Item $zipPath).Length -le 0) {
        throw 'Portable package creation failed.'
    }

    Write-Host "Portable package created: $zipPath"
}
finally {
    if (Test-Path $stageDirectory) {
        Remove-Item $stageDirectory -Recurse -Force
    }
}
