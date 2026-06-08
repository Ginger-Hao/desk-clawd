# find-esp32.ps1 — 自动扫描局域网找到 ESP32 红绿灯并更新 Claude Code hooks
# 用法: 连上手机热点后，在 PowerShell 里运行:  .\find-esp32.ps1
#       或任意目录运行:  powershell -File 路径\find-esp32.ps1

$settingsPath = "$env:USERPROFILE\.claude\settings.json"
$timeoutSec   = 2   # 每个 IP 的超时秒数
$jobs         = @() # 并行任务的列表
$found        = $false

# ── 快速检测: 上次用的 IP 还能通吗？ ────────────────────────────
Write-Host "🔍 检查上次使用的 IP 是否仍有效..." -ForegroundColor Cyan
$lastIP = Select-String -Path $settingsPath -Pattern '\d+\.\d+\.\d+\.\d+' |
          Select-Object -First 1 |
          ForEach-Object { $_.Matches.Value }

if ($lastIP) {
    try {
        $r = Invoke-WebRequest -Uri "http://$lastIP/light?state=idle" -TimeoutSeconds 2 -ErrorAction Stop
        if ($r.StatusCode -eq 200) {
            Write-Host "  ✅ $lastIP 仍然有效，无需更新" -ForegroundColor Green
            $found = $true
        }
    } catch {
        Write-Host "  ❌ $lastIP 已失效，开始扫描..." -ForegroundColor Yellow
    }
}

# ── 扫描局域网 ────────────────────────────────────────────────────
if (-not $found) {
    # 获取当前网段的 IP 前缀 (比如 192.168.x 或 10.181.x)
    $localIP = (Get-NetIPAddress -AddressFamily IPv4 |
                Where-Object { $_.InterfaceAlias -notlike "*Loopback*" -and $_.PrefixOrigin -eq "Dhcp" } |
                Select-Object -First 1).IPAddress

    if (-not $localIP) {
        # fallback: 取第一个非回环 IPv4
        $localIP = (Get-NetIPAddress -AddressFamily IPv4 |
                    Where-Object { $_.InterfaceAlias -notlike "*Loopback*" } |
                    Select-Object -First 1).IPAddress
    }

    $prefix = $localIP.Substring(0, $localIP.LastIndexOf('.'))
    Write-Host "📡 本机 IP: $localIP  →  扫描 $prefix.1 ~ $prefix.254" -ForegroundColor Cyan
    Write-Host "⏳ 正在扫描，约需 $($timeoutSec * 2) 秒..." -ForegroundColor Cyan

    # 并行 ping + HTTP 检测
    $scriptBlock = {
        param($ip, $timeoutSec)
        try {
            $r = Invoke-WebRequest -Uri "http://$ip/light?state=idle" -TimeoutSeconds $timeoutSec -ErrorAction Stop
            if ($r.StatusCode -eq 200) { return $ip }
        } catch {}
        return $null
    }

    for ($i = 1; $i -le 254; $i++) {
        $testIP = "$prefix.$i"
        $jobs += Start-Job -ScriptBlock $scriptBlock -ArgumentList $testIP, $timeoutSec
        if ($jobs.Count -ge 50) {  # 每 50 个一批，防止内存爆炸
            $jobs | Wait-Job -Timeout 10 | Out-Null
            $results = $jobs | Receive-Job
            $jobs = @()
            foreach ($r in $results) {
                if ($r) {
                    $found = $r
                    break
                }
            }
            if ($found) { break }
            $jobs = @($jobs | Where-Object { $_.State -eq 'Running' })
        }
    }

    # 等剩余的任务完成
    if ($jobs.Count -gt 0) {
        $jobs | Wait-Job -Timeout 15 | Out-Null
        $results = $jobs | Receive-Job
        foreach ($r in $results) {
            if ($r) { $found = $r; break }
        }
        $jobs | Remove-Job -Force -ErrorAction SilentlyContinue
    }

    # ── 更新 settings.json ────────────────────────────────────
    if ($found) {
        $content = Get-Content $settingsPath -Raw
        $content = $content -replace '\d+\.\d+\.\d+\.\d+(?=/light)', $found
        Set-Content $settingsPath $content
        Write-Host ""
        Write-Host "  ✅ 发现 ESP32 红绿灯！IP: $found" -ForegroundColor Green
        Write-Host "  ✅ 已自动更新 settings.json" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "  ❌ 没找到 ESP32" -ForegroundColor Red
        Write-Host "  💡 请确认:" -ForegroundColor Yellow
        Write-Host "     1. 电脑已连上手机热点"
        Write-Host "     2. ESP32 已通电启动"
        Write-Host "     3. 防火墙没有拦截"
    }
}
