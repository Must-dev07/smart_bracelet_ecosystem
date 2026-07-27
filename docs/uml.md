# UML Diagrams

Mermaid sources — viewable on GitHub or any Mermaid renderer.

## 1. Use-case diagram

```mermaid
flowchart LR
    subgraph Actors
        P(("👤 Parent"))
        D(("🧑‍⚕️ Doctor"))
        A(("🛠 Admin"))
        B(("📟 Bracelet"))
        S(("⏱ Scheduler"))
    end

    subgraph "Mobile App"
        UC1[Register / Login]
        UC2[Pair bracelet via BLE]
        UC3[View live vitals]
        UC4[View history & graphs]
        UC5[Receive push alerts / acknowledge]
        UC6[Manage baby profile]
    end

    subgraph "Doctor Dashboard"
        UC7[Monitor assigned patients]
        UC8[Triage & acknowledge alerts]
        UC9[Add medical history entries]
        UC10[Generate PDF reports]
        UC11[View statistics]
        UC12[Manage users - admin]
    end

    subgraph "Backend (automatic)"
        UC13[Ingest & validate measurements]
        UC14[Evaluate rules → raise alerts]
        UC15[Dispatch notifications FCM]
        UC16[Watchdog: no-data detection]
    end

    P --> UC1 & UC2 & UC3 & UC4 & UC5 & UC6
    D --> UC1 & UC7 & UC8 & UC9 & UC10 & UC11
    A --> UC7 & UC8 & UC10 & UC11 & UC12
    B -->|BLE notify| UC3
    B -.->|via app relay| UC13
    UC13 --> UC14 --> UC15
    S --> UC16 --> UC14
```

## 2. Class diagram — backend rule engine & notifications

```mermaid
classDiagram
    class Rule {
        <<abstract>>
        +str code
        +str severity
        +bool critical
        +evaluate(measurement) RuleResult|None
    }
    class RuleResult {
        +str type
        +str severity
        +str message
        +float value
    }
    class HighTemperatureRule
    class LowTemperatureRule
    class LowOxygenRule
    class HighHeartRateRule
    class LowHeartRateRule
    class NoMovementRule
    class BraceletRemovedRule
    class BatteryLowRule
    class RuleRegistry {
        +register(rule) decorator
        +run_rules(measurement, critical_only, non_critical_only)
    }
    class NotificationChannel {
        <<abstract>>
        +send(user, title, body, data) bool
    }
    class FCMPushChannel {
        -_access_token() str
        +send(user, title, body, data) bool
    }
    class Alert {
        +Type type
        +Severity severity
        +resolved_at
        +acknowledged_by
    }
    class Measurement {
        +heart_rate
        +temperature
        +spo2
        +movement JSON
    }

    Rule <|-- HighTemperatureRule
    Rule <|-- LowTemperatureRule
    Rule <|-- LowOxygenRule
    Rule <|-- HighHeartRateRule
    Rule <|-- LowHeartRateRule
    Rule <|-- NoMovementRule
    Rule <|-- BraceletRemovedRule
    Rule <|-- BatteryLowRule
    RuleRegistry o-- Rule : registry
    Rule ..> Measurement : evaluates
    Rule ..> RuleResult : produces
    RuleResult ..> Alert : materialised as
    NotificationChannel <|-- FCMPushChannel
    Alert ..> NotificationChannel : fan-out
```

## 3. Class diagram — firmware sensor abstraction

```mermaid
classDiagram
    class SensorDriver {
        <<abstract>>
        +name() const char*
        +begin() bool
        +read(Sample&) bool
        +sleep()
        +wake()
        #healthy_ bool
    }
    class Max30102Driver {
        -MedianFilter5 hr_filter_
        -MedianFilter5 spo2_filter_
    }
    class TemperatureDriver {
        -MedianFilter5 filter_
    }
    class Mpu6050Driver
    class BatteryDriver {
        -BatteryFilter filter_
    }
    class SkinContactDriver {
        -debounce 3 reads
    }
    class Sample {
        +float heart_rate
        +float temperature
        +float spo2
        +Movement movement
        +float battery_pct
        +bool skin_contact
    }
    class RingBuffer~Sample,720~ {
        +push() overwrite-oldest
        +pop() FIFO
    }
    class HealthService {
        +begin(serial, onCommand)
        +publish(Sample)
        +connected() bool
    }

    SensorDriver <|-- Max30102Driver
    SensorDriver <|-- TemperatureDriver
    SensorDriver <|-- Mpu6050Driver
    SensorDriver <|-- BatteryDriver
    SensorDriver <|-- SkinContactDriver
    SensorDriver ..> Sample : fills
    RingBuffer o-- Sample : buffers offline
    HealthService ..> Sample : encodes float32 LE
```

## 4. Sequence — pairing, ingest, alert, notification

```mermaid
sequenceDiagram
    autonumber
    participant BR as Bracelet (ESP32)
    participant APP as Mobile app (Flutter)
    participant API as Backend (DRF)
    participant RE as Rule engine
    participant CE as Celery
    participant FCM as FCM
    participant DASH as Dashboard

    APP->>BR: BLE scan (service UUID) + connect + bond
    BR-->>APP: device_info "fw=1.0.0;serial=ABC123"
    APP->>API: POST /bracelets/ {serial, firmware}
    APP->>API: POST /bracelets/{id}/pair/ {baby_id}
    API-->>APP: 200 paired

    loop every 5 s
        BR-->>APP: notify hr/temp/spo2/movement/battery (float32 LE)
        APP->>APP: queue in SQLite (offline-first)
    end

    APP->>API: POST /measurements/ [batch ≤500]
    API->>API: validate ranges, check ownership,<br/>update last_seen_at/battery
    API->>RE: run critical rules (sync)
    RE-->>API: HIGH_TEMP fired (38.4 °C > 38.0)
    API->>API: create Alert (dedup: no open same-type)
    API->>CE: queue non-critical rules + dispatch task
    CE->>FCM: HTTP v1 send → parent & doctor device tokens
    FCM-->>APP: push "High temperature — not a diagnosis"
    APP->>APP: deep link → Alert detail screen
    DASH->>API: GET /alerts/?status=active (poll 20 s)
    API-->>DASH: alert list (+ disclaimer field)
    DASH->>API: POST /alerts/{id}/acknowledge/
    API-->>DASH: acknowledged (+auto-resolve)
```

## 5. Sequence — login & session rotation

```mermaid
sequenceDiagram
    autonumber
    participant C as Client (app/dashboard)
    participant API as Backend
    participant DB as Session table

    C->>API: POST /auth/login {email, password}
    API->>API: authenticate, issue access+refresh JWT
    API->>DB: INSERT Session(refresh_jti, device_info)
    API-->>C: {access, refresh, user}

    Note over C: access expires (15 min)

    C->>API: POST /auth/refresh {refresh}
    API->>DB: lookup jti — revoked? ─ reject if so
    API->>DB: revoke old session, INSERT new Session(jti')
    API-->>C: {access', refresh'} (rotation)

    C->>API: POST /auth/logout {refresh}
    API->>DB: revoke session
    API-->>C: 204
```
