# Merge the pre-parsed JSON containing the non-placeholder property comments to the corresponding property objects of the remote `TppClassDefinitions.json`

# ------
# Config
# ------

$inputFile = $env:PARSE_OUTPUT
$remoteUrl = "https://api.github.com/repos/${env:REMOTE_OWNER}/${env:REMOTE_REPO}/contents/${env:REL_JSON_PATH}?ref=${env:REMOTE_BASE_BRANCH}"
$origOutput = $env:ORIG_OUTPUT
$mergedOutput = $env:MERGE_OUTPUT

# ------------
# Fetch remote
# ------------

$sourceArray = Get-Content -Raw -Path $inputFile | ConvertFrom-Json

function Get-JsonFromUrl {
    param(
        [Parameter(Mandatory)]
        [string]$Url,

        [Parameter()]
        [int]$TimeoutSec = 15,

        [Parameter()]
        [int]$Retries = 2,

        [Parameter()]
        [int]$RetryDelaySec = 2
    )
    process {
        $attempt = 0
        $headers = @{
            "Authorization" = "Bearer $env:GH_TOKEN"
            "Accept" = "application/vnd.github.raw+json"
            "User-Agent" = "Powershell script"
        }
        while ($attempt -le $Retries) {
            try {
                $attempt++
                $response = Invoke-RestMethod -Uri $Url -Headers $headers -TimeoutSec $TimeoutSec -ErrorAction Stop -Method Get
                $response | ConvertTo-Json -Depth 10 | Set-Content -Path $origOutput
                return $response # Invoke-RestMethod already parses JSON response so no need to convert
            } catch {
                if ($attempt -gt $Retries) { throw "Failed to fetch/parse JSON from $Url after $Retries attempts: $_" }
                Start-Sleep -Seconds $RetryDelaySec
            }
        }
    }
}

$outputArray = Get-JsonFromUrl -Url $remoteUrl

# -----
# Parse
# -----

$targetParentLookup = @{}
for ($i = 0; $i -lt $outputArray.Count; $i++) {
    $parName = $outputArray[$i].name
    if ($parName) {
        $targetParentLookup[$parName.Trim().ToLower()] = $i
    }
}

ForEach ($sourceParent in $sourceArray) {
    if (!$sourceParent.name) { continue }
    $key = $sourceParent.name.Trim().ToLower()

    if (!$targetParentLookup.ContainsKey($key)) { continue } # skip parents not in target

    $targetParentIndex = $targetParentLookup[$key]
    $targetParent = $outputArray[$targetParentIndex]

    if (!$targetParent.properties) { continue }

    $targetPropLookup = @{}
    for ($p = 0; $p -lt $targetParent.properties.Count; $p++) {
        $propName = $targetParent.properties[$p].name
        if ($propName) { $targetPropLookup[$propName.Trim().ToLower()] = $p }
    }

    ForEach ($sourceProp in @($sourceParent.properties)) {
        if (!$sourceProp.name) { continue }
        $propKey = $sourceProp.name.Trim().ToLower()
        if (!$targetPropLookup.ContainsKey($propKey)) { continue }  # only update existing property items

        $index = $targetPropLookup[$propKey]
        $existing = $targetParent.properties[$index]

        $existing | Add-Member -NotePropertyName "comments" -NotePropertyValue $sourceProp.comments -Force
        $targetParent.properties[$index] = $existing
    }

    $outputArray[$targetParentIndex] = $targetParent
}

# -------------
# Generate JSON
# -------------

$outputArray | ConvertTo-Json -Depth 10 | Set-Content -Path $mergedOutput