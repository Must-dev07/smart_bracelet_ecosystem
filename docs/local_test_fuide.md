# Guide d'exécution locale — Smart Bracelet Ecosystem

**Pas à pas complet : du dépôt Git jusqu'à la prévisualisation de chaque composant, pour les 3 rôles (parent, docteur, admin).**
Le matériel (bracelet ESP32) n'étant pas disponible, le firmware est validé via ses **tests hôtes**, et les données réelles sont remplacées soit par le **simulateur Python** (côté backend), soit par le **simulateur BLE intégré à l'app mobile** (aucun script à lancer, juste un interrupteur dans Réglages).

> ⚕️ Rappel : ce système signale des lectures anormales pour un suivi parental/médical. **Ce n'est pas un dispositif de diagnostic médical.**

---

## 0. Nouveautés depuis la dernière version de ce guide

Un gros lot de fonctionnalités a été ajouté depuis la première version de ce document (17 correctifs/évolutions cumulés). Ce qui change concrètement pour votre prévisualisation :

- **Les 3 rôles fonctionnent maintenant sur mobile ET sur le dashboard web**, pas seulement le docteur sur le web. Un compte admin est maintenant testable de bout en bout (voir §4).
- **App mobile** : navigation par onglets en bas d'écran (au lieu d'icônes dans la barre du haut), différente par rôle et teintée d'une couleur d'accent par rôle. Nouveaux écrans : demandes d'assignation de docteur, historique médical, annuaires admin (utilisateurs/docteurs/parents/bracelets), préférences de notifications, confidentialité, suppression de compte. Un **simulateur BLE intégré** (Réglages → *Use BLE simulator*, activé par défaut) permet de tester les constantes vitales en direct **sans le script Python et sans bracelet réel**.
- **Dashboard** : nouvelle page **Notifications** (n'existait pas avant), action **Resolve** distincte de *Acknowledge* sur les alertes.
- **Backend** : 105 tests (au lieu de 55), plusieurs nouvelles migrations (assignation de docteur par demande/acceptation, catégories de notifications, préférences de notifications, désactivation de compte, agrégats batterie/mouvement). Un bug préexistant a été corrigé au passage : `parent_name` était toujours vide dans les réponses API (silencieusement avalé par un défaut DRF) — il est maintenant rempli correctement.

Tout le reste de ce guide reste valable ; les sections ci-dessous intègrent ces nouveautés directement.

---

## 1. Vue d'ensemble de ce que vous allez faire

| Étape | Composant | Résultat |
|---|---|---|
| 1 | Prérequis | Outils installés et vérifiés |
| 2 | Récupération du projet | Arborescence du projet en place |
| 3 | Backend Django | API vivante sur `http://localhost:8080` + 105 tests verts |
| 4 | Comptes de test | 1 parent + 1 docteur + 1 **admin** créés |
| 5 | Simulateur (optionnel côté backend) | Données vitales + alertes injectées via script Python |
| 6 | Dashboard Next.js | Interface docteur/admin sur `http://localhost:3100` |
| 7 | Firmware (sans matériel) | 184 checks g++ verts |
| 8 | App mobile Flutter | Tests unitaires/widgets + exécution sur émulateur, **3 rôles** |
| 9 | (Option) Docker Compose | Stack production complète |

**Ordre important** : le backend (étape 3) doit tourner avant le simulateur (5), le dashboard (6) et l'app mobile (8). Le simulateur Python (5) est **optionnel** pour l'app mobile — son propre simulateur BLE intégré suffit pour tester les constantes vitales.

---

## 2. Prérequis logiciels

### 2.1 Obligatoires

| Outil | Version min. | Vérification | Sert à |
|---|---|---|---|
| **Python** | 3.11+ | `python --version` | Backend + simulateur |
| **Node.js** | 18+ (20 recommandé) | `node --version` | Dashboard |
| **npm** | 9+ | `npm --version` | Dashboard |
| **g++** (ou MinGW/MSVC) | C++17 | `g++ --version` | Tests firmware |

### 2.2 Optionnels (selon ce que vous voulez tester)

| Outil | Sert à |
|---|---|
| **Flutter SDK** 3.22+ + Android Studio | App mobile (étape 8) |
| **Docker Desktop** | Stack production (étape 9) |
| **Git** | Récupération du projet |

### 2.3 Installation des prérequis par OS

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

### 2.4 Vérification finale

```bash
python --version    # ou python3 --version  → 3.11+
node --version      # → v18+
npm --version
g++ --version
```

---

## 3. Récupérer le projet

Si vous partez du dépôt Git (recommandé — c'est ce que ce guide suppose) :

```bash
git clone <url-du-depot> webapp
cd webapp
```

Si vous appliquez des correctifs reçus sous forme de fichiers `.patch` (livrés un par un, chacun vérifié pour s'appliquer proprement sur le précédent) :

```bash
cd webapp
git apply 01-....patch
git apply 02-....patch
# ... dans l'ordre numérique, jusqu'au dernier
```

Vérifiez l'arborescence :

```
webapp/
├── backend/      ← API Django + moteur de règles
├── dashboard/    ← Dashboard docteur/admin Next.js
├── mobile/       ← App Flutter — parent, docteur ET admin
├── firmware/     ← Firmware ESP32 + tests hôtes
├── tools/simulator/  ← Simulateur de bracelet (côté backend, optionnel)
└── docs/         ← Documentation complète (ce guide inclus)
```

> 💡 Tout le reste du guide suppose que votre terminal est dans le dossier `webapp/`. Ouvrez **un terminal par service** (backend, dashboard…) car chaque serveur occupe son terminal.

---

## 4. Backend Django — l'API centrale

### 4.1 Créer l'environnement virtuel et installer les dépendances

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

### 4.2 Lancer les tests (recommandé — valide votre installation)

```bash
python -m pytest
```

**Résultat attendu : `105 passed`** (≈ 2 min 30). Les tests utilisent SQLite et exécutent Celery en mode synchrone : **aucun Redis/PostgreSQL n'est requis**.

### 4.3 Créer la base de données locale

```bash
python manage.py migrate
```

Résultat attendu : une longue liste de `Applying ... OK` (plusieurs nouvelles migrations sont apparues : assignation de docteur, catégories/préférences de notifications, agrégats batterie/mouvement…). Un fichier `db.sqlite3` est créé — c'est votre base locale (supprimez-le pour repartir de zéro).

### 4.4 Démarrer le serveur API

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

### 4.5 Vérifier que l'API répond

Dans un **nouveau terminal** :
```bash
curl -s http://localhost:8080/api/v1/auth/login -X POST -H "Content-Type: application/json" -d "{}"
```
Réponse attendue : `{"email":["This field is required."],"password":["This field is required."]}` → l'API est vivante. ✅

**Bonus — documentation interactive :** ouvrez http://localhost:8080/api/docs/ dans votre navigateur (Swagger UI avec tous les endpoints, y compris `/babies/doctor-requests/`, `/notifications/preferences/`, `/me/deactivate/`).

---

## 5. Créer les comptes de test (parent + docteur + **admin**)

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

### 5.1 Compte admin — obligatoirement via la ligne de commande

Contrairement à parent/docteur, **un compte admin ne se crée jamais depuis l'app ou l'API d'inscription** (choix volontaire — voir `users/serializers.py::RegisterSerializer`, qui n'accepte que `parent`/`doctor`). Il se provisionne côté serveur :

```bash
cd backend    # si vous n'y êtes pas déjà, environnement virtuel activé
python manage.py createsuperuser
```

Répondez aux invites (email, mot de passe). Cette commande positionne automatiquement `role="admin"` (voir `users/models.py::UserManager.create_superuser`) — aucun autre réglage nécessaire.

| Compte | Email | Mot de passe | Usage |
|---|---|---|---|
| Parent | `parent@test.com` | `TestPass123!` | App mobile + simulateur |
| Docteur | `doctor@test.com` | `TestPass123!` | App mobile + Dashboard |
| **Admin** | *(le vôtre, via `createsuperuser`)* | *(le vôtre)* | App mobile + Dashboard |

Les 3 comptes se connectent avec le **même écran de login**, sur le **même backend**, dans l'app mobile comme sur le dashboard — le rôle est lu automatiquement depuis le serveur et détermine l'interface affichée.

---

## 6. Simulateur Python — remplacer le bracelet physique (optionnel)

Le script `tools/simulator/bracelet_simulator.py` joue **à la fois** le bracelet (vitaux réalistes, encodage float32 identique au firmware) et l'app mobile (login JWT + envoi par lots). Il enregistre le bracelet, crée le bébé, l'appaire, puis injecte les mesures.

> 💡 **Sur mobile, ce script n'est plus indispensable** : l'app a désormais son propre simulateur BLE intégré (§8.4), activé par défaut, qui génère des constantes en direct sans script ni bracelet. Ce script Python reste utile pour peupler le **dashboard web** de données, ou pour des scénarios automatisés/CI.

### 6.1 Scénario normal (aucune alerte attendue)

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

### 6.2 Déclencher des alertes (moteur de règles)

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

> ℹ️ Ces mêmes noms de scénario (`normal`/`fever`/`hypoxia`/`tachy`/`lowbatt`) existent aussi dans le simulateur BLE intégré à l'app mobile (§8.4) — le vocabulaire est partagé volontairement entre les deux.

### 6.3 Assigner le docteur au bébé

Deux façons d'assigner un docteur (§7 de la section mobile détaille le nouveau flux demande/acceptation) :

**A. Assignation directe admin (le plus rapide pour préparer une démo du dashboard) :**

**macOS / Linux :**
```bash
TOKEN=$(curl -s http://localhost:8080/api/v1/auth/login -X POST -H "Content-Type: application/json" -d '{"email":"parent@test.com","password":"TestPass123!"}' | python3 -c "import sys,json;print(json.load(sys.stdin)['access'])")
curl -s http://localhost:8080/api/v1/babies/1/ -X PATCH -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{"assigned_doctor":1}'
```
> ⚠️ Depuis les dernières évolutions, **seul un compte admin** peut affecter directement un docteur par ce PATCH — un parent recevra désormais une erreur `403` (voir §7 mobile : le parent doit passer par une *demande*). Reconnectez-vous avec votre compte admin (§5.1) pour que ce PATCH fonctionne, ou utilisez le flux de demande normal depuis l'app.

**Windows (PowerShell) :**
```powershell
$login = Invoke-RestMethod -Uri http://localhost:8080/api/v1/auth/login -Method Post -ContentType "application/json" -Body '{"email":"parent@test.com","password":"TestPass123!"}'
Invoke-RestMethod -Uri http://localhost:8080/api/v1/babies/1/ -Method Patch -ContentType "application/json" -Headers @{Authorization="Bearer $($login.access)"} -Body '{"assigned_doctor":1}'
```

La réponse JSON doit montrer `"assigned_doctor": 1`. ✅

**B. Flux normal (demande → acceptation)** : voir le parcours complet dans la section mobile, §7.

---

## 7. Dashboard Next.js — docteur & admin

### 7.1 Installer et configurer

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

### 7.2 Démarrer

```bash
npm run dev
```

Attendez `✓ Ready` puis ouvrez **http://localhost:3100** dans votre navigateur.

### 7.3 Parcours de prévisualisation — docteur

1. **Login** : `doctor@test.com` / `TestPass123!` *(un compte parent est refusé avec un message explicite — c'est voulu, le dashboard est réservé docteur/admin).*
2. **Dashboard** : cartes de stats (patients, alertes actives/critiques, flotte de bracelets), dernières alertes actives, tableau de la flotte. Rafraîchissement auto toutes les 30 s.
3. **Patients** : « Sim Baby » apparaît → cliquez pour ouvrir la fiche.
4. **Fiche patient** : dernières constantes, **graphiques Chart.js** (période 6 h / 24 h / 7 j / 30 j avec seuils en pointillés), historique médical (ajoutez une entrée pour tester), historique des alertes.
5. **Alerts** : filtrez par statut/sévérité/recherche libre. **Acknowledge** marque l'alerte comme vue **sans forcément la fermer** (les alertes liées aux constantes vitales restent actives) ; **Resolve** (nouveau bouton) referme réellement l'alerte — c'est l'action distincte à utiliser une fois le suivi terminé.
6. **Notifications** (nouvelle page) : filtres par catégorie (🚨 alerte / ⌚ bracelet / 🩺 médical / ℹ️ système), marquer comme lu, tout marquer lu, supprimer.
7. **Statistics** : répartition des alertes par type (barres), par sévérité (donut), tendance 14 jours (ligne).
8. **Reports** : sélectionnez « Sim Baby » + une période → **Generate PDF report** → un vrai PDF se télécharge (identité, min/moy/max des vitaux, journal des alertes, disclaimer sur chaque page).
9. **Settings** : modifiez le profil docteur (nom, téléphone, spécialité) → Save.
10. **Sign out** : révoque la session côté serveur.

### 7.4 Parcours de prévisualisation — admin

1. **Login** avec le compte admin créé au §5.1.
2. Le nav affiche un item **Users** en plus (annuaire complet de tous les comptes, tous rôles).
3. Toutes les pages docteur (Patients, Alerts, Notifications, Statistics, Reports, Settings) sont aussi accessibles — un admin voit **tous** les bébés/alertes/bracelets, pas seulement ceux d'un docteur assigné (déjà géré côté backend par le scoping par rôle).

> 💡 Relancez le simulateur Python (`--scenario fever`) pendant que le dashboard est ouvert : la nouvelle alerte apparaît au rafraîchissement automatique.

**Build de production (optionnel) :** `npm run build && npm run start` → même URL, version optimisée.

---

## 8. Firmware — validation sans matériel

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

## 9. App mobile Flutter — les 3 rôles

### 9.1 Prérequis Flutter

1. Installez le **Flutter SDK** : https://docs.flutter.dev/get-started/install
2. Installez **Android Studio** (fournit le SDK Android + l'émulateur).
3. Vérifiez : `flutter doctor` — corrigez ce qui est en rouge (licences Android : `flutter doctor --android-licenses`).

### 9.2 Récupérer les dépendances (important — une nouvelle a été ajoutée)

```bash
cd mobile
flutter pub get
```

> ⚠️ **`shared_preferences` a été ajoutée** aux dépendances (persistance des réglages — thème, langue, unités, simulateur BLE). Si vous mettez à jour un dossier `mobile/` existant plutôt que de repartir de zéro, `flutter pub get` est **obligatoire** après avoir récupéré les derniers changements, sinon la compilation échouera sur un import manquant.

### 9.3 Tests unitaires et widgets (sans émulateur)

```bash
flutter test
```

Résultat attendu : **All tests passed!** — client API + refresh JWT, modèles JSON (y compris les nouveaux : demandes d'assignation de docteur, historique médical, profils docteur/parent, catégories de notification), conversions d'unités, écran alertes, écran monitoring live, écran des demandes docteur, préférences de notifications (services BLE/sync mockés).

> Ce projet n'a pas de SDK Flutter dans l'environnement où les modifications ont été préparées — chaque changement a été vérifié « à la main » (équilibrage des accolades, recoupement des imports/références, relecture complète) plutôt que compilé. **`flutter analyze` et `flutter test` restent l'étape de vérification qui fait foi** ; si l'un des deux remonte une erreur, c'est probablement plus fiable que ma propre relecture — n'hésitez pas à signaler tout écart.

### 9.4 Exécution sur émulateur Android

1. Android Studio → **Device Manager** → créez/démarrez un émulateur (ex. Pixel 7, API 34).
2. Lancez l'app en pointant l'API locale :

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

> ⚠️ `10.0.2.2` est l'alias de `localhost` **vu depuis l'émulateur Android**. Sur un téléphone physique, utilisez l'IP LAN de votre PC (ex. `http://192.168.1.20:8080`) — PC et téléphone sur le même Wi-Fi, pare-feu autorisant le port 8080.

### 9.5 Parcours de prévisualisation — parent

1. Connectez-vous avec `parent@test.com` / `TestPass123!`.
2. **Onglet Home** : bouton flottant **« Add baby »** toujours visible (avant, il ne s'affichait que tant qu'aucun bébé n'existait — corrigé). Ajoutez un second bébé pour vérifier.
3. Ouvrez un bébé → **Medical history** (nouveau) : lecture seule pour un parent, recherche par mot-clé.
4. Toujours sur la fiche bébé → section **Doctor** : si aucun docteur n'est assigné, bouton **« Request a doctor »** → recherchez un docteur (le compte créé au §5) → envoyez la demande. Le statut passe en « Request pending ».
5. **Onglet Alerts** / **Inbox** (notifications) / **Profile** — navigation par onglets en bas d'écran désormais, teintée en vert pour le rôle parent.
6. **Réglages** (icône ⚙️ depuis Profile) :
   - **Use BLE simulator** (activé par défaut) : constantes vitales simulées en direct, sans script ni bracelet — pairez un « bracelet » depuis l'écran Pairing, choisissez un scénario (normal/fever/hypoxia/tachy/lowbatt), ouvrez **Live monitoring** pour voir les valeurs arriver toutes les 5 s.
   - **Units** : basculez metric/imperial, vérifiez que le poids et la température affichés changent (Home, fiche bébé, Live monitoring, History).
   - **Notification preferences** : les alertes ne peuvent pas être désactivées (cadenas visible) ; bracelet/médical/système sont mutables.
   - **Privacy**, **Delete account** (demande le mot de passe — désactive le compte, ne le supprime pas définitivement).

### 9.6 Parcours de prévisualisation — docteur (sur mobile, pas seulement sur le dashboard)

1. Connectez-vous avec `doctor@test.com` / `TestPass123!`.
2. **Onglet Patients** : liste des bébés assignés uniquement (teinte bleue). Une puce **« N pending request(s) »** apparaît si le parent a envoyé une demande au §9.5 étape 4.
3. **Onglet Requests** : acceptez ou refusez la demande → si acceptée, le bébé apparaît dans Patients.
4. Ouvrez un patient → **Medical history** : cette fois un formulaire d'ajout est visible (docteur/admin uniquement) — ajoutez une entrée.
5. **Onglets Alerts / Inbox / Profile** identiques dans l'esprit à ceux du parent, données différentes (celles des patients assignés).

### 9.7 Parcours de prévisualisation — admin (sur mobile)

1. Connectez-vous avec le compte admin créé au §5.1.
2. **Onglet Home** (teinte violette) : cartes de statistiques (Users/Doctors/Parents/Babies/Bracelets/Active alerts) — chacune ouvre l'annuaire correspondant, avec recherche et (pour les bracelets) un filtre appairé/non-appairé.
3. Depuis la fiche d'un bébé, un admin peut assigner/changer/retirer un docteur **directement**, sans passer par le flux de demande (bouton dédié dans la section Doctor).
4. **Onglets Alerts / Inbox / Profile** : vue globale, tous rôles confondus.

> ℹ️ **Limites sans matériel réel** : seul le **vrai BLE** (bracelet physique, pas le simulateur intégré) nécessite un appareil Bluetooth — indisponible sur l'émulateur Android. Les notifications push nécessitent une configuration Firebase (`mobile/android_notes/README.md`). Tout le reste — y compris les constantes vitales en direct via le simulateur intégré — fonctionne sans aucun matériel.

---

## 10. (Option) Stack production Docker Compose

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
docker compose exec web python manage.py createsuperuser   # compte admin
docker compose ps          # tous les services → healthy
```

L'API est alors sur **http://localhost:80** (nginx). Refaites les étapes 5-7 en remplaçant `:8080` par `:80`. Arrêt : `docker compose down` (ajoutez `-v` pour effacer les données).

---

## 11. Dépannage rapide

| Problème | Cause probable | Solution |
|---|---|---|
| `python` introuvable (Windows) | PATH | Réinstallez Python en cochant « Add to PATH », ou utilisez `py` |
| `Activate.ps1 cannot be loaded` | Politique PowerShell | `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` |
| `pip install` échoue sur un paquet | Python trop ancien | Vérifiez `python --version` ≥ 3.11 |
| Port 8080 déjà pris | Autre service | Lancez sur 8081 et adaptez `--base-url` / `.env.local` |
| Dashboard : « Failed to fetch » / CORS | Backend arrêté ou mauvaise URL | Vérifiez le terminal backend + `NEXT_PUBLIC_API_BASE_URL` ; l'origine `http://localhost:3100` est déjà autorisée par le CORS par défaut du backend |
| Dashboard : liste patients vide | Docteur non assigné | Refaites l'étape 6.3 (assignation directe admin ou flux de demande) |
| Dashboard : compte parent refusé au login | Comportement voulu | Le dashboard est réservé docteur/admin — utilisez l'app mobile pour un compte parent |
| Simulateur Python : HTTP 401 | Mauvais identifiants | Recréez le compte parent (étape 5) |
| `flutter doctor` en rouge | SDK Android/licences | `flutter doctor --android-licenses`, installez les composants demandés |
| Mobile : erreur de compilation sur `shared_preferences` | Dépendances pas à jour | `cd mobile && flutter pub get` |
| L'app mobile ne joint pas l'API | Mauvaise adresse | Émulateur → `10.0.2.2` ; téléphone → IP LAN du PC |
| Mobile : PATCH `assigned_doctor` refusé (403) pour un parent | Comportement voulu | Un parent doit passer par « Request a doctor », pas par une modification directe — seul un admin peut assigner directement |
| Mobile : « Add baby » invisible | Ancienne version du bouton | Vérifiez que le correctif 16 (`16-add-baby-bug-fix`) est bien appliqué — le bouton est maintenant un FAB permanent, plus seulement affiché sur liste vide |
| g++ : `command not found` (Windows) | MinGW absent du PATH | Ajoutez `C:\msys64\ucrt64\bin` au PATH, rouvrez le terminal |
| Repartir de zéro (données) | — | Stoppez le backend, supprimez `backend/db.sqlite3`, refaites 4.3 → 6 |

---

## 12. Récapitulatif des commandes de démarrage quotidien

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

# Terminal 3 — injecter des données à la demande (optionnel, mobile a son propre simulateur)
cd webapp/tools/simulator
python bracelet_simulator.py --base-url http://localhost:8080 --email parent@test.com --password "TestPass123!" --scenario fever --count 12
```

Comptes : docteur `doctor@test.com` / parent `parent@test.com` — mot de passe `TestPass123!`. Compte admin : le vôtre, créé via `python manage.py createsuperuser` (§5.1).

Bonne exploration ! 🩺
