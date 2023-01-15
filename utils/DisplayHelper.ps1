function Show-White {
    Param(
        [Parameter(Mandatory=$true)][String]$Message
    )
    Write-Host $Message -ForegroundColor White
}
function Show-Red {
    Param(
        [Parameter(Mandatory=$true)][String]$Message
    )
    Write-Host $Message -ForegroundColor Red
}

function Show-Green {
    Param(
        [Parameter(Mandatory=$true)][String]$Message
    )
    Write-Host $Message -ForegroundColor Green
}

function Show-Yellow {
    Param(
        [Parameter(Mandatory=$true)][String]$Message
    )
    Write-Host $Message -ForegroundColor Yellow
}