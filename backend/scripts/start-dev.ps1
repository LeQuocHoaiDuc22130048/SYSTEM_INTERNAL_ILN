param(
    [switch]$Restart
)

$ErrorActionPreference = "Stop"

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$FaceAiService = if ([string]::IsNullOrWhiteSpace($env:FACE_AI_SERVICE)) { "simple" } else { $env:FACE_AI_SERVICE.ToLowerInvariant() }
$AiScript = if ($FaceAiService -eq "real") {
    Join-Path $ProjectRoot "face_ai_service\real_face_ai_service.py"
} else {
    Join-Path $ProjectRoot "face_ai_service\simple_face_ai_service.py"
}

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
        return
    }

    $commandLine = Get-ProcessCommandLine $pidOnPort
    if ($commandLine -notlike "*$ExpectedText*") {
        throw "Port $Port is already used by another process. PID=$pidOnPort CommandLine=$commandLine"
    }

    if ($Restart) {
        Write-Host "Stopping existing project process on port $Port (PID $pidOnPort)..."
        Stop-Process -Id $pidOnPort -Force
        Start-Sleep -Seconds 1
        return
    }

    throw "Port $Port is already used by this project (PID $pidOnPort). Re-run with -Restart or stop it with scripts\stop-dev.ps1."
}

Set-Location $ProjectRoot

Stop-ProjectProcessOnPort 8080 "SystemInternalApplication"

$aiPid = Get-ListenerProcessId 5000
if ($null -eq $aiPid) {
    Write-Host "Starting local Face AI service '$FaceAiService' on http://localhost:5000..."
    Start-Process -FilePath "python" -ArgumentList "`"$AiScript`"" -WorkingDirectory $ProjectRoot -WindowStyle Hidden
    Start-Sleep -Seconds 2
} else {
    $aiCommandLine = Get-ProcessCommandLine $aiPid
    $expectedScriptName = Split-Path $AiScript -Leaf
    if ($aiCommandLine -notlike "*$expectedScriptName*") {
        throw "Port 5000 is already used by another process. PID=$aiPid CommandLine=$aiCommandLine"
    }
    Write-Host "Local Face AI service is already running on port 5000 (PID $aiPid)."
}

if ($FaceAiService -eq "real") {
    $env:FACE_RECOGNITION_SKIP_DUPLICATE_CHECK = "false"
}

Write-Host "Starting Spring Boot backend on http://localhost:8080..."
& .\mvnw.cmd spring-boot:run
