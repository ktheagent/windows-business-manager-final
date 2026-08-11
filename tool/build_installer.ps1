$ErrorActionPreference = 'Stop'

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$reportPath = Join-Path $repositoryRoot 'installer-build-report.txt'
$releaseDirectory = Join-Path $repositoryRoot 'build\windows\x64\runner\Release'
$applicationPath = Join-Path $releaseDirectory 'airmonlink_business_manager.exe'
$installerScript = Join-Path $repositoryRoot 'installer\airmonlink_business_manager.iss'
$licenseFile = Join-Path $repositoryRoot 'installer\Airmonlink-Business-Manager-EULA.rtf'
$outputDirectory = Join-Path $repositoryRoot 'dist'
$productPrefix = 'Airmonlink-Business-Manager-1.3.0-Build9'
$installerPath = Join-Path $outputDirectory "$productPrefix-Setup.exe"

Set-Content -Path $reportPath -Value '' -Encoding utf8

function Write-Report {
    param([Parameter(Mandatory = $true)][string]$Message)
    $line = "[$([DateTime]::UtcNow.ToString('o'))] $Message"
    Write-Host $line
    Add-Content -Path $reportPath -Value $line -Encoding utf8
}

try {
    Write-Report "Repository root: $repositoryRoot"
    foreach ($requiredPath in @($releaseDirectory, $applicationPath, $installerScript, $licenseFile)) {
        if (-not (Test-Path $requiredPath)) {
            throw "Required installer input is missing: $requiredPath"
        }
        Write-Report "Verified input: $requiredPath"
    }

    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
    if (Test-Path $installerPath) {
        Remove-Item $installerPath -Force
    }

    $compilerCandidates = [System.Collections.Generic.List[string]]::new()
    $command = Get-Command 'ISCC.exe' -ErrorAction SilentlyContinue
    if ($command -and $command.Source) {
        $compilerCandidates.Add($command.Source)
    }
    if ($env:ChocolateyInstall) {
        $compilerCandidates.Add((Join-Path $env:ChocolateyInstall 'bin\ISCC.exe'))
    }
    if (${env:ProgramFiles(x86)}) {
        $compilerCandidates.Add((Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'))
    }
    if ($env:ProgramFiles) {
        $compilerCandidates.Add((Join-Path $env:ProgramFiles 'Inno Setup 6\ISCC.exe'))
    }

    $compiler = $compilerCandidates |
        Select-Object -Unique |
        Where-Object { Test-Path $_ } |
        Select-Object -First 1

    if (-not $compiler) {
        $candidateText = ($compilerCandidates | Select-Object -Unique) -join '; '
        throw "ISCC.exe was not found. Checked: $candidateText"
    }

    Write-Report "Using Inno Setup compiler: $compiler"
    Write-Report "Inno Setup compiler version: $((Get-Item $compiler).VersionInfo.FileVersion)"

    $arguments = @(
        '/Qp',
        "/O$outputDirectory",
        "/F$productPrefix-Setup",
        $installerScript
    )

    & $compiler @arguments 2>&1 |
        ForEach-Object {
            $line = $_.ToString()
            Write-Host $line
            Add-Content -Path $reportPath -Value $line -Encoding utf8
        }

    $compilerExitCode = $LASTEXITCODE
    Write-Report "ISCC exit code: $compilerExitCode"

    if ($compilerExitCode -ne 0) {
        throw "Inno Setup compilation failed with exit code $compilerExitCode."
    }
    if (-not (Test-Path $installerPath)) {
        throw "Compiler returned success but the expected installer is missing: $installerPath"
    }

    $installer = Get-Item $installerPath
    if ($installer.Length -le 0) {
        throw "The generated installer is empty: $installerPath"
    }

    $hash = (Get-FileHash $installerPath -Algorithm SHA256).Hash.ToLowerInvariant()
    Write-Report "Installer created: $installerPath"
    Write-Report "Installer size: $($installer.Length) bytes"
    Write-Report "Installer SHA-256: $hash"
}
catch {
    Write-Report "ERROR: $($_.Exception.Message)"
    throw
}
