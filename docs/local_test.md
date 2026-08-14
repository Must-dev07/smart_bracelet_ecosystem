# Guide d'exécution locale — Smart Bracelet Ecosystem

**Pas à pas complet : du fichier ZIP jusqu'à la prévisualisation de chaque composant.**
Le matériel (bracelet ESP32) n'étant pas disponible, le firmware est validé via ses **tests hôtes** et les données réelles sont remplacées par le **simulateur** fourni.

> ⚕️ Rappel : ce système signale des lectures anormales pour un suivi parental/médical. **Ce n'est pas un dispositif de diagnostic médical.**

---

## 0. Vue d'ensemble de ce que vous allez faire

| Étape | Composant | Résultat |
|---|---|---|
| 1 | Prérequis | Outils installés et vérifiés |
| 2 | Décompression | Arborescence du projet en place |
| 3 | Backend Django | API vivante sur `http://localhost:8080` + 55 tests verts |
| 4 | Comptes de test | 1 parent + 1 docteur créés |
| 5 | Simulateur | Données vitales + alertes injectées (remplace le bracelet) |
| 6 | Dashboard Next.js | Interface docteur sur `http://localhost:3100` avec données réelles |
| 7 | Firmware (sans matériel) | 184 checks g++ verts |
| 8 | App mobile Flutter | Tests unitaires/widgets + exécution sur émulateur Android |
| 9 | (Option) Docker Compose | Stack production complète |

**Ordre important** : le backend (étape 3) doit tourner avant le simulateur (5), le dashboard (6) et l'app mobile (8).

---

## 1. Prérequis logiciels

### 1.1 Obligatoires

| Outil | Version min. | Vérification | Sert à |
|---|---|---|---|
| **Python** | 3.11+ | `python --version` | Backend + simulateur |
| **Node.js** | 18+ (20 recommandé) | `node --version` | Dashboard |
| **npm** | 9+ | `npm --version` | Dashboard |
| **g++** (ou MinGW/MSVC) | C++17 | `g++ --version` | Tests firmware |

### 1.2 Optionnels (selon ce que vous voulez tester)

| Outil | Sert à |
|---|---|
| **Flutter SDK** 3.22+ + Android Studio | App mobile (étape 8) |
| **Docker Desktop** | Stack production (étape 9) |
| **Git** | Historique / versionnage |

### 1.3 Installation des prérequis par OS

**Windows :**
1. Python : https://www.python.org/downloads/ → cochez **"Add python.exe to PATH"** pendant l'installation.
2. Node.js : https://nodejs.org (version LTS).
3. g++ : installez **MSYS2** (https://www.msys2.org) puis dans le terminal MSYS2 : `pacman -S mingw-w64-ucrt-x86_64-gcc`, et ajoutez `C:\msys64\ucrt64\bin` au PATH. *(Alternative : WSL2 avec Ubuntu, puis `sudo apt install g++`.)*
4. Ouvrez **PowerShell** pour toutes les commandes de ce guide (les variantes Windows sont indiquées).

**macOS :**
```bash
xcode-select --install          # fournit g++ (clang)
brew install python@3.12 node   # via Homebrew (https://brew.sh)
```

**Linux (Debian/Ubuntu) :**
```bash
sudo apt update
sudo apt install -y python3 python3-venv python3-pip nodejs npm g++
# Si le node du dépôt est < 18 : https://github.com/nodesource/distributions
```

### 1.4 Vérification finale

```bash
python --version    # ou python3 --version  → 3.11+
node --version      # → v18+
npm --version
g++ --version
```

---

## 2. Décompresser le projet

1. Placez `smart_bracelet_ecosystem.zip` dans un dossier de travail, par ex. `~/projets` (ou `C:\projets`).
2. Décompressez :

**Windows (PowerShell) :**
```powershell
cd C:\projets
Expand-Archive smart_bracelet_ecosystem.zip -DestinationPath .
cd webapp
```

**macOS / Linux :**
```bash
cd ~/projets
unzip smart_bracelet_ecosystem.zip
cd webapp
```

3. Vérifiez l'arborescence :

```
webapp/
├── backend/      ← API Django + moteur de règles
├── dashboard/    ← Dashboard docteur Next.js
├── mobile/       ← App Flutter parent
├── firmware/     ← Firmware ESP32 + tests hôtes
├── tools/simulator/  ← Simulateur de bracelet
└── docs/         ← Documentation complète
```

> 💡 Tout le reste du guide suppose que votre terminal est dans le dossier `webapp/`. Ouvrez **un terminal par service** (backend, dashboard…) car chaque serveur occupe son terminal.

---

## 3. Backend Django — l'API centrale

### 3.1 Créer l'environnement virtuel et installer les dépendances

**Windows (PowerShell) :**
```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
# Si erreur "scripts disabled" :
#   Set-ExecutionPolicy -Scope CurrentUser RemoteSigned   (puis relancez)
pip install -r requirements.txt
```

**macOS / Linux :**
```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

L'installation prend 1 à 3 minutes. Le prompt doit afficher `(.venv)`.

### 3.2 Lancer les tests (recommandé — valide votre installation)

```bash
python -m pytest
```

**Résultat attendu : `55 passed`** (≈ 60 s). Les tests utilisent SQLite et exécutent Celery en mode synchrone : **aucun Redis/PostgreSQL n'est requis**.

### 3.3 Créer la base de données locale

```bash
python manage.py migrate
```

Résultat attendu : une liste de `Applying ... OK`. Un fichier `db.sqlite3` est créé — c'est votre base locale (supprimez-le pour repartir de zéro).

### 3.4 Démarrer le serveur API

**Windows (PowerShell) :**
```powershell
$env:CELERY_TASK_ALWAYS_EAGER = "true"
$env:DJANGO_DEBUG = "true"
python manage.py runserver 0.0.0.0:8080
```

**macOS / Linux :**
```bash
CELERY_TASK_ALWAYS_EAGER=true DJANGO_DEBUG=true python manage.py runserver 0.0.0.0:8080
```

> `CELERY_TASK_ALWAYS_EAGER=true` exécute les règles d'analyse **dans le processus web** : pas besoin de Redis ni d'un worker Celery en développement local.

**Laissez ce terminal ouvert.** Le serveur est prêt quand vous voyez `Starting development server at http://0.0.0.0:8080/`.

### 3.5 Vérifier que l'API répond

Dans un **nouveau terminal** :
```bash
curl -s http://localhost:8080/api/v1/auth/login -X POST -H "Content-Type: application/json" -d "{}"
```
Réponse attendue : `{"email":["This field is required."],"password":["This field is required."]}` → l'API est vivante. ✅

**Bonus — documentation interactive :** ouvrez http://localhost:8080/api/docs/ dans votre navigateur (Swagger UI avec tous les endpoints).

---

## 4. Créer les comptes de test (parent + docteur)

Toujours dans le 2ᵉ terminal :

**macOS / Linux :**
```bash
curl -s http://localhost:8080/api/v1/auth/register -X POST -H "Content-Type: application/json" \
  -d '{"email":"parent@test.com","password":"TestPass123!","first_name":"Marie","last_name":"Dupont","role":"parent","phone":"+33600000001"}'

curl -s http://localhost:8080/api/v1/auth/register -X POST -H "Content-Type: application/json" \
  -d '{"email":"doctor@test.com","password":"TestPass123!","first_name":"Jean","last_name":"Martin","role":"doctor","license_number":"LIC-001","specialty":"Neonatologie"}'
```

**Windows (PowerShell) :**
```powershell
Invoke-RestMethod -Uri http://localhost:8080/api/v1/auth/register -Method Post -ContentType "application/json" -Body '{"email":"parent@test.com","password":"TestPass123!","first_name":"Marie","last_name":"Dupont","role":"parent","phone":"+33600000001"}'

Invoke-RestMethod -Uri http://localhost:8080/api/v1/auth/register -Method Post -ContentType "application/json" -Body '{"email":"doctor@test.com","password":"TestPass123!","first_name":"Jean","last_name":"Martin","role":"doctor","license_number":"LIC-001","specialty":"Neonatologie"}'
```

Chaque appel renvoie un JSON contenant `access`, `refresh` et `user` → comptes créés. ✅

| Compte | Email | Mot de passe | Usage |
|---|---|---|---|
| Parent | `parent@test.com` | `TestPass123!` | App mobile + simulateur |
| Docteur | `doctor@test.com` | `TestPass123!` | Dashboard |

*(Option : un compte admin se crée avec `python manage.py createsuperuser` puis en mettant `role='admin'` via l'admin Django `http://localhost:8080/admin/`.)*

---

## 5. Simulateur — remplacer le bracelet physique

Le script `tools/simulator/bracelet_simulator.py` joue **à la fois** le bracelet (vitaux réalistes, encodage float32 identique au firmware) et l'app mobile (login JWT + envoi par lots). Il enregistre le bracelet, crée le bébé, l'appaire, puis injecte les mesures.

### 5.1 Scénario normal (aucune alerte attendue)

Depuis le dossier `webapp/` (le backend doit tourner) :
```bash
cd tools/simulator
python bracelet_simulator.py --base-url http://localhost:8080 --email parent@test.com --password "TestPass123!" --serial SIM0001 --scenario normal --count 20
```

Sortie attendue :
```
[sim] logged in as parent@test.com (parent)
[sim] registered bracelet #1 serial=SIM0001
[sim] created baby #1 (Sim Baby)
[sim] paired bracelet #1 with baby #1
[sim] sent batch of 5 (total created=5, errors=0)
...
[sim] scenario=normal → 20 measurements ingested; 0 active alert(s):
```

### 5.2 Déclencher des alertes (moteur de règles)

```bash
python bracelet_simulator.py --base-url http://localhost:8080 --email parent@test.com --password "TestPass123!" --scenario fever --count 12
python bracelet_simulator.py --base-url http://localhost:8080 --email parent@test.com --password "TestPass123!" --scenario hypoxia --count 12
python bracelet_simulator.py --base-url http://localhost:8080 --email parent@test.com --password "TestPass123!" --scenario tachy --count 12
python bracelet_simulator.py --base-url http://localhost:8080 --email parent@test.com --password "TestPass123!" --scenario lowbatt --count 12
```

Chaque scénario doit afficher son alerte, ex. :
```
[sim] scenario=fever → 12 measurements ingested; 1 active alert(s):
  - [critical] high_temp   Temperature reading 38.1°C is above 38.0°C — flagged for caregiver/medical follow-up.
```

| Scénario | Dérive simulée | Alerte attendue |
|---|---|---|
| `normal` | vitaux sains | aucune |
| `fever` | température > 38 °C | `high_temp` (critique) |
| `hypoxia` | SpO2 < 92 % | `low_oxygen` (critique) |
| `tachy` | FC > 180 bpm | `high_hr` (critique) |
| `still` | mouvement ≈ 0 | alimente `no_movement` |
| `lowbatt` | batterie < 15 % | `battery_low` (info) |

### 5.3 Assigner le docteur au bébé (indispensable pour le dashboard)

Le docteur ne voit que ses patients assignés. Assignez-le :

**macOS / Linux :**
```bash
TOKEN=$(curl -s http://localhost:8080/api/v1/auth/login -X POST -H "Content-Type: application/json" -d '{"email":"parent@test.com","password":"TestPass123!"}' | python3 -c "import sys,json;print(json.load(sys.stdin)['access'])")
curl -s http://localhost:8080/api/v1/babies/1/ -X PATCH -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{"assigned_doctor":1}'
```

**Windows (PowerShell) :**
```powershell
$login = Invoke-RestMethod -Uri http://localhost:8080/api/v1/auth/login -Method Post -ContentType "application/json" -Body '{"email":"parent@test.com","password":"TestPass123!"}'
Invoke-RestMethod -Uri http://localhost:8080/api/v1/babies/1/ -Method Patch -ContentType "application/json" -Headers @{Authorization="Bearer $($login.access)"} -Body '{"assigned_doctor":1}'
```

La réponse JSON doit montrer `"assigned_doctor": 1`. ✅

---

## 6. Dashboard Next.js — la prévisualisation principale

### 6.1 Installer et configurer

Dans un **3ᵉ terminal**, depuis `webapp/` :

```bash
cd dashboard
npm install          # 1-2 minutes
```

Créez le fichier d'environnement :

**macOS / Linux :** `cp .env.example .env.local`
**Windows :** `Copy-Item .env.example .env.local`

Le contenu par défaut est déjà correct pour ce guide :
```
NEXT_PUBLIC_API_BASE_URL=http://localhost:8080
```

### 6.2 Démarrer

```bash
npm run dev
```

Attendez `✓ Ready` puis ouvrez **http://localhost:3100** dans votre navigateur.

### 6.3 Parcours de prévisualisation

1. **Login** : `doctor@test.com` / `TestPass123!` *(un compte parent est refusé avec un message explicite — c'est voulu).*
2. **Dashboard** : cartes de stats (patients, alertes actives/critiques, flotte de bracelets), dernières alertes actives, tableau de la flotte. Rafraîchissement auto toutes les 30 s.
3. **Patients** : « Sim Baby » apparaît → cliquez pour ouvrir la fiche.
4. **Fiche patient** : dernières constantes, **graphiques Chart.js** (période 6 h / 24 h / 7 j / 30 j avec seuils en pointillés), historique médical (ajoutez une entrée pour tester), historique des alertes.
5. **Alerts** : filtrez par statut/sévérité, cliquez **Acknowledge** sur une alerte → elle passe en « Resolved ». ✅
6. **Statistics** : répartition des alertes par type (barres), par sévérité (donut), tendance 14 jours (ligne).
7. **Reports** : sélectionnez « Sim Baby » + une période → **Generate PDF report** → un vrai PDF se télécharge (identité, min/moy/max des vitaux, journal des alertes, disclaimer sur chaque page).
8. **Settings** : modifiez le profil docteur (nom, téléphone, spécialité) → Save.
9. **Sign out** : révoque la session côté serveur.

> 💡 Relancez le simulateur (`--scenario fever`) pendant que le dashboard est ouvert : la nouvelle alerte apparaît au rafraîchissement automatique.

**Build de production (optionnel) :** `npm run build && npm run start` → même URL, version optimisée.

---

## 7. Firmware — validation sans matériel

Aucun ESP32 requis : la logique pure (encodage BLE float32, ring buffer, modèle batterie, filtres médians, fenêtres de plausibilité) est testée sur votre machine avec g++.

Dans un terminal, depuis `webapp/` :

```bash
cd firmware/test_host
g++ -std=c++17 -I../include -Wall -Wextra -Werror -o test_host test_main.cpp
./test_host            # Windows MinGW : .\test_host.exe
```

**Résultat attendu :**
```
184 checks, 0 failure(s)
```
✅ Le contrat de payload BLE (float32 little-endian, ordre des 7 champs mouvement), le tampon hors-ligne (FIFO, écrasement du plus ancien), le modèle batterie LiPo et les filtres anti-pics sont validés.

> 🔧 **Plus tard, avec le matériel** : `pip install platformio`, puis `cd firmware && pio run -t upload` et `pio device monitor -b 115200`. Câblage complet dans `firmware/README.md`.

---

## 8. App mobile Flutter

### 8.1 Prérequis Flutter

1. Installez le **Flutter SDK** : https://docs.flutter.dev/get-started/install
2. Installez **Android Studio** (fournit le SDK Android + l'émulateur).
3. Vérifiez : `flutter doctor` — corrigez ce qui est en rouge (licences Android : `flutter doctor --android-licenses`).

### 8.2 Tests unitaires et widgets (sans émulateur)

```bash
cd mobile
flutter pub get
flutter test
```

Résultat attendu : **All tests passed!** (client API + refresh JWT, modèles JSON, écran alertes, écran monitoring live — services BLE/sync mockés).

### 8.3 Exécution sur émulateur Android

1. Android Studio → **Device Manager** → créez/démarrez un émulateur (ex. Pixel 7, API 34).
2. Lancez l'app en pointant l'API locale :

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

> ⚠️ `10.0.2.2` est l'alias de `localhost` **vu depuis l'émulateur Android**. Sur un téléphone physique, utilisez l'IP LAN de votre PC (ex. `http://192.168.1.20:8080`) — PC et téléphone sur le même Wi-Fi, pare-feu autorisant le port 8080.

3. **Parcours de prévisualisation** :
   - Connectez-vous avec `parent@test.com` / `TestPass123!`.
   - L'écran d'accueil montre « Sim Baby » (créé par le simulateur).
   - **Historique / Graphiques** : les mesures injectées par le simulateur s'affichent.
   - **Alertes** : les alertes des scénarios apparaissent ; ouvrez le détail (disclaimer visible), acquittez.
   - Écrans profil, réglages, infos bracelet… navigables.

> ℹ️ **Limites sans matériel** : l'écran *Pairing/Live BLE* nécessite un vrai bracelet (l'émulateur n'a pas de Bluetooth) et les notifications push nécessitent une configuration Firebase (`mobile/android_notes/README.md`). Tout le reste fonctionne avec le simulateur.

---

## 9. (Option) Stack production Docker Compose

Pour tester l'infrastructure complète (PostgreSQL, Redis, gunicorn, Celery worker + beat, nginx) :

```bash
cd backend
cp .env.example .env      # Windows : Copy-Item .env.example .env
```

Éditez `.env` — renseignez au minimum les lignes `# REQUIRES:` :
- `DJANGO_SECRET_KEY` → générez : `python -c "import secrets;print(secrets.token_urlsafe(64))"`
- `POSTGRES_PASSWORD` → un mot de passe fort
- Les variables FCM peuvent rester vides en local (les push seront simplement inactifs).

```bash
docker compose up -d --build
docker compose exec web python manage.py migrate
docker compose ps          # tous les services → healthy
```

L'API est alors sur **http://localhost:80** (nginx). Refaites les étapes 4-6 en remplaçant `:8080` par `:80`. Arrêt : `docker compose down` (ajoutez `-v` pour effacer les données).

---

## 10. Dépannage rapide

| Problème | Cause probable | Solution |
|---|---|---|
| `python` introuvable (Windows) | PATH | Réinstallez Python en cochant « Add to PATH », ou utilisez `py` |
| `Activate.ps1 cannot be loaded` | Politique PowerShell | `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` |
| `pip install` échoue sur un paquet | Python trop ancien | Vérifiez `python --version` ≥ 3.11 |
| Port 8080 déjà pris | Autre service | Lancez sur 8081 et adaptez `--base-url` / `.env.local` |
| Dashboard : « Failed to fetch » / CORS | Backend arrêté ou mauvaise URL | Vérifiez le terminal backend + `NEXT_PUBLIC_API_BASE_URL` ; l'origine `http://localhost:3100` est déjà autorisée par le CORS par défaut du backend |
| Dashboard : liste patients vide | Docteur non assigné | Refaites l'étape 5.3 |
| Simulateur : HTTP 401 | Mauvais identifiants | Recréez le compte parent (étape 4) |
| `flutter doctor` en rouge | SDK Android/licences | `flutter doctor --android-licenses`, installez les composants demandés |
| L'app mobile ne joint pas l'API | Mauvaise adresse | Émulateur → `10.0.2.2` ; téléphone → IP LAN du PC |
| g++ : `command not found` (Windows) | MinGW absent du PATH | Ajoutez `C:\msys64\ucrt64\bin` au PATH, rouvrez le terminal |
| Repartir de zéro (données) | — | Stoppez le backend, supprimez `backend/db.sqlite3`, refaites 3.3 → 5 |

---

## 11. Récapitulatif des commandes de démarrage quotidien

Une fois tout installé, pour relancer l'environnement :

```bash
# Terminal 1 — backend
cd webapp/backend
source .venv/bin/activate            # Windows : .\.venv\Scripts\Activate.ps1
CELERY_TASK_ALWAYS_EAGER=true python manage.py runserver 0.0.0.0:8080
# Windows : $env:CELERY_TASK_ALWAYS_EAGER="true" ; python manage.py runserver 0.0.0.0:8080

# Terminal 2 — dashboard
cd webapp/dashboard
npm run dev                          # http://localhost:3100

# Terminal 3 — injecter des données à la demande
cd webapp/tools/simulator
python bracelet_simulator.py --base-url http://localhost:8080 --email parent@test.com --password "TestPass123!" --scenario fever --count 12
```

Comptes : docteur `doctor@test.com` / parent `parent@test.com` — mot de passe `TestPass123!`.

Bonne exploration ! 🩺
