import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { StatusGate } from '../src/components/StatusGate';
import type { AuthStatus } from '../src/auth/useAuth';

function renderGate(status: AuthStatus) {
  return render(
    <StatusGate
      status={status}
      loading={<div>LOADING</div>}
      signedOut={<div>SIGN_IN</div>}
      notAllowed={<div>DENIED</div>}
      allowed={<div>DASHBOARD_reads_farms</div>}
    />,
  );
}

describe('StatusGate (Property W7 routing)', () => {
  // Feature: web-app-google-auth, Property W7: Access requires allowlist membership
  it('W7: shows the farms-reading dashboard only when status is "allowed"', () => {
    const cases: Array<[AuthStatus, string]> = [
      ['loading', 'LOADING'],
      ['signed_out', 'SIGN_IN'],
      ['not_allowed', 'DENIED'],
      ['allowed', 'DASHBOARD_reads_farms'],
    ];
    for (const [status, expected] of cases) {
      const { unmount } = renderGate(status);
      expect(screen.getByText(expected)).toBeInTheDocument();
      // The dashboard branch must never appear for non-allowed statuses.
      if (status !== 'allowed') {
        expect(screen.queryByText('DASHBOARD_reads_farms')).not.toBeInTheDocument();
      }
      unmount();
    }
  });
});
