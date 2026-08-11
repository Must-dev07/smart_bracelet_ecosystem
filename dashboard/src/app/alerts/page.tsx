'use client';

/**
 * Alerts triage page: filter by status/severity, acknowledge alerts.
 * Acknowledging non-persistent alerts also resolves them server-side.
 */

import Link from 'next/link';
import { useCallback, useEffect, useState } from 'react';
import Shell from '@/components/Shell';
import { Empty, ErrorBox, Loading, PageTitle, SeverityBadge } from '@/components/ui';
import { apiFetch } from '@/lib/api';
import { alertTypeLabel, fmtDateTime } from '@/lib/format';
import type { Alert, Paginated } from '@/lib/types';
import { MEDICAL_DISCLAIMER } from '@/lib/types';

type StatusFilter = 'active' | 'resolved' | 'all';
type SeverityFilter = 'all' | 'critical' | 'warning' | 'info';

export default function AlertsPage() {
  const [alerts, setAlerts] = useState<Alert[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [status, setStatus] = useState<StatusFilter>('active');
  const [severity, setSeverity] = useState<SeverityFilter>('all');
  const [ackBusy, setAckBusy] = useState<number | null>(null);
  const [resolveBusy, setResolveBusy] = useState<number | null>(null);

  const load = useCallback(async () => {
    try {
      const params = new URLSearchParams();
      if (status !== 'all') params.set('status', status);
      if (severity !== 'all') params.set('severity', severity);
      const out: Alert[] = [];
      let page = 1;
      for (;;) {
        params.set('page', String(page));
        const res = await apiFetch<Paginated<Alert>>(`/api/v1/alerts/?${params.toString()}`);
        out.push(...res.results);
        if (!res.next || page > 20) break;
        page += 1;
      }
      setAlerts(out);
      setError(null);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load alerts.');
    }
  }, [status, severity]);

  useEffect(() => {
    load();
    const t = setInterval(load, 20_000);
    return () => clearInterval(t);
  }, [load]);

  async function acknowledge(id: number) {
    setAckBusy(id);
    try {
      await apiFetch(`/api/v1/alerts/${id}/acknowledge/`, { method: 'POST' });
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to acknowledge.');
    } finally {
      setAckBusy(null);
    }
  }

  async function resolve(id: number) {
    setResolveBusy(id);
    try {
      await apiFetch(`/api/v1/alerts/${id}/resolve/`, { method: 'POST' });
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to resolve.');
    } finally {
      setResolveBusy(null);
    }
  }

  return (
    <Shell>
      <PageTitle title="Alerts" sub={MEDICAL_DISCLAIMER} />

      <nav className="mb-4 flex flex-wrap items-center gap-3" aria-label="Alert filters">
        <div className="flex gap-1">
          {(['active', 'resolved', 'all'] as StatusFilter[]).map((s) => (
            <button
              key={s}
              onClick={() => setStatus(s)}
              className={`rounded-lg px-3 py-1.5 text-xs font-medium capitalize transition ${
                status === s ? 'bg-brand-600 text-white' : 'bg-slate-100 text-slate-600 hover:bg-slate-200'
              }`}
            >
              {s}
            </button>
          ))}
        </div>
        <select
          id="severity-filter"
          className="input !w-auto"
          value={severity}
          onChange={(e) => setSeverity(e.target.value as SeverityFilter)}
          aria-label="Severity filter"
        >
          <option value="all">All severities</option>
          <option value="critical">Critical</option>
          <option value="warning">Warning</option>
          <option value="info">Info</option>
        </select>
      </nav>

      {error ? <ErrorBox message={error} /> : null}
      {!alerts && !error ? <Loading /> : null}
      {alerts ? (
        alerts.length === 0 ? (
          <Empty message="No alerts match the current filters." />
        ) : (
          <section className="card overflow-x-auto p-0">
            <table className="table-base">
              <thead>
                <tr>
                  <th>Severity</th>
                  <th>Type</th>
                  <th>Patient</th>
                  <th>Message</th>
                  <th>Value</th>
                  <th>Triggered</th>
                  <th>Status</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                {alerts.map((a) => (
                  <tr key={a.id}>
                    <td><SeverityBadge severity={a.severity} /></td>
                    <td className="whitespace-nowrap font-medium">{alertTypeLabel(a.type)}</td>
                    <td>
                      <Link href={`/patients/${a.baby}`} className="text-brand-600 hover:underline">
                        {a.baby_name}
                      </Link>
                    </td>
                    <td className="max-w-sm text-slate-600">{a.message}</td>
                    <td>{a.value ?? '—'}</td>
                    <td className="whitespace-nowrap text-slate-500">{fmtDateTime(a.triggered_at)}</td>
                    <td>
                      {a.resolved_at ? (
                        <span className="text-xs text-emerald-600">Resolved</span>
                      ) : (
                        <span className="text-xs font-medium text-amber-600">Active</span>
                      )}
                      {a.acknowledged_at ? (
                        <span className="block text-[11px] text-slate-400">
                          ack {fmtDateTime(a.acknowledged_at)}
                          {a.acknowledged_by_name ? ` by ${a.acknowledged_by_name}` : ''}
                        </span>
                      ) : null}
                      {a.resolved_at ? (
                        <span className="block text-[11px] text-slate-400">
                          resolved {fmtDateTime(a.resolved_at)}
                          {a.resolved_by_name ? ` by ${a.resolved_by_name}` : ''}
                        </span>
                      ) : null}
                    </td>
                    <td>
                      <div className="flex gap-2">
                        {!a.acknowledged_at ? (
                          <button
                            className="btn-secondary !px-3 !py-1 text-xs"
                            disabled={ackBusy === a.id}
                            onClick={() => acknowledge(a.id)}
                          >
                            {ackBusy === a.id ? '…' : 'Acknowledge'}
                          </button>
                        ) : null}
                        {!a.resolved_at ? (
                          <button
                            className="btn-primary !px-3 !py-1 text-xs"
                            disabled={resolveBusy === a.id}
                            onClick={() => resolve(a.id)}
                            title="Assert the underlying concern has been handled"
                          >
                            {resolveBusy === a.id ? '…' : 'Resolve'}
                          </button>
                        ) : null}
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </section>
        )
      ) : null}
    </Shell>
  );
}
