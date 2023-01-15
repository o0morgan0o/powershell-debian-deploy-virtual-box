
function Invoke-BashFunction {
    Param(
        [Parameter(Mandatory=$true)][String]$SshSessionId,
        [Parameter(Mandatory=$true)][String]$CommandToExecute,
        [Parameter()][Int16]$Timeout = 60
    )
    $CommandAsString = $CommandToExecute
    Write-Host "COMMAND: $CommandAsString" -ForegroundColor Red -BackgroundColor Yellow
    $result = Invoke-SSHCommand -SessionId $SshSessionId -Command $CommandToExecute -TimeOut $Timeout
    $resultOutput = $result.Output
    $resultStatus = $result.ExitStatus
    if( $resultStatus -eq 0 ){
        $global:operationSuccessCounter++
    }else {
        $global:operationErrorCounter++
        $global:operationErrorCommands += $CommandAsString
    }
    Write-Output $resultOutput
    Write-Host "OUTPUT ($resultStatus):" -ForegroundColor Red
    Write-Host ""
}

