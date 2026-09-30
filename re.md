# Guide d'exécution locale — Smart Bracelet Ecosystem

**Pas à pas complet : de la récupération du projet jusqu'à la prévisualisation de chaque composant, pour les 3 rôles (parent, docteur, admin), avec le nouveau workflow d'enrôlement.**
Le matériel (bracelet ESP32) n'étant pas disponible, le firmware est validé via ses **tests hôtes**, et les données réelles sont remplacées soit par le **simulateur Python** (côté backend), soit par le **simulateur BLE intégré à l'app mobile** (aucun script à lancer, juste un interrupteur dans Réglages).

> ⚕️ Rappel : ce système signale des lectures anormales pour un suivi parental/médical. **Ce n'est pas un dispositif de diagnostic médical.**

---

## 0. Ce qui a changé : le workflow d'enrôlement (refonte)

La refonte décrite dans `webapp/REFONTE_system.md` est implémentée (backend, dashboard, mobile). Conséquences directes pour ce guide :

- **Le bébé est enrôlé par un docteur ou un admin**, plus par le parent. Formulaire *Enroll newborn* sur le dashboard (`POST /api/v1/babies/`) : motif d'enrôlement (`prematurity`, `clinical_sign`, `congenital_condition`, `other` + description obligatoire), âge gestationnel, docteur assigné, **email du parent**.
- **Le parent ne peut plus s'inscrire seul** : `POST /auth/register` avec `role=parent` renvoie **403** (« les comptes parents sont créés via une invitation médicale »). L'écran *Create account* de l'app affiche ce message.
- **Invitation** : si aucun compte parent n'existe pour l'email, le bébé est créé **sans parent** et une invitation (valable **7 jours**) est créée. Le dashboard affiche un lien `app://invite/{token}` à transmettre au parent (**aucun email n'est envoyé**). Le parent l'ouvre dans l'app → *Finish your registration* → compte créé, connecté, bébé visible. Si le compte parent existe déjà, le bébé lui est rattaché directement.
- **Enrôlements en attente** : nouvelle page dashboard *Pending enrollments* ; *Resend invitation* génère un nouveau lien (l'ancien ne marche plus).
- **Fiche bébé en lecture seule pour le parent** ; modifiable par le docteur assigné (poids, taille, champs d'enrôlement — pas nom/date de naissance/sexe) ou un admin.
- **Appairage** : le docteur assigné et l'admin peuvent appairer un bracelet (ex. à la maternité). Si le bébé est déjà appairé, l'app affiche *Already paired by medical staff*.
- **Plus de flux « demande de docteur »** dans les interfaces : le docteur est choisi à l'enrôlement (ou par un admin). Les endpoints `/babies/doctor-requests/` existent encore côté backend mais ne sont plus utilisés.
- Un nouveau watchdog Celery-beat (`expire_invitations`) passe les invitations périmées en `expired`.

---

## 1. Vue d'ensemble de ce que vous allez faire

| Étape | Composant | Résultat |
|---|---|---|
| 2 | Prérequis | Outils installés et vérifiés |
| 3 | Récupération du projet | Arborescence en place |
| 4 | Backend Django | API vivante sur `http://localhost:8080` + suite pytest verte |
| 5 | Comptes & enrôlement | 1 admin + 1 docteur, 1 bébé enrôlé, 1 parent créé **par invitation** |
| 6 | Simulateur Python (optionnel) | Données vitales + alertes injectées |
| 7 | Dashboard Next.js | Interface docteur/admin sur `http://localhost:3100` (enrôlement, invitations) |
| 8 | Firmware (sans matériel) | 184 checks g++ verts |
| 9 | App mobile Flutter | Tests + exécution sur émulateur, **3 rôles**, acceptation d'invitation |
| 10 | (Option) Docker Compose | Stack production complète |

**Ordre important** : le backend (4) doit tourner avant tout le reste. Un bébé doit être **enrôlé (5)** avant de lancer le simulateur (6) ou de tester l'app parent (9).

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
| **Flutter SDK** 3.38 (Dart 3.10) + Android Studio | App mobile (étape 9) |
| **Docker Desktop** | Stack production (étape 10) |
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

Les composants sont des **dossiers frères** (dépôts Git séparés) sous la racine `smart_bracele/` :

```
smart_bracele/
├── centure_backend/       ← API Django + moteur de règles + invitations
├── dashboard/dashboard/   ← Dashboard docteur/admin Next.js
└── webapp/
    ├── mobile/            ← App Flutter — parent, docteur ET admin
    ├── firmware/          ← Firmware ESP32 + tests hôtes
    ├── tools/simulator/   ← Simulateur de bracelet (optionnel)
    ├── docs/              ← Documentation (ce guide inclus)
    └── REFONTE_system.md  ← Spécification du workflow d'enrôlement
```

> 💡 Tout le reste du guide suppose que votre terminal part du dossier **`smart_bracele/`**. Ouvrez **un terminal par service** (backend, dashboard…) car chaque serveur occupe son terminal.

---

## 4. Backend Django — l'API centrale

### 4.1 Créer l'environnement virtuel et installer les dépendances

**Windows (PowerShell) :**
```powershell
cd centure_backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
# Si erreur "scripts disabled" :
#   Set-ExecutionPolicy -Scope CurrentUser RemoteSigned   (puis relancez)
pip install -r requirements.txt
```

**macOS / Linux :**
```bash
cd centure_backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

L'installation prend 1 à 3 minutes. Le prompt doit afficher `(.venv)`.

### 4.2 Lancer les tests (recommandé — valide votre installation)

```bash
python -m pytest
```

**Résultat attendu : tous les tests passent** (voir `docs/testing_report.md` pour le nombre exact de la dernière exécution ; la suite couvre maintenant l'enrôlement, les invitations, l'annuaire parents et les nouvelles permissions d'appairage). Les tests utilisent SQLite et exécutent Celery en mode synchrone : **aucun Redis/PostgreSQL n'est requis**. Comptez plusieurs minutes.

### 4.3 Créer la base de données locale

```bash
python manage.py migrate
```

Résultat attendu : une liste de `Applying ... OK`, dont `babies.0004_baby_enrollment_fields`, `babies.0005_backfill_legacy_enrollment` et `invitations.0001_initial`. Un fichier `db.sqlite3` est créé — c'est votre base locale (supprimez-le pour repartir de zéro).

> ⚠️ **Base existante contenant déjà des bébés** (antérieure à la refonte) : la migration `0005` attribue `enrolled_by` au premier docteur/admin actif, sinon au premier superuser. S'il n'y en a aucun, elle s'arrête avec un message explicite : créez d'abord un superuser (`python manage.py createsuperuser`), puis relancez `migrate`. Aucune donnée n'est supprimée.

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

> `CELERY_TASK_ALWAYS_EAGER=true` exécute les règles d'analyse **dans le processus web** : pas besoin de Redis ni d'un worker Celery en local. Conséquence : les tâches **périodiques** (watchdog `no_data`, expiration des invitations) ne tournent pas — une invitation dépassée est quand même refusée (410) à l'acceptation, elle apparaît simplement encore « pending » dans la liste.

**Laissez ce terminal ouvert.** Le serveur est prêt quand vous voyez `Starting development server at http://0.0.0.0:8080/`.

### 4.5 Vérifier que l'API répond

Dans un **nouveau terminal** :
```bash
curl -s http://localhost:8080/api/v1/auth/login -X POST -H "Content-Type: application/json" -d "{}"
```
Réponse attendue : `{"email":["This field is required."],"password":["This field is required."]}` → l'API est vivante. ✅

**Bonus — documentation interactive :** http://localhost:8080/api/docs/ (Swagger UI, dont `/invitations/`, `/parents/`, `/babies/`).

---

## 5. Comptes de test et premier enrôlement

Nouveau principe : **admin** en ligne de commande, **docteur** par inscription, **bébé** enrôlé par le docteur, **parent** créé en acceptant l'invitation.

### 5.1 Compte admin — obligatoirement via la ligne de commande

Un compte admin ne se crée jamais depuis l'app ou l'API d'inscription :

```bash
cd centure_backend    # environnement virtuel activé
python manage.py createsuperuser
```

Répondez aux invites (email, mot de passe). La commande positionne automatiquement `role="admin"`.

### 5.2 Compte docteur — inscription libre (inchangée)

**macOS / Linux :**
```bash
curl -s http://localhost:8080/api/v1/auth/register -X POST -H "Content-Type: application/json" \
  -d '{"email":"doctor@test.com","password":"TestPass123!","first_name":"Jean","last_name":"Martin","role":"doctor","license_number":"LIC-001","specialty":"Neonatologie"}'
```

**Windows (PowerShell) :**
```powershell
Invoke-RestMethod -Uri http://localhost:8080/api/v1/auth/register -Method Post -ContentType "application/json" -Body '{"email":"doctor@test.com","password":"TestPass123!","first_name":"Jean","last_name":"Martin","role":"doctor","license_number":"LIC-001","specialty":"Neonatologie"}'
```

Réponse : JSON avec `access`, `refresh`, `user` → compte créé. ✅

> Vérification de la fermeture de l'inscription parent : la même commande avec `"role":"parent"` renvoie **403** `les comptes parents sont créés via une invitation médicale`. C'est voulu.

### 5.3 Enrôler un bébé (le docteur) et obtenir le lien d'invitation

**Méthode recommandée : le dashboard** (§7.3) — formulaire *Enroll newborn*, email parent `parent@test.com`, *Assigned doctor* = vous-même. Le lien d'invitation s'affiche avec un bouton de copie.

**Méthode API (pour scripter) :**

**macOS / Linux :**
```bash
DOC=$(curl -s http://localhost:8080/api/v1/auth/login -X POST -H "Content-Type: application/json" \
  -d '{"email":"doctor@test.com","password":"TestPass123!"}' | python3 -c "import sys,json;print(json.load(sys.stdin)['access'])")

# id du profil docteur (champ "id" de /doctors/, pas l'id utilisateur)
curl -s http://localhost:8080/api/v1/doctors/ -H "Authorization: Bearer $DOC"

curl -s http://localhost:8080/api/v1/babies/ -X POST -H "Authorization: Bearer $DOC" -H "Content-Type: application/json" \
  -d '{"name":"Sim Baby","birth_date":"2026-09-15","weight_grams":1850,"gender":"female","assigned_doctor":1,
       "enrollment_reason":"prematurity","enrollment_notes":"Né à 32 SA","gestational_age_weeks":32,
       "parent_email":"parent@test.com"}'
```

**Windows (PowerShell) :**
```powershell
$doc = Invoke-RestMethod -Uri http://localhost:8080/api/v1/auth/login -Method Post -ContentType "application/json" -Body '{"email":"doctor@test.com","password":"TestPass123!"}'
$H = @{Authorization="Bearer $($doc.access)"}
Invoke-RestMethod -Uri http://localhost:8080/api/v1/doctors/ -Headers $H
$baby = Invoke-RestMethod -Uri http://localhost:8080/api/v1/babies/ -Method Post -ContentType "application/json" -Headers $H -Body '{"name":"Sim Baby","birth_date":"2026-09-15","weight_grams":1850,"gender":"female","assigned_doctor":1,"enrollment_reason":"prematurity","enrollment_notes":"Ne a 32 SA","gestational_age_weeks":32,"parent_email":"parent@test.com"}'
$baby.parent_status; $baby.invitation_link
```

Réponse attendue (aucun compte parent n'existe encore) :
```json
{ "id": 1, "name": "Sim Baby", "parent": null, ..., "parent_status": "invitation_pending",
  "invitation_link": "app://invite/Xy7...43 caractères" }
```
Notez le **token** (la partie après `app://invite/`). Il n'est plus jamais affiché ensuite (seul un *resend* en génère un nouveau).

> Règles de validation : `enrollment_reason="other"` exige `enrollment_notes` ; poids 300–8000 g ; date de naissance non future. Un second bébé enrôlé pour le même email **réutilise** la même invitation.

### 5.4 Créer le compte parent en acceptant l'invitation

**Méthode recommandée : l'app mobile** (§9.5) — c'est le vrai parcours parent.

**Méthode API :**

**macOS / Linux :**
```bash
TOKEN=<token-du-lien>
curl -s http://localhost:8080/api/v1/invitations/$TOKEN/accept/ -X POST -H "Content-Type: application/json" \
  -d '{"password":"TestPass123!","first_name":"Marie","last_name":"Dupont","phone":"+33600000001"}'
```

**Windows (PowerShell) :**
```powershell
$TOKEN = "<token-du-lien>"
Invoke-RestMethod -Uri "http://localhost:8080/api/v1/invitations/$TOKEN/accept/" -Method Post -ContentType "application/json" -Body '{"password":"TestPass123!","first_name":"Marie","last_name":"Dupont","phone":"+33600000001"}'
```

Réponse : `access`, `refresh`, `user` (rôle `parent`) → compte créé, bébé rattaché. ✅ Rejouer la même commande renvoie **410** (invitation déjà utilisée) ; un token inconnu renvoie **404**.

| Compte | Email | Mot de passe | Créé par | Usage |
|---|---|---|---|---|
| **Admin** | *(le vôtre)* | *(le vôtre)* | `createsuperuser` | Dashboard + app mobile |
| Docteur | `doctor@test.com` | `TestPass123!` | inscription | Dashboard + app mobile |
| Parent | `parent@test.com` | `TestPass123!` | **invitation acceptée** | App mobile (+ simulateur) |

Les 3 comptes utilisent le **même écran de login** ; le rôle est lu depuis le serveur et détermine l'interface. Le dashboard refuse les comptes parent.

---

## 6. Simulateur Python — remplacer le bracelet physique (optionnel)

`webapp/tools/simulator/bracelet_simulator.py` joue le bracelet (vitaux réalistes, float32 comme le firmware) et l'app (login JWT + envoi par lots). Il enregistre le bracelet, l'appaire au **premier bébé visible par le compte**, puis injecte les mesures.

> ⚠️ **Prérequis** : un bébé doit déjà être enrôlé (§5.3). Connectez le simulateur avec le **parent** (une fois l'invitation acceptée) **ou avec le docteur assigné** (fonctionne même si l'invitation est encore en attente). Sans bébé visible, le script tente de créer un bébé et reçoit **403** (parent) / **400** (docteur).

> 💡 Sur mobile, ce script n'est pas nécessaire : l'app a son propre simulateur BLE intégré (§9.5). Il reste utile pour peupler le **dashboard** ou pour des scénarios automatisés.

### 6.1 Scénario normal (aucune alerte attendue)

Depuis `smart_bracele/` (le backend doit tourner) :
```bash
cd webapp/tools/simulator
python bracelet_simulator.py --base-url http://localhost:8080 --email parent@test.com --password "TestPass123!" --serial SIM0001 --scenario normal --count 20
```

Sortie attendue :
```
[sim] logged in as parent@test.com (parent)
[sim] registered bracelet #1 serial=SIM0001
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

> ℹ️ Ces noms de scénario existent aussi dans le simulateur BLE intégré à l'app mobile — vocabulaire partagé volontairement.

### 6.3 Docteur assigné

Il n'y a **plus d'étape d'assignation séparée** : le docteur est choisi dans le formulaire d'enrôlement (§5.3). Pour changer le docteur d'un bébé existant, connectez-vous en **admin** et modifiez la fiche (dashboard ou app), ou via l'API :

```bash
ADMIN=$(curl -s http://localhost:8080/api/v1/auth/login -X POST -H "Content-Type: application/json" -d '{"email":"<admin>","password":"<mdp>"}' | python3 -c "import sys,json;print(json.load(sys.stdin)['access'])")
curl -s http://localhost:8080/api/v1/babies/1/ -X PATCH -H "Authorization: Bearer $ADMIN" -H "Content-Type: application/json" -d '{"assigned_doctor":1}'
```
Un parent reçoit **403** (fiche en lecture seule) ; un docteur ne peut que se **retirer** lui-même (`"assigned_doctor": null`).

---

## 7. Dashboard Next.js — docteur & admin

### 7.1 Installer et configurer

Dans un **3ᵉ terminal**, depuis `smart_bracele/` :

```bash
cd dashboard/dashboard
npm install          # 1-2 minutes
```

Fichier d'environnement (facultatif — la valeur par défaut est déjà `http://localhost:8080`) :

**macOS / Linux :** `echo "NEXT_PUBLIC_API_BASE_URL=http://localhost:8080" > .env.local`
**Windows :** `Set-Content .env.local "NEXT_PUBLIC_API_BASE_URL=http://localhost:8080"`

### 7.2 Démarrer

```bash
npm run dev
```

Attendez `✓ Ready` puis ouvrez **http://localhost:3100**.

### 7.3 Parcours de prévisualisation — docteur

1. **Login** : `doctor@test.com` / `TestPass123!` *(un compte parent est refusé avec un message explicite — voulu).*
2. **Enroll newborn** (nouveau) :
   - Remplissez le bébé (nom, date de naissance, poids, sexe), le **motif** (essayez *Other* sans description → erreur de validation), l'âge gestationnel.
   - *Assigned doctor* : **choisissez-vous** (un docteur ne voit que ses patients assignés — le formulaire le rappelle).
   - *Parent email* : tapez `parent@` → la recherche (`GET /parents/?search=`) propose les comptes existants.
   - Résultat : **Linked** (parent existant) ou **Invitation pending** avec le lien `app://invite/…` et un bouton de copie. Testez les deux : un email inconnu, puis `parent@test.com` après §5.4.
3. **Pending enrollments** (nouveau) : liste des invitations `pending` / `expired` (email, bébés, expiration — jamais le lien). **Resend invitation** → nouveau lien affiché, valable 7 jours ; l'ancien renvoie désormais 404 à l'acceptation.
4. **Dashboard** : cartes de stats, dernières alertes actives, flotte de bracelets (rafraîchissement 30 s).
5. **Patients** → fiche : infos d'enrôlement, dernières constantes, **graphiques** (6 h / 24 h / 7 j / 30 j), historique médical (la première entrée est « Enrôlement »), historique des alertes. Bouton **Edit** visible car vous êtes le docteur assigné : poids/taille/champs d'enrôlement modifiables ; nom, date de naissance et sexe refusés (403).
6. **Alerts** : filtres statut/sévérité/recherche. **Acknowledge** = vu (les alertes vitales restent actives) ; **Resolve** = clôture.
7. **Notifications** : filtres par catégorie, lu/non lu, tout marquer lu, supprimer.
8. **Statistics**, **Reports** (PDF), **Settings** (profil docteur), **Sign out** (révoque la session).

### 7.4 Parcours de prévisualisation — admin

1. **Login** avec le compte admin (§5.1).
2. Item **Users** en plus (annuaire complet, tous rôles).
3. L'admin voit **tous** les bébés, alertes, bracelets et invitations ; il peut enrôler, modifier toute fiche (y compris l'identité et le docteur assigné) et renvoyer n'importe quelle invitation.

> 💡 Relancez le simulateur (`--scenario fever`) pendant que le dashboard est ouvert : l'alerte apparaît au rafraîchissement automatique.

**Build de production (optionnel) :** `npm run build && npm run start` → même URL.

---

## 8. Firmware — validation sans matériel

Aucun ESP32 requis : la logique pure est testée avec g++.

```bash
cd webapp/firmware/test_host
g++ -std=c++17 -I../include -Wall -Wextra -Werror -o test_host test_main.cpp
./test_host            # Windows MinGW : .\test_host.exe
```

**Résultat attendu :** `184 checks, 0 failure(s)`. (Le firmware n'est pas concerné par la refonte.)

> 🔧 Avec le matériel : `pip install platformio`, puis `cd webapp/firmware && pio run -t upload` et `pio device monitor -b 115200`. Câblage dans `webapp/firmware/README.md`.

---

## 9. App mobile Flutter — les 3 rôles

### 9.1 Prérequis Flutter

1. **Flutter SDK** 3.38 : https://docs.flutter.dev/get-started/install
2. **Android Studio** (SDK Android + émulateur).
3. `flutter doctor` — corrigez ce qui est en rouge (`flutter doctor --android-licenses`).

### 9.2 Dépendances

```bash
cd webapp/mobile
flutter pub get
```
(Ne lancez pas `flutter pub upgrade`.)

### 9.3 Vérifications sans émulateur

```bash
flutter analyze
flutter test
dart format --output=none --set-exit-if-changed lib test
```

Résultat attendu : **No issues found!** puis **All tests passed!** — dont les nouveaux tests : parsing des liens d'invitation, mapping des erreurs 404/410/401/409/400, écran *Finish your registration*, bouton *I have an invitation link*, restrictions parent (fiche en lecture seule, pas d'ajout de bébé), fiche patient côté docteur.

### 9.4 Exécution sur émulateur Android

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

> ⚠️ `10.0.2.2` = `localhost` **vu depuis l'émulateur**. Sur un téléphone physique, utilisez l'IP LAN du PC (ex. `http://192.168.1.20:8080`), même Wi-Fi, port 8080 autorisé.

### 9.5 Parcours de prévisualisation — parent (par invitation)

1. Enrôlez un bébé pour un **nouvel** email, ex. `parent2@test.com` (§7.3), et copiez le lien.
2. Ouvrez le lien dans l'émulateur, au choix :
   - **Deep link** (app lancée ou non) :
     ```bash
     adb shell am start -a android.intent.action.VIEW -d "app://invite/<token>"
     ```
   - **Copier-coller** : écran de connexion → **I have an invitation link** → collez le lien (ou le message entier, ou le token seul) → Continue.
3. Écran **Finish your registration** : prénom, nom, téléphone (facultatif), mot de passe + confirmation → validation. Vous êtes connecté, le bébé apparaît sur **Home**.
4. Cas à tester :
   - Même lien une 2ᵉ fois → « expired or was already used » (410).
   - Lien remplacé par un *Resend* → « not valid » (404).
   - Enrôlez un 2ᵉ bébé pour `parent2@test.com` (déjà client) → il apparaît directement (*Linked*, pas d'invitation).
   - Ouvrir un lien alors qu'un autre compte est connecté → l'app propose **Sign out and continue**.
   - **Create account** avec un rôle parent → message « les comptes parents sont créés via une invitation médicale ».
5. **Home** : plus de bouton *Add baby* ; sans bébé lié, un message explique que le bébé est enrôlé par l'équipe médicale.
6. Fiche bébé : **lecture seule** (aucun champ éditable, pas de suppression). **Medical history** en lecture seule.
7. **Pairing** : si le docteur a déjà appairé un bracelet → *Already paired by medical staff* + raccourci *Live monitoring* ; sinon scan normal.
8. **Réglages** (depuis Profile) : **Use BLE simulator** (activé par défaut — choisissez un scénario et ouvrez *Live monitoring*), unités, préférences de notifications (les alertes ne sont pas désactivables), confidentialité, **Delete account** (désactive le compte après mot de passe).

### 9.6 Parcours de prévisualisation — docteur (sur mobile)

1. Connectez-vous avec `doctor@test.com`.
2. **Onglet Patients** : bébés assignés uniquement (y compris ceux dont l'invitation est encore en attente — pas de parent affiché). Plus d'onglet *Requests*.
3. Fiche patient : mise à jour **poids / taille**, **appairage Bluetooth** du bracelet (cas « à la maternité »), historique, **Medical history** avec formulaire d'ajout.
4. Onglets **Alerts / Inbox / Profile** : données des patients assignés.

### 9.7 Parcours de prévisualisation — admin (sur mobile)

1. Connectez-vous avec le compte admin.
2. **Onglet Home** : cartes Users / Doctors / Parents / Babies / Bracelets / Active alerts → annuaires avec recherche.
3. Fiche bébé : modification/suppression complètes, affectation directe du docteur.
4. Onglets **Alerts / Inbox / Profile** : vue globale.

> ℹ️ **Limites sans matériel** : seul le **vrai BLE** nécessite un appareil Bluetooth (indisponible sur émulateur). Les push nécessitent Firebase (`webapp/mobile/android_notes/README.md`). Tout le reste fonctionne sans matériel.

---

## 10. (Option) Stack production Docker Compose

PostgreSQL, Redis, gunicorn, Celery worker + **beat** (watchdogs `no_data` et expiration des invitations), nginx :

```bash
cd centure_backend
cp .env.example .env      # Windows : Copy-Item .env.example .env
```

Éditez `.env` — au minimum les lignes `# REQUIRES:` :
- `DJANGO_SECRET_KEY` → `python -c "import secrets;print(secrets.token_urlsafe(64))"`
- `POSTGRES_PASSWORD` → un mot de passe fort
- FCM peut rester vide en local (push inactifs).
- Optionnel : `INVITATION_TTL_DAYS` (défaut 7), `INVITATION_EXPIRY_CHECK_SECONDS` (défaut 3600).

```bash
docker compose up -d --build        # le conteneur web applique migrate + collectstatic au démarrage
docker compose exec web python manage.py createsuperuser   # compte admin
docker compose ps                   # tous les services → healthy
```

L'API est alors sur **http://localhost:8080** (nginx, port `NGINX_PORT`, 8080 par défaut) — les commandes des étapes 5 à 7 restent identiques. Arrêt : `docker compose down` (`-v` pour effacer les données).

---

## 11. Dépannage rapide

| Problème | Cause probable | Solution |
|---|---|---|
| `python` introuvable (Windows) | PATH | Réinstallez Python avec « Add to PATH », ou utilisez `py` |
| `Activate.ps1 cannot be loaded` | Politique PowerShell | `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` |
| `migrate` échoue sur `0005_backfill_legacy_enrollment` | Base avec bébés mais aucun docteur/admin/superuser | `python manage.py createsuperuser`, puis `migrate` |
| Port 8080 déjà pris | Autre service | Lancez sur 8081 et adaptez `--base-url` / `.env.local` |
| Dashboard : « Failed to fetch » / CORS | Backend arrêté ou mauvaise URL | Vérifiez le backend + `NEXT_PUBLIC_API_BASE_URL` ; `http://localhost:3100` est autorisé par défaut |
| Dashboard : bébé enrôlé absent de *Patients* | Docteur non assigné | Réenrôlez en vous choisissant comme *Assigned doctor*, ou faites l'affectation en admin (§6.3) |
| Dashboard : compte parent refusé | Voulu | Le dashboard est réservé docteur/admin |
| `POST /auth/register` → 403 pour un parent | Voulu (refonte) | Enrôlez le bébé puis acceptez l'invitation (§5.3–5.4) |
| `POST /babies/` → 403 | Appel fait avec un compte parent | Seuls docteur/admin enrôlent |
| `POST /babies/` → 400 `enrollment_notes` | Motif `other` sans description | Ajoutez `enrollment_notes` |
| Acceptation → 404 | Token inconnu ou remplacé par un *Resend* | Utilisez le dernier lien |
| Acceptation → 410 | Invitation expirée ou déjà acceptée | *Resend invitation* depuis *Pending enrollments* |
| Acceptation → 401 | Un compte parent existe déjà pour cet email | Saisissez le mot de passe **existant** |
| Acceptation → 409 | L'email appartient à un docteur/admin | Corrigez l'email du parent et réenrôlez |
| Lien `app://` non cliquable (SMS, messagerie) | Schéma personnalisé | *I have an invitation link* sur l'écran de connexion, ou `adb shell am start …` |
| Simulateur Python : 403 / 400 sur `POST /babies/` | Aucun bébé visible pour ce compte | Enrôlez un bébé (§5.3) ; connectez le parent lié ou le docteur assigné |
| Simulateur Python : HTTP 401 | Mauvais identifiants | Vérifiez le compte (§5) |
| `flutter doctor` en rouge | SDK Android/licences | `flutter doctor --android-licenses` |
| L'app mobile ne joint pas l'API | Mauvaise adresse | Émulateur → `10.0.2.2` ; téléphone → IP LAN du PC |
| g++ : `command not found` (Windows) | MinGW absent du PATH | Ajoutez `C:\msys64\ucrt64\bin` au PATH |
| Repartir de zéro | — | Stoppez le backend, supprimez `centure_backend/db.sqlite3`, refaites 4.3 → 5 |

---

## 12. Récapitulatif des commandes de démarrage quotidien

Depuis `smart_bracele/` :

```bash
# Terminal 1 — backend
cd centure_backend
source .venv/bin/activate            # Windows : .\.venv\Scripts\Activate.ps1
CELERY_TASK_ALWAYS_EAGER=true python manage.py runserver 0.0.0.0:8080
# Windows : $env:CELERY_TASK_ALWAYS_EAGER="true" ; python manage.py runserver 0.0.0.0:8080

# Terminal 2 — dashboard
cd dashboard/dashboard
npm run dev                          # http://localhost:3100

# Terminal 3 — app mobile
cd webapp/mobile
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080

# Terminal 4 — injecter des données (optionnel ; un bébé doit être enrôlé)
cd webapp/tools/simulator
python bracelet_simulator.py --base-url http://localhost:8080 --email parent@test.com --password "TestPass123!" --scenario fever --count 12
```

Comptes : docteur `doctor@test.com`, parent `parent@test.com` (créé par invitation) — mot de passe `TestPass123!`. Admin : le vôtre (`createsuperuser`).

Bonne exploration ! 🩺
