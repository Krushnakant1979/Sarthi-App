"use client";
import React, { createContext, useContext, useEffect, useState } from "react";
import { 
  onAuthStateChanged, 
  signInWithEmailAndPassword, 
  createUserWithEmailAndPassword, 
  signOut,
  updateProfile
} from "firebase/auth";
import { collection, query, where, onSnapshot } from "firebase/firestore";
import { auth, db } from "@/config/firebase";

const AuthContext = createContext({});

export const useAuth = () => useContext(AuthContext);

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const [activeRideId, setActiveRideId] = useState(null);

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, (currentUser) => {
      setUser(currentUser);
      setLoading(false);
    });
    return () => unsubscribe();
  }, []);

  useEffect(() => {
    if (!user) {
      setActiveRideId(null);
      return;
    }

    const q = query(
      collection(db, "ride_requests"),
      where("userId", "==", user.uid),
      where("status", "in", ["searching", "accepted", "arriving", "arrived", "in_progress"])
    );

    const unsub = onSnapshot(q, (snapshot) => {
      if (!snapshot.empty) {
        const now = Date.now();
        
        // Filter out rides that have been stuck for more than 2 hours
        // This prevents old test rides from infinitely restoring
        const validDocs = snapshot.docs.filter(d => {
          const data = d.data();
          if (data.createdAt) {
            const ageMs = now - data.createdAt.toMillis();
            const ageHours = ageMs / (1000 * 60 * 60);
            if (ageHours > 2) {
              return false; // ignore stale ride
            }
          }
          return true;
        });

        if (validDocs.length > 0) {
          // Sort by newest first
          validDocs.sort((a, b) => {
            const aTime = a.data().createdAt?.toMillis() || 0;
            const bTime = b.data().createdAt?.toMillis() || 0;
            return bTime - aTime;
          });
          setActiveRideId(validDocs[0].id);
        } else {
          setActiveRideId(null);
        }
      } else {
        setActiveRideId(null);
      }
    });

    return () => unsub();
  }, [user]);

  const login = (email, password) => {
    return signInWithEmailAndPassword(auth, email, password);
  };

  const signup = async (email, password, name) => {
    const cred = await createUserWithEmailAndPassword(auth, email, password);
    if (cred.user) {
      await updateProfile(cred.user, { displayName: name });
      setUser({ ...cred.user, displayName: name });
    }
    return cred;
  };

  const logout = () => {
    return signOut(auth);
  };

  return (
    <AuthContext.Provider value={{ user, login, signup, logout, loading, activeRideId }}>
      {!loading && children}
    </AuthContext.Provider>
  );
};

