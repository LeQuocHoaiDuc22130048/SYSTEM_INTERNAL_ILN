$ErrorActionPreference = "Stop"

function Get-ListenerProcessId([int]$Port) {
    $connection = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($null -eq $connection) {
        return $null
    }
    return [int]$connection.OwningProcess
}

function Get-ProcessCommandLine([int]$ProcessId) {
    $process = Get-CimInstance Win32_Process -Filter "ProcessId=$ProcessId" -ErrorAction SilentlyContinue
    if ($null -eq $process) {
        return ""
    }
    return [string]$process.CommandLine
}

function Stop-ProjectProcessOnPort([int]$Port, [string]$ExpectedText) {
    $pidOnPort = Get-ListenerProcessId $Port
    if ($null -eq $pidOnPort) {
        Write-Host "Port $Port is free."
        return
    }

    $commandLine = Get-ProcessCommandLine $pidOnPort
    if ($commandLine -notlike "*$ExpectedText*") {
        Write-Host "Port $Port is used by a non-project process. PID=$pidOnPort"
        return
    }

    Write-Host "Stopping project process on port $Port (PID $pidOnPort)..."
    Stop-Process -Id $pidOnPort -Force
}

Stop-ProjectProcessOnPort 8080 "SystemInternalApplication"
Stop-ProjectProcessOnPort 5000 "simple_face_ai_service.py"
