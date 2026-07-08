import { useAuth } from './useAuth';

export function AccessDenied() {
  const { user, signOutUser } = useAuth();
  return (
    <div className="centered-screen">
      <div className="card">
        <h1>Немає доступу</h1>
        <p>
          Акаунт <strong>{user?.email ?? 'цей'}</strong> не має дозволу на керування
          фермою. Зверніться до власника, щоб вас додали до списку доступу.
        </p>
        <button type="button" onClick={() => void signOutUser()}>
          Вийти
        </button>
      </div>
    </div>
  );
}
