// Single shared Firebase initialisation module. Reads the web SDK config from
// build-time environment variables (VITE_FB_*), which are produced from the
// Terraform outputs — no secrets are hard-coded here.

import { initializeApp, type FirebaseApp } from 'firebase/app';
import { getAuth, GoogleAuthProvider, type Auth } from 'firebase/auth';
import { getDatabase, type Database } from 'firebase/database';

const firebaseConfig = {
  apiKey: import.meta.env.VITE_FB_API_KEY,
  authDomain: import.meta.env.VITE_FB_AUTH_DOMAIN,
  projectId: import.meta.env.VITE_FB_PROJECT_ID,
  appId: import.meta.env.VITE_FB_APP_ID,
  messagingSenderId: import.meta.env.VITE_FB_SENDER_ID,
  databaseURL: import.meta.env.VITE_FB_DATABASE_URL,
};

export const app: FirebaseApp = initializeApp(firebaseConfig);
export const auth: Auth = getAuth(app);
export const db: Database = getDatabase(app);
export const googleProvider = new GoogleAuthProvider();
