'use client';

/**
 * Settings: the signed-in doctor edits their profile (name, phone,
 * specialty). Admins see their account info (admin accounts are managed
 * via Django admin / CLI). Also shows API endpoint + session info.
 */

import { useEffect, useState } from 'react';
import Shell from '@/components/Shell';
import { ErrorBox, Loading, PageTitle } from '@/components/ui';
import { API_BASE, apiFetch, getStoredUser } from '@/lib/api';
import type { Doctor, Paginated, UserSummary } from '@/lib/types';

export default function SettingsPage() {
  const [me, setMe] = useState<UserSummary | null>(null);
  const [doctor, setDoctor] = useState<Doctor | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [saved, setSaved] = useState(false);
  const [busy, setBusy] = useState(false);

  const [firstName, setFirstName] = useState('');
  const [lastName, setLastName] = useState('');
  const [phone, setPhone] = useState('');
  const [specialty, setSpecialty] = useState('');

  useEffect(() => {
    (async () => {
      try {
        const user = await apiFetch<UserSummary>('/api/v1/me/');
        setMe(user);
        setFirstName(user.first_name);
        setLastName(user.last_name);
        setPhone(user.phone ?? '');
        if (user.role === 'doctor') {
          // Find own doctor profile id via the doctors listing.
          const res = await apiFetch<Paginated<Doctor>>('/api/v1/doctors/?page=1');
          let all = res.results;
          let next = res.next;
          let page = 2;
          while (next && page <= 50) {
            const r = await apiFetch<Paginated<Doctor>>(`/api/v1/doctors/?page=${page}`);
            all = all.concat(r.results);
            next = r.next;
            page += 1;
          }
          const mine = all.find((d) => d.user.id === user.id) ?? null;
          setDoctor(mine);
          if (mine) setSpecialty(mine.specialty ?? '');
        }
      } catch (e) {
        setError(e instanceof Error ? e.message : 'Failed to load profile.');
      }
    })();
  }, []);

  async function save(e: React.FormEvent) {
    e.preventDefault();
    if (!doctor) return;
    setBusy(true);
    setError(null);
    setSaved(false);
    try {
      const updated = await apiFetch<Doctor>(`/api/v1/doctors/${doctor.id}/`, {
        method: 'PATCH',
        body: JSON.stringify({
          specialty,
          user: { first_name: firstName, last_name: lastName, phone },
        }),
      });
      setDoctor(updated);
      // Keep the cached header user in sync.
      const stored = getStoredUser();
      if (stored) {
        localStorage.setItem(
          'sb_user',
          JSON.stringify({ ...stored, first_name: firstName, last_name: lastName, phone }),
        );
      }
      setSaved(true);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to save.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <Shell>
      <PageTitle title="Settings" sub="Your profile and environment information." />
      {error ? <ErrorBox message={error} /> : null}
      {!me && !error ? <Loading /> : null}
      {me ? (
        <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
          <section id="profile-settings" className="card">
            <h2 className="mb-4 text-lg font-semibold text-slate-900">Profile</h2>
            {me.role === 'doctor' && doctor ? (
              <form onSubmit={save} className="space-y-4">
                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label className="label" htmlFor="set-first">First name</label>
                    <input id="set-first" className="input" value={firstName} onChange={(e) => setFirstName(e.target.value)} required />
                  </div>
                  <div>
                    <label className="label" htmlFor="set-last">Last name</label>
                    <input id="set-last" className="input" value={lastName} onChange={(e) => setLastName(e.target.value)} required />
                  </div>
                </div>
                <div>
                  <label className="label" htmlFor="set-phone">Phone</label>
                  <input id="set-phone" className="input" value={phone} onChange={(e) => setPhone(e.target.value)} />
                </div>
                <div>
                  <label className="label" htmlFor="set-specialty">Specialty</label>
                  <input id="set-specialty" className="input" value={specialty} onChange={(e) => setSpecialty(e.target.value)} />
                </div>
                <div>
                  <p className="label">License number</p>
                  <p className="rounded-lg bg-slate-50 px-3 py-2 text-sm text-slate-500">{doctor.license_number} (read-only)</p>
                </div>
                <button type="submit" className="btn-primary" disabled={busy}>
                  {busy ? 'Saving…' : 'Save changes'}
                </button>
                {saved ? <p className="text-sm text-emerald-600">Profile updated.</p> : null}
              </form>
            ) : (
              <dl className="space-y-2 text-sm">
                <div className="flex justify-between"><dt className="text-slate-500">Name</dt><dd className="font-medium">{me.first_name} {me.last_name}</dd></div>
                <div className="flex justify-between"><dt className="text-slate-500">Email</dt><dd className="font-medium">{me.email}</dd></div>
                <div className="flex justify-between"><dt className="text-slate-500">Role</dt><dd className="font-medium capitalize">{me.role}</dd></div>
                <p className="pt-2 text-xs text-slate-400">
                  Admin accounts are managed via the Django admin or the createsuperuser CLI.
                </p>
              </dl>
            )}
          </section>

          <section id="environment-info" className="card">
            <h2 className="mb-4 text-lg font-semibold text-slate-900">Environment</h2>
            <dl className="space-y-2 text-sm">
              <div className="flex justify-between gap-4">
                <dt className="text-slate-500">API endpoint</dt>
                <dd className="break-all font-mono text-xs">{API_BASE}/api/v1/</dd>
              </div>
              <div className="flex justify-between">
                <dt className="text-slate-500">Account email</dt>
                <dd className="font-medium">{me.email}</dd>
              </div>
              <div className="flex justify-between">
                <dt className="text-slate-500">Member since</dt>
                <dd>{new Date(me.created_at).toLocaleDateString()}</dd>
              </div>
            </dl>
            <p className="mt-4 rounded-lg bg-slate-50 p-3 text-xs leading-relaxed text-slate-500">
              Sessions use rotating JWT refresh tokens; signing out revokes the current
              session server-side. Alert thresholds are configured on the backend
              (see <code>ANALYSIS_THRESHOLDS</code>) and apply system-wide.
            </p>
          </section>
        </div>
      ) : null}
    </Shell>
  );
}
