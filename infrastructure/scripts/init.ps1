# Distributed System Automation Script (Windows/PowerShell)
# This script detects your local IP and updates the Nginx configuration.
# Usage: .\init.ps1 -Workers "192.168.1.11", "192.168.1.12"

param (
    [string[]]$Workers = @(),
    [string]$Join = "",
    [string]$ForceIP = ""
)

function Get-LocalIPs {
    $ips = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { 
        $_.InterfaceAlias -notmatch 'Loopback' -and 
        $_.InterfaceAlias -notmatch 'VirtualBox' -and 
        $_.InterfaceAlias -notmatch 'VMware' -and
        $_.IPAddress -notmatch '^169\.254\.'
    } | Select-Object -ExpandProperty IPAddress
    
    if (-not $ips) {
        $ips = @("127.0.0.1")
        Write-Host "[WAIT] Could not detect any valid local network IPs. Falling back to 127.0.0.1" -ForegroundColor Yellow
    }
    return $ips
}

$allLocalIps = Get-LocalIPs
$primaryIp = if ($ForceIP -ne "") { $ForceIP } else { $allLocalIps[0] }

Write-Host "[INFO] Detected Network Interfaces:" -ForegroundColor Cyan
foreach ($ip in $allLocalIps) {
    $prefix = if ($ip -eq $primaryIp) { " -> " } else { "    " }
    Write-Host "$prefix $ip" -ForegroundColor Gray
}
Write-Host "[INFO] Primary IP set to: $primaryIp" -ForegroundColor Green

# --- JOIN MODE (For Workers) ---
if ($Join -ne "") {
    Write-Host "[JOIN] Attempting to join Main Server at $Join..." -ForegroundColor Yellow
    
    try {
        $body = @{ ip = $primaryIp } | ConvertTo-Json
        $response = Invoke-RestMethod -Uri "http://$($Join):8080/api/nodes/register" -Method Post -Body $body -ContentType "application/json" -ErrorAction Stop
        Write-Host "[SUCCESS] $($response.message)" -ForegroundColor Green
        
        # Update local .env to point to Main Server's database
        $envPath = ".env"
        if (Test-Path $envPath) {
            $envContent = Get-Content $envPath
            $envContent = $envContent -replace '^DB_HOST=.*', "DB_HOST=$Join"
            $envContent | Set-Content $envPath
            Write-Host "[INFO] Updated .env: DB_HOST set to $Join" -ForegroundColor Gray
        }
    } catch {
        Write-Host "[ERROR] Could not register with Main Server. Is it running? Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "[FINISH] Worker setup complete!" -ForegroundColor Magenta
    Write-Host "Run 'docker compose -f compose.backend.yml up -d' to join the cluster." -ForegroundColor White
    exit
}

# --- MAIN SERVER MODE ---
# Prepare Worker Server string for Nginx
$workerString = ""
# If we have a nodes.json from dynamic registration, prioritize it
$nodesFile = "../../storage/app/nodes.json"
$dynamicWorkers = @()
if (Test-Path $nodesFile) {
    $dynamicWorkers = Get-Content $nodesFile | ConvertFrom-Json
}

$allWorkers = @($Workers) + @($dynamicWorkers)
$cleanWorkers = $allWorkers -split ',' | ForEach-Object { $_.Trim().Trim('"').Trim("'") } | Where-Object { $_ -ne "" } | Select-Object -Unique

if ($cleanWorkers.Count -gt 0) {
    Write-Host "[INFO] Aggregating $($cleanWorkers.Count) worker servers..." -ForegroundColor Cyan
    foreach ($wIP in $cleanWorkers) {
        $line = "        server " + $wIP + ":8000 max_fails=3 fail_timeout=30s;`n"
        $workerString += $line
        Write-Host "   - $wIP" -ForegroundColor Gray
    }
} else {
    Write-Host "[INFO] No external workers specified or registered." -ForegroundColor Gray
}

# Update nginx/nginx.conf from template
$templatePath = "../nginx/nginx.conf.template"
$nginxPath = "../nginx/nginx.conf"

if (Test-Path $templatePath) {
    $content = Get-Content $templatePath -Raw
    $content = $content.Replace('{{LOCAL_IP}}', $primaryIp)
    
    # Generate multi-allow block for Nginx
    $allowBlock = "            allow 127.0.0.1;`n"
    foreach ($ip in $allLocalIps) {
        $allowBlock += "            allow $ip;`n"
    }
    $content = $content.Replace('{{ALLOW_IPS}}', $allowBlock.TrimEnd())
    $content = $content.Replace('{{WORKER_SERVERS}}', $workerString.TrimEnd())
    
    $content | Set-Content $nginxPath -Encoding UTF8
    Write-Host "[SUCCESS] Generated $nginxPath from template." -ForegroundColor Green
} else {
    Write-Host "[ERROR] $templatePath not found." -ForegroundColor Red
}

Write-Host ""
Write-Host "[FINISH] Main Server setup complete!" -ForegroundColor Magenta
Write-Host "Run 'docker compose up -d' to start the system." -ForegroundColor White
Write-Host ("Access the system at http://" + $primaryIp + ":8080/api/data") -ForegroundColor Cyan
