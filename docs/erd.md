# Entity-Relationship Diagram (ERD)

Database schema of the Django backend (PostgreSQL in production, SQLite in
local tests). Rendered with Mermaid — viewable on GitHub or any Mermaid
viewer.

```mermaid
erDiagram
    USER {
        int id PK
        string email UK "login identifier"
        string first_name
        string last_name
        string role "parent | doctor | admin"
        string phone
        datetime created_at
    }
    DOCTOR {
        int id PK
        int user_id FK, UK "OneToOne → USER"
        string license_number UK
        string specialty
    }
    PARENT {
        int id PK
        int user_id FK, UK "OneToOne → USER"
        string address
        string emergency_contact
    }
    SESSION {
        int id PK
        int user_id FK
        string refresh_jti UK "JWT ID of the refresh token"
        string device_info
        bool revoked
        datetime created_at
        datetime last_used_at
    }
    BABY {
        int id PK
        string name
        date birth_date
        int weight_grams "300–8000 validated"
        string gender "male | female | unspecified"
        int parent_id FK
        int assigned_doctor_id FK "nullable"
        datetime created_at
    }
    MEDICAL_HISTORY_ENTRY {
        int id PK
        int baby_id FK
        string title
        text details
        int recorded_by FK "→ USER, nullable"
        int supersedes FK "append-only correction chain"
        datetime created_at
    }
    BRACELET {
        int id PK
        string serial_number UK
        string firmware_version
        int baby_id FK "nullable — paired baby"
        float battery_level "0–100"
        datetime last_seen_at
        string status "active | inactive"
        datetime created_at
    }
    PAIRING {
        int id PK
        int bracelet_id FK
        int baby_id FK
        datetime paired_at
        datetime unpaired_at "null while active"
    }
    MEASUREMENT {
        int id PK
        int baby_id FK "denormalised at ingest"
        int bracelet_id FK
        float heart_rate "20–300 validated, nullable"
        float temperature "25–45 validated, nullable"
        float spo2 "0–100 validated, nullable"
        json movement "accel[3], gyro[3], magnitude"
        float battery
        bool skin_contact
        datetime recorded_at "device clock"
        datetime received_at "server clock"
    }
    ALERT {
        int id PK
        int baby_id FK
        int bracelet_id FK "nullable"
        string type "high_temp | low_temp | low_oxygen | high_hr | low_hr | no_movement | bracelet_removed | battery_low | ble_lost | no_data"
        string severity "info | warning | critical"
        text message "always non-diagnostic wording"
        float value "offending reading, nullable"
        datetime triggered_at
        datetime resolved_at "null while open (dedup key)"
        int acknowledged_by FK "→ USER, nullable"
        datetime acknowledged_at
    }
    NOTIFICATION {
        int id PK
        int user_id FK "recipient"
        int alert_id FK "nullable"
        string title
        text body
        string channel "push | (future: sms, email)"
        string status "pending | sent | failed"
        datetime created_at
        datetime read_at
    }
    DEVICE_TOKEN {
        int id PK
        int user_id FK
        string token UK "FCM registration token"
        string platform "android | ios"
        datetime created_at
    }
    AUDIT_LOG {
        int id PK
        int user_id FK "nullable"
        string method
        string path
        int status_code
        string ip
        datetime created_at "metadata only, no payloads"
    }

    USER ||--o| DOCTOR : "profile"
    USER ||--o| PARENT : "profile"
    USER ||--o{ SESSION : "sessions"
    USER ||--o{ DEVICE_TOKEN : "push tokens"
    USER ||--o{ NOTIFICATION : "receives"
    USER ||--o{ AUDIT_LOG : "actions"
    PARENT ||--o{ BABY : "children"
    DOCTOR ||--o{ BABY : "assigned patients"
    BABY ||--o{ MEDICAL_HISTORY_ENTRY : "history"
    BABY ||--o{ MEASUREMENT : "vitals"
    BABY ||--o{ ALERT : "alerts"
    BABY ||--o{ PAIRING : "pairing history"
    BRACELET ||--o{ PAIRING : "pairing history"
    BRACELET ||--o{ MEASUREMENT : "produces"
    BRACELET |o--o| BABY : "currently paired"
    ALERT ||--o{ NOTIFICATION : "fans out"
```

## Design notes

- **`MEASUREMENT.baby_id` is denormalised** at ingest time (copied from the
  bracelet's current pairing) so historical data stays attached to the baby
  even after unpairing/re-pairing the bracelet to another child.
- **Alert dedup**: one *open* alert (`resolved_at IS NULL`) per
  `(baby, type)`; rules skip firing while an open alert of the same type
  exists. Acknowledging a non-persistent alert resolves it.
- **`SESSION.refresh_jti`** enables refresh-token rotation: each refresh
  revokes the previous session row and records a new one; logout revokes.
- **`MEDICAL_HISTORY_ENTRY.supersedes`** keeps history append-only —
  corrections reference the superseded entry instead of editing it.
- Indexes: `measurement(baby, recorded_at)`, `alert(baby, resolved_at)`,
  `user(email)`, `bracelet(serial_number)` — the hot query paths.
