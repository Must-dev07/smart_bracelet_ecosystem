'use client';

import { useRouter } from 'next/navigation';
import { useState } from 'react';
import { ApiError, login } from '@/lib/api';
import { MEDICAL_DISCLAIMER } from '@/lib/types';

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setBusy(true);
    try {
      const pair = await login(email, password);
      if (pair.user.role === 'parent') {
        setError('This dashboard is for doctors and administrators. Parents should use the mobile app.');
        return;
      }
      router.replace('/dashboard');
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Unable to sign in. Check your connection.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <main className="flex min-h-screen items-center justify-center bg-gradient-to-br from-brand-50 to-slate-100 p-4">
      <section id="login-card" className="card w-full max-w-md">
        <header className="mb-6 text-center">
          <span className="text-4xl">🩺</span>
          <h1 className="mt-2 text-xl font-bold text-slate-900">Smart Bracelet Dashboard</h1>
          <p className="mt-1 text-sm text-slate-500">Doctor &amp; administrator access</p>
        </header>

        <form onSubmit={onSubmit} className="space-y-4">
          <div>
            <label htmlFor="login-email" className="label">Email</label>
            <input
              id="login-email"
              type="email"
              className="input"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
              autoComplete="email"
            />
          </div>
          <div>
            <label htmlFor="login-password" className="label">Password</label>
            <input
              id="login-password"
              type="password"
              className="input"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
              autoComplete="current-password"
            />
          </div>
          {error ? (
            <p className="rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">{error}</p>
          ) : null}
          <button id="login-submit" type="submit" className="btn-primary w-full justify-center" disabled={busy}>
            {busy ? 'Signing in…' : 'Sign in'}
          </button>
        </form>

        <footer className="mt-6 border-t border-slate-100 pt-4">
          <p className="text-center text-[11px] leading-snug text-slate-400">{MEDICAL_DISCLAIMER}</p>
        </footer>
      </section>
    </main>
  );
}
