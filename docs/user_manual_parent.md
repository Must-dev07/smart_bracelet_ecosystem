# Parent User Manual — Smart Bracelet Mobile App

> **Important — please read first**
> This system flags abnormal readings so you can follow up with a
> caregiver or medical professional. **It is not a medical diagnosis
> device.** In any emergency, contact your emergency services immediately.

## 1. Getting started

### 1.1 Create your account
1. Open the app → **Create account**.
2. Enter your email, a password (8+ characters), your name and phone.
3. You are signed in automatically.

### 1.2 Add your baby
1. Home screen → **Add baby**.
2. Enter name, birth date, weight and (optionally) gender.
3. If your paediatrician uses the platform, they can be assigned to your
   baby so they see the same data and alerts.

### 1.3 Pair the bracelet
1. Charge the bracelet, then put it near your phone (Bluetooth ON,
   location services ON — Android requires this for BLE scanning).
2. App → **Pairing** screen → **Scan**. The bracelet appears as
   `SB-BRACELET-…`.
3. Tap it → confirm the pairing request. The app registers the bracelet
   and links it to your baby.
4. Fasten the bracelet snugly (one finger of slack) on your baby's ankle
   or wrist, sensor side against the skin.

## 2. Everyday use

### 2.1 Live monitoring
The **Live** screen shows heart rate, temperature, oxygen (SpO2),
movement and bracelet battery, refreshed every few seconds while the
phone is in Bluetooth range.

### 2.2 History & graphs
**History** lists past readings; **Graphs** shows trends over 6 h to 30
days. Data recorded while your phone was away is uploaded automatically
when the connection returns.

### 2.3 Alerts
When a reading crosses a safety threshold (e.g. temperature above
38 °C), you receive a push notification. Open it to see the details.
- **Acknowledge** an alert once you have checked on your baby.
- Alert thresholds are managed medically on the server side — the same
  ones your doctor sees.

| Alert | Meaning |
|---|---|
| High/low temperature | Reading outside 36.0–38.0 °C |
| Low oxygen | SpO2 below 92 % |
| High/low heart rate | Outside 90–180 bpm |
| No movement | No significant movement detected over the watch window |
| Bracelet removed | Skin contact lost |
| Connection lost | Phone lost Bluetooth link to the bracelet |
| No data | Server stopped receiving data (phone offline?) |
| Battery low | Bracelet needs charging |

**An alert is a prompt to check on your baby and, if you are concerned,
contact a medical professional. It is never a diagnosis.**

## 3. Tips & troubleshooting

- **Bracelet won't appear in scan** — check it is charged; toggle phone
  Bluetooth; Android: ensure Location permission is granted.
- **Frequent "connection lost"** — keep the phone within ~10 m; walls
  and metal reduce range. Data is buffered on the bracelet (~1 hour) and
  re-sent automatically.
- **Readings look wrong** — check the strap: too loose gives bad optical
  readings. Obvious impossible values are filtered out automatically.
- **Battery** — charge daily; you'll get a notification below 15 %. At
  5 % the bracelet enters power-saving sleep.
- **Changing phones** — sign in on the new phone and re-pair the
  bracelet from the Pairing screen.

## 4. Your data & privacy

- Vitals are stored encrypted in transit (HTTPS) on the platform server.
- Only you, and the doctor assigned to your baby, can see your baby's
  data. Access is logged.
- Signing out revokes the session on the server.

## 5. Care of the device

- Wipe with a slightly damp cloth; no solvents.
- Check your baby's skin under the strap daily.
- The bracelet is splash-resistant, not for bathing.
