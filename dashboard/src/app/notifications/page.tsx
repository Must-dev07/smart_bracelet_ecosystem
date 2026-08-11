'use client';

/**
 * Notifications inbox for the doctor/admin dashboard (Section 9). This page
 * didn't exist before — doctors and admins had no way to see notifications
 * on the web at all, only on mobile. Category filter, unread filter, mark
 * read / mark all read, delete.
 */

import { useEffect, useState } from 'react';
import Shell from '@/components/Shell';
import { Empty, ErrorBox, Loading, PageTitle } from '@/components/ui';
import { apiFetch, fetchAllPages } from '@/lib/api';
import { fmtDateTime } from '@/lib/format';
import type { AppNotification, NotificationCategory } from '@/lib/types';

const CATEGORY_ICON: Record<NotificationCategory, string> = {
  alert: '🚨',
  bracelet: '⌚',
  medical: '🩺',
  system: 'ℹ️',
};

export default function NotificationsPage() {
  const [notifications, setNotifications] = useState<AppNotification[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [category, setCategory] = useState<NotificationCategory | 'all'>('all');
  const [unreadOnly, setUnreadOnly] = useState(false);
  const [busyId, setBusyId] = useState<number | null>(null);

  async function load() {
    setError(null);
    try {
      const data = await fetchAllPages<AppNotification>('/api/v1/notifications/');
      setNotifications(data);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load notifications.');
    }
  }

  useEffect(() => {
    load();
  }, []);

  async function markRead(id: number) {
    setBusyId(id);
    try {
      await apiFetch(`/api/v1/notifications/${id}/read/`, { method: 'POST' });
      await load();
    } finally {
      setBusyId(null);
    }
  }

  async function markAllRead() {
    try {
      await apiFetch('/api/v1/notifications/read-all/', { method: 'POST' });
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to mark all read.');
    }
  }

  async function remove(id: number) {
    setBusyId(id);
    try {
      await apiFetch(`/api/v1/notifications/${id}/`, { method: 'DELETE' });
      await load();
    } finally {
      setBusyId(null);
    }
  }

  const filtered = (notifications ?? [])
    .filter((n) => category === 'all' || n.category === category)
    .filter((n) => !unreadOnly || !n.read_at);
  const unreadCount = (notifications ?? []).filter((n) => !n.read_at).length;

  return (
    <Shell>
      <PageTitle
        title="Notifications"
        sub={unreadCount > 0 ? `${unreadCount} unread` : 'All caught up'}
        actions={
          unreadCount > 0 ? (
            <button className="btn-secondary" onClick={markAllRead}>
              Mark all read
            </button>
          ) : undefined
        }
      />

      <div className="mb-4 flex flex-wrap gap-2">
        {(['all', 'alert', 'bracelet', 'medical', 'system'] as const).map((c) => (
          <button
            key={c}
            onClick={() => setCategory(c)}
            className={`rounded-full border px-3 py-1 text-xs font-medium capitalize transition ${
              category === c
                ? 'border-brand-300 bg-brand-50 text-brand-700'
                : 'border-slate-200 bg-white text-slate-600 hover:bg-slate-50'
            }`}
          >
            {c === 'all' ? 'All' : `${CATEGORY_ICON[c]} ${c}`}
          </button>
        ))}
        <button
          onClick={() => setUnreadOnly((v) => !v)}
          className={`rounded-full border px-3 py-1 text-xs font-medium transition ${
            unreadOnly
              ? 'border-brand-300 bg-brand-50 text-brand-700'
              : 'border-slate-200 bg-white text-slate-600 hover:bg-slate-50'
          }`}
        >
          Unread only
        </button>
      </div>

      {error ? <ErrorBox message={error} /> : null}

      {notifications === null ? (
        <Loading />
      ) : filtered.length === 0 ? (
        <Empty message="No notifications match this filter." />
      ) : (
        <div className="card divide-y divide-slate-100 !p-0">
          {filtered.map((n) => (
            <div
              key={n.id}
              className={`flex items-start gap-3 px-4 py-3 ${!n.read_at ? 'bg-brand-50/40' : ''}`}
            >
              <span className="mt-0.5 text-lg" aria-hidden>
                {CATEGORY_ICON[n.category]}
              </span>
              <div className="min-w-0 flex-1">
                <p className={`text-sm ${!n.read_at ? 'font-semibold text-slate-900' : 'text-slate-700'}`}>
                  {n.title}
                </p>
                <p className="mt-0.5 text-sm text-slate-500">{n.body}</p>
                <p className="mt-1 text-xs text-slate-400">{fmtDateTime(n.created_at)}</p>
              </div>
              <div className="flex shrink-0 gap-2">
                {!n.read_at ? (
                  <button
                    className="btn-secondary !px-3 !py-1 text-xs"
                    disabled={busyId === n.id}
                    onClick={() => markRead(n.id)}
                  >
                    Mark read
                  </button>
                ) : null}
                <button
                  className="btn-secondary !px-3 !py-1 text-xs text-red-600"
                  disabled={busyId === n.id}
                  onClick={() => remove(n.id)}
                >
                  Delete
                </button>
              </div>
            </div>
          ))}
        </div>
      )}
    </Shell>
  );
}
