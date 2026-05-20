# ------
# Config
# ------

$uniqueJson = $env:PARSE_OUTPUT
$origJson = $env:ORIG_OUTPUT
$mergedJson = $env:MERGE_OUTPUT

# -----------------
# Generate new JSON
# -----------------

pwsh "$PSScriptRoot/parse.ps1" # sibling script
if (!(Test-Path $uniqueJson)) {
    Write-Host "Parse script output missing"
    exit 1
}

pwsh "$PSScriptRoot/merge.ps1"
if ((!(Test-Path $origJson)) -and (!(Test-Path $mergedJson))) {
    Write-Host "Merge script output missing"
    exit 1
}

# -------
# Compare
# -------

# Check against the main branch's version (expects changes already merged in remote repo since last run)
$checksumMainBranch = Get-FileHash -Path $origJson -Algorithm SHA256
$checksumNew = Get-FileHash -Path $mergedJson -Algorithm SHA256

if ($checksumMainBranch.Hash -eq $checksumNew.Hash) {
    Write-Host "No change to property comments detected. Exiting."
    exit 0
}

# -------------
# Create commit
# -------------

pwsh "$PSScriptRoot/commit.ps1"

