import { db } from '../../../config/firebase';
import { doc, updateDoc, deleteDoc, serverTimestamp } from 'firebase/firestore';
import { logAdminAction } from '../../../services/auditService';

export const captainService = {
  verifyCaptain: async (captainId) => {
    const res = await updateDoc(doc(db, 'users', captainId), {
      verificationStatus: 'verified',
      verificationUpdatedAt: serverTimestamp(),
    });
    await logAdminAction('captain_verification_changed', captainId, {
      status: 'verified',
    });
    return res;
  },

  rejectCaptain: async (captainId, reason) => {
    const res = await updateDoc(doc(db, 'users', captainId), {
      verificationStatus: 'rejected',
      verificationUpdatedAt: serverTimestamp(),
      ...(reason ? { rejectionReason: reason } : {})
    });
    await logAdminAction('captain_verification_changed', captainId, {
      status: 'rejected',
      ...(reason ? { reason } : {})
    });
    return res;
  },

  deleteCaptain: async (captainId) => {
    const res = await deleteDoc(doc(db, 'users', captainId));
    await logAdminAction('captain_deleted', captainId, {});
    return res;
  }
};
