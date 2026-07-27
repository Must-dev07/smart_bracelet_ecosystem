'use client';

/**
 * Statistics: aggregate view across the doctor's whole caseload —
 * alert distribution by type & severity (bar/doughnut) and a 14-day
 * alert trend line, all computed client-side from the alerts API.
 */

import {
  ArcElement,
  BarElement,
  CategoryScale,
  Chart as ChartJS,
  Legend,
  LinearScale,
  LineElement,
  PointElement,
  Tooltip,
} from 'chart.js';
import { useEffect, useMemo, useState } from 'react';
import { Bar, Doughnut, Line } from 'react-chartjs-2';
import Shell from '@/components/Shell';
import { Empty, ErrorBox, Loading, PageTitle, StatCard } from '@/components/ui';
import { apiFetch } from '@/lib/api';
import { alertTypeLabel } from '@/lib/format';
import type { Alert, Baby, Paginated } from '@/lib/types';

ChartJS.register(CategoryScale, LinearScale, BarElement, ArcElement, PointElement, LineElement, Tooltip, Legend);

export default function StatisticsPage() {
  const [alerts, setAlerts] = useState<Alert[] | null>(null);
  const [babies, setBabies] = useState<Baby[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    (async () => {
      try {
        const fetchAll = async <T,>(base: string): Promise<T[]> => {
          const out: T[] = [];
          let page = 1;
          for (;;) {
            const sep = base.includes('?') ? '&' : '?';
            const res = await apiFetch<Paginated<T>>(`${base}${sep}page=${page}`);
            out.push(...res.results);
            if (!res.next || page > 50) break;
            page += 1;
          }
          return out;
        };
        const [a, b] = await Promise.all([fetchAll<Alert>('/api/v1/alerts/'), fetchAll<Baby>('/api/v1/babies/')]);
        setAlerts(a);
        setBabies(b);
      } catch (e) {
        setError(e instanceof Error ? e.message : 'Failed to load statistics.');
      }
    })();
  }, []);

  const stats = useMemo(() => {
    if (!alerts) return null;
    const byType = new Map<string, number>();
    const bySeverity = { critical: 0, warning: 0, info: 0 };
    for (const a of alerts) {
      byType.set(a.type, (byType.get(a.type) ?? 0) + 1);
      if (a.severity in bySeverity) bySeverity[a.severity as keyof typeof bySeverity] += 1;
    }
    const days: string[] = [];
    const counts: number[] = [];
    for (let i = 13; i >= 0; i--) {
      const d = new Date();
      d.setHours(0, 0, 0, 0);
      d.setDate(d.getDate() - i);
      const next = new Date(d.getTime() + 86_400_000);
      days.push(d.toLocaleDateString(undefined, { month: 'short', day: '2-digit' }));
      counts.push(
        alerts.filter((a) => {
          const t = new Date(a.triggered_at);
          return t >= d && t < next;
        }).length,
      );
    }
    return { byType, bySeverity, days, counts };
  }, [alerts]);

  const activeCount = alerts?.filter((a) => !a.resolved_at).length ?? 0;

  return (
    <Shell>
      <PageTitle title="Statistics" sub="Aggregated alert analytics across your caseload." />
      {error ? <ErrorBox message={error} /> : null}
      {(!alerts || !babies) && !error ? <Loading /> : null}
      {alerts && babies && stats ? (
        alerts.length === 0 ? (
          <Empty message="No alert data yet — statistics will appear once measurements flow in." />
        ) : (
          <>
            <section className="grid grid-cols-1 gap-4 sm:grid-cols-3">
              <StatCard label="Total alerts" value={alerts.length} sub="all time, all patients" />
              <StatCard label="Active now" value={activeCount} accent={activeCount ? 'amber' : 'emerald'} />
              <StatCard
                label="Alerts / patient"
                value={babies.length ? (alerts.length / babies.length).toFixed(1) : '—'}
                sub={`${babies.length} patient(s)`}
              />
            </section>

            <div className="mt-6 grid grid-cols-1 gap-6 lg:grid-cols-2">
              <section className="card">
                <h2 className="mb-4 text-lg font-semibold text-slate-900">Alerts by type</h2>
                <div className="h-72">
                  <Bar
                    data={{
                      labels: [...stats.byType.keys()].map(alertTypeLabel),
                      datasets: [
                        {
                          label: 'Count',
                          data: [...stats.byType.values()],
                          backgroundColor: 'rgba(29,108,241,0.7)',
                          borderRadius: 6,
                        },
                      ],
                    }}
                    options={{
                      responsive: true,
                      maintainAspectRatio: false,
                      plugins: { legend: { display: false } },
                      scales: { y: { beginAtZero: true, ticks: { precision: 0 } } },
                    }}
                  />
                </div>
              </section>

              <section className="card">
                <h2 className="mb-4 text-lg font-semibold text-slate-900">Severity distribution</h2>
                <div className="mx-auto h-72 max-w-xs">
                  <Doughnut
                    data={{
                      labels: ['Critical', 'Warning', 'Info'],
                      datasets: [
                        {
                          data: [stats.bySeverity.critical, stats.bySeverity.warning, stats.bySeverity.info],
                          backgroundColor: ['#dc2626', '#f59e0b', '#3b82f6'],
                          borderWidth: 2,
                        },
                      ],
                    }}
                    options={{ responsive: true, maintainAspectRatio: false }}
                  />
                </div>
              </section>
            </div>

            <section className="card mt-6">
              <h2 className="mb-4 text-lg font-semibold text-slate-900">Alert trend — last 14 days</h2>
              <div className="h-64">
                <Line
                  data={{
                    labels: stats.days,
                    datasets: [
                      {
                        label: 'Alerts / day',
                        data: stats.counts,
                        borderColor: '#1d6cf1',
                        backgroundColor: 'rgba(29,108,241,0.1)',
                        fill: true,
                        tension: 0.3,
                      },
                    ],
                  }}
                  options={{
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: { legend: { display: false } },
                    scales: { y: { beginAtZero: true, ticks: { precision: 0 } } },
                  }}
                />
              </div>
            </section>
          </>
        )
      ) : null}
    </Shell>
  );
}
