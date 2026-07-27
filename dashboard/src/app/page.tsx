'use client';

import { useRouter } from 'next/navigation';
import { useEffect } from 'react';
import { isLoggedIn } from '@/lib/api';

/** Root route: redirect to dashboard when signed in, otherwise to login. */
export default function RootPage() {
  const router = useRouter();
  useEffect(() => {
    router.replace(isLoggedIn() ? '/dashboard' : '/login');
  }, [router]);
  return <div className="flex min-h-screen items-center justify-center text-slate-400">Redirecting…</div>;
}
