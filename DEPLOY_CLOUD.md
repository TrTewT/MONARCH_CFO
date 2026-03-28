# Déploiement Cloud — Monarch Money MCP Server

> **Objectif :** Rendre le serveur MCP accessible depuis n'importe quel appareil
> (claude.ai web, Claude Desktop, Claude Mobile) sans configuration par appareil.

---

## Pourquoi Render.com ?

- Tier gratuit **always-on** pour les services web Python ✅
- Déploiement automatique depuis GitHub ✅
- Variables d'environnement sécurisées dans le dashboard ✅
- URL HTTPS publique compatible avec claude.ai ✅

---

## Étape 1 — Obtenir ton token Monarch Money

Si tu n'as pas encore ton token :

1. Va sur [app.monarch.com](https://app.monarch.com) dans ton navigateur
2. Ouvre la console (F12 → Console)
3. Colle ce code et appuie sur Entrée :

```javascript
const raw = localStorage.getItem('persist:root');
const user = JSON.parse(JSON.parse(raw)['user']);
console.log(user.token);
```

4. Copie le token affiché (64 caractères hexadécimaux)

> Le token expire environ tous les 30 jours. Si le serveur retourne des erreurs d'auth, répète cette étape.

---

## Étape 2 — Déployer sur Render.com

### 2a. Créer un compte Render
Va sur [render.com](https://render.com) → Sign up with GitHub

### 2b. Créer un nouveau Web Service

1. Dashboard → **New +** → **Web Service**
2. Connecte ton repo GitHub : **TrTewT/MONARCH_CFO**
3. Render va détecter le `render.yaml` automatiquement

### 2c. Configurer les paramètres

Si Render ne détecte pas automatiquement, configure manuellement :

| Champ | Valeur |
|-------|--------|
| **Name** | monarch-mcp-server |
| **Runtime** | Python 3 |
| **Region** | Oregon (US West) |
| **Branch** | main |
| **Build Command** | `pip install -r requirements.txt` |
| **Start Command** | `python src/monarch_mcp_server/server.py` |
| **Plan** | Free |

### 2d. Ajouter la variable d'environnement MONARCH_TOKEN

**IMPORTANT : ne jamais mettre ton token dans le code ou sur GitHub.**

Dans Render Dashboard → ton service → **Environment** → **Add Environment Variable** :

| Key | Value |
|-----|-------|
| `MONARCH_TOKEN` | `ton_token_64_chars_ici` |
| `MCP_TRANSPORT` | `streamable-http` |
| `PORT` | `8000` |

### 2e. Déployer

Clique **Deploy** — Render va build et lancer le serveur (~2-3 minutes).

L'URL de ton serveur sera du type :
```
https://monarch-mcp-server.onrender.com
```

---

## Étape 3 — Connecter Claude

### Sur claude.ai (web + mobile)

1. Va sur [claude.ai](https://claude.ai) → **Settings** → **Integrations**
2. Clique **Add MCP Server**
3. Entre l'URL :
   ```
   https://monarch-mcp-server.onrender.com/mcp
   ```
4. Clique **Save**

Une fois ajouté, Claude (web et mobile) aura accès aux outils Monarch Money dans toutes tes conversations.

### Sur Claude Desktop (optionnel — si tu veux aussi l'accès local)

Dans `%APPDATA%\Claude\claude_desktop_config.json`, ajoute :

```json
{
  "mcpServers": {
    "Monarch Money (Cloud)": {
      "command": "npx",
      "args": [
        "mcp-remote",
        "https://monarch-mcp-server.onrender.com/mcp"
      ]
    }
  }
}
```

> `mcp-remote` est un package npm qui connecte Claude Desktop à un MCP distant.
> Install : `npm install -g mcp-remote`

---

## Étape 4 — Tester

Dans une conversation Claude, essaie :

```
Montre-moi tous mes comptes Monarch Money
```

Si tout est bien configuré, tu verras tes comptes bancaires avec leurs soldes.

---

## Renouvellement du token

Le token Monarch Money expire environ tous les 30 jours. Pour le renouveler :

1. Récupère un nouveau token via la console du navigateur (voir Étape 1)
2. Dans Render Dashboard → ton service → **Environment**
3. Modifie la valeur de `MONARCH_TOKEN`
4. Render redémarrera automatiquement le serveur avec le nouveau token

---

## Dépannage

| Problème | Solution |
|----------|----------|
| Erreur d'auth dans Claude | Token expiré → renouveler dans Render Dashboard |
| Serveur lent au premier appel | Free tier spin-down → normal, Render redémarre (~30s) |
| "MCP server not found" | Vérifier l'URL dans claude.ai Settings → l'endpoint est `/mcp` |
| Build échoue | Vérifier que `requirements.txt` est à jour |

---

## Architecture résultante

```
claude.ai web  ──┐
Claude Desktop ──┼──► Render.com (HTTPS) ──► api.monarchmoney.com
Claude Mobile  ──┘     monarch-mcp-server
                        (Python FastMCP)
                        MONARCH_TOKEN = env var
```

Tous les appareils partagent le même serveur cloud → **zéro config par appareil**.
