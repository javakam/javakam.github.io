[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [string]$RepoRoot,

    [int[]]$Ports = @(4173),

    [int[]]$ServerPid = @(),

    [string[]]$TempPath = @()
)

$ErrorActionPreference = "Stop"

function Get-FullPath([string]$Path) {
    return [System.IO.Path]::GetFullPath((Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path).TrimEnd("\")
}

function Test-Within([string]$Path, [string]$Parent) {
    $candidate = [System.IO.Path]::GetFullPath($Path).TrimEnd("\")
    $parentPath = $Parent.TrimEnd("\")
    $prefix = $parentPath + "\"
    return $candidate.Equals($parentPath, [System.StringComparison]::OrdinalIgnoreCase) -or
        $candidate.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)
}

$root = Get-FullPath $RepoRoot
$tempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd("\")
$knownServers = "(?i)(http\.server|hugo(?:\.exe)?\s+server|vite(?:\.js)?)"
$stopped = [System.Collections.Generic.HashSet[int]]::new()
$trackedTargets = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

function Stop-OwnedServer([int]$ProcessId, [string]$Reason) {
    if ($stopped.Contains($ProcessId)) {
        return
    }

    $process = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
    if ($null -eq $process) {
        return
    }

    if ($PSCmdlet.ShouldProcess("$($process.ProcessName) [$ProcessId]", "Stop owned development server ($Reason)")) {
        Stop-Process -Id $ProcessId -Force
        $stopped.Add($ProcessId) | Out-Null
        Write-Output "Stopped $($process.ProcessName) [$ProcessId]"
    }
}

$connections = @()
try {
    $connections = @(Get-NetTCPConnection -State Listen -ErrorAction Stop | Where-Object { $Ports -contains $_.LocalPort })
} catch {
    Write-Warning "Could not inspect listeners: $($_.Exception.Message)"
}

foreach ($connection in $connections) {
    $processInfo = Get-CimInstance Win32_Process -Filter "ProcessId = $($connection.OwningProcess)"
    if ($null -eq $processInfo) {
        continue
    }

    $commandLine = [string]$processInfo.CommandLine
    $isKnownServer = $commandLine -match $knownServers
    $pointsToRepo = $commandLine.IndexOf($root, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
    $explicit = $ServerPid -contains [int]$connection.OwningProcess

    if ($isKnownServer -and $pointsToRepo) {
        Stop-OwnedServer ([int]$connection.OwningProcess) "port $($connection.LocalPort)"
    } else {
        $recorded = if ($explicit) { " (recorded PID, but ownership could not be verified)" } else { "" }
        Write-Warning "Leaving unrelated listener $($connection.LocalAddress):$($connection.LocalPort) owned by PID $($connection.OwningProcess)$recorded"
    }
}

foreach ($pidValue in $ServerPid) {
    if (-not $stopped.Contains($pidValue)) {
        $processInfo = Get-CimInstance Win32_Process -Filter "ProcessId = $pidValue"
        if ($null -eq $processInfo) {
            continue
        }

        $commandLine = [string]$processInfo.CommandLine
        if (($commandLine -match $knownServers) -and
            ($commandLine.IndexOf($root, [System.StringComparison]::OrdinalIgnoreCase) -ge 0)) {
            Stop-OwnedServer $pidValue "recorded PID"
        } else {
            Write-Warning "Leaving recorded PID $pidValue because it is not a known server for this repository"
        }
    }
}

$repoTargets = @(
    "public",
    "resources",
    ".hugo_build.lock",
    "assets/jsconfig.json",
    ".playwright-cli"
)

foreach ($relativePath in $repoTargets) {
    $target = [System.IO.Path]::GetFullPath((Join-Path $root $relativePath)).TrimEnd("\")
    if (-not (Test-Within $target $root)) {
        throw "Refusing to remove a path outside the repository: $target"
    }

    $tracked = @(git -C $root ls-files -- $relativePath)
    if ($tracked.Count -gt 0) {
        $trackedTargets.Add($target) | Out-Null
        Write-Warning "Leaving tracked path: $target"
        continue
    }

    if (Test-Path -LiteralPath $target) {
        if ($PSCmdlet.ShouldProcess($target, "Remove generated Hugo artifact")) {
            Remove-Item -LiteralPath $target -Recurse -Force
            Write-Output "Removed $target"
        }
    }
}

foreach ($path in $TempPath) {
    $target = [System.IO.Path]::GetFullPath($path).TrimEnd("\")
    if (-not (Test-Within $target $tempRoot) -or $target.Equals($tempRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove a temporary path outside the system temp directory: $target"
    }

    if (Test-Path -LiteralPath $target -PathType Container) {
        if ($PSCmdlet.ShouldProcess($target, "Remove registered temporary directory")) {
            Remove-Item -LiteralPath $target -Recurse -Force
            Write-Output "Removed $target"
        }
    } else {
        Write-Warning "Temporary path does not exist or is not a directory: $target"
    }
}

if (-not $WhatIfPreference) {
    $remaining = @(
        $repoTargets |
            ForEach-Object { [System.IO.Path]::GetFullPath((Join-Path $root $_)).TrimEnd("\") } |
            Where-Object { -not $trackedTargets.Contains($_) -and (Test-Path -LiteralPath $_) }
    )
    if ($remaining.Count -gt 0) {
        throw "Cleanup incomplete; generated paths remain: $($remaining -join ', ')"
    }
}

Write-Output "Hugo cleanup complete. Stopped $($stopped.Count) owned server(s)."
