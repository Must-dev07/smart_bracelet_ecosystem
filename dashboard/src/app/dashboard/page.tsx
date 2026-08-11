'use client';

/**
 * Dashboard home: patient count, active/critical alert counts, bracelet
 * fleet status, and the latest active alerts for quick triage.
 */

import Link from 'next/link';
import { useEffect, useState } from 'react';
import Shell from '@/components/Shell';
import { Empty, ErrorBox, Loading, PageTitle, SeverityBadge, StatCard } from '@/components/ui';
import { fetchAllPages } from '@/lib/api';
import { alertTypeLabel, fmtDateTime } from '@/lib/format';
import type { Alert, Baby, Bracelet } from '@/lib/types';

interface DashboardData {
  babies: Baby[];
  bracelets: Bracelet[];
  activeAlerts: Alert[];
}

export default function DashboardPage() {
  const [data, setData] = useState<DashboardData | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    async function load() {
      try {
        const [babies, bracelets, activeAlerts] = await Promise.all([
          fetchAllPages<Baby>('/api/v1/babies/'),
          fetchAllPages<Bracelet>('/api/v1/bracelets/'),
          fetchAllPages<Alert>('/api/v1/alerts/?status=active'),
        ]);
        if (!cancelled) setData({ babies, bracelets, activeAlerts });
      } catch (e) {
        if (!cancelled) setError(e instanceof Error ? e.message : 'Failed to load dashboard.');
      }
    }
    load();
    const t = setInterval(load, 30_000); // refresh every 30s
    return () => {
      cancelled = true;
      clearInterval(t);
    };
  }, []);

  return (
    <Shell>
      <PageTitle title="Overview" sub="Live status of your monitored patients and devices." />
      {error ? <ErrorBox message={error} /> : null}
      {!data && !error ? <Loading /> : null}
      {data ? (
        <>
          <section id="stats-grid" className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
            <StatCard label="Patients" value={data.babies.length} sub="babies under your care" />
            <StatCard
              label="Active alerts"
              value={data.activeAlerts.length}
              accent={data.activeAlerts.length > 0 ? 'amber' : 'emerald'}
              sub="unresolved"
            />
            <StatCard
              label="Critical alerts"
              value={data.activeAlerts.filter((a) => a.severity === 'critical').length}
              accent={data.activeAlerts.some((a) => a.severity === 'critical') ? 'red' : 'emerald'}
              sub="need attention now"
            />
            <StatCard
              label="Bracelets online"
              value={`${data.bracelets.filter((b) => b.status === 'active').length}/${data.bracelets.length}`}
              accent="brand"
              sub="active devices"
            />
          </section>

          <section id="recent-alerts" className="card mt-6">
            <header className="mb-4 flex items-center justify-between">
              <h2 className="text-lg font-semibold text-slate-900">Latest active alerts</h2>
              <Link href="/alerts" className="text-sm font-medium text-brand-600 hover:underline">
                View all →
              </Link>
            </header>
            {data.activeAlerts.length === 0 ? (
              <Empty message="No active alerts. All readings within configured thresholds." />
            ) : (
              <div className="overflow-x-auto">
                <table className="table-base">
                  <thead>
                    <tr>
                      <th>Severity</th>
                      <th>Type</th>
                      <th>Patient</th>
                      <th>Message</th>
                      <th>Triggered</th>
                    </tr>
                  </thead>
                  <tbody>
                    {data.activeAlerts.slice(0, 8).map((a) => (
                      <tr key={a.id}>
                        <td><SeverityBadge severity={a.severity} /></td>
                        <td className="font-medium">{alertTypeLabel(a.type)}</td>
                        <td>
                          <Link href={`/patients/${a.baby}`} className="text-brand-600 hover:underline">
                            {a.baby_name}
                          </Link>
                        </td>
                        <td className="max-w-xs truncate text-slate-600">{a.message}</td>
                        <td className="whitespace-nowrap text-slate-500">{fmtDateTime(a.triggered_at)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </section>

          <section id="fleet-status" className="card mt-6">
            <h2 className="mb-4 text-lg font-semibold text-slate-900">Bracelet fleet</h2>
            {data.bracelets.length === 0 ? (
              <Empty message="No bracelets registered yet." />
            ) : (
              <div className="overflow-x-auto">
                <table className="table-base">
                  <thead>
                    <tr>
                      <th>Serial</th>
                      <th>Firmware</th>
                      <th>Paired baby</th>
                      <th>Battery</th>
                      <th>Last seen</th>
                      <th>Status</th>
                    </tr>
                  </thead>
                  <tbody>
                    {data.bracelets.map((b) => (
                      <tr key={b.id}>
                        <td className="font-mono text-xs">{b.serial_number}</td>
                        <td>{b.firmware_version || '—'}</td>
                        <td>{b.baby_name ?? <span className="text-slate-400">unpaired</span>}</td>
                        <td>{b.battery_level !== null ? `${b.battery_level}%` : '—'}</td>
                        <td className="text-slate-500">{fmtDateTime(b.last_seen_at)}</td>
                        <td className="capitalize">{b.status}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </section>
        </>
      ) : null}
    </Shell>
  );
}
