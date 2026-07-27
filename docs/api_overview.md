# API Overview (human-readable)

Base URL: `https://<host>/api/v1/` · Auth: `Authorization: Bearer <access JWT>`
Machine-readable spec: [`openapi.yaml`](./openapi.yaml) · live Swagger UI at `/api/docs/`.

Pagination: DRF page-number style — `{count, next, previous, results}`, `?page=N`.
Role scoping: parents see their own babies/bracelets; doctors see assigned
babies; admins see everything. Foreign objects return **404**.

## Auth (`/auth/`)
| Method & path | Body | Notes |
|---|---|---|
| POST `/auth/register` | `email, password, first_name, last_name, role(parent\|doctor), phone?, license_number*, specialty?, address?, emergency_contact?` | `license_number` required for doctors. Returns token pair + user. Throttled 20/min. |
| POST `/auth/login` | `email, password` | Returns `{access, refresh, user}`; records a Session. |
| POST `/auth/refresh` | `refresh` | **Rotation**: revokes the old session, issues a new pair. |
| POST `/auth/logout` | `refresh` | Revokes the session. |

## Users
| Method & path | Access | Notes |
|---|---|---|
| GET `/me/` | any | Current user summary. |
| GET `/users/` | **admin** | Full account list. |
| GET `/doctors/` | any | Doctor directory (for assignment). |
| GET/PATCH `/doctors/{id}/` | self or admin | Nested `user{first_name,last_name,phone}` + `specialty`. |
| GET/PATCH `/parents/{id}/` | self or admin | `address`, `emergency_contact`. |

## Babies (`/babies/`)
| Method & path | Notes |
|---|---|
| GET, POST `/babies/` | POST (parent): `name, birth_date, weight_grams(300–8000), gender(male\|female\|unspecified)`. |
| GET, PATCH, DELETE `/babies/{id}/` | PATCH can set `assigned_doctor`. |
| GET, POST `/babies/{id}/medical-history/` | Append-only entries; `supersedes` chains corrections. |

## Bracelets (`/bracelets/`)
| Method & path | Notes |
|---|---|
| GET, POST `/bracelets/` | POST: `serial_number, firmware_version`. |
| GET, PATCH `/bracelets/{id}/` | `battery_level`, `status`. |
| POST `/bracelets/{id}/pair/` | `{baby_id}` — opens a Pairing record. |
| POST `/bracelets/{id}/unpair/` | Closes the pairing. |
| GET `/bracelets/{id}/pairings/` | Pairing history. |

## Measurements (`/measurements/`)
| Method & path | Notes |
|---|---|
| POST `/measurements/` | Single object **or bulk array (≤500)**. Fields: `bracelet, heart_rate?, temperature?, spo2?, movement?{accel[3],gyro[3],magnitude}, battery?, skin_contact?, recorded_at`. Validates physiological ranges (HR 20–300, temp 25–45, SpO2 0–100); rejects foreign/unpaired bracelets; updates `last_seen_at`/battery; runs **critical rules synchronously**, queues the rest; auto-resolves NO_DATA. Throttled 600/min. |
| GET `/measurements/?baby_id=&from=&to=&granularity=` | `granularity`: `raw` (default, window ≤ 92 days) or `minute`/`hour`/`day` buckets `{bucket, heart_rate_avg/min/max, temperature_avg, spo2_avg, count}`. Defaults: last 24 h. |

## Alerts (`/alerts/`)
| Method & path | Notes |
|---|---|
| GET `/alerts/?baby_id=&status=active\|resolved&severity=` | Every payload includes the non-diagnostic `disclaimer`. |
| GET `/alerts/{id}/` | Detail. |
| POST `/alerts/{id}/acknowledge/` | Sets acknowledged_by/at; auto-resolves non-persistent types. |
| POST `/alerts/report-ble-lost/` | `{bracelet_id}` — mobile-observed BLE loss; deduplicated. |

## Notifications (`/notifications/`)
| Method & path | Notes |
|---|---|
| GET `/notifications/` | Current user's notifications. |
| POST `/notifications/{id}/read/` | Mark read. |
| POST `/notifications/device-tokens/` | `{token, platform}` — FCM registration. |

## Rule engine (server-side, automatic)
| Rule | Trigger | Severity |
|---|---|---|
| high_temp / low_temp | > 38.0 °C / < 36.0 °C | critical / warning |
| low_oxygen | SpO2 < 92 % | critical |
| high_hr / low_hr | > 180 / < 90 bpm | critical |
| no_movement | magnitude below threshold over window | warning |
| bracelet_removed | skin_contact false streak | warning |
| battery_low | < 15 % | info |
| ble_lost | reported by the app | warning |
| no_data | celery-beat watchdog: no ingest for the window | warning |

One **open** alert per (baby, type); duplicates suppressed until resolution.
