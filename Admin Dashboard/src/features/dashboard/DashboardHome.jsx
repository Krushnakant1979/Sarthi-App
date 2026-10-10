import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { db } from '../../config/firebase';
import { collection, onSnapshot, query, where, orderBy, limit } from 'firebase/firestore';
import {
  Car, Users, CurrencyInr, SteeringWheel,
  Gear, Tag, ChartLineUp
} from '@phosphor-icons/react';
import { DashboardStatCard } from './components/DashboardStatCard';
import { RecentRidesTable } from './components/RecentRidesTable';
import { PlatformHealthCard } from './components/PlatformHealthCard';

const calculateSparkline = (docs, valueExtractor = () => 1) => {
  const now = new Date();
  const res = Array.from({ length: 7 }, () => 0);
  docs.forEach(doc => {
    const data = doc.data();
    if (!data.createdAt) return;
    let createdAt = data.createdAt.toDate ? data.createdAt.toDate() : new Date(data.createdAt.seconds ? data.createdAt.seconds * 1000 : data.createdAt);
    if (isNaN(createdAt.getTime())) return;
    const diffTime = Math.abs(now - createdAt);
    const diffDays = Math.floor(diffTime / (1000 * 60 * 60 * 24));
    if (diffDays < 7) {
      res[6 - diffDays] += valueExtractor(data);
    }
  });
  return res.map(val => ({ val }));
};

const statCards = [
  {
    key: 'rides',
    label: 'Total Rides',
    icon: Car,
    accent: '#1565C0',
    iconBg: 'rgba(21,101,192,0.1)',
    format: (v) => v.toLocaleString(),
    tag: 'All Time',
  },
  {
    key: 'captains',
    label: 'Total Captains',
    icon: SteeringWheel,
    accent: '#00A6A6',
    iconBg: 'rgba(0,166,166,0.1)',
    format: (v) => v.toLocaleString(),
    tag: 'Registered',
  },
  {
    key: 'users',
    label: 'Total Users',
    icon: Users,
    accent: '#7C3AED',
    iconBg: 'rgba(124,58,237,0.1)',
    format: (v) => v.toLocaleString(),
    tag: 'Passengers',
  },
  {
    key: 'revenue',
    label: 'Total Revenue',
    icon: CurrencyInr,
    accent: '#D97706',
    iconBg: 'rgba(217,119,6,0.1)',
    format: (v) => `₹${v.toLocaleString(undefined, { minimumFractionDigits: 0, maximumFractionDigits: 0 })}`,
    tag: 'Completed',
  },
];

const calculateTrend = (docs, valueExtractor = () => 1) => {
  const now = new Date();
  const oneWeekAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
  const twoWeeksAgo = new Date(now.getTime() - 14 * 24 * 60 * 60 * 1000);

  let current = 0;
  let previous = 0;

  docs.forEach(doc => {
    const data = doc.data();
    if (!data.createdAt) return;
    
    let createdAt;
    if (data.createdAt.toDate) {
      createdAt = data.createdAt.toDate();
    } else if (data.createdAt.seconds) {
      createdAt = new Date(data.createdAt.seconds * 1000);
    } else {
      createdAt = new Date(data.createdAt);
    }

    if (isNaN(createdAt.getTime())) return;

    const val = valueExtractor(data);

    if (createdAt >= oneWeekAgo) {
      current += val;
    } else if (createdAt >= twoWeeksAgo && createdAt < oneWeekAgo) {
      previous += val;
    }
  });

  if (previous === 0) {
    if (current > 0) return 100;
    return 0;
  }

  return Math.round(((current - previous) / previous) * 100);
};

const DashboardHome = () => {
  const navigate = useNavigate();
  const [stats, setStats] = useState({ rides: 0, captains: 0, activeCaptains: 0, users: 0, revenue: 0 });
  const [trends, setTrends] = useState({ rides: 0, captains: 0, users: 0, revenue: 0 });
  const [sparklines, setSparklines] = useState({
    rides: Array.from({ length: 7 }, () => ({ val: 0 })),
    captains: Array.from({ length: 7 }, () => ({ val: 0 })),
    users: Array.from({ length: 7 }, () => ({ val: 0 })),
    revenue: Array.from({ length: 7 }, () => ({ val: 0 }))
  });
  const [loading, setLoading] = useState(true);
  const [dbStatus, setDbStatus] = useState('checking');
  const [recentRides, setRecentRides] = useState([]);

  useEffect(() => {
    let currentStats = { rides: 0, captains: 0, activeCaptains: 0, users: 0, revenue: 0 };
    let currentTrends = { rides: 0, captains: 0, users: 0, revenue: 0 };
    let currentSparklines = { ...sparklines };
    
    const updateUI = () => {
      setStats({ ...currentStats });
      setTrends({ ...currentTrends });
      setSparklines({ ...currentSparklines });
      setDbStatus('connected');
      setLoading(false);
    };

    const unsubCaptains = onSnapshot(query(collection(db, 'users'), where('role', '==', 'captain')), (snap) => {
      let active = 0;
      snap.forEach(doc => { if (doc.data().isOnline) active++; });
      currentStats.captains = snap.size;
      currentStats.activeCaptains = active;
      currentTrends.captains = calculateTrend(snap.docs);
      currentSparklines.captains = calculateSparkline(snap.docs);
      updateUI();
    }, (err) => { setDbStatus('error'); console.error(err); });

    const unsubUsers = onSnapshot(query(collection(db, 'users'), where('role', '==', 'user')), (snap) => {
      currentStats.users = snap.size;
      currentTrends.users = calculateTrend(snap.docs);
      currentSparklines.users = calculateSparkline(snap.docs);
      updateUI();
    }, (err) => console.error(err));

    const unsubRides = onSnapshot(query(collection(db, 'ride_requests'), orderBy('createdAt', 'desc'), limit(500)), (snap) => {
      let rev = 0;
      let rList = [];
      snap.forEach(doc => {
        const d = doc.data();
        if (d.status === 'completed' && d.fareEstimate) rev += Number(d.fareEstimate);
        rList.push({ id: doc.id, ...d });
      });
      currentStats.rides = snap.size; 
      currentStats.revenue = rev;
      
      currentTrends.rides = calculateTrend(snap.docs);
      currentTrends.revenue = calculateTrend(snap.docs, (d) => (d.status === 'completed' && d.fareEstimate) ? Number(d.fareEstimate) : 0);
      
      currentSparklines.rides = calculateSparkline(snap.docs);
      currentSparklines.revenue = calculateSparkline(snap.docs, (d) => (d.status === 'completed' && d.fareEstimate) ? Number(d.fareEstimate) : 0);
      
      setRecentRides(rList.slice(0, 5));
      updateUI();
    }, (err) => console.error(err));

    return () => {
      unsubCaptains();
      unsubUsers();
      unsubRides();
    };
  }, []);

  return (
    <div style={{ paddingBottom: '2rem' }}>
      
      {/* 1. Premium Welcome Banner */}
      <div className="animate-fade-up stagger-1" style={{ 
        background: 'linear-gradient(135deg, var(--brand-primary) 0%, #1a365d 100%)',
        borderRadius: 'var(--r-xl)',
        padding: '2.5rem 3rem',
        color: 'white',
        marginBottom: '2rem',
        boxShadow: 'var(--shadow-md)',
        display: 'flex',
        justifyContent: 'space-between',
        alignItems: 'center',
        position: 'relative',
        overflow: 'hidden'
      }}>
        {/* Decorative background element */}
        <div className="animate-float" style={{ position: 'absolute', right: '-5%', top: '-20%', width: '300px', height: '300px', background: 'radial-gradient(circle, rgba(255,255,255,0.1) 0%, rgba(255,255,255,0) 70%)', borderRadius: '50%' }}></div>
        
        <div style={{ position: 'relative', zIndex: 1 }}>
          <h1 style={{ fontSize: '2rem', fontWeight: 800, margin: 0, letterSpacing: '-0.03em' }}>
            Welcome back to Sarthi
          </h1>
          <p style={{ color: 'rgba(255,255,255,0.7)', fontSize: '1rem', marginTop: '0.5rem' }}>
            Here is what's happening across your platform today.
          </p>
        </div>
        
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', background: 'rgba(255,255,255,0.1)', padding: '0.75rem 1.25rem', borderRadius: 'var(--r-full)', backdropFilter: 'blur(10px)', border: '1px solid rgba(255,255,255,0.2)' }}>
          <div className={`status-dot ${dbStatus === 'connected' ? 'online' : dbStatus === 'error' ? 'error' : 'warning'}`} style={{ width: 10, height: 10, animation: dbStatus === 'connected' ? 'pulseGlow 2s infinite' : 'none' }}></div>
          <span style={{ fontSize: '0.875rem', fontWeight: 600 }}>
            {dbStatus === 'connected' ? 'Systems Operational' : 'Connecting...'}
          </span>
        </div>
      </div>

      {/* 2. Quick Actions */}
      <div className="animate-fade-up stagger-2" style={{ display: 'flex', gap: '1rem', marginBottom: '2rem' }}>
        <button onClick={() => navigate('/settings')} className="btn btn-secondary" style={{ flex: 1, padding: '1rem', background: 'var(--surface-1)', border: '1px solid var(--border)', borderRadius: 'var(--r-md)' }}>
          <Gear size={20} style={{ color: 'var(--brand-blue)' }} /> Configure Pricing
        </button>
        <button onClick={() => navigate('/offers')} className="btn btn-secondary" style={{ flex: 1, padding: '1rem', background: 'var(--surface-1)', border: '1px solid var(--border)', borderRadius: 'var(--r-md)' }}>
          <Tag size={20} style={{ color: 'var(--warning)' }} /> Create Offer
        </button>
        <button onClick={() => navigate('/analytics')} className="btn btn-secondary" style={{ flex: 1, padding: '1rem', background: 'var(--surface-1)', border: '1px solid var(--border)', borderRadius: 'var(--r-md)' }}>
          <ChartLineUp size={20} style={{ color: 'var(--brand-teal)' }} /> View Analytics
        </button>
      </div>

      {/* 3. Upgraded Stat Cards with Sparklines */}
      <div className="animate-fade-up stagger-3" style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: '1.5rem', marginBottom: '2.5rem' }}>
        {statCards.map((card) => (
          <DashboardStatCard 
            key={card.key}
            {...card}
            value={stats[card.key]}
            trendPercentage={trends[card.key]}
            trendData={sparklines[card.key]}
            loading={loading}
          />
        ))}
      </div>

      {/* 4. Split Layout */}
      <div className="animate-fade-up stagger-4" style={{ display: 'grid', gridTemplateColumns: '2fr 1fr', gap: '2rem', alignItems: 'start' }}>
        
        {/* Left: Recent Rides */}
        <RecentRidesTable 
          rides={recentRides} 
          loading={loading} 
          onNavigateToRides={() => navigate('/rides')} 
        />

        {/* Right: Platform Health */}
        <PlatformHealthCard 
          dbStatus={dbStatus} 
          activeCaptains={stats.activeCaptains} 
        />

      </div>
    </div>
  );
};

export default DashboardHome;
