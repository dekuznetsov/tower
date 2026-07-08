import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen } from '@testing-library/react';

// Mutable holders the hoisted mocks close over.
const h = vi.hoisted(() => ({
  user: null as { uid: string; email: string } | null,
  allow: {} as Record<string, unknown>,
}));

vi.mock('firebase/auth', () => ({
  onAuthStateChanged: (_auth: unknown, cb: (u: unknown) => void) => {
    cb(h.user);
    return () => {};
  },
  signInWithPopup: vi.fn(),
  signInWithRedirect: vi.fn(),
  signOut: vi.fn(),
}));

vi.mock('firebase/database', () => ({
  ref: (_db: unknown, path: string) => ({ path }),
  get: async (node: { path: string }) => ({
    val: () => (node.path in h.allow ? h.allow[node.path] : null),
  }),
}));

vi.mock('../src/firebase', () => ({ auth: {}, db: {}, googleProvider: {} }));

import { AuthProvider, useAuth } from '../src/auth/useAuth';

function Probe() {
  const { status } = useAuth();
  return <div>status:{status}</div>;
}

beforeEach(() => {
  h.user = null;
  h.allow = {};
});

describe('AuthProvider allowlist decision (Property W7)', () => {
  // Feature: web-app-google-auth, Property W7: Access requires allowlist membership
  it('W7: allowlisted user resolves to "allowed"', async () => {
    h.user = { uid: 'uid-allowed', email: 'ok@example.com' };
    h.allow = { 'allowlist/uid-allowed': true };
    render(
      <AuthProvider>
        <Probe />
      </AuthProvider>,
    );
    expect(await screen.findByText('status:allowed')).toBeInTheDocument();
  });

  it('W7: non-allowlisted user resolves to "not_allowed"', async () => {
    h.user = { uid: 'uid-stranger', email: 'stranger@example.com' };
    h.allow = {}; // absent from allowlist
    render(
      <AuthProvider>
        <Probe />
      </AuthProvider>,
    );
    expect(await screen.findByText('status:not_allowed')).toBeInTheDocument();
  });

  it('signed-out user resolves to "signed_out"', async () => {
    h.user = null;
    render(
      <AuthProvider>
        <Probe />
      </AuthProvider>,
    );
    expect(await screen.findByText('status:signed_out')).toBeInTheDocument();
  });
});
