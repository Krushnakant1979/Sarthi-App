import React, { createContext, useContext, useEffect, useState } from 'react';
import { db } from '../config/firebase';
import { collection, query, where, onSnapshot, orderBy } from 'firebase/firestore';

const NotifContext = createContext(null);
export const useNotifications = () => useContext(NotifContext);

/**
 * Listens in real-time for captain accounts with verificationStatus === 'pending'
 * Each one maps to a notification item for the admin.
 */
export const NotificationProvider = ({ children }) => {
  const [notifications, setNotifications] = useState([]);

  useEffect(() => {
    // Stream all users with role=captain and status=pending — each is a notification
    const q = query(
      collection(db, 'users'),
      where('role', '==', 'captain'),
      where('verificationStatus', '==', 'pending'),
      orderBy('createdAt', 'desc')
    );

    const unsub = onSnapshot(q, (snap) => {
      const items = snap.docs.map(doc => ({
        id: doc.id,
        type: 'captain_pending',
        title: 'New Captain Registration',
        desc: `${doc.data().name || 'Unknown'} is awaiting document verification.`,
        data: { id: doc.id, ...doc.data() },
        time: doc.data().createdAt,
      }));
      setNotifications(items);
    }, (error) => {
      console.error('Notification listener error:', error);
    });

    return () => unsub();
  }, []);

  return (
    <NotifContext.Provider value={{ notifications, count: notifications.length }}>
      {children}
    </NotifContext.Provider>
  );
};
