function Resolve-ThemeGodotExecutable {
    param(
        [string]$GodotExecutable = ""
    )

    $candidate = $GodotExecutable
    if ([string]::IsNullOrWhiteSpace($candidate)) {
        $candidate = [Environment]::GetEnvironmentVariable("GODOT4_EXECUTABLE", "Process")
    }
    if ([string]::IsNullOrWhiteSpace($candidate)) {
        $candidate = [Environment]::GetEnvironmentVariable("GODOT_EXECUTABLE", "Process")
    }
    if ([string]::IsNullOrWhiteSpace($candidate)) {
        $runningGodot = Get-Process | Where-Object {
            $_.ProcessName -like "Godot*" `
                -and $_.ProcessName -notlike "godot-ai*" `
                -and $_.Path
        } | Select-Object -First 1
        if ($runningGodot) {
            $candidate = $runningGodot.Path
        }
    }
    if ([string]::IsNullOrWhiteSpace($candidate)) {
        foreach ($commandName in @("godot", "godot4")) {
            $command = Get-Command $commandName -ErrorAction SilentlyContinue
            if ($command) {
                $candidate = $command.Source
                break
            }
        }
    }
    if ([string]::IsNullOrWhiteSpace($candidate) -or -not (Test-Path -LiteralPath $candidate)) {
        throw "Godot 4.7 was not found. Start Godot Editor, add godot/godot4 to PATH, set GODOT4_EXECUTABLE, or pass -GodotExecutable."
    }

    $candidate = (Resolve-Path -LiteralPath $candidate).Path
    $consoleCandidate = Join-Path `
        (Split-Path -Parent $candidate) `
        (([System.IO.Path]::GetFileNameWithoutExtension($candidate)) + "_console.exe")
    if (Test-Path -LiteralPath $consoleCandidate) {
        $candidate = $consoleCandidate
    }

    $godotVersion = & $candidate --version 2>$null
    if ($LASTEXITCODE -ne 0 -or $godotVersion -notmatch '^4\.7(\.|$)') {
        throw "A real Godot 4.7 executable is required; the godot-ai MCP server is not Godot. Found: '$godotVersion'."
    }

    return $candidate
}
