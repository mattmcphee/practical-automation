[CmdletBinding()]
[OutputType()]
param (
    [Parameter(Mandatory = $true)]
    [string]$LogPath,
    [Parameter(Mandatory = $true)]
    [string]$ZipPath,
    [Parameter(Mandatory = $true)]
    [string]$ZipPrefix,
    [Parameter(Mandatory = $false)]
    [double]$NumberOfDays = 30
)

function Set-ArchiveFilePath {
    <#
    .SYNOPSIS
    Creates an archive.
    
    .DESCRIPTION
    Creates an archive with a timestamp filename.
    
    .EXAMPLE
    An example
    
    .NOTES
    General notes
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        # Parameter help description
        [Parameter(Mandatory = $true)]
        [string]
        $ZipPath,
        # Parameter help description
        [Parameter(Mandatory = $true)]
        [string]
        $ZipPrefix,
        # Parameter help description
        [Parameter(Mandatory = $true)]
        [datetime]
        $Date
    )

    if (!(Test-Path -Path $ZipPath)) {
        New-Item -Path $ZipPath -ItemType Directory | Out-Null
        Write-Verbose "Created folder '$ZipPath'"
    }

    $timeString = $Date.ToString('yyyyMMdd')
    $zipName = "$($ZipPrefix)$($timeString).zip"
    $zipFile = Join-Path $ZipPath $zipName

    if (Test-Path -Path $zipFile) {
        throw "The file '$zipFile' already exists"
    }

    $zipFile
}

<#
.SYNOPSIS
check and remove files that have been archived

.DESCRIPTION
check and remove files that have been archived

.PARAMETER ZipFile
zip file name

.PARAMETER FilesToDelete
object containing files to delete

.PARAMETER WhatIf
switch to enable whatif

.EXAMPLE
An example

.NOTES
General notes
#>
function Remove-ArchivedFiles {
    [CmdletBinding()]
    [OutputType()]
    param (
        # zip file name
        [Parameter(Mandatory = $true)]
        [string]$ZipFile,
        # object containing files to delete
        [Parameter(Mandatory = $true)]
        [object]$FilesToDelete,
        # switch that enables whatif
        [Parameter(Mandatory = $false)]
        [switch]$WhatIf
    )
    
    #load the compression library to the current session
    $AssemblyName = 'System.IO.Compression.FileSystem'
    Add-Type -AssemblyName $AssemblyName | Out-Null
    #get information on the files in the zip
    $openZip = [System.IO.Compression.ZipFile]::OpenRead($ZipFile)
    $zipFileEntries = $openZip.Entries

    #match the files to delete with the files in the zip
    foreach($file in $FilesToDelete) {
        $check = $zipFileEntries | 
            Where-Object { $_.Name -eq $file.Name -and $_.Length -eq $file.Length }
        if ($null -ne $check) {
            $file | Remove-Item -Force -WhatIf:$WhatIf
        } else {
            Write-Error "'$($file.Name)' was not found in '$($ZipFile)'"
        }
    }
}

$Date = (Get-Date).AddDays(-$NumberOfDays)
$files = Get-ChildItem -Path $LogPath -File | 
    Where-Object { $_.LastWriteTime -lt $Date }
    
$zipParameters = @{
    ZipPath = $ZipPath
    ZipPrefix = $ZipPrefix
    Date = $Date
}
$ZipFile = Set-ArchiveFilePath @zipParameters

$files | Compress-Archive -DestinationPath $ZipFile

$RemoveFiles = @{
    ZipFile = $ZipFile
    FilesToDelete = $files
}
Remove-ArchivedFiles @RemoveFiles