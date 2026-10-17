import React, { useState, useRef, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { Bell, MagnifyingGlass, SteeringWheel, ArrowLeft, SignOut, List, Sun, Moon, WarningCircle, ShieldWarning } from '@phosphor-icons/react';
import { auth } from '../../config/firebase';
import { signOut } from 'firebase/auth';
import { useNotifications } from '../../context/NotificationContext';
import { useTheme } from '../../context/ThemeContext';
import { CaptainVerifyModal } from '../../features/captains/components/CaptainVerifyModal';
import { AdminProfileModal } from './AdminProfileModal';

export const Topbar = ({ toggleMobileMenu }) => {
  const user = auth.currentUser;
  const initials = user?.email ? user.email.charAt(0).toUpperCase() : 'A';
  const { notifications, count, hasEmergency } = useNotifications();
  const { theme, toggleTheme } = useTheme();
  const navigate = useNavigate();

  const [panelOpen, setPanelOpen] = useState(false);
  const [profileOpen, setProfileOpen] = useState(false);
  const [selectedCaptain, setSelectedCaptain] = useState(null);
  const [searchQuery, setSearchQuery] = useState('');
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

  const handleSearchKeyDown = (e) => {
    if (e.key === 'Enter' && searchQuery.trim()) {
      const q = searchQuery.trim();
      if (q.toUpperCase().startsWith('RIDE-') || q.startsWith('ride_')) {
        navigate(`/rides?search=${encodeURIComponent(q)}`);
      } else {
        navigate(`/users?search=${encodeURIComponent(q)}`);
      }
    }
  };

  const handleNotifClick = (notif) => {
    if (notif.type === 'captain_pending') {
      setSelectedCaptain(notif.data);
      setPanelOpen(false);
    } else if (notif.type === 'emergency_sos') {
      const rideId = notif.data?.rideId || '';
      navigate(`/rides?search=${encodeURIComponent(rideId)}&emergency=true`);
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
            <input 
              type="text" 
              placeholder="Search rides, users, captains (Press Enter)..." 
              value={searchQuery}
              onChange={e => setSearchQuery(e.target.value)}
              onKeyDown={handleSearchKeyDown}
            />
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
              style={hasEmergency ? { borderColor: 'var(--error)', color: 'var(--error)' } : {}}
            >
              <Bell size={18} weight={count > 0 ? 'fill' : 'regular'} />
              {count > 0 && (
                <span 
                  className={`notif-dot badge-pulse`} 
                  style={hasEmergency ? { background: 'var(--error)', boxShadow: '0 0 10px rgba(220, 38, 38, 0.8)' } : {}}
                />
              )}
            </button>

            {/* Notification Panel */}
            {panelOpen && (
              <div ref={panelRef} className="notif-panel">
                <div className="notif-panel-header" style={hasEmergency ? { background: 'rgba(220, 38, 38, 0.1)', borderBottom: '1px solid rgba(220, 38, 38, 0.2)' } : {}}>
                  <span className="notif-panel-title">
                    {hasEmergency ? '🚨 Emergency & Operations' : 'Notifications'}
                  </span>
                  {count > 0 && (
                    <span className={`badge ${hasEmergency ? 'badge-error' : 'badge-warning'}`}>
                      {count} pending
                    </span>
                  )}
                </div>

                {notifications.length === 0 ? (
                  <div className="notif-empty">No pending alerts or captain registrations</div>
                ) : (
                  notifications.map(notif => (
                    <div
                      key={notif.id}
                      className={`notif-item unread ${notif.priority === 'emergency' ? 'emergency-item' : ''}`}
                      onClick={() => handleNotifClick(notif)}
                      style={notif.priority === 'emergency' ? {
                        background: 'rgba(220, 38, 38, 0.08)',
                        borderLeft: '3px solid var(--error)'
                      } : {}}
                    >
                      <div 
                        className="notif-icon" 
                        style={{ 
                          background: notif.priority === 'emergency' ? 'rgba(220, 38, 38, 0.15)' : 'var(--warning-bg)' 
                        }}
                      >
                        {notif.priority === 'emergency' ? (
                          <ShieldWarning size={18} weight="fill" style={{ color: 'var(--error)' }} />
                        ) : (
                          <SteeringWheel size={18} weight="bold" style={{ color: 'var(--warning)' }} />
                        )}
                      </div>
                      <div style={{ flex: 1, minWidth: 0 }}>
                        <div 
                          className="notif-item-title" 
                          style={notif.priority === 'emergency' ? { color: 'var(--error)', fontWeight: 800 } : {}}
                        >
                          {notif.title}
                        </div>
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
          <div 
            className="user-chip" 
            onClick={() => setProfileOpen(true)}
            style={{ cursor: 'pointer' }}
            title="View Admin Profile & Security"
          >
            <div className="user-avatar">{initials}</div>
            <div className="user-chip-info">
              <span className="user-chip-name">{user?.email?.split('@')[0] || 'Admin'}</span>
              <span className="user-chip-role">Super Admin</span>
            </div>
          </div>
        </div>
      </header>

      {/* Admin Profile Modal */}
      {profileOpen && (
        <AdminProfileModal onClose={() => setProfileOpen(false)} />
      )}

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
