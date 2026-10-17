import { db, auth } from '../config/firebase';
import { collection, addDoc, serverTimestamp } from 'firebase/firestore';

/**
 * Records admin actions to the unified `admin_audit_logs` collection.
 * Maintains security, auditability, and full compliance parity with the mobile admin app.
 *
 * @param {string} action - Event identifier (e.g. 'captain_verification_changed', 'fare_rules_changed', 'payout_settled')
 * @param {string} targetId - Document ID or target entity ID
 * @param {object} details - Additional contextual payload
 */
export const logAdminAction = async (action, targetId, details = {}) => {
  try {
    const adminUid = auth.currentUser?.uid || 'unknown_admin';
    await addDoc(collection(db, 'admin_audit_logs'), {
      adminUid,
      adminEmail: auth.currentUser?.email || '',
      action,
      targetId: targetId || '',
      details,
      timestamp: serverTimestamp(),
      platform: 'web_admin'
    });
  } catch (err) {
    console.error(`[auditService] Failed to record audit log for action "${action}":`, err);
  }
};
