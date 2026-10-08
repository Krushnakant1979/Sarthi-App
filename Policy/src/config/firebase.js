import { initializeApp } from "firebase/app";
import { getAuth } from "firebase/auth";

const firebaseConfig = {
  apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY || "AIzaSyCZgfdYu_DVHm3Ai5jNukAaZCtqp2wGKpk",
  authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN || "rapido-app-8745a.firebaseapp.com",
  projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID || "rapido-app-8745a",
  storageBucket: process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET || "rapido-app-8745a.firebasestorage.app",
  messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID || "38677009511",
  appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID || "1:38677009511:web:placeholder"
};

import { getFirestore } from "firebase/firestore";
import { getDatabase } from "firebase/database";

// Initialize Firebase
const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const db = getFirestore(app);
export const rtdb = getDatabase(app, "https://rapido-app-8745a-default-rtdb.asia-southeast1.firebasedatabase.app");

export default app;
