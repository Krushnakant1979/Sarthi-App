import React, { useState, useRef, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { Bell, MagnifyingGlass, SteeringWheel, ArrowLeft, SignOut, List, Sun, Moon } from '@phosphor-icons/react';
import { auth } from '../../config/firebase';
import { signOut } from 'firebase/auth';
import { useNotifications } from '../../context/NotificationContext';
import { useTheme } from '../../context/ThemeContext';
import { CaptainVerifyModal } from '../../features/captains/components/CaptainVerifyModal';

export const Topbar = ({ toggleMobileMenu }) => {
  const user = auth.currentUser;
  const initials = user?.email ? user.email.charAt(0).toUpperCase() : 'A';
  const { notifications, count } = useNotifications();
  const { theme, toggleTheme } = useTheme();
  const navigate = useNavigate();

  const [panelOpen, setPanelOpen] = useState(false);
  const [selectedCaptain, setSelectedCaptain] = useState(null);
  const bellRef = useRef(null);
  const panelRef = useRef(null);

  // Close panel when clicking outside
  useEffect(() => {
    const handler = (e) => {
      if (panelRef.current && !panelRef.current.contains(e.target) && !bellRef.current.contains(e.target)) {
        setPanelOpen(false);
      }
    };
    document.addEventListener('mousedown', handler);
    return () => document.removeEventListener('mousedown', handler);
  }, []);

  const handleNotifClick = (notif) => {
    if (notif.type === 'captain_pending') {
      setSelectedCaptain(notif.data);
      setPanelOpen(false);
    }
  };

  const formatTime = (ts) => {
    if (!ts) return '';
    const date = ts.toDate ? ts.toDate() : new Date(ts);
    return date.toLocaleDateString('en-IN', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' });
  };

  return (
    <>
      <header className="topbar">
        <div style={{ display: 'flex', alignItems: 'center', gap: '1rem', flex: 1 }}>
          <button 
            className="mobile-menu-btn" 
            onClick={toggleMobileMenu}
            title="Menu"
          >
            <List size={24} />
          </button>
          
          <button 
            onClick={() => navigate(-1)} 
            className="btn btn-icon" 
            style={{ width: 36, height: 36, border: '1px solid var(--border)', background: 'var(--surface-1)', color: 'var(--text-secondary)', display: 'flex', alignItems: 'center', justifyContent: 'center', borderRadius: 'var(--r-md)' }}
            title="Go Back"
          >
            <ArrowLeft size={18} weight="bold" />
          </button>
          
          <div className="topbar-search" style={{ flex: 1, maxWidth: '400px' }}>
            <MagnifyingGlass size={16} className="topbar-search-icon" />
            <input type="text" placeholder="Search captains, rides, users..." />
          </div>
        </div>

        <div className="topbar-right">
          {/* Theme Toggle */}
          <button
            className="topbar-icon-btn"
            title="Toggle Theme"
            onClick={toggleTheme}
          >
            {theme === 'dark' ? <Sun size={18} /> : <Moon size={18} />}
          </button>

          {/* Notification Bell */}
          <div style={{ position: 'relative' }}>
            <button
              ref={bellRef}
              className="topbar-icon-btn"
              title={`${count} pending notifications`}
              onClick={() => setPanelOpen(v => !v)}
            >
              <Bell size={18} weight={count > 0 ? 'fill' : 'regular'} />
              {count > 0 && <span className="notif-dot badge-pulse"></span>}
            </button>

            {/* Notification Panel */}
            {panelOpen && (
              <div ref={panelRef} className="notif-panel">
                <div className="notif-panel-header">
                  <span className="notif-panel-title">Notifications</span>
                  {count > 0 && <span className="badge badge-error">{count} pending</span>}
                </div>

                {notifications.length === 0 ? (
                  <div className="notif-empty">No pending captain registrations</div>
                ) : (
                  notifications.map(notif => (
                    <div
                      key={notif.id}
                      className="notif-item unread"
                      onClick={() => handleNotifClick(notif)}
                    >
                      <div className="notif-icon" style={{ background: 'var(--warning-bg)' }}>
                        <SteeringWheel size={18} weight="bold" style={{ color: 'var(--warning)' }} />
                      </div>
                      <div style={{ flex: 1, minWidth: 0 }}>
                        <div className="notif-item-title">{notif.title}</div>
                        <div className="notif-item-desc">{notif.desc}</div>
                        <div className="notif-item-time">{formatTime(notif.time)}</div>
                      </div>
                    </div>
                  ))
                )}
              </div>
            )}
          </div>

          {/* Sign Out Button */}
          <button 
            className="topbar-icon-btn" 
            title="Sign Out"
            onClick={() => signOut(auth)}
            style={{ color: 'var(--error)' }}
          >
            <SignOut size={18} weight="bold" />
          </button>

          {/* User Chip */}
          <div className="user-chip">
            <div className="user-avatar">{initials}</div>
            <div className="user-chip-info">
              <span className="user-chip-name">{user?.email?.split('@')[0] || 'Admin'}</span>
              <span className="user-chip-role">Super Admin</span>
            </div>
          </div>
        </div>
      </header>

      {/* Captain Verify Modal triggered from notification */}
      {selectedCaptain && (
        <CaptainVerifyModal
          captain={selectedCaptain}
          onClose={() => setSelectedCaptain(null)}
        />
      )}
    </>
  );
};
