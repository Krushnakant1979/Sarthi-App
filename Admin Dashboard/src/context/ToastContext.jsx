import React, { createContext, useContext, useState, useCallback } from 'react';
import { CheckCircle, XCircle, Info } from '@phosphor-icons/react';

const ToastContext = createContext(null);

export const useToast = () => useContext(ToastContext);

export const ToastProvider = ({ children }) => {
  const [toasts, setToasts] = useState([]);

  const addToast = useCallback((msg, type = 'info') => {
    const id = Date.now();
    setToasts(prev => [...prev, { id, msg, type }]);
    setTimeout(() => setToasts(prev => prev.filter(t => t.id !== id)), 3500);
  }, []);

  const icons = { success: CheckCircle, error: XCircle, info: Info };

  return (
    <ToastContext.Provider value={addToast}>
      {children}
      <div className="toast-container">
        {toasts.map(({ id, msg, type }) => {
          const Icon = icons[type] || Info;
          return (
            <div key={id} className={`toast toast-${type}`}>
              <Icon size={20} weight="fill" style={{ flexShrink: 0, color: type === 'success' ? 'var(--success)' : type === 'error' ? 'var(--error)' : 'var(--brand-blue)' }} />
              {msg}
            </div>
          );
        })}
      </div>
    </ToastContext.Provider>
  );
};
