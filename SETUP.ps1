# ============================================================
# MONARCH_CFO - Script de configuration automatique
# Double-clique sur SETUP.bat pour lancer ce script
# ============================================================

$Host.UI.RawUI.WindowTitle = "MONARCH_CFO - Setup"
$projectPath = $PSScriptRoot

Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "   MONARCH_CFO - Configuration automatique  " -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Dossier du projet : $projectPath" -ForegroundColor Yellow
Write-Host ""

# ── Etape 1 : Verifier Python ────────────────────────────────
Write-Host "[1/4] Verification de Python..." -ForegroundColor White

$pythonCmd = $null
foreach ($cmd in @("python", "python3", "py")) {
    try {
        $ver = & $cmd --version 2>&1
        if ($ver -match "Python (\d+)\.(\d+)") {
            $major = [int]$Matches[1]
            $minor = [int]$Matches[2]
            if ($major -ge 3 -and $minor -ge 10) {
                $pythonCmd = $cmd
                Write-Host "    OK - $ver trouve" -ForegroundColor Green
                break
            } else {
                Write-Host "    $ver trouve mais trop ancien (besoin 3.10+)" -ForegroundColor Yellow
            }
        }
    } catch {}
}

if (-not $pythonCmd) {
    Write-Host ""
    Write-Host "    ERREUR : Python 3.10+ non trouve !" -ForegroundColor Red
    Write-Host "    Telecharge Python ici : https://www.python.org/downloads/" -ForegroundColor Yellow
    Write-Host "    Coche 'Add Python to PATH' pendant l'installation." -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Appuie sur Entree pour ouvrir la page de telechargement"
    Start-Process "https://www.python.org/downloads/"
    exit 1
}

# ── Etape 2 : Installer les dependances ─────────────────────
Write-Host ""
Write-Host "[2/4] Installation des dependances Python..." -ForegroundColor White

Set-Location $projectPath

& $pythonCmd -m pip install --upgrade pip --quiet
& $pythonCmd -m pip install -r requirements.txt --quiet

if ($LASTEXITCODE -eq 0) {
    Write-Host "    OK - Toutes les dependances installee" -ForegroundColor Green
} else {
    Write-Host "    Erreur lors de l'installation des dependances" -ForegroundColor Red
    Read-Host "Appuie sur Entree pour continuer quand meme"
}

# ── Etape 3 : Configurer Claude Desktop ─────────────────────
Write-Host ""
Write-Host "[3/4] Configuration de Claude Desktop..." -ForegroundColor White

$claudeConfigDir = "$env:APPDATA\Claude"
$claudeConfigFile = "$claudeConfigDir\claude_desktop_config.json"
$serverScript = "$projectPath\src\monarch_mcp_server\server.py"

# Trouver uv
$uvPath = $null
foreach ($candidate in @("uv", "$env:USERPROFILE\.local\bin\uv", "$env:USERPROFILE\.cargo\bin\uv")) {
    try {
        $uvVer = & $candidate --version 2>&1
        if ($uvVer -match "uv") {
            $uvPath = $candidate
            break
        }
    } catch {}
}

# Construire la config MCP
if ($uvPath) {
    Write-Host "    uv trouve : $uvPath" -ForegroundColor Green
    $mcpConfig = @{
        mcpServers = @{
            "Monarch Money" = @{
                command = $uvPath
                args    = @(
                    "run",
                    "--with", "mcp[cli]",
                    "--with-editable", $projectPath,
                    "mcp",
                    "run",
                    $serverScript
                )
            }
        }
    }
} else {
    Write-Host "    uv non trouve, utilisation de python directement" -ForegroundColor Yellow
    $mcpConfig = @{
        mcpServers = @{
            "Monarch Money" = @{
                command = $pythonCmd
                args    = @("-m", "mcp", "run", $serverScript)
                env     = @{
                    PYTHONPATH = "$projectPath\src"
                }
            }
        }
    }
}

# Creer le dossier si necessaire
if (-not (Test-Path $claudeConfigDir)) {
    New-Item -ItemType Directory -Path $claudeConfigDir -Force | Out-Null
}

# Fusionner avec une config existante si elle existe
if (Test-Path $claudeConfigFile) {
    try {
        $existingConfig = Get-Content $claudeConfigFile -Raw | ConvertFrom-Json
        if (-not $existingConfig.mcpServers) {
            $existingConfig | Add-Member -NotePropertyName mcpServers -NotePropertyValue @{}
        }
        $existingConfig.mcpServers | Add-Member -NotePropertyName "Monarch Money" -NotePropertyValue $mcpConfig.mcpServers."Monarch Money" -Force
        $existingConfig | ConvertTo-Json -Depth 10 | Set-Content $claudeConfigFile -Encoding UTF8
        Write-Host "    OK - Config existante mise a jour" -ForegroundColor Green
    } catch {
        # En cas d'erreur, on ecrit une config propre
        $mcpConfig | ConvertTo-Json -Depth 10 | Set-Content $claudeConfigFile -Encoding UTF8
        Write-Host "    OK - Nouvelle config creee" -ForegroundColor Green
    }
} else {
    $mcpConfig | ConvertTo-Json -Depth 10 | Set-Content $claudeConfigFile -Encoding UTF8
    Write-Host "    OK - Config Claude Desktop creee" -ForegroundColor Green
}

Write-Host "    Fichier : $claudeConfigFile" -ForegroundColor DarkGray

# ── Etape 4 : Authentification Monarch Money ─────────────────
Write-Host ""
Write-Host "[4/4] Authentification Monarch Money" -ForegroundColor White
Write-Host ""
Write-Host "    Tu vas maintenant entrer tes identifiants Monarch Money." -ForegroundColor Yellow
Write-Host "    Ton mot de passe ne sera PAS sauvegarde - seulement un token d'acces." -ForegroundColor Yellow
Write-Host ""
Read-Host "    Appuie sur Entree pour commencer la connexion"

Set-Location $projectPath
& $pythonCmd login_setup.py

# ── Fin ───────────────────────────────────────────────────────
Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "   Setup termine !                          " -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  PROCHAINE ETAPE :" -ForegroundColor White
Write-Host "  Redémarre Claude Desktop pour activer le serveur Monarch Money." -ForegroundColor Yellow
Write-Host ""
Write-Host "  Une fois redémarre, tu peux dire a Claude :" -ForegroundColor White
Write-Host "  'Montre-moi tous mes comptes Monarch Money'" -ForegroundColor Green
Write-Host ""
Read-Host "Appuie sur Entree pour fermer"
