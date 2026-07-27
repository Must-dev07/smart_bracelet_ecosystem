'use client';

/**
 * Real PDF report generation with jsPDF + autotable.
 * Produces a per-patient clinical summary: identity, period vitals
 * aggregates, alert table, and the mandatory non-diagnostic disclaimer.
 */

import jsPDF from 'jspdf';
import autoTable from 'jspdf-autotable';
import { ageFromBirthDate, alertTypeLabel, fmtDate, fmtDateTime } from './format';
import type { Alert, Baby, MeasurementBucket } from './types';
import { MEDICAL_DISCLAIMER } from './types';

export interface ReportInput {
  baby: Baby;
  buckets: MeasurementBucket[];
  alerts: Alert[];
  periodLabel: string;
  generatedBy: string;
}

function agg(values: (number | null)[]): { min: number | null; max: number | null; avg: number | null } {
  const nums = values.filter((v): v is number => v !== null && Number.isFinite(v));
  if (!nums.length) return { min: null, max: null, avg: null };
  return {
    min: Math.min(...nums),
    max: Math.max(...nums),
    avg: nums.reduce((a, b) => a + b, 0) / nums.length,
  };
}

const f = (v: number | null, d = 1) => (v === null ? '—' : v.toFixed(d));

export function generatePatientReport(input: ReportInput): void {
  const { baby, buckets, alerts, periodLabel, generatedBy } = input;
  const doc = new jsPDF({ unit: 'mm', format: 'a4' });
  const W = doc.internal.pageSize.getWidth();

  // Header band
  doc.setFillColor(29, 108, 241);
  doc.rect(0, 0, W, 24, 'F');
  doc.setTextColor(255, 255, 255);
  doc.setFontSize(15);
  doc.setFont('helvetica', 'bold');
  doc.text('Smart Bracelet — Patient Monitoring Report', 14, 11);
  doc.setFontSize(9);
  doc.setFont('helvetica', 'normal');
  doc.text(`Generated ${fmtDateTime(new Date().toISOString())} by ${generatedBy}`, 14, 18);

  // Identity block
  doc.setTextColor(30, 41, 59);
  doc.setFontSize(12);
  doc.setFont('helvetica', 'bold');
  doc.text('Patient', 14, 34);
  doc.setFontSize(10);
  doc.setFont('helvetica', 'normal');
  const identity = [
    `Name: ${baby.name}`,
    `Birth date: ${fmtDate(baby.birth_date)}  (${ageFromBirthDate(baby.birth_date)} old)`,
    `Weight at registration: ${baby.weight_grams} g`,
    `Gender: ${baby.gender === 'male' ? 'Male' : baby.gender === 'female' ? 'Female' : 'Unspecified'}`,
    `Parent: ${baby.parent_name || '—'}`,
    `Report period: ${periodLabel}`,
  ];
  identity.forEach((line, i) => doc.text(line, 14, 41 + i * 5.5));

  // Vitals summary table
  const hr = agg(buckets.map((b) => b.heart_rate_avg));
  const temp = agg(buckets.map((b) => b.temperature_avg));
  const spo2 = agg(buckets.map((b) => b.spo2_avg));
  const samples = buckets.reduce((a, b) => a + b.count, 0);

  autoTable(doc, {
    startY: 78,
    head: [['Vital sign', 'Min', 'Average', 'Max', 'Reference range']],
    body: [
      ['Heart rate (bpm)', f(hr.min, 0), f(hr.avg, 0), f(hr.max, 0), '90 – 180'],
      ['Temperature (°C)', f(temp.min), f(temp.avg), f(temp.max), '36.0 – 38.0'],
      ['SpO2 (%)', f(spo2.min, 0), f(spo2.avg, 0), f(spo2.max, 0), '≥ 92'],
    ],
    styles: { fontSize: 9 },
    headStyles: { fillColor: [29, 108, 241] },
    foot: [[{ content: `Based on ${samples} measurement(s) over the period.`, colSpan: 5 }]],
    footStyles: { fillColor: [241, 245, 249], textColor: [100, 116, 139], fontSize: 8 },
  });

  // Alerts table
  const afterVitals = (doc as unknown as { lastAutoTable: { finalY: number } }).lastAutoTable.finalY;
  doc.setFontSize(12);
  doc.setFont('helvetica', 'bold');
  doc.text(`Alerts during period (${alerts.length})`, 14, afterVitals + 12);

  autoTable(doc, {
    startY: afterVitals + 16,
    head: [['Severity', 'Type', 'Message', 'Value', 'Triggered', 'Resolved']],
    body: alerts.length
      ? alerts.map((a) => [
          a.severity,
          alertTypeLabel(a.type),
          a.message,
          a.value === null ? '—' : String(a.value),
          fmtDateTime(a.triggered_at),
          a.resolved_at ? fmtDateTime(a.resolved_at) : 'active',
        ])
      : [[{ content: 'No alerts during the selected period.', colSpan: 6 }]],
    styles: { fontSize: 8 },
    headStyles: { fillColor: [29, 108, 241] },
    columnStyles: { 2: { cellWidth: 55 } },
  });

  // Disclaimer footer on every page
  const pages = doc.getNumberOfPages();
  for (let i = 1; i <= pages; i++) {
    doc.setPage(i);
    const H = doc.internal.pageSize.getHeight();
    doc.setFontSize(7.5);
    doc.setTextColor(148, 163, 184);
    doc.text(doc.splitTextToSize(MEDICAL_DISCLAIMER, W - 28), 14, H - 12);
    doc.text(`Page ${i} / ${pages}`, W - 26, H - 6);
  }

  doc.save(`report_${baby.name.replace(/\s+/g, '_').toLowerCase()}_${new Date().toISOString().slice(0, 10)}.pdf`);
}
