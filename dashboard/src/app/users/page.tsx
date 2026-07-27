'use client';

/**
 * Users (admin-only): full user listing with role filter. The backend
 * enforces admin permission (403 otherwise); the page also guards
 * client-side and shows a friendly message for non-admins.
 */

import { useEffect, useMemo, useState } from 'react';
import Shell from '@/components/Shell';
import { Empty, ErrorBox, Loading, PageTitle } from '@/components/ui';
import { ApiError, apiFetch, getStoredUser } from '@/lib/api';
import { fmtDate } from '@/lib/format';
import type { Paginated, Role, UserSummary } from '@/lib/types';

const ROLE_STYLES: Record<Role, string> = {
  admin: 'bg-purple-100 text-purple-800',
  doctor: 'bg-blue-100 text-blue-800',
  parent: 'bg-emerald-100 text-emerald-800',
};

export default function UsersPage() {
  const [users, setUsers] = useState<UserSummary[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [roleFilter, setRoleFilter] = useState<Role | 'all'>('all');
  const [search, setSearch] = useState('');
  const isAdmin = getStoredUser()?.role === 'admin';

  useEffect(() => {
    (async () => {
      try {
        const out: UserSummary[] = [];
        let page = 1;
        for (;;) {
          const res = await apiFetch<Paginated<UserSummary>>(`/api/v1/users/?page=${page}`);
          out.push(...res.results);
          if (!res.next || page > 100) break;
          page += 1;
        }
        setUsers(out);
      } catch (e) {
        setError(
          e instanceof ApiError && e.status === 403
            ? 'This page is restricted to administrators.'
            : e instanceof Error
              ? e.message
              : 'Failed to load users.',
        );
      }
    })();
  }, []);

  const filtered = useMemo(() => {
    if (!users) return null;
    const q = search.trim().toLowerCase();
    return users.filter(
      (u) =>
        (roleFilter === 'all' || u.role === roleFilter) &&
        (!q ||
          u.email.toLowerCase().includes(q) ||
          `${u.first_name} ${u.last_name}`.toLowerCase().includes(q)),
    );
  }, [users, roleFilter, search]);

  return (
    <Shell>
      <PageTitle
        title="Users"
        sub="All platform accounts (administrators only). Account creation happens via mobile app registration or the Django admin."
      />
      {!isAdmin && !error ? (
        <ErrorBox message="This page is restricted to administrators." />
      ) : null}
      {error ? <ErrorBox message={error} /> : null}
      {isAdmin && !users && !error ? <Loading /> : null}

      {isAdmin && filtered ? (
        <>
          <nav className="mb-4 flex flex-wrap items-center gap-3" aria-label="User filters">
            <input
              id="user-search"
              type="search"
              className="input !w-64"
              placeholder="Search name or email…"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
            <select
              className="input !w-auto"
              value={roleFilter}
              onChange={(e) => setRoleFilter(e.target.value as Role | 'all')}
              aria-label="Role filter"
            >
              <option value="all">All roles</option>
              <option value="admin">Admins</option>
              <option value="doctor">Doctors</option>
              <option value="parent">Parents</option>
            </select>
            <span className="text-sm text-slate-500">{filtered.length} account(s)</span>
          </nav>

          {filtered.length === 0 ? (
            <Empty message="No users match the current filters." />
          ) : (
            <section className="card overflow-x-auto p-0">
              <table className="table-base">
                <thead>
                  <tr>
                    <th>Name</th>
                    <th>Email</th>
                    <th>Role</th>
                    <th>Phone</th>
                    <th>Created</th>
                  </tr>
                </thead>
                <tbody>
                  {filtered.map((u) => (
                    <tr key={u.id}>
                      <td className="font-medium">{u.first_name} {u.last_name}</td>
                      <td className="text-slate-600">{u.email}</td>
                      <td>
                        <span className={`rounded-full px-2 py-0.5 text-xs font-medium capitalize ${ROLE_STYLES[u.role]}`}>
                          {u.role}
                        </span>
                      </td>
                      <td>{u.phone || '—'}</td>
                      <td className="text-slate-500">{fmtDate(u.created_at)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </section>
          )}
        </>
      ) : null}
    </Shell>
  );
}
