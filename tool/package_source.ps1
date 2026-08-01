$ErrorActionPreference = 'Stop'

$version = '1.3.0'
$build = '8'
$productPrefix = "Airmonlink-Business-Manager-$version-Build$build"
$outputDirectory = Join-Path (Get-Location) 'dist'
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null

$sourceZip = Join-Path $outputDirectory "$productPrefix-Full-Source.zip"
if (Test-Path $sourceZip) {
    Remove-Item $sourceZip -Force
}

$stage = Join-Path ([System.IO.Path]::GetTempPath()) (
    'airmonlink-business-manager-source-' + [System.Guid]::NewGuid().ToString('N')
)

try {
    New-Item -ItemType Directory -Path $stage -Force | Out-Null
    $excludedDirectories = @('.git', '.dart_tool', 'build', 'dist')
    $excludedFiles = @('.DS_Store', 'Thumbs.db')

    Get-ChildItem -Force | ForEach-Object {
        if ($excludedDirectories -contains $_.Name -or $excludedFiles -contains $_.Name) {
            return
        }
        Copy-Item $_.FullName -Destination $stage -Recurse -Force
    }

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::CreateFromDirectory(
        $stage,
        $sourceZip,
        [System.IO.Compression.CompressionLevel]::Optimal,
        $false
    )

    $archive = [System.IO.Compression.ZipFile]::OpenRead($sourceZip)
    try {
        $entries = @(
            $archive.Entries |
                ForEach-Object { $_.FullName.Replace('\', '/') }
        )
        foreach ($required in @(
            '.gitattributes',
            '.gitignore',
            '.github/workflows/windows-build.yml',
            'windows/.gitignore',
            'pubspec.yaml',
            'pubspec.lock'
        )) {
            if ($entries -notcontains $required) {
                throw "Full-source ZIP is missing required entry: $required"
            }
        }
    }
    finally {
        $archive.Dispose()
    }
}
finally {
    if (Test-Path $stage) {
        Remove-Item $stage -Recurse -Force
    }
}

if (-not (Test-Path $sourceZip) -or (Get-Item $sourceZip).Length -le 0) {
    throw 'Full-source package creation failed.'
}

Write-Host "Full-source package created: $sourceZip"
