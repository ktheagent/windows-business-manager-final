$ErrorActionPreference = 'Stop'

$requiredFiles = @(
    'windows/CMakeLists.txt',
    'windows/runner/CMakeLists.txt',
    'windows/runner/main.cpp',
    'windows/runner/Runner.rc',
    'windows/runner/resources/app_icon.ico'
)

foreach ($path in $requiredFiles) {
    if (-not (Test-Path $path)) {
        throw "Required Windows source file is missing: $path"
    }
}

$mainCpp = Get-Content 'windows/runner/main.cpp' -Raw
if ($mainCpp -notmatch 'L"Airmonlink Business Manager"') {
    throw 'The Windows window title does not match Airmonlink Business Manager.'
}

$cmake = Get-Content 'windows/CMakeLists.txt' -Raw
if ($cmake -notmatch 'set\(BINARY_NAME\s+"airmonlink_business_manager"\)') {
    throw 'The Windows executable identity is not airmonlink_business_manager.'
}

Write-Host 'Existing Windows platform source verified. No template files were generated.'
