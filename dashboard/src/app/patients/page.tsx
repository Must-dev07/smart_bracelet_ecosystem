'use client';

/** Patients list with client-side search over name/parent. */

import Link from 'next/link';
import { useEffect, useMemo, useState } from 'react';
import Shell from '@/components/Shell';
import { Empty, ErrorBox, Loading, PageTitle } from '@/components/ui';
import { apiFetch } from '@/lib/api';
import { ageFromBirthDate, fmtDate } from '@/lib/format';
import type { Baby, Paginated } from '@/lib/types';

export default function PatientsPage() {
  const [babies, setBabies] = useState<Baby[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [search, setSearch] = useState('');

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
      } catch (e) {
        setError(e instanceof Error ? e.message : 'Failed to load patients.');
      }
    })();
  }, []);

  const filtered = useMemo(() => {
    if (!babies) return null;
    const q = search.trim().toLowerCase();
    if (!q) return babies;
    return babies.filter(
      (b) => b.name.toLowerCase().includes(q) || b.parent_name.toLowerCase().includes(q),
    );
  }, [babies, search]);

  return (
    <Shell>
      <PageTitle
        title="Patients"
        sub="Babies assigned to you (doctors see their assigned patients; admins see all)."
      />
      <div className="mb-4 max-w-sm">
        <input
          id="patient-search"
          type="search"
          className="input"
          placeholder="Search by baby or parent name…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
      </div>
      {error ? <ErrorBox message={error} /> : null}
      {!filtered && !error ? <Loading /> : null}
      {filtered ? (
        filtered.length === 0 ? (
          <Empty message="No patients found." />
        ) : (
          <section className="card overflow-x-auto p-0">
            <table className="table-base">
              <thead>
                <tr>
                  <th>Name</th>
                  <th>Age</th>
                  <th>Birth date</th>
                  <th>Weight</th>
                  <th>Gender</th>
                  <th>Parent</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                {filtered.map((b) => (
                  <tr key={b.id}>
                    <td className="font-medium">
                      <Link href={`/patients/${b.id}`} className="text-brand-600 hover:underline">
                        {b.name}
                      </Link>
                    </td>
                    <td>{ageFromBirthDate(b.birth_date)}</td>
                    <td>{fmtDate(b.birth_date)}</td>
                    <td>{b.weight_grams} g</td>
                    <td>{b.gender === 'male' ? 'Male' : b.gender === 'female' ? 'Female' : '—'}</td>
                    <td className="text-slate-600">{b.parent_name || '—'}</td>
                    <td>
                      <Link href={`/patients/${b.id}`} className="btn-secondary !px-3 !py-1 text-xs">
                        Open
                      </Link>
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
