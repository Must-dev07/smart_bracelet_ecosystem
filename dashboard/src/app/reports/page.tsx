'use client';

/**
 * Reports: pick a patient + period → generate a real PDF (jsPDF) with
 * vitals aggregates and the alert log. ?baby_id= preselects a patient.
 */

import { useSearchParams } from 'next/navigation';
import { Suspense, useEffect, useState } from 'react';
import Shell from '@/components/Shell';
import { ErrorBox, Loading, PageTitle } from '@/components/ui';
import { apiFetch, getStoredUser } from '@/lib/api';
import { generatePatientReport } from '@/lib/pdf';
import type { Alert, Baby, MeasurementBucket, MeasurementQueryBuckets, Paginated } from '@/lib/types';

const PERIODS = [
  { key: '24h', label: 'Last 24 hours', hours: 24, granularity: 'hour' as const },
  { key: '7d', label: 'Last 7 days', hours: 24 * 7, granularity: 'hour' as const },
  { key: '30d', label: 'Last 30 days', hours: 24 * 30, granularity: 'day' as const },
];

function ReportsInner() {
  const search = useSearchParams();
  const [babies, setBabies] = useState<Baby[] | null>(null);
  const [babyId, setBabyId] = useState<string>('');
  const [periodKey, setPeriodKey] = useState('7d');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [done, setDone] = useState(false);

  useEffect(() => {
    (async () => {
      try {
        const out: Baby[] = [];
        let page = 1;
        for (;;) {
          const res = await apiFetch<Paginated<Baby>>(`/api/v1/babies/?page=${page}`);
          out.push(...res.results);
          if (!res.next || page > 50) break;
          page += 1;
        }
        setBabies(out);
        const preset = search.get('baby_id');
        if (preset && out.some((b) => String(b.id) === preset)) setBabyId(preset);
        else if (out.length) setBabyId(String(out[0].id));
      } catch (e) {
        setError(e instanceof Error ? e.message : 'Failed to load patients.');
      }
    })();
  }, [search]);

  async function generate() {
    if (!babyId || !babies) return;
    setBusy(true);
    setError(null);
    setDone(false);
    try {
      const period = PERIODS.find((p) => p.key === periodKey)!;
      const to = new Date();
      const from = new Date(to.getTime() - period.hours * 3_600_000);
      const baby = await apiFetch<Baby>(`/api/v1/babies/${babyId}/`);
      const meas = await apiFetch<MeasurementQueryBuckets>(
        `/api/v1/measurements/?baby_id=${babyId}&from=${from.toISOString()}&to=${to.toISOString()}&granularity=${period.granularity}`,
      );
      const alertsPage = await apiFetch<Paginated<Alert>>(`/api/v1/alerts/?baby_id=${babyId}`);
      const alerts = alertsPage.results.filter((a) => new Date(a.triggered_at) >= from);
      const user = getStoredUser();
      generatePatientReport({
        baby,
        buckets: meas.results as MeasurementBucket[],
        alerts,
        periodLabel: `${from.toLocaleDateString()} → ${to.toLocaleDateString()} (${period.label})`,
        generatedBy: user ? `${user.first_name} ${user.last_name} (${user.role})` : 'dashboard user',
      });
      setDone(true);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to generate report.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <>
      <PageTitle title="Reports" sub="Generate a per-patient PDF summary: vitals aggregates + alert log." />
      {error ? <ErrorBox message={error} /> : null}
      {!babies && !error ? <Loading /> : null}
      {babies ? (
        <section id="report-form" className="card max-w-xl space-y-4">
          <div>
            <label htmlFor="report-baby" className="label">Patient</label>
            <select
              id="report-baby"
              className="input"
              value={babyId}
              onChange={(e) => setBabyId(e.target.value)}
            >
              {babies.map((b) => (
                <option key={b.id} value={b.id}>
                  {b.name} — parent: {b.parent_name || '—'}
                </option>
              ))}
            </select>
          </div>
          <div>
            <label htmlFor="report-period" className="label">Period</label>
            <select
              id="report-period"
              className="input"
              value={periodKey}
              onChange={(e) => setPeriodKey(e.target.value)}
            >
              {PERIODS.map((p) => (
                <option key={p.key} value={p.key}>{p.label}</option>
              ))}
            </select>
          </div>
          <button id="generate-report" className="btn-primary" onClick={generate} disabled={busy || !babyId}>
            {busy ? 'Generating…' : 'Generate PDF report'}
          </button>
          {done ? (
            <p className="text-sm text-emerald-600">Report downloaded. Check your browser downloads.</p>
          ) : null}
        </section>
      ) : null}
    </>
  );
}

export default function ReportsPage() {
  return (
    <Shell>
      <Suspense fallback={<Loading />}>
        <ReportsInner />
      </Suspense>
    </Shell>
  );
}
