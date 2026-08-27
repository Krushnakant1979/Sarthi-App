import { db } from '../../../config/firebase';
import { doc, updateDoc, deleteDoc, serverTimestamp } from 'firebase/firestore';

export const captainService = {
  verifyCaptain: async (captainId) => {
    return updateDoc(doc(db, 'users', captainId), {
      verificationStatus: 'verified',
      verificationUpdatedAt: serverTimestamp(),
    });
  },

  rejectCaptain: async (captainId) => {
    return updateDoc(doc(db, 'users', captainId), {
      verificationStatus: 'rejected',
      verificationUpdatedAt: serverTimestamp(),
    });
  },

  deleteCaptain: async (captainId) => {
    return deleteDoc(doc(db, 'users', captainId));
  }
};
