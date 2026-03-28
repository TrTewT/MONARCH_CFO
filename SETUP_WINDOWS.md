# 🪟 Guide de configuration — Windows

Ce guide explique comment configurer le **Monarch Money MCP Server** sur Windows, étape par étape.

---

## Prérequis

- **Python 3.12+** → [python.org/downloads](https://www.python.org/downloads/)
- **uv** (gestionnaire de paquets rapide) → [docs.astral.sh/uv](https://docs.astral.sh/uv/getting-started/installation/)
- **Un compte Monarch Money** → [monarchmoney.com](https://www.monarchmoney.com)
- **Claude Desktop** installé

---

## Étape 1 — Cloner le repo

```powershell
git clone https://github.com/TrTewT/MONARCH_CFO.git
cd MONARCH_CFO
```

---

## Étape 2 — Installer les dépendances

```powershell
pip install -r requirements.txt
pip install -e .
```

---

## Étape 3 — Authentification Monarch Money (une seule fois)

Lance le script de connexion dans un terminal PowerShell :

```powershell
python login_setup.py
```

Suis les instructions :
1. Saisis ton adresse email Monarch Money
2. Saisis ton mot de passe
3. Saisis le code 2FA si tu as l'authentification à deux facteurs

> La session est sauvegardée dans `.mm/mm_session.pickle`. Tu n'auras plus besoin de te reconnecter pendant des semaines.

---

## Étape 4 — Configurer Claude Desktop

Ouvre le fichier de configuration de Claude Desktop :

```
%APPDATA%\Claude\claude_desktop_config.json
```

(Tu peux coller ce chemin directement dans la barre d'adresse de l'Explorateur Windows)

Ajoute le bloc suivant dans la section `mcpServers`. Remplace `C:\chemin\vers\MONARCH_CFO` par le **vrai chemin** de ton dossier cloné :

```json
{
  "mcpServers": {
    "Monarch Money": {
      "command": "uv",
      "args": [
        "run",
        "--with",
        "mcp[cli]",
        "--with-editable",
        "C:\\chemin\\vers\\MONARCH_CFO",
        "mcp",
        "run",
        "C:\\chemin\\vers\\MONARCH_CFO\\src\\monarch_mcp_server\\server.py"
      ]
    }
  }
}
```

> ⚠️ Sur Windows, utilise des **doubles backslashes** `\\` dans les chemins JSON.

---

## Étape 5 — Redémarrer Claude Desktop

Ferme et relance Claude Desktop. Le serveur Monarch Money sera actif.

---

## Outils disponibles dans Claude

| Commande | Description |
|---|---|
| `get_accounts` | Voir tous tes comptes financiers |
| `get_transactions` | Transactions récentes avec filtres |
| `get_budgets` | Budget et dépenses |
| `get_cashflow` | Analyse revenus/dépenses |
| `check_auth_status` | Vérifier l'état de la connexion |
| `refresh_accounts` | Forcer la mise à jour des comptes |

---

## Dépannage

**"No valid session found"** → Relance `python login_setup.py`

**Erreur de chemin** → Vérifie que les chemins dans `claude_desktop_config.json` sont corrects et utilisent `\\`

**`uv` non trouvé** → Installe uv : `pip install uv` ou via [l'installateur officiel](https://docs.astral.sh/uv/getting-started/installation/)

---

## Mettre à jour

```powershell
git pull origin main
```

Redémarre ensuite Claude Desktop.
