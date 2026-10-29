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
import { Marketing } from './features/marketing';
import { Reviews } from './features/reviews';
import { Vehicles } from './features/vehicles';
import { Support } from './features/support';
import { Login } from './features/auth';
import { Finance } from './features/finance';
import { Pricing } from './features/pricing';
import { Settings } from './features/settings';

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
        <img
          src="/Sarthi app Admin logo.png"
          alt="Sarthi Admin Logo"
          style={{
            width: 56,
            height: 56,
            borderRadius: 14,
            objectFit: 'cover',
            marginBottom: '0.25rem',
            boxShadow: '0 4px 20px rgba(30, 128, 240, 0.35)'
          }}
        />
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
            <Route path="finance" element={<Finance />} />
            <Route path="pricing" element={<Pricing />} />
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
