import { db } from '../config/firebase';
import { doc, runTransaction } from 'firebase/firestore';

export const publicIdService = {
  /**
   * Generates a sequential public ID for a user or captain.
   * Uses a Firestore transaction to ensure uniqueness and atomic counter increments.
   *
   * @param {string} userId - The raw Firebase UID to assign the publicId to.
   * @param {string} role - 'user' or 'captain'
   * @returns {Promise<string>} The generated publicId
   */
  assignSequentialId: async (userId, role) => {
    const isCaptain = role === 'captain';
    const counterDocRef = doc(db, 'counters', isCaptain ? 'captains' : 'users');
    const userDocRef = doc(db, 'users', userId);

    try {
      return await runTransaction(db, async (transaction) => {
        // 1. Check if user already has a publicId to prevent overwriting
        const userDoc = await transaction.get(userDocRef);
        if (!userDoc.exists()) {
          throw new Error('User document does not exist!');
        }

        const userData = userDoc.data();
        if (userData.publicId) {
          return userData.publicId; // Already assigned
        }

        // 2. Read the counter
        const counterDoc = await transaction.get(counterDocRef);
        let newCount = 1;

        if (counterDoc.exists()) {
          newCount = counterDoc.data().count + 1;
        }

        // 3. Format the new ID
        const prefix = isCaptain ? 'Cap' : 'USR';
        const formattedCount = String(newCount).padStart(3, '0');
        const generatedId = `${prefix}-${formattedCount}`;

        // 4. Update the counter
        transaction.set(counterDocRef, { count: newCount }, { merge: true });

        // 5. Update the user document
        transaction.update(userDocRef, { publicId: generatedId });

        return generatedId;
      });
    } catch (error) {
      console.error("Error generating sequential ID: ", error);
      throw error;
    }
  }
};
