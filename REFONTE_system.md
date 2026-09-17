# TÂCHE — Refonte du workflow d'enrôlement des bébés (suivi clinique à risque)

> Ce document est le cahier des charges à donner à Claude Code. Il ne doit PAS être
> collé directement dans le terminal comme un message de chat — voir la fin du fichier
> pour la méthode d'exécution recommandée.

## ⚠️ Décisions à confirmer avant de lancer l'implémentation

- [ ] `Baby.enrollment_reason` : liste fermée (`prematurity`, `clinical_sign`,
      `congenital_condition`, `other`) OU texte libre uniquement ? **Par défaut ci-dessous : liste fermée.**
      Si vous préférez du texte libre, remplacez la section 2.1 en conséquence avant d'envoyer ce fichier.
- [ ] `Baby.gestational_age_weeks` : à garder ou à supprimer si non pertinent pour votre cas d'usage ?
- [ ] Durée de validité du token d'invitation (proposé : 14 jours, ajustable en settings).

---

## 0. Contexte — NE PAS CASSER CE QUI EXISTE

Projet : plateforme de suivi de nouveau-nés via bracelet connecté.
- Backend : Django + DRF (`users`, `babies`, `bracelets`, `measurements`, `alerts`, `notifications`)
- Dashboard : Next.js (docteurs/admin)
- Mobile : Flutter (parents), Riverpod pour l'état
- Firmware ESP32 (hors périmètre de cette tâche)

**Règles impératives pour Claude Code :**
1. Conserver l'architecture existante (Django + DRF + JWT, structure des apps, Riverpod côté mobile).
2. Ne PAS toucher au moteur de règles (`analysis`), aux `Measurement`, à la pagination, à la rotation
   des tokens JWT, ni aux endpoints qui ne sont pas listés ci-dessous.
3. Toute migration Django doit être réversible et ne jamais supprimer de données existantes sans
   migration de données explicite.
4. Ajouter des tests pour chaque nouveau comportement (le projet a une suite pytest existante à 55 tests
   qui doit continuer à passer).
5. Ne jamais renommer un endpoint existant utilisé par le mobile ou le dashboard sans lister explicitement
   tous les fichiers clients à mettre à jour en conséquence.

## 1. Changement de concept

**Avant** : le parent crée son compte, ajoute son bébé, l'appaire lui-même à un bracelet.

**Après** : le bébé est enrôlé par un **docteur ou un admin** au moment où un risque est identifié
(prématurité, signe clinique). Le parent n'a plus le droit de créer ni modifier la fiche du bébé.
Le parent peut ne pas encore avoir de compte au moment de l'enrôlement.

## 2. Modèle de données

### 2.1 Modifications sur `Baby` (app `babies`)

```python
class Baby(models.Model):
    class EnrollmentReason(models.TextChoices):
        PREMATURITY = "prematurity"
        CLINICAL_SIGN = "clinical_sign"
        CONGENITAL_CONDITION = "congenital_condition"
        OTHER = "other"

    # parent devient nullable : un bébé peut exister avant que le compte parent existe
    parent = models.ForeignKey(Parent, null=True, blank=True, on_delete=models.SET_NULL, related_name="babies")

    enrollment_reason = models.CharField(max_length=32, choices=EnrollmentReason.choices)
    enrollment_notes = models.TextField(blank=True)  # détail texte libre du signe clinique observé
    gestational_age_weeks = models.PositiveSmallIntegerField(null=True, blank=True)
    enrolled_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name="enrolled_babies"
    )  # audit : quel docteur/admin a créé la fiche
```

À la création d'un `Baby`, créer automatiquement une première `MedicalHistoryEntry` avec
`title="Enrôlement"` et `details=enrollment_notes`, `recorded_by=enrolled_by`.

Migration : `parent` passe de `on_delete=CASCADE` (obligatoire) à `on_delete=SET_NULL` (nullable).
Écrire une migration de données qui, pour les `Baby` existants, copie l'`enrolled_by` actuel vers
le premier `Doctor`/`Admin` disponible (ou vers le premier superuser si aucun autre choix), afin de
ne pas casser les lignes déjà en base.

### 2.2 Nouveau modèle `Invitation` (nouvelle app `invitations` ou dans `users`)

```python
class Invitation(models.Model):
    class Status(models.TextChoices):
        PENDING = "pending"
        ACCEPTED = "accepted"
        EXPIRED = "expired"

    email = models.EmailField()
    phone = models.CharField(max_length=32, blank=True)
    first_name = models.CharField(max_length=100, blank=True)
    last_name = models.CharField(max_length=100, blank=True)
    token = models.CharField(max_length=64, unique=True, db_index=True)  # secrets.token_urlsafe
    status = models.CharField(max_length=10, choices=Status.choices, default=Status.PENDING)
    created_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name="invitations_sent")
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()
    accepted_at = models.DateTimeField(null=True, blank=True)
    babies = models.ManyToManyField(Baby, related_name="pending_invitations", blank=True)
```

## 3. Logique métier à implémenter

### 3.1 Création d'un bébé — `POST /babies/` (permission : docteur ou admin uniquement)

Nouveau payload attendu :
```json
{
  "name": "...", "birth_date": "...", "weight_grams": ...,
  "gender": "...", "assigned_doctor": <id, optionnel>,
  "enrollment_reason": "prematurity", "enrollment_notes": "...", "gestational_age_weeks": 32,
  "parent_email": "parent@example.com"
}
```

Logique côté vue :
1. Rechercher un `User` existant avec `role=parent` et cet email.
   - **Trouvé** → créer le `Baby` avec `parent` renseigné directement. Ne rien créer d'autre.
   - **Non trouvé** → créer le `Baby` avec `parent=None`, puis créer (ou réutiliser si `pending` existe déjà
     pour cet email) une `Invitation` avec ce `Baby` dans `babies`, `token` généré, `expires_at` = now + 14 jours.
2. Répondre avec le `Baby` créé + un champ `parent_status`: `"linked"` ou `"invitation_pending"` pour que le
   dashboard affiche clairement l'état.

### 3.2 Nouvel endpoint — `GET /parents/` (permission : docteur ou admin)

Liste paginée des `Parent` (annuaire, sur le même modèle que `GET /doctors/` déjà existant), avec un
paramètre `?search=` sur email/nom pour que le docteur retrouve un parent existant en tapant son email.

### 3.3 Nouveaux endpoints — invitations

- `POST /invitations/{token}/accept/` — **accès public sans JWT** (auth par token uniquement, comme un lien
  de réinitialisation de mot de passe). Payload : `password, first_name?, last_name?, phone?`.
  - Vérifie que le token est `pending` et non expiré (sinon 410 Gone).
  - Crée le `User` (role=parent) + `Parent`.
  - Rattache tous les `Baby` de `invitation.babies` à ce nouveau `Parent`.
  - Passe `invitation.status = accepted`, `accepted_at = now`.
  - Retourne une paire de tokens JWT (comme `/auth/login`) pour connecter l'utilisateur immédiatement.
- `GET /invitations/?status=pending` (permission docteur/admin) — pour lister les enrôlements en attente
  de rattachement parent sur le dashboard.
- Watchdog Celery (même mécanisme que `detect_no_data`) qui passe les invitations expirées à `status=expired`.

### 3.4 Fermeture de l'auto-inscription parent

`POST /auth/register` : si `role == "parent"`, retourner **403** avec un message clair
("les comptes parents sont créés via une invitation médicale"). Le rôle `doctor` reste en inscription libre,
inchangé. (Le rôle `admin` n'a jamais été en self-register — vérifier que c'est toujours le cas.)

### 3.5 Pairing du bracelet — permission élargie

`POST /bracelets/{id}/pair/` et `POST /bracelets/{id}/unpair/` :
Permission actuelle : parent propriétaire du bébé uniquement.
Nouvelle permission : **parent propriétaire OU docteur assigné au bébé OU admin**.
Aucun changement de schéma de requête/réponse — uniquement la classe de permission DRF à modifier.

### 3.6 Modification de la fiche bébé

`PATCH /babies/{id}/` : permission actuelle (self-or-admin côté parent) → devient
**docteur assigné ou admin uniquement**. Le parent perd l'accès en écriture (garde le `GET` en lecture seule).

## 4. Permissions — tableau récapitulatif à implémenter dans les classes DRF

| Endpoint | Avant | Après |
|---|---|---|
| `POST /babies/` | Parent | Docteur, Admin |
| `PATCH /babies/{id}/` | Parent (self), Admin | Docteur assigné, Admin |
| `GET /babies/{id}/`, `GET /babies/` | Parent (own), Docteur (assigné), Admin | inchangé |
| `POST /bracelets/{id}/pair/` `.../unpair/` | Parent propriétaire | Parent propriétaire, Docteur assigné, Admin |
| `POST /auth/register` (role=parent) | Libre | **403 interdit** |
| `POST /auth/register` (role=doctor) | Libre | inchangé |
| `GET /parents/` | N'existe pas | Docteur, Admin (nouveau) |
| `POST /invitations/{token}/accept/` | N'existe pas | Public (token) |
| `GET /invitations/` | N'existe pas | Docteur, Admin |

## 5. Dashboard (Next.js)

- Nouvel écran "Enrôler un nouveau-né" : formulaire avec les champs de 3.1, recherche de parent existant
  (`GET /parents/?search=`) avec fallback "créer une invitation" si aucun résultat.
- Nouvel écran/onglet "Enrôlements en attente" (`GET /invitations/?status=pending`) listant les bébés dont
  le parent n'a pas encore accepté l'invitation, avec possibilité de renvoyer l'invitation.
- Écran fiche bébé : rendre le formulaire d'édition accessible uniquement si l'utilisateur connecté est
  le docteur assigné ou un admin.

## 6. Mobile (Flutter)

- Supprimer l'écran/action "Ajouter un bébé" pour le rôle parent (le bébé apparaît automatiquement dans
  `babiesProvider` une fois le compte lié).
- Nouvel écran "Finaliser mon inscription" atteint via un lien profond (deep link) `app://invite/{token}`
  → appelle `POST /invitations/{token}/accept/`, stocke les JWT reçus, redirige vers `/home`.
- La fiche bébé (`baby_details_screen`) passe en **lecture seule** pour le parent (garder l'affichage,
  retirer les champs éditables).
- L'écran Pairing reste inchangé fonctionnellement (le parent peut toujours appairer), mais gérer le cas
  où le bébé est déjà appairé par le personnel médical à l'hôpital (afficher "déjà appairé par Dr. X" au
  lieu de proposer un nouveau scan).

## 7. Tests à ajouter (pytest)

- Création de bébé par un parent → 403.
- Création de bébé par un docteur avec email d'un parent existant → bébé lié directement, aucune invitation créée.
- Création de bébé par un docteur avec email inconnu → bébé créé avec `parent=None`, invitation `pending` créée.
- Acceptation d'une invitation valide → compte créé, bébé(s) rattaché(s), tokens JWT renvoyés.
- Acceptation d'une invitation expirée → 410.
- Double création de bébé avec le même email non enregistré → réutilisation de l'invitation `pending`
  existante plutôt que d'en créer une deuxième.
- `PATCH /babies/{id}/` par le parent propriétaire → 403 (avant : 200).
- Pairing par le docteur assigné → 200 (nouveau cas à couvrir).
- `POST /auth/register` avec `role=parent` → 403.

## 8. Ordre d'implémentation recommandé (à respecter, phase par phase)

1. **Modèles + migrations** (`Baby`, `Invitation`) — rien d'autre. Lancer `pytest` : les tests existants
   qui touchent à la création de `Baby` vont casser à cause de `parent` nullable et des nouveaux champs
   obligatoires — les adapter à ce stade seulement pour qu'ils repassent.
2. **Permissions DRF + logique de création/pairing** (sections 3.1, 3.5, 3.6, 3.4).
3. **Endpoints invitations** (3.2, 3.3) + Celery watchdog d'expiration.
4. **Tests pytest** de la section 7.
5. **Dashboard** (section 5).
6. **Mobile** (section 6).

Claude Code doit s'arrêter après chaque phase, résumer ce qui a été fait, exécuter les tests concernés,
et attendre validation avant de passer à la phase suivante.
