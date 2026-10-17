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
  const [hasEmergency, setHasEmergency] = useState(false);

  useEffect(() => {
    let captainItems = [];
    let emergencyItems = [];

    const updateCombined = () => {
      const combined = [
        ...emergencyItems,
        ...captainItems,
      ].sort((a, b) => {
        // High priority emergency events always on top
        if (a.priority === 'emergency' && b.priority !== 'emergency') return -1;
        if (b.priority === 'emergency' && a.priority !== 'emergency') return 1;
        const tA = a.time?.toDate ? a.time.toDate().getTime() : new Date(a.time || 0).getTime();
        const tB = b.time?.toDate ? b.time.toDate().getTime() : new Date(b.time || 0).getTime();
        return tB - tA;
      });
      setNotifications(combined);
      setHasEmergency(emergencyItems.length > 0);
    };

    // 1. Listen for emergency SOS alerts
    const qEmergency = query(
      collection(db, 'emergency_events'),
      where('status', '==', 'active')
    );
    const unsubEmergency = onSnapshot(qEmergency, (snap) => {
      emergencyItems = snap.docs.map(doc => {
        const d = doc.data();
        return {
          id: doc.id,
          type: 'emergency_sos',
          priority: 'emergency',
          title: '🚨 EMERGENCY SOS ALERT',
          desc: `Active incident reported on Ride: ${d.rideId ? (d.rideId.slice(0, 8).toUpperCase()) : 'Live Ride'}. Rider: ${d.userId ? d.userId.slice(0, 8) : 'Unknown'}.`,
          data: { id: doc.id, ...d },
          time: d.timestamp || d.createdAt,
        };
      });
      updateCombined();
    }, (err) => console.error('Emergency notification error:', err));

    // 2. Stream pending captain registrations
    const qCaptains = query(
      collection(db, 'users'),
      where('role', '==', 'captain')
    );
    const unsubCaptains = onSnapshot(qCaptains, (snap) => {
      captainItems = snap.docs
        .filter(doc => {
          const status = doc.data().verificationStatus;
          return status === 'pending_review' || status === 'pending';
        })
        .map(doc => ({
          id: doc.id,
          type: 'captain_pending',
          priority: 'normal',
          title: 'New Captain Registration',
          desc: `${doc.data().name || 'Unknown'} is awaiting document verification.`,
          data: { id: doc.id, ...doc.data() },
          time: doc.data().createdAt,
        }));
      updateCombined();
    }, (error) => {
      console.error('Notification listener error:', error);
    });

    return () => {
      unsubEmergency();
      unsubCaptains();
    };
  }, []);

  return (
    <NotifContext.Provider value={{ notifications, count: notifications.length, hasEmergency }}>
      {children}
    </NotifContext.Provider>
  );
};
