# ============================================================
#  auto-mirror-watch.ps1
#  Watches for connected phones and auto-mirrors each new one
#  in its own scrcpy window. Keeps running in the background.
#
#  On start it asks for a video quality (Max / Mid / Min).
#  The choice is saved to quality.cfg and reused next time.
#  Run it again any time to change the quality.
#
#  Stop it any time with Ctrl+C (or just close the window).
# ============================================================

$PollSeconds = 2        # how often to re-scan for new devices
$LaunchGapSeconds = 6   # wait between starting scrcpy windows
$PortBase = 27183       # first scrcpy local port to assign
$PortMax = 27199        # last scrcpy local port to assign

# Never let a stray error kill the watcher loop
$ErrorActionPreference = 'Continue'

# Always work from this script's own folder so adb/scrcpy are found
Set-Location -Path $PSScriptRoot

$adb        = Join-Path $PSScriptRoot "adb.exe"
$scrcpy     = Join-Path $PSScriptRoot "scrcpy.exe"
$server     = Join-Path $PSScriptRoot "scrcpy-server"
$serverZip  = Join-Path $PSScriptRoot "scrcpy-server.zip"
$cfgFile    = Join-Path $PSScriptRoot "quality.cfg"
$logDir     = Join-Path $PSScriptRoot "logs"

if (-not (Test-Path -LiteralPath $server) -and (Test-Path -LiteralPath $serverZip)) {
    Copy-Item -LiteralPath $serverZip -Destination $server
}

foreach ($tool in @($adb, $scrcpy, $server)) {
    if (-not (Test-Path -LiteralPath $tool)) {
        Write-Host ("[fatal] Missing required file: " + $tool)
        exit 1
    }
}

if (-not (Test-Path -LiteralPath $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
}

# --- Quality presets ---------------------------------------
# Each preset = how big / how smooth / how much bandwidth.
$presets = @{
    'max' = @{ Label = "MAX  (native resolution, 16 Mbps, 60 fps)"; Size = 0;    Bitrate = "16M"; Fps = 60 }
    'mid' = @{ Label = "MID  (1280px, 8 Mbps, 60 fps)";             Size = 1280; Bitrate = "8M";  Fps = 60 }
    'min' = @{ Label = "MIN  (800px, 4 Mbps, 30 fps)";              Size = 800;  Bitrate = "4M";  Fps = 30 }
}

# Read the previously saved quality (default = mid the first time)
$saved = 'mid'
if (Test-Path $cfgFile) {
    $val = (Get-Content $cfgFile -Raw).Trim().ToLower()
    if ($presets.ContainsKey($val)) { $saved = $val }
}

# --- Quality menu ------------------------------------------
Write-Host "================================================"
Write-Host " scrcpy auto-mirror - choose video quality"
Write-Host "================================================"
Write-Host ("   1)  " + $presets['max'].Label)
Write-Host ("   2)  " + $presets['mid'].Label)
Write-Host ("   3)  " + $presets['min'].Label)
Write-Host ""
Write-Host (" Current saved quality: " + $saved.ToUpper())
Write-Host " Press 1 / 2 / 3 to pick, or just press Enter to keep current."
$choice = Read-Host " Your choice"

switch ($choice.Trim()) {
    '1'     { $saved = 'max' }
    '2'     { $saved = 'mid' }
    '3'     { $saved = 'min' }
    default { }   # empty / anything else -> keep current
}

# Save the choice so next run remembers it
Set-Content -Path $cfgFile -Value $saved -Encoding ASCII

$q = $presets[$saved]
Write-Host ""
Write-Host (" Using quality: " + $saved.ToUpper() + "  ->  " + $q.Label)
Write-Host ""

# Make sure the adb server is up before we start polling
& $adb start-server 2>$null | Out-Null

function Start-ScrcpyMirror {
    param(
        [Parameter(Mandatory = $true)][string]$Serial,
        [Parameter(Mandatory = $true)]$Quality,
        [Parameter(Mandatory = $true)][int]$Port
    )

    $safeSerial = ($Serial -replace '[^\w.-]', '_')
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $stdoutLog = Join-Path $logDir ("scrcpy-$safeSerial-$stamp.out.log")
    $stderrLog = Join-Path $logDir ("scrcpy-$safeSerial-$stamp.err.log")

    $argList = @("-s", $Serial, "--window-title=$Serial", "--stay-awake", "--port=$Port",
                 "--max-fps=$($Quality.Fps)", "--video-bit-rate=$($Quality.Bitrate)")
    if ($Quality.Size -gt 0) { $argList += "--max-size=$($Quality.Size)" }

    $proc = Start-Process -FilePath $scrcpy `
        -ArgumentList $argList `
        -WorkingDirectory $PSScriptRoot `
        -RedirectStandardOutput $stdoutLog `
        -RedirectStandardError $stderrLog `
        -PassThru

    Start-Sleep -Milliseconds 800
    if ($proc.HasExited) {
        Write-Host ("[!] " + (Get-Date -Format 'HH:mm:ss') + "  scrcpy exited immediately for $Serial")
        Write-Host ("    stderr log: " + $stderrLog)
        Write-Host ("    stdout log: " + $stdoutLog)

        $details = @()
        if (Test-Path -LiteralPath $stderrLog) {
            $details += Get-Content -LiteralPath $stderrLog -Tail 6
        }
        if (Test-Path -LiteralPath $stdoutLog) {
            $details += Get-Content -LiteralPath $stdoutLog -Tail 6
        }
        foreach ($line in $details) {
            if (-not [string]::IsNullOrWhiteSpace($line)) {
                Write-Host ("    " + $line)
            }
        }

        return $null
    }

    Write-Host ("    port: " + $Port)
    Write-Host ("    logs: " + $stderrLog)
    return $proc
}

function Get-FreeScrcpyPort {
    param(
        [Parameter(Mandatory = $true)]$AssignedPorts
    )

    for ($candidate = $PortBase; $candidate -le $PortMax; $candidate++) {
        if (-not $AssignedPorts.ContainsValue($candidate)) {
            return $candidate
        }
    }

    return $null
}

# Remember which serials we've already launched (and their process)
$mirrored = @{}
$portsBySerial = @{}
$lastLaunchAt = [DateTime]::MinValue

# Heartbeat: print "still watching" once in a while so you know it's alive
$tick      = 0
$beatEvery = [Math]::Max(1, [int](30 / $PollSeconds))   # ~every 30 seconds

Write-Host "================================================"
Write-Host " Watcher running. Plug in a phone to auto-mirror."
Write-Host " Press Ctrl+C or close this window to stop."
Write-Host "================================================"
Write-Host ""

while ($true) {
    try {
        # Get current device list from adb
        $lines = & $adb devices 2>$null

        $current = @{}
        $launchedThisPass = $false
        foreach ($line in $lines) {
            # Lines look like:  R5CRB06E9XX<TAB>device
            if ($line -match '^(\S+)\s+(device|unauthorized|offline)\s*$') {
                $serial = $matches[1]
                $status = $matches[2]
                $current[$serial] = $status

                if ($status -eq 'device' -and -not $mirrored.ContainsKey($serial)) {
                    if ($launchedThisPass) {
                        continue
                    }

                    $secondsSinceLaunch = ((Get-Date) - $lastLaunchAt).TotalSeconds
                    if ($secondsSinceLaunch -lt $LaunchGapSeconds) {
                        continue
                    }

                    $port = Get-FreeScrcpyPort -AssignedPorts $portsBySerial
                    if ($null -eq $port) {
                        Write-Host ("[!] " + (Get-Date -Format 'HH:mm:ss') + "  No free scrcpy port left for $serial")
                        continue
                    }

                    Write-Host ("[+] " + (Get-Date -Format 'HH:mm:ss') + "  New device: $serial  -> starting mirror")
                    $portsBySerial[$serial] = $port
                    $lastLaunchAt = Get-Date
                    $proc = Start-ScrcpyMirror -Serial $serial -Quality $q -Port $port
                    if ($null -ne $proc) {
                        $mirrored[$serial] = $proc
                        $launchedThisPass = $true
                    }
                    else {
                        $portsBySerial.Remove($serial)
                    }
                }
                elseif ($status -eq 'unauthorized') {
                    Write-Host ("[!] " + (Get-Date -Format 'HH:mm:ss') + "  $serial is UNAUTHORIZED - tap 'Allow USB debugging' on the phone (and tick 'Always allow')")
                }
            }
        }

        # Clean up devices that were unplugged, so re-plugging mirrors again
        foreach ($serial in @($mirrored.Keys)) {
            if (-not $current.ContainsKey($serial)) {
                Write-Host ("[-] " + (Get-Date -Format 'HH:mm:ss') + "  Device removed: $serial")
                $mirrored.Remove($serial)
                $portsBySerial.Remove($serial)
            }
            elseif ($mirrored[$serial].HasExited) {
                # User closed the scrcpy window manually -> allow re-mirror later
                $mirrored.Remove($serial)
                $portsBySerial.Remove($serial)
            }
        }

        # Heartbeat so you can tell the watcher is still alive
        $tick++
        if ($tick % $beatEvery -eq 0) {
            $count = $mirrored.Count
            Write-Host ("    " + (Get-Date -Format 'HH:mm:ss') + "  watching... ($count mirrored) - waiting for new devices")
        }
    }
    catch {
        # Swallow any transient error (e.g. adb hiccup during replug) and keep going
        Write-Host ("[err] " + (Get-Date -Format 'HH:mm:ss') + "  " + $_.Exception.Message + "  (continuing)")
    }

    Start-Sleep -Seconds $PollSeconds
}
