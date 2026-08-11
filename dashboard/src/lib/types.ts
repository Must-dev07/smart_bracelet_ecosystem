/** API types mirroring the Django backend serializers (api/v1). */

export type Role = 'parent' | 'doctor' | 'admin';

export interface UserSummary {
  id: number;
  email: string;
  first_name: string;
  last_name: string;
  role: Role;
  phone: string;
  created_at: string;
}

export interface Doctor {
  id: number;
  user: UserSummary;
  license_number: string;
  specialty: string;
}

export interface Parent {
  id: number;
  user: UserSummary;
  address: string;
  emergency_contact: string;
}

export interface MedicalHistoryEntry {
  id: number;
  title: string;
  details: string;
  recorded_by: number | null;
  supersedes: number | null;
  created_at: string;
}

export interface Baby {
  id: number;
  name: string;
  birth_date: string;
  weight_grams: number;
  gender: 'male' | 'female' | 'unspecified';
  parent: number;
  parent_name: string;
  assigned_doctor: number | null;
  medical_history: MedicalHistoryEntry[];
  created_at: string;
}

export interface Bracelet {
  id: number;
  serial_number: string;
  firmware_version: string;
  baby: number | null;
  baby_name: string | null;
  battery_level: number | null;
  last_seen_at: string | null;
  status: string;
  created_at: string;
}

export interface Movement {
  accel?: [number, number, number];
  gyro?: [number, number, number];
  magnitude?: number;
}

export interface Measurement {
  id: number;
  baby: number;
  bracelet: number;
  heart_rate: number | null;
  temperature: number | null;
  spo2: number | null;
  movement: Movement | null;
  battery: number | null;
  skin_contact: boolean | null;
  recorded_at: string;
  received_at: string;
}

export interface MeasurementBucket {
  bucket: string;
  heart_rate_avg: number | null;
  temperature_avg: number | null;
  spo2_avg: number | null;
  heart_rate_min: number | null;
  heart_rate_max: number | null;
  count: number;
}

export type Granularity = 'raw' | 'minute' | 'hour' | 'day';

export interface MeasurementQueryRaw {
  granularity: 'raw';
  results: Measurement[];
}

export interface MeasurementQueryBuckets {
  granularity: Exclude<Granularity, 'raw'>;
  results: MeasurementBucket[];
}

export type MeasurementQueryResponse = MeasurementQueryRaw | MeasurementQueryBuckets;

export type AlertSeverity = 'info' | 'warning' | 'critical';

export interface Alert {
  id: number;
  baby: number;
  baby_name: string;
  bracelet: number | null;
  type: string;
  severity: AlertSeverity;
  message: string;
  value: number | null;
  triggered_at: string;
  resolved_at: string | null;
  resolved_by: number | null;
  resolved_by_name: string | null;
  acknowledged_by: number | null;
  acknowledged_by_name: string | null;
  acknowledged_at: string | null;
  auto_resolves_on_acknowledge: boolean;
  disclaimer: string;
}

export type NotificationCategory = 'alert' | 'bracelet' | 'medical' | 'system';

export interface AppNotification {
  id: number;
  alert: number | null;
  category: NotificationCategory;
  channel: string;
  title: string;
  body: string;
  status: string;
  sent_at: string | null;
  read_at: string | null;
  created_at: string;
}

export interface Paginated<T> {
  count: number;
  next: string | null;
  previous: string | null;
  results: T[];
}

export interface TokenPair {
  access: string;
  refresh: string;
  user: UserSummary;
}

/** Non-diagnostic disclaimer — shown wherever alerts/measurements guide decisions. */
export const MEDICAL_DISCLAIMER =
  'This system flags abnormal readings for caregiver or medical follow-up. It is not a medical diagnosis device.';
