import { AuthProvider, useAuth } from './auth/useAuth';
import { StatusGate } from './components/StatusGate';
import { SignInScreen } from './auth/SignInScreen';
import { AccessDenied } from './auth/AccessDenied';
import { TowerDashboard } from './components/TowerDashboard';

function Routed() {
  const { status } = useAuth();
  return (
    <StatusGate
      status={status}
      loading={<div className="centered-screen">Завантаження…</div>}
      signedOut={<SignInScreen />}
      notAllowed={<AccessDenied />}
      allowed={<TowerDashboard />}
    />
  );
}

export default function App() {
  return (
    <AuthProvider>
      <Routed />
    </AuthProvider>
  );
}
