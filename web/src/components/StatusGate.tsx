import type { ReactNode } from 'react';
import type { AuthStatus } from '../auth/useAuth';

interface StatusGateProps {
  status: AuthStatus;
  loading: ReactNode;
  signedOut: ReactNode;
  notAllowed: ReactNode;
  allowed: ReactNode;
}

/**
 * Pure routing component: renders exactly one branch for the current auth
 * status. Kept free of Firebase imports so the gating logic (Property W7) is
 * testable in isolation — the `allowed` branch (which mounts the tower
 * dashboard and thus reads `farms/`) is reachable only when status is 'allowed'.
 */
export function StatusGate({
  status,
  loading,
  signedOut,
  notAllowed,
  allowed,
}: StatusGateProps): ReactNode {
  switch (status) {
    case 'loading':
      return loading;
    case 'signed_out':
      return signedOut;
    case 'not_allowed':
      return notAllowed;
    case 'allowed':
      return allowed;
  }
}
