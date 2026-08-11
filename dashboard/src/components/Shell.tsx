'use client';

/**
 * Authenticated app shell: sidebar navigation + header + disclaimer footer.
 * Redirects to /login when no session is present. Admin-only links are
 * hidden for doctors (backend enforces authorization regardless).
 */

import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { useEffect, useState } from 'react';
import { getStoredUser, isLoggedIn, logout } from '@/lib/api';
import { MEDICAL_DISCLAIMER, type UserSummary } from '@/lib/types';

const NAV = [
  { href: '/dashboard', label: 'Dashboard', icon: '📊' },
  { href: '/patients', label: 'Patients', icon: '👶' },
  { href: '/alerts', label: 'Alerts', icon: '🚨' },
  { href: '/notifications', label: 'Notifications', icon: '🔔' },
  { href: '/statistics', label: 'Statistics', icon: '📈' },
  { href: '/reports', label: 'Reports', icon: '📄' },
  { href: '/settings', label: 'Settings', icon: '⚙️' },
];

const ADMIN_NAV = [{ href: '/users', label: 'Users', icon: '🧑‍⚕️' }];

export default function Shell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const router = useRouter();
  const [user, setUser] = useState<UserSummary | null>(null);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    if (!isLoggedIn()) {
      router.replace('/login');
      return;
    }
    setUser(getStoredUser());
    setReady(true);
  }, [router]);

  if (!ready) {
    return (
      <div className="flex min-h-screen items-center justify-center text-slate-400">
        Loading…
      </div>
    );
  }

  const nav = user?.role === 'admin' ? [...NAV, ...ADMIN_NAV] : NAV;

  return (
    <div className="flex min-h-screen">
      <aside className="hidden w-60 shrink-0 flex-col border-r border-slate-200 bg-white md:flex">
        <div className="flex items-center gap-2 border-b border-slate-100 px-5 py-4">
          <span className="text-2xl">🩺</span>
          <div>
            <p className="text-sm font-bold text-slate-900">Smart Bracelet</p>
            <p className="text-xs text-slate-500">Doctor Dashboard</p>
          </div>
        </div>
        <nav id="main-nav" className="flex-1 space-y-1 p-3">
          {nav.map((item) => {
            const active = pathname.startsWith(item.href);
            return (
              <Link
                key={item.href}
                href={item.href}
                className={`flex items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium transition ${
                  active
                    ? 'bg-brand-50 text-brand-700'
                    : 'text-slate-600 hover:bg-slate-50 hover:text-slate-900'
                }`}
              >
                <span aria-hidden>{item.icon}</span>
                {item.label}
              </Link>
            );
          })}
        </nav>
        <footer className="border-t border-slate-100 p-4">
          <p className="text-[11px] leading-snug text-slate-400">{MEDICAL_DISCLAIMER}</p>
        </footer>
      </aside>

      <div className="flex min-w-0 flex-1 flex-col">
        <header className="flex items-center justify-between border-b border-slate-200 bg-white px-6 py-3">
          <p className="text-sm text-slate-500">
            Signed in as{' '}
            <span className="font-medium text-slate-800">
              {user ? `${user.first_name} ${user.last_name}` : ''}
            </span>{' '}
            <span className="ml-1 rounded-full bg-slate-100 px-2 py-0.5 text-xs capitalize text-slate-600">
              {user?.role}
            </span>
          </p>
          <button
            id="logout-button"
            className="btn-secondary"
            onClick={async () => {
              await logout();
              router.replace('/login');
            }}
          >
            Sign out
          </button>
        </header>
        <main className="min-w-0 flex-1 p-6">{children}</main>
      </div>
    </div>
  );
}
