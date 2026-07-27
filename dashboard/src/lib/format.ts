/** Formatting helpers shared across the dashboard. */

export function fmtDateTime(iso: string | null | undefined): string {
  if (!iso) return '—';
  const d = new Date(iso);
  return d.toLocaleString(undefined, {
    year: 'numeric',
    month: 'short',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  });
}

export function fmtDate(iso: string | null | undefined): string {
  if (!iso) return '—';
  return new Date(iso).toLocaleDateString(undefined, {
    year: 'numeric',
    month: 'short',
    day: '2-digit',
  });
}

export function ageFromBirthDate(birthDate: string): string {
  const birth = new Date(birthDate);
  const now = new Date();
  const days = Math.floor((now.getTime() - birth.getTime()) / 86_400_000);
  if (days < 0) return '—';
  if (days < 60) return `${days} day${days === 1 ? '' : 's'}`;
  const months = Math.floor(days / 30.44);
  return `${months} month${months === 1 ? '' : 's'}`;
}

export function fmtNumber(v: number | null | undefined, digits = 1): string {
  if (v === null || v === undefined) return '—';
  return v.toFixed(digits);
}

export const SEVERITY_STYLES: Record<string, string> = {
  critical: 'bg-red-100 text-red-800 border-red-200',
  warning: 'bg-amber-100 text-amber-800 border-amber-200',
  info: 'bg-blue-100 text-blue-800 border-blue-200',
};

export const ALERT_TYPE_LABELS: Record<string, string> = {
  high_temp: 'High temperature',
  low_temp: 'Low temperature',
  low_oxygen: 'Low SpO2',
  high_hr: 'High heart rate',
  low_hr: 'Low heart rate',
  no_movement: 'No movement',
  bracelet_removed: 'Bracelet removed',
  battery_low: 'Low battery',
  ble_lost: 'Bluetooth connection lost',
  no_data: 'No data received',
};

export function alertTypeLabel(type: string): string {
  return ALERT_TYPE_LABELS[type] ?? type;
}
