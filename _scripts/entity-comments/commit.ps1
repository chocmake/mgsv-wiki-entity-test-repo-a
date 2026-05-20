# ------
# Config
# ------

$remoteRepoPath = "${env:REMOTE_OWNER}/${env:REMOTE_REPO}"
$remoteNewBranch = "auto-class-defs"
$prTitle = "Updated TppClassDefinitions.json with new property comments"
$prBody = "Automated by wiki action."
$headers = @{
    "Authorization" = "Bearer $env:GH_TOKEN"
    "Accept" = "application/vnd.github+json"
    "User-Agent" = "Powershell script"
}

# -------------------
# Generate new commit
# -------------------

# Useful guide here: https://gist.github.com/hardboiled/4edac2f3f919c4dd084014886a92e2b0

# Upload blob of encoded JSON (temporary until committed)
$outputEncoded = [Convert]::ToBase64String([IO.File]::ReadAllBytes($env:MERGE_OUTPUT))
$blobBody = @{ content = $outputEncoded; encoding = "base64" } | ConvertTo-Json
$blob = Invoke-RestMethod -Uri "https://api.github.com/repos/${remoteRepoPath}/git/blobs" -Headers $headers -ContentType "application/json" -Body $blobBody -Method Post

# Get latest commit reference from base branch and commit itself
$ref = Invoke-RestMethod -Uri "https://api.github.com/repos/${remoteRepoPath}/git/refs/heads/${env:REMOTE_BASE_BRANCH}" -Headers $headers
$commitObj = Invoke-RestMethod -Uri "https://api.github.com/repos/${remoteRepoPath}/git/commits/$($ref.object.sha)" -Headers $headers

# Create tree for the blob
$tree = @{
    base_tree = $commitObj.tree.sha
    tree = @(
        @{
            path = $env:REL_JSON_PATH
            mode = "100644"
            type = "blob"
            sha = $blob.sha
        }
    )
} | ConvertTo-Json -Depth 10
$newTree = Invoke-RestMethod -Uri "https://api.github.com/repos/${remoteRepoPath}/git/trees" -Headers $headers -ContentType "application/json" -Body $tree -Method Post

# Create the commit from the tree
$commit = @{
    message = $prTitle
    parents = @($($ref.object.sha))
    tree = $newTree.sha
} | ConvertTo-Json
$newCommit = Invoke-RestMethod -Uri "https://api.github.com/repos/${remoteRepoPath}/git/commits" -Headers $headers -ContentType "application/json" -Body $commit -Method Post

# Create new ref from commit
try {
    Invoke-RestMethod -Uri "https://api.github.com/repos/${remoteRepoPath}/git/refs/heads/$remoteNewBranch" -Headers $headers -ErrorAction Stop
    # If ref exists force update it
    $update = @{ sha = $newCommit.sha; force = $true } | ConvertTo-Json
    Invoke-RestMethod -Uri "https://api.github.com/repos/${remoteRepoPath}/git/refs/heads/$remoteNewBranch" -Headers $headers -ContentType "application/json" -Body $update -Method Patch
} catch {
    # Create it
    $refBody = @{ ref = "refs/heads/$remoteNewBranch"; sha = $newCommit.sha } | ConvertTo-Json
    Invoke-RestMethod -Uri "https://api.github.com/repos/${remoteRepoPath}/git/refs" -Headers $headers -ContentType "application/json" -Body $refBody -Method Post
}

# ---------
# Submit PR
# ---------

# FYI, currently not guarding for whether there's an existing PR, so the workflow log will print a benign error but it doesn't affect the commit.

$pr = @{
    head = "${env:REMOTE_OWNER}:${remoteNewBranch}"
    base = ${env:REMOTE_BASE_BRANCH}
    title = $prTitle
    body = $prBody
} | ConvertTo-Json
$prResponse = Invoke-RestMethod -Uri "https://api.github.com/repos/${remoteRepoPath}/pulls" -Headers $headers -ContentType "application/json" -Body $pr -Method Post
