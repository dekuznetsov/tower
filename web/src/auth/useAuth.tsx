// Authentication + allowlist authorization context.
// Mirrors the intent of the Flutter auth gate: Google OAuth sign-in, then a
// membership check against /allowlist/{uid}. The client check is UX only — the
// authoritative boundary is the RTDB security rules.

import {
  createContext,
  useContext,
  useEffect,
  useState,
  type ReactNode,
} from 'react';
import {
  onAuthStateChanged,
  signInWithPopup,
  signInWithRedirect,
  signOut,
  type User,
} from 'firebase/auth';
import { ref, get } from 'firebase/database';
import { auth, db, googleProvider } from '../firebase';

export type AuthStatus = 'loading' | 'signed_out' | 'not_allowed' | 'allowed';

interface AuthContextValue {
  status: AuthStatus;
  user: User | null;
  error: string | null;
  signIn: () => Promise<void>;
  signOutUser: () => Promise<void>;
}

const AuthContext = createContext<AuthContextValue | undefined>(undefined);

/** Reads `/allowlist/{uid}` and returns whether the user is authorized. */
export async function checkAllowlist(uid: string): Promise<boolean> {
  const snapshot = await get(ref(db, `allowlist/${uid}`));
  return snapshot.val() === true;
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [status, setStatus] = useState<AuthStatus>('loading');
  const [user, setUser] = useState<User | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, async (nextUser) => {
      if (!nextUser) {
        setUser(null);
        setStatus('signed_out');
        return;
      }
      setUser(nextUser);
      setStatus('loading');
      try {
        const allowed = await checkAllowlist(nextUser.uid);
        setStatus(allowed ? 'allowed' : 'not_allowed');
      } catch {
        // If the membership read fails (e.g. rules deny), treat as not allowed.
        setStatus('not_allowed');
      }
    });
    return unsubscribe;
  }, []);

  const signIn = async () => {
    setError(null);
    try {
      await signInWithPopup(auth, googleProvider);
    } catch (e) {
      const code = (e as { code?: string }).code;
      if (
        code === 'auth/popup-blocked' ||
        code === 'auth/operation-not-supported-in-environment'
      ) {
        try {
          await signInWithRedirect(auth, googleProvider);
        } catch {
          setError('Не вдалося увійти. Спробуйте ще раз.');
        }
      } else if (
        code === 'auth/popup-closed-by-user' ||
        code === 'auth/cancelled-popup-request'
      ) {
        // User dismissed the popup — not an error worth surfacing.
      } else {
        setError('Не вдалося увійти. Спробуйте ще раз.');
      }
    }
  };

  const signOutUser = async () => {
    await signOut(auth);
  };

  return (
    <AuthContext.Provider value={{ status, user, error, signIn, signOutUser }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth(): AuthContextValue {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used within an AuthProvider');
  return ctx;
}
