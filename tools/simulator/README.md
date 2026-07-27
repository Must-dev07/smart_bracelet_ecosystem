# Bracelet Simulator

Emulates the full **bracelet → mobile app → backend** data path without
hardware: logs in as a parent, registers/pairs a simulated bracelet,
generates physiologically plausible newborn vitals (round-tripped through
float32 exactly like the firmware's BLE payloads), and bulk-ingests them —
so the whole backend pipeline (validation → rule engine → alerts) can be
exercised end to end.

## Usage

```bash
# backend running on :8080, a parent account existing
python3 bracelet_simulator.py \
  --base-url http://localhost:8080 \
  --email parent.sim@example.com --password 'SimPass123!' \
  --serial SIM0001 --scenario fever --count 12
```

## Scenarios

| Scenario | Drift | Expected backend reaction |
|---|---|---|
| `normal` | healthy vitals | no alerts |
| `fever` | temp ramps > 38 °C | `high_temp` critical |
| `hypoxia` | SpO2 dips < 92 % | `low_oxygen` critical |
| `tachy` | HR climbs > 180 bpm | `high_hr` critical |
| `still` | movement ≈ 0 | feeds the `no_movement` rule window |
| `lowbatt` | battery < 15 % | `battery_low` info |

Options: `--count` (samples), `--batch-size` (mimics the mobile offline
queue draining in batches), `--interval` (seconds between samples),
`--seed` (reproducible runs).

## Verified integration pass (in-sandbox, 2026-07-24)

Against the Django backend on SQLite with `CELERY_TASK_ALWAYS_EAGER`:

1. `register` parent + doctor → tokens issued, sessions recorded
2. simulator: bracelet registered, baby created, paired
3. `normal` ×10 → 0 alerts ✅
4. `fever`/`hypoxia`/`tachy` → `high_temp`, `low_oxygen`, `high_hr`
   critical alerts (deduplicated while open) ✅
5. `lowbatt` → `battery_low` info alert ✅
6. doctor saw **0** babies before assignment; after the parent set
   `assigned_doctor`, the doctor saw the baby, minute-bucketed
   measurements, active alerts, and successfully acknowledged one
   (auto-resolved) ✅
