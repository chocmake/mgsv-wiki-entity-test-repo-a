# Parse the wiki's entity reference index for non-placeholder property comments from the Markdown tables

# ------
# Config
# ------

$inputFile = "_site/assets/js/virtualindex.js"
$outputFile = $env:PARSE_OUTPUT
$placeholder = "TODO: Description"

# -----
# Parse
# -----

$inputContent = Get-Content -Raw -Path $inputFile
$modulePrefix = 'export const virtualindex = '
$inputArray = $inputContent -replace "^\s*$( [regex]::Escape($modulePrefix) )", '' -replace ';\s*$','' | ConvertFrom-Json

$result = [System.Collections.ArrayList]@()

ForEach ($item in $inputArray) {
    if (!$item.url.StartsWith("/Entity_Reference/")) { continue }
    $name = $item.title
    $content = if ($item.content -ne $null) { [string]$item.content } else { '' }

    $headerMatch = [regex]::Match($content, '##\s*Properties\b')
    if (!$headerMatch.Success) { continue }
    $contentAfter = $content.Substring($headerMatch.Index + $headerMatch.Length)

    # Pattern expects two table columns with the first column containing a Markdown link (the property name will be matched from the link name).
    # Handles escaped pipes in the comments column (`\\|` in the literal JSON, only needed in the original Markdown to avoid parsing as cell delimiter).
    $tableRowPattern = '\|\s*\[([^\]]+)\]\([^\)]+\)\s*\|\s*((?:\\\||[^|])*)\s*\|'
    $tableWholePattern = "(?:${tableRowPattern}\s*)+"
    $firstTable = [regex]::Match($contentAfter, $tableWholePattern)

    if (!$firstTable.Success) { continue }

    $tableRowMatches = [regex]::Matches($firstTable.Value, $tableRowPattern)
    $properties = [System.Collections.ArrayList]@()

    ForEach ($match in $tableRowMatches) {
        $propertyName = $match.Groups[1].Value.Trim()
        $comments = $match.Groups[2].Value.Trim() -replace '\\\|','|' -replace '\\\\','\' # convert any escaped pipes back to regular since won't be used for Markdown tables

        # Only add to properties array if not a placeholder string
        if ($comments -ne $placeholder -and $propertyName -ne '') {
            $properties.Add([PSCustomObject]@{ name = $propertyName; comments = $comments }) | Out-Null
        }
    }

    if ($properties.Count -gt 0) {
        $result.Add([PSCustomObject]@{ name = $name; properties = $properties }) | Out-Null
    }
}

# -------------
# Generate JSON
# -------------

$result | ConvertTo-Json -Depth 5 | Set-Content -Path $outputFile
