# ============================================================
# MONARCH_CFO - Activation finale (token + Claude Desktop)
# Lance ce script UNE SEULE FOIS après le setup
# ============================================================

$Host.UI.RawUI.WindowTitle = "MONARCH_CFO - Activation"
$projectPath = $PSScriptRoot
$tokenFile = Join-Path $projectPath ".monarch_token_setup"

Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "   MONARCH_CFO - Activation                 " -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

# ── Etape 1 : Lire le token ──────────────────────────────────
if (-not (Test-Path $tokenFile)) {
    Write-Host "Fichier token introuvable. Re-lance depuis Cowork." -ForegroundColor Red
    Read-Host "Appuie sur Entree pour fermer"
    exit 1
}

$token = Get-Content $tokenFile -Raw
$token = $token.Trim()
Write-Host "[1/3] Token lu ($($token.Length) chars) OK" -ForegroundColor Green

# ── Etape 2 : Sauvegarder dans Windows Credential Manager ───
Write-Host "[2/3] Sauvegarde dans Windows Credential Manager..." -ForegroundColor White

# Trouver python
$pythonCmd = $null
foreach ($cmd in @("python", "python3", "py")) {
    try {
        $ver = & $cmd --version 2>&1
        if ($ver -match "Python") { $pythonCmd = $cmd; break }
    } catch {}
}

if (-not $pythonCmd) {
    Write-Host "    Python non trouve ! Installe Python 3.10+ d'abord." -ForegroundColor Red
    exit 1
}

# Sauvegarder via Python keyring (utilise Windows Credential Manager automatiquement)
$saveScript = @"
import sys
sys.path.insert(0, r'$projectPath\src')
import keyring
SERVICE = 'com.mcp.monarch-mcp-server'
USERNAME = 'monarch-token'
TOKEN = '$token'
keyring.set_password(SERVICE, USERNAME, TOKEN)
loaded = keyring.get_password(SERVICE, USERNAME)
if loaded == TOKEN:
    print('KEYRING_OK:' + str(len(loaded)))
else:
    print('KEYRING_FAIL')
"@

$result = & $pythonCmd -c $saveScript 2>&1
if ($result -like "KEYRING_OK*") {
    Write-Host "    Token sauvegarde dans Credential Manager" -ForegroundColor Green
    # Supprimer le fichier temporaire du token
    Remove-Item $tokenFile -Force
    Write-Host "    Fichier temporaire supprime" -ForegroundColor DarkGray
} else {
    Write-Host "    Erreur keyring: $result" -ForegroundColor Red
    Write-Host "    Tentative via cmdkey..." -ForegroundColor Yellow
    cmdkey /generic:"com.mcp.monarch-mcp-server:monarch-token" /user:"monarch-token" /pass:"$token" | Out-Null
    Write-Host "    Sauvegarde cmdkey effectuee" -ForegroundColor Green
    Remove-Item $tokenFile -Force
}

# ── Etape 3 : Configurer claude_desktop_config.json ─────────
Write-Host "[3/3] Configuration de Claude Desktop..." -ForegroundColor White

$claudeConfigDir  = "$env:APPDATA\Claude"
$claudeConfigFile = "$claudeConfigDir\claude_desktop_config.json"
$serverScript     = "$projectPath\src\monarch_mcp_server\server.py"

# Chercher uv
$uvPath = $null
foreach ($candidate in @("uv", "$env:USERPROFILE\.local\bin\uv.exe", "$env:USERPROFILE\.cargo\bin\uv.exe", "C:\Users\$env:USERNAME\.local\bin\uv.exe")) {
    try {
        $v = & $candidate --version 2>&1
        if ($v -match "uv") { $uvPath = $candidate; break }
    } catch {}
}

if ($uvPath) {
    $serverBlock = [PSCustomObject]@{
        command = $uvPath
        args    = @("run","--with","mcp[cli]","--with-editable",$projectPath,"mcp","run",$serverScript)
    }
} else {
    $serverBlock = [PSCustomObject]@{
        command = $pythonCmd
        args    = @("-m","mcp","run",$serverScript)
        env     = [PSCustomObject]@{ PYTHONPATH = "$projectPath\src" }
    }
}

if (-not (Test-Path $claudeConfigDir)) {
    New-Item -ItemType Directory -Path $claudeConfigDir -Force | Out-Null
}

$config = [PSCustomObject]@{ mcpServers = [PSCustomObject]@{ "Monarch Money" = $serverBlock } }

# Fusionner si config existante
if (Test-Path $claudeConfigFile) {
    try {
        $existing = Get-Content $claudeConfigFile -Raw | ConvertFrom-Json
        if (-not $existing.PSObject.Properties['mcpServers']) {
            $existing | Add-Member -NotePropertyName mcpServers -NotePropertyValue ([PSCustomObject]@{})
        }
        $existing.mcpServers | Add-Member -NotePropertyName "Monarch Money" -NotePropertyValue $serverBlock -Force
        $existing | ConvertTo-Json -Depth 10 | Set-Content $claudeConfigFile -Encoding UTF8
    } catch {
        $config | ConvertTo-Json -Depth 10 | Set-Content $claudeConfigFile -Encoding UTF8
    }
} else {
    $config | ConvertTo-Json -Depth 10 | Set-Content $claudeConfigFile -Encoding UTF8
}

Write-Host "    Claude Desktop configure : $claudeConfigFile" -ForegroundColor Green
Write-Host "    Chemin du projet : $projectPath" -ForegroundColor DarkGray

# ── Resultat ─────────────────────────────────────────────────
Write-Host ""
Write-Host "=============================================" -ForegroundColor Green
Write-Host "   ACTIVATION TERMINEE !                    " -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green
Write-Host ""
Write-Host "  PROCHAINE ETAPE (une seule fois) :" -ForegroundColor White
Write-Host "  Ferme et relance Claude Desktop." -ForegroundColor Yellow
Write-Host ""
Write-Host "  Ensuite dis a Claude :" -ForegroundColor White
Write-Host "  'Montre-moi tous mes comptes Monarch Money'" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Le token est sauvegarde de facon permanente." -ForegroundColor DarkGray
Write-Host "  Tu n'auras plus jamais a refaire cette etape." -ForegroundColor DarkGray
Write-Host ""
Read-Host "Appuie sur Entree pour fermer"
