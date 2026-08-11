'use client';

/**
 * API client for the Django backend (/api/v1).
 *
 * - Stores JWT pair in localStorage (dashboard is a trusted clinician tool;
 *   tokens are short-lived and refresh rotation revokes old sessions server-side).
 * - Transparently retries ONCE after a silent refresh on 401.
 * - Throws ApiError with parsed body for consistent error surfaces.
 */

import type { TokenPair, UserSummary } from './types';

export const API_BASE =
  process.env.NEXT_PUBLIC_API_BASE_URL ?? 'http://localhost:8080';

const ACCESS_KEY = 'sb_access';
const REFRESH_KEY = 'sb_refresh';
const USER_KEY = 'sb_user';

export class ApiError extends Error {
  status: number;
  body: unknown;
  constructor(status: number, body: unknown) {
    super(typeof body === 'object' && body !== null && 'detail' in (body as Record<string, unknown>)
      ? String((body as Record<string, unknown>).detail)
      : `API error ${status}`);
    this.status = status;
    this.body = body;
  }
}

export function getStoredUser(): UserSummary | null {
  if (typeof window === 'undefined') return null;
  const raw = localStorage.getItem(USER_KEY);
  if (!raw) return null;
  try {
    return JSON.parse(raw) as UserSummary;
  } catch {
    return null;
  }
}

export function isLoggedIn(): boolean {
  return typeof window !== 'undefined' && !!localStorage.getItem(ACCESS_KEY);
}

function saveTokens(pair: { access: string; refresh: string }) {
  localStorage.setItem(ACCESS_KEY, pair.access);
  localStorage.setItem(REFRESH_KEY, pair.refresh);
}

export function clearSession() {
  localStorage.removeItem(ACCESS_KEY);
  localStorage.removeItem(REFRESH_KEY);
  localStorage.removeItem(USER_KEY);
}

async function parseBody(res: Response): Promise<unknown> {
  const text = await res.text();
  try {
    return text ? JSON.parse(text) : null;
  } catch {
    return text;
  }
}

async function refreshOnce(): Promise<boolean> {
  const refresh = localStorage.getItem(REFRESH_KEY);
  if (!refresh) return false;
  const res = await fetch(`${API_BASE}/api/v1/auth/refresh`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ refresh }),
  });
  if (!res.ok) {
    clearSession();
    return false;
  }
  const body = (await res.json()) as { access: string; refresh: string };
  saveTokens(body);
  return true;
}

export async function apiFetch<T>(
  path: string,
  init: RequestInit = {},
  retry = true,
): Promise<T> {
  const access = typeof window !== 'undefined' ? localStorage.getItem(ACCESS_KEY) : null;
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    ...(init.headers as Record<string, string> | undefined),
  };
  if (access) headers['Authorization'] = `Bearer ${access}`;

  const res = await fetch(`${API_BASE}${path}`, { ...init, headers });

  if (res.status === 401 && retry) {
    const ok = await refreshOnce();
    if (ok) return apiFetch<T>(path, init, false);
    if (typeof window !== 'undefined') window.location.href = '/login';
    throw new ApiError(401, { detail: 'Session expired.' });
  }
  if (!res.ok) throw new ApiError(res.status, await parseBody(res));
  if (res.status === 204) return null as T;
  return (await parseBody(res)) as T;
}

// ---------------------------------------------------------------- auth

export async function login(email: string, password: string): Promise<TokenPair> {
  const res = await fetch(`${API_BASE}/api/v1/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password }),
  });
  if (!res.ok) throw new ApiError(res.status, await parseBody(res));
  const pair = (await res.json()) as TokenPair;
  saveTokens(pair);
  localStorage.setItem(USER_KEY, JSON.stringify(pair.user));
  return pair;
}

// ---------------------------------------------------------------- pagination

/** Walks every page of a DRF paginated endpoint and returns the flattened list.
 * Shared by every list page (users, doctors, parents, bracelets, babies…) so
 * pagination-walking logic lives in exactly one place. */
export async function fetchAllPages<T>(basePath: string, maxPages = 100): Promise<T[]> {
  const out: T[] = [];
  let page = 1;
  for (;;) {
    const sep = basePath.includes('?') ? '&' : '?';
    const res = await apiFetch<{ results: T[]; next: string | null }>(`${basePath}${sep}page=${page}`);
    out.push(...res.results);
    if (!res.next || page >= maxPages) break;
    page += 1;
  }
  return out;
}

export async function logout(): Promise<void> {
  const refresh = localStorage.getItem(REFRESH_KEY);
  try {
    if (refresh) {
      await apiFetch('/api/v1/auth/logout', {
        method: 'POST',
        body: JSON.stringify({ refresh }),
      });
    }
  } catch {
    // Local logout still proceeds if the server call fails.
  } finally {
    clearSession();
  }
}
