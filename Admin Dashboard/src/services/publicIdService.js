export const publicIdService = {
  /**
   * Generates a short 8-character deterministic public ID from a raw Firebase UID.
   * This matches the logic used in the Flutter app.
   *
   * @param {string} userId - The raw Firebase UID
   * @returns {string} The formatted publicId (e.g., A1B2C3D4)
   */
  formatId: (userId) => {
    if (!userId) return 'UNKNOWN';
    if (userId.length < 8) return userId.toUpperCase();
    return userId.substring(0, 8).toUpperCase();
  }
};
