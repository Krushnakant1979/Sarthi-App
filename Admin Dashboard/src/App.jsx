import React, { useState, useEffect } from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { onAuthStateChanged } from 'firebase/auth';
import { auth, db } from './config/firebase';
import { doc, getDoc } from 'firebase/firestore';

import { ToastProvider } from './context/ToastContext';
import { NotificationProvider } from './context/NotificationContext';
import { ThemeProvider } from './context/ThemeContext';

import { Layout } from './components/layout/Layout';
import { DashboardHome, Analytics } from './features/dashboard';
import { Captains } from './features/captains';
import { Users } from './features/users';
import { Rides } from './features/rides';
import { Offers } from './features/offers';
import { Settings } from './features/settings';
import { Marketing } from './features/marketing';
import { Reviews } from './features/reviews';
import { Vehicles } from './features/vehicles';
import { Support } from './features/support';
import { Login } from './features/auth';

function AppInner() {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const unsub = onAuthStateChanged(auth, async (currentUser) => {
      if (currentUser) {
        try {
          const userDoc = await getDoc(doc(db, 'users', currentUser.uid));
          if (userDoc.exists() && userDoc.data().role === 'admin') {
            setUser(currentUser);
          } else {
            await auth.signOut();
            setUser(null);
          }
        } catch {
          setUser(null);
        }
      } else {
        setUser(null);
      }
      setLoading(false);
    });
    return () => unsub();
  }, []);

  if (loading) {
    return (
      <div className="loading-screen">
        <div style={{ width: 52, height: 52, background: 'linear-gradient(135deg, #FFD633, #FFB300)', borderRadius: 14, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '1.5rem', fontWeight: 800, color: '#0B2545', marginBottom: '1rem', boxShadow: '0 4px 16px rgba(255,179,0,0.35)' }}>
          S
        </div>
        <div className="loading-screen-brand">Sarthi Admin</div>
        <div className="spinner"></div>
      </div>
    );
  }

  if (!user) {
    return <Login onLogin={(u) => setUser(u)} />;
  }

  return (
    <NotificationProvider>
      <Router>
        <Routes>
          <Route path="/" element={<Layout />}>
            <Route index element={<DashboardHome />} />
            <Route path="captains" element={<Captains />} />
            <Route path="users" element={<Users />} />
            <Route path="rides" element={<Rides />} />
            <Route path="offers" element={<Offers />} />
            <Route path="analytics" element={<Analytics />} />
            <Route path="marketing" element={<Marketing />} />
            <Route path="reviews" element={<Reviews />} />
            <Route path="vehicles" element={<Vehicles />} />
            <Route path="support" element={<Support />} />
            <Route path="settings" element={<Settings />} />
            <Route path="*" element={<Navigate to="/" replace />} />
          </Route>
        </Routes>
      </Router>
    </NotificationProvider>
  );
}

function App() {
  return (
    <ThemeProvider>
      <ToastProvider>
        <AppInner />
      </ToastProvider>
    </ThemeProvider>
  );
}

export default App;
