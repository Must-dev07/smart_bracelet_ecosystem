'use client';

/**
 * Chart.js vitals visualisation for one baby.
 * Fetches /api/v1/measurements/ with a period selector, adaptive granularity
 * (raw <6h, minute <48h, hour <14d, day otherwise) and renders HR / temp /
 * SpO2 line charts with clinically-derived threshold lines.
 */

import {
  CategoryScale,
  Chart as ChartJS,
  Filler,
  Legend,
  LinearScale,
  LineElement,
  PointElement,
  TimeSeriesScale,
  Tooltip,
} from 'chart.js';
import { useCallback, useEffect, useState } from 'react';
import { Line } from 'react-chartjs-2';
import { apiFetch } from '@/lib/api';
import { Empty, ErrorBox, Loading } from '@/components/ui';
import type { Granularity, MeasurementQueryResponse } from '@/lib/types';

ChartJS.register(
  CategoryScale,
  LinearScale,
  TimeSeriesScale,
  PointElement,
  LineElement,
  Tooltip,
  Legend,
  Filler,
);

const PERIODS: { key: string; label: string; hours: number }[] = [
  { key: '6h', label: '6 h', hours: 6 },
  { key: '24h', label: '24 h', hours: 24 },
  { key: '7d', label: '7 days', hours: 24 * 7 },
  { key: '30d', label: '30 days', hours: 24 * 30 },
];

function granularityFor(hours: number): Granularity {
  if (hours <= 6) return 'raw';
  if (hours <= 48) return 'minute';
  if (hours <= 24 * 14) return 'hour';
  return 'day';
}

interface Series {
  labels: string[];
  hr: (number | null)[];
  temp: (number | null)[];
  spo2: (number | null)[];
}

function toSeries(res: MeasurementQueryResponse): Series {
  const labels: string[] = [];
  const hr: (number | null)[] = [];
  const temp: (number | null)[] = [];
  const spo2: (number | null)[] = [];
  if (res.granularity === 'raw') {
    for (const m of res.results) {
      labels.push(new Date(m.recorded_at).toLocaleString(undefined, { month: 'short', day: '2-digit', hour: '2-digit', minute: '2-digit' }));
      hr.push(m.heart_rate);
      temp.push(m.temperature);
      spo2.push(m.spo2);
    }
  } else {
    for (const b of res.results) {
      labels.push(new Date(b.bucket).toLocaleString(undefined, { month: 'short', day: '2-digit', hour: '2-digit', minute: '2-digit' }));
      hr.push(b.heart_rate_avg);
      temp.push(b.temperature_avg);
      spo2.push(b.spo2_avg);
    }
  }
  return { labels, hr, temp, spo2 };
}

function thresholdLine(labels: string[], value: number) {
  return labels.map(() => value);
}

const BASE_OPTS = {
  responsive: true,
  maintainAspectRatio: false,
  interaction: { mode: 'index' as const, intersect: false },
  plugins: { legend: { display: true, labels: { boxWidth: 12, font: { size: 11 } } } },
  elements: { point: { radius: 0 }, line: { tension: 0.25 } },
  scales: { x: { ticks: { maxTicksLimit: 10, font: { size: 10 } } } },
};

export default function VitalsCharts({ babyId }: { babyId: number }) {
  const [period, setPeriod] = useState(PERIODS[1]);
  const [series, setSeries] = useState<Series | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const to = new Date();
      const from = new Date(to.getTime() - period.hours * 3_600_000);
      const g = granularityFor(period.hours);
      const res = await apiFetch<MeasurementQueryResponse>(
        `/api/v1/measurements/?baby_id=${babyId}&from=${from.toISOString()}&to=${to.toISOString()}&granularity=${g}`,
      );
      setSeries(toSeries(res));
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load measurements.');
    } finally {
      setLoading(false);
    }
  }, [babyId, period]);

  useEffect(() => {
    load();
  }, [load]);

  return (
    <section id="vitals-charts" className="card">
      <header className="mb-4 flex flex-wrap items-center justify-between gap-3">
        <h2 className="text-lg font-semibold text-slate-900">Vitals</h2>
        <nav className="flex gap-1" aria-label="Chart period">
          {PERIODS.map((p) => (
            <button
              key={p.key}
              onClick={() => setPeriod(p)}
              className={`rounded-lg px-3 py-1.5 text-xs font-medium transition ${
                p.key === period.key
                  ? 'bg-brand-600 text-white'
                  : 'bg-slate-100 text-slate-600 hover:bg-slate-200'
              }`}
            >
              {p.label}
            </button>
          ))}
        </nav>
      </header>

      {error ? <ErrorBox message={error} /> : null}
      {loading ? <Loading /> : null}
      {!loading && series && series.labels.length === 0 ? (
        <Empty message="No measurements in this period." />
      ) : null}

      {!loading && series && series.labels.length > 0 ? (
        <div className="grid grid-cols-1 gap-6 xl:grid-cols-3">
          <div className="h-64">
            <Line
              data={{
                labels: series.labels,
                datasets: [
                  {
                    label: 'Heart rate (bpm)',
                    data: series.hr,
                    borderColor: '#e11d48',
                    backgroundColor: 'rgba(225,29,72,0.08)',
                    fill: true,
                    spanGaps: true,
                  },
                  { label: 'High (180)', data: thresholdLine(series.labels, 180), borderColor: 'rgba(225,29,72,0.35)', borderDash: [6, 6], pointStyle: false as const },
                  { label: 'Low (90)', data: thresholdLine(series.labels, 90), borderColor: 'rgba(225,29,72,0.35)', borderDash: [6, 6], pointStyle: false as const },
                ],
              }}
              options={{ ...BASE_OPTS, scales: { ...BASE_OPTS.scales, y: { suggestedMin: 60, suggestedMax: 220 } } }}
            />
          </div>
          <div className="h-64">
            <Line
              data={{
                labels: series.labels,
                datasets: [
                  {
                    label: 'Temperature (°C)',
                    data: series.temp,
                    borderColor: '#d97706',
                    backgroundColor: 'rgba(217,119,6,0.08)',
                    fill: true,
                    spanGaps: true,
                  },
                  { label: 'High (38.0)', data: thresholdLine(series.labels, 38.0), borderColor: 'rgba(217,119,6,0.35)', borderDash: [6, 6], pointStyle: false as const },
                  { label: 'Low (36.0)', data: thresholdLine(series.labels, 36.0), borderColor: 'rgba(217,119,6,0.35)', borderDash: [6, 6], pointStyle: false as const },
                ],
              }}
              options={{ ...BASE_OPTS, scales: { ...BASE_OPTS.scales, y: { suggestedMin: 34, suggestedMax: 40 } } }}
            />
          </div>
          <div className="h-64">
            <Line
              data={{
                labels: series.labels,
                datasets: [
                  {
                    label: 'SpO2 (%)',
                    data: series.spo2,
                    borderColor: '#2563eb',
                    backgroundColor: 'rgba(37,99,235,0.08)',
                    fill: true,
                    spanGaps: true,
                  },
                  { label: 'Low (92)', data: thresholdLine(series.labels, 92), borderColor: 'rgba(37,99,235,0.35)', borderDash: [6, 6], pointStyle: false as const },
                ],
              }}
              options={{ ...BASE_OPTS, scales: { ...BASE_OPTS.scales, y: { suggestedMin: 80, suggestedMax: 100 } } }}
            />
          </div>
        </div>
      ) : null}
    </section>
  );
}
