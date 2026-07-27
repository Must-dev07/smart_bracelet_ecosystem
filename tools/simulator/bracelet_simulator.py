#!/usr/bin/env python3
"""Bracelet simulator — emulates the phone-relay data path end to end.

The physical chain is: bracelet --BLE--> mobile app --HTTPS--> backend.
This tool plays both bracelet (realistic vitals generation, same float32
semantics as the firmware) and mobile app (JWT auth + bulk ingest), so the
whole backend pipeline (validation → rules → alerts) can be exercised
without hardware.

Scenarios:
  normal    healthy newborn vitals (default)
  fever     temperature ramps to >38 °C  → HIGH_TEMP alert
  hypoxia   SpO2 dips below 92 %         → LOW_OXYGEN critical alert
  tachy     heart rate above 180 bpm     → HIGH_HR alert
  still     movement magnitude ~0        → NO_MOVEMENT path
  lowbatt   battery drains below 15 %    → BATTERY_LOW alert

Usage:
  python bracelet_simulator.py --base-url http://localhost:8080 \
      --email parent@example.com --password 'Secret123!' \
      --serial SIM0001 --scenario fever --count 12 --interval 0
"""
from __future__ import annotations

import argparse
import json
import math
import random
import struct
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timedelta, timezone


# ------------------------------------------------------------------ HTTP
class Api:
    def __init__(self, base_url: str) -> None:
        self.base_url = base_url.rstrip("/")
        self.access: str | None = None

    def request(self, method: str, path: str, body: dict | list | None = None,
                auth: bool = True) -> dict | list | None:
        url = f"{self.base_url}{path}"
        data = json.dumps(body).encode() if body is not None else None
        req = urllib.request.Request(url, data=data, method=method)
        req.add_header("Content-Type", "application/json")
        if auth and self.access:
            req.add_header("Authorization", f"Bearer {self.access}")
        try:
            with urllib.request.urlopen(req, timeout=15) as resp:
                raw = resp.read()
                return json.loads(raw) if raw else None
        except urllib.error.HTTPError as e:
            detail = e.read().decode(errors="replace")
            raise SystemExit(f"HTTP {e.code} {method} {path}: {detail}") from e

    def login(self, email: str, password: str) -> dict:
        out = self.request("POST", "/api/v1/auth/login",
                           {"email": email, "password": password}, auth=False)
        assert isinstance(out, dict)
        self.access = out["access"]
        return out


# ------------------------------------------------------------------ vitals
def f32(value: float) -> float:
    """Round-trip through float32 — the exact precision the firmware sends
    over BLE (struct '<f'), so ingested values match hardware reality."""
    return struct.unpack("<f", struct.pack("<f", value))[0]


class VitalsGenerator:
    """Physiologically plausible newborn vitals with per-scenario drift."""

    def __init__(self, scenario: str, seed: int | None = None) -> None:
        self.scenario = scenario
        self.rng = random.Random(seed)
        self.t = 0
        self.battery = 87.0

    def next(self) -> dict:
        t = self.t
        self.t += 1
        rng = self.rng

        hr = 135.0 + 8.0 * math.sin(t / 5.0) + rng.gauss(0, 3)
        temp = 37.0 + 0.15 * math.sin(t / 9.0) + rng.gauss(0, 0.05)
        spo2 = 97.5 + rng.gauss(0, 0.6)
        movement = abs(rng.gauss(0.25, 0.15))
        self.battery = max(1.0, self.battery - 0.05)

        if self.scenario == "fever":
            temp += min(2.0, 0.25 * t)              # ramps past 38 °C
        elif self.scenario == "hypoxia":
            spo2 -= min(9.0, 1.2 * t)               # dips below 92 %
        elif self.scenario == "tachy":
            hr += min(60.0, 8.0 * t)                # climbs past 180 bpm
        elif self.scenario == "still":
            movement = abs(rng.gauss(0.005, 0.003))  # essentially still
        elif self.scenario == "lowbatt":
            self.battery = max(1.0, 14.0 - 0.5 * t)  # below 15 %

        spo2 = min(100.0, max(70.0, spo2))
        return {
            "heart_rate": round(f32(hr), 1),
            "temperature": round(f32(temp), 2),
            "spo2": round(f32(spo2), 1),
            "movement": {
                "accel": [round(f32(rng.gauss(0, 0.1)), 4) for _ in range(2)]
                + [round(f32(1.0 + rng.gauss(0, 0.05)), 4)],
                "gyro": [round(f32(rng.gauss(0, 2.0)), 3) for _ in range(3)],
                "magnitude": round(f32(movement), 4),
            },
            "battery": round(self.battery, 1),
            "skin_contact": True,
        }


# ------------------------------------------------------------------ flow
def ensure_bracelet(api: Api, serial: str) -> dict:
    """Find or register the simulated bracelet."""
    page: dict = api.request("GET", "/api/v1/bracelets/")  # type: ignore[assignment]
    for b in page["results"]:
        if b["serial_number"] == serial:
            return b
    created: dict = api.request(  # type: ignore[assignment]
        "POST", "/api/v1/bracelets/",
        {"serial_number": serial, "firmware_version": "1.0.0-sim"})
    print(f"[sim] registered bracelet #{created['id']} serial={serial}")
    return created


def ensure_paired(api: Api, bracelet: dict, baby_name: str) -> dict:
    """Pair the bracelet with the parent's first baby (created if needed)."""
    if bracelet["baby"] is not None:
        return bracelet
    babies: dict = api.request("GET", "/api/v1/babies/")  # type: ignore[assignment]
    if babies["results"]:
        baby = babies["results"][0]
    else:
        baby = api.request("POST", "/api/v1/babies/", {
            "name": baby_name,
            "birth_date": (datetime.now(timezone.utc) - timedelta(days=12)).date().isoformat(),
            "weight_grams": 3350,
            "gender": "female",
        })
        print(f"[sim] created baby #{baby['id']} ({baby['name']})")
    out: dict = api.request(  # type: ignore[assignment]
        "POST", f"/api/v1/bracelets/{bracelet['id']}/pair/", {"baby_id": baby["id"]})
    print(f"[sim] paired bracelet #{bracelet['id']} with baby #{baby['id']}")
    return out


def run(args: argparse.Namespace) -> None:
    api = Api(args.base_url)
    session = api.login(args.email, args.password)
    print(f"[sim] logged in as {session['user']['email']} ({session['user']['role']})")

    bracelet = ensure_bracelet(api, args.serial)
    bracelet = ensure_paired(api, bracelet, args.baby_name)
    baby_id = bracelet["baby"]

    gen = VitalsGenerator(args.scenario, seed=args.seed)
    sent = 0
    batch: list[dict] = []
    for i in range(args.count):
        m = gen.next()
        m["bracelet"] = bracelet["id"]
        m["recorded_at"] = datetime.now(timezone.utc).isoformat()
        batch.append(m)
        # Mobile app drains its offline queue in batches — mimic that.
        if len(batch) >= args.batch_size or i == args.count - 1:
            out = api.request("POST", "/api/v1/measurements/", batch)
            sent += out.get("created", 0)  # type: ignore[union-attr]
            print(f"[sim] sent batch of {len(batch)} "
                  f"(total created={sent}, errors={len(out.get('errors', []))})")  # type: ignore[union-attr]
            batch = []
        if args.interval > 0:
            time.sleep(args.interval)

    alerts: dict = api.request(  # type: ignore[assignment]
        "GET", f"/api/v1/alerts/?baby_id={baby_id}&status=active")
    print(f"\n[sim] scenario={args.scenario} → {sent} measurements ingested; "
          f"{alerts['count']} active alert(s):")
    for a in alerts["results"]:
        print(f"  - [{a['severity']:8s}] {a['type']:16s} {a['message']}")


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--base-url", default="http://localhost:8080")
    p.add_argument("--email", required=True, help="parent account email")
    p.add_argument("--password", required=True)
    p.add_argument("--serial", default="SIM0001")
    p.add_argument("--baby-name", default="Sim Baby")
    p.add_argument("--scenario", default="normal",
                   choices=["normal", "fever", "hypoxia", "tachy", "still", "lowbatt"])
    p.add_argument("--count", type=int, default=12, help="measurements to send")
    p.add_argument("--batch-size", type=int, default=5)
    p.add_argument("--interval", type=float, default=0.0,
                   help="seconds between samples (0 = as fast as possible)")
    p.add_argument("--seed", type=int, default=None)
    run(p.parse_args())


if __name__ == "__main__":
    sys.exit(main())
