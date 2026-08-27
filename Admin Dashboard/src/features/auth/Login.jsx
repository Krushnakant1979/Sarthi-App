import React, { useState } from 'react';
import { signInWithEmailAndPassword } from 'firebase/auth';
import { auth, db } from '../../config/firebase';
import { doc, getDoc } from 'firebase/firestore';
import { ShieldCheck, LockKey, EnvelopeSimple, Eye, EyeSlash } from '@phosphor-icons/react';

const Login = ({ onLogin }) => {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const handleLogin = async (e) => {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      const userCredential = await signInWithEmailAndPassword(auth, email, password);
      const userDoc = await getDoc(doc(db, 'users', userCredential.user.uid));
      if (userDoc.exists() && userDoc.data().role === 'admin') {
        onLogin(userCredential.user);
      } else {
        await auth.signOut();
        setError('Access denied. This account does not have administrator privileges.');
      }
    } catch {
      setError('Invalid email or password. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="login-page animate-fade-in">
      {/* Left Panel */}
      <div className="login-panel">
        <div className="login-panel-inner">
          <div className="login-logo">S</div>

          <h1 className="login-title">Welcome back</h1>
          <p className="login-subtitle">Sign in to Sarthi Admin Console</p>

          {error && (
            <div className="login-error">{error}</div>
          )}

          <form onSubmit={handleLogin} style={{ display: 'flex', flexDirection: 'column', gap: '1.125rem' }}>
            <div className="form-group">
              <label className="form-label">Email Address</label>
              <div style={{ position: 'relative' }}>
                <EnvelopeSimple
                  size={18}
                  style={{ position: 'absolute', left: '0.875rem', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)', pointerEvents: 'none' }}
                />
                <input
                  type="email"
                  required
                  value={email}
                  onChange={e => setEmail(e.target.value)}
                  placeholder="admin@sarthi.com"
                  className="form-input"
                  style={{ paddingLeft: '2.5rem' }}
                />
              </div>
            </div>

            <div className="form-group">
              <label className="form-label">Password</label>
              <div style={{ position: 'relative' }}>
                <LockKey
                  size={18}
                  style={{ position: 'absolute', left: '0.875rem', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)', pointerEvents: 'none' }}
                />
                <input
                  type={showPassword ? 'text' : 'password'}
                  required
                  value={password}
                  onChange={e => setPassword(e.target.value)}
                  placeholder="••••••••"
                  className="form-input"
                  style={{ paddingLeft: '2.5rem', paddingRight: '2.75rem' }}
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(v => !v)}
                  style={{ position: 'absolute', right: '0.875rem', top: '50%', transform: 'translateY(-50%)', background: 'none', border: 'none', cursor: 'pointer', color: 'var(--text-muted)', padding: 0 }}
                >
                  {showPassword ? <EyeSlash size={18} /> : <Eye size={18} />}
                </button>
              </div>
            </div>

            <button
              type="submit"
              className="btn btn-primary"
              disabled={loading}
              style={{ width: '100%', padding: '0.875rem', marginTop: '0.5rem', fontSize: '0.9375rem', borderRadius: 'var(--r-md)' }}
            >
              {loading ? (
                <span style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                  <span className="spinner" style={{ width: 16, height: 16 }}></span>
                  Signing in...
                </span>
              ) : 'Sign In to Dashboard'}
            </button>
          </form>

          <p style={{ marginTop: '1.5rem', fontSize: '0.8125rem', color: 'var(--text-muted)', textAlign: 'center' }}>
            Protected by Firebase Authentication. Admin access only.
          </p>
        </div>
      </div>

      {/* Right Hero Panel */}
      <div className="login-hero">
        <div className="login-hero-content">
          <div className="login-hero-badge">
            <ShieldCheck size={14} weight="fill" />
            Admin Console v2.0
          </div>
          <h2 className="login-hero-title">
            Sarthi<br />Admin Dashboard
          </h2>
          <p className="login-hero-desc">
            Manage your entire ride-hailing platform in one place — captains, users, rides, fares, and promotions.
          </p>
          <div className="login-hero-stats">
            <div className="hero-stat">
              <div className="hero-stat-value">Live</div>
              <div className="hero-stat-label">Firebase Data</div>
            </div>
            <div className="hero-stat">
              <div className="hero-stat-value">5+</div>
              <div className="hero-stat-label">Modules</div>
            </div>
            <div className="hero-stat">
              <div className="hero-stat-value">24/7</div>
              <div className="hero-stat-label">Monitoring</div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Login;
