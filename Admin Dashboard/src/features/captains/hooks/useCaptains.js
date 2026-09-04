import { useState, useEffect } from 'react';
import { db } from '../../../config/firebase';
import { collection, query, where, onSnapshot } from 'firebase/firestore';
import { publicIdService } from '../../../services/publicIdService';

export const useCaptains = () => {
  const [captains, setCaptains] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    const q = query(collection(db, 'users'), where('role', '==', 'captain'));
    const unsub = onSnapshot(
      q,
      (snap) => {
        setCaptains(snap.docs.map((d) => ({ 
          id: d.id, 
          ...d.data(),
          publicId: publicIdService.formatId(d.id)
        })));
        
        setLoading(false);
      },
      (err) => {
        console.error(err);
        setError(err);
        setLoading(false);
      }
    );
    return () => unsub();
  }, []);

  return { captains, loading, error };
};
