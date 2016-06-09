Param
(
    [Parameter(Mandatory=$false)]
    [string]$productVersion,
    
    [Parameter(Mandatory=$false)]
    [switch]$ForceProductVersion
)

Write-Verbose "Starting Prebuild script" -Verbose
        
## Build Number
$buildNumber = $env:BUILD_BUILDNUMBER
Write-Verbose "Build Number is: $buildNumber" -Verbose

## Get Collection Url
$CollectionUrl = $env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI
Write-Verbose "Collection Url is: $CollectionUrl" -Verbose


if ($buildNumber -eq $null)
{
    $buildIncrementalNumber = 0
}
else
{
    $splitted = $buildNumber.Split('.')
    $buildIncrementalNumber = $splitted[$splitted.Length - 1]
}
    
## Get Assembly Files from source directory
$SrcPath = $env:BUILD_SOURCESDIRECTORY
Write-Verbose "Executing Update-AssemblyInfoVersionFiles in path $SrcPath for product version Version $productVersion"  -Verbose
$AllVersionFiles = Get-ChildItem $SrcPath AssemblyInfo.cs -recurse

foreach ($line in $AllVersionFiles)
{
    Write-Verbose $line -Verbose
}

# Check out the file from TFS
Write-Verbose "Loading TFS cmdlets" -Verbose
add-pssnapin Microsoft.TeamFoundation.PowerShell
Get-TfsServer -Name "$CollectionUrl"
    
## getting the old version number
$rawVersionNumber = $productVersion
## if the parameter is not available, this means, use the one existing in the file rather than the supplied version.
if($ForceProductVersion.IsPresent -eq $false) 
{
    $AllVersionFiles = Get-ChildItem $SrcPath AssemblyInfo.cs -recurse
    $assemblyVersionPattern = 'AssemblyVersion\("(.*)"\)'
    $rawVersionNumberGroup = get-content $AllVersionFiles[0].Fullname | select-string -pattern $assemblyVersionPattern | select -first 1 | % { $_.Matches }              
    $rawVersionNumber = $rawVersionNumberGroup.Groups[1].Value
    Write-Verbose "Raw version is got from the assembly info file: $rawVersionNumber" -Verbose
}
# if($ForceProductVersion.IsPresent -eq $false) 
# {
#     $assemblyVersionPattern = 'AssemblyVersion\("([0-9]+(\.([0-9]+|\*)){1,3})"\)'
#     $rawVersionNumberGroup = get-content $AllVersionFiles | select-string -pattern $assemblyVersionPattern | select -last 1 | % { $_.Matches }              
#     $rawVersionNumber = $rawVersionNumberGroup.Groups[1].Value
#     Write-Verbose "Raw version is got from the assembly info file: $rawVersionNumber" -Verbose
# }
else {
    Write-Verbose "Raw version is got from the parameter: $rawVersionNumber" -Verbose    
}

foreach ($file in $AllVersionFiles) 
{
    # Get the file
    $filePath = $file.Fullname
    
    # Check out the file from TFS
    Add-TfsPendingChange -Edit -Item $filepath -ErrorAction SilentlyContinue -wa 0
    
    ## Increment the version number by 1
    $versionParts = $rawVersionNumber.Split('.') 
    $versionParts[3] = ([int]$versionParts[3]) + 1 
    $buildnum = "{0}.{1}.{2}.{3}" -f $versionParts[0], $versionParts[1], $versionParts[2], $versionParts[3]
    
    Write-Host "Updating the assembly info file '$filepath' to version ' $buildnum '" -Verbose
     
    ##version replacements
    (Get-Content $filePath) |
    ##%{$_ -replace 'AssemblyDescription\(""\)', "AssemblyDescription(""assembly built by TFS Build $buildNumber"")" } |
    %{$_ -replace 'AssemblyDescription\("(.*)"\)', "AssemblyDescription(""$buildNumber"")" } |
    %{$_ -replace 'AssemblyVersion\("(.*)"\)', "AssemblyVersion(""$buildnum"")" } |
    %{$_ -replace 'AssemblyFileVersion\("(.*)"\)', "AssemblyFileVersion(""$buildnum"")" } |
    %{$_ -replace 'AssemblyInformationalVersion\("(.*)"\)', "AssemblyInformationalVersion(""$buildNumber"")" } | 
    Set-Content $filePath -Force
    
    # Check in the file after changes.
    New-TfsChangeset -Item $filepath -Comment "Build '$buildNumber' By Build machine" -Override "By Build Machine" -ErrorAction SilentlyContinue
}
    
#New-TfsChangeset -Item "$SrcPath\*.cs" -Comment "Build '$buildNumber' By Build machine" -Override "By Build Machine" -ErrorAction SilentlyContinue

return $assemblyFileVersion
exit 0