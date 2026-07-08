import { useAuth } from './useAuth';

export function SignInScreen() {
  const { signIn, error } = useAuth();
  return (
    <div className="centered-screen">
      <div className="card sign-in">
        <h1>Hydroponics Farm</h1>
        <p>Увійдіть, щоб керувати теплицею.</p>
        <button type="button" className="google-btn" onClick={() => void signIn()}>
          Увійти через Google
        </button>
        {error && <p className="error" role="alert">{error}</p>}
      </div>
    </div>
  );
}
