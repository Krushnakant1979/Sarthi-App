"use client";
import { useEffect, useState, useRef } from "react";
import { useAuth } from "@/context/AuthContext";
import { db } from "@/config/firebase";
import { collection, query, where, orderBy, onSnapshot } from "firebase/firestore";
import styles from "./rides.module.css";
import Link from "next/link";
import { useRouter } from "next/navigation";

export default function MyRides() {
  const { user, loading: authLoading } = useAuth();
  const [rides, setRides] = useState([]);
  const [loading, setLoading] = useState(true);
  const router = useRouter();

  const [activeFilter, setActiveFilter] = useState('all');
  const [filterDate, setFilterDate] = useState('');
  const [selectedRide, setSelectedRide] = useState(null);
  const datePickerRef = useRef(null);

  useEffect(() => {
    if (!authLoading && !user) {
      router.push("/login");
    }
  }, [user, authLoading, router]);

  useEffect(() => {
    if (!user?.uid) return;

    const ridesRef = collection(db, "ride_requests");
    const q = query(
      ridesRef, 
      where("userId", "==", user.uid),
      orderBy("createdAt", "desc")
    );

    const unsubscribe = onSnapshot(q, (querySnapshot) => {
      const fetchedRides = [];
      querySnapshot.forEach((doc) => {
        fetchedRides.push({ id: doc.id, ...doc.data() });
      });
      setRides(fetchedRides);
      setLoading(false);
    }, (error) => {
      console.error("Failed to fetch rides in real-time:", error);
      setLoading(false);
    });

    return () => unsubscribe();
  }, [user]);

  if (authLoading || loading) return <div className={styles.loader}>Loading your rides...</div>;

  // Stats Calculations
  const activeStatuses = ['searching', 'accepted', 'arriving', 'arrived', 'in_progress'];
  const totalRides = rides.length;
  const completedRides = rides.filter(r => r.status === 'completed').length;
  const cancelledRides = rides.filter(r => r.status === 'cancelled').length;
  const upcomingRides = rides.filter(r => activeStatuses.includes(r.status)).length;
  
  const successRate = totalRides ? Math.round((completedRides / totalRides) * 100) : 0;
  const cancelRate = totalRides ? Math.round((cancelledRides / totalRides) * 100) : 0;

  // Filters
  let filteredRides = rides.filter(ride => {
    if (filterDate) {
      if (!ride.createdAt) return false;
      const rideDate = ride.createdAt.toDate();
      const selected = new Date(filterDate);
      if (rideDate.getDate() !== selected.getDate() ||
          rideDate.getMonth() !== selected.getMonth() ||
          rideDate.getFullYear() !== selected.getFullYear()) {
        return false;
      }
    } else {
      if (activeFilter === 'today' && ride.createdAt) {
        const rideDate = ride.createdAt.toDate();
        const today = new Date();
        if (rideDate.getDate() !== today.getDate() ||
            rideDate.getMonth() !== today.getMonth() ||
            rideDate.getFullYear() !== today.getFullYear()) {
          return false;
        }
      }
    }

    if (activeFilter === 'upcoming') return activeStatuses.includes(ride.status);
    if (activeFilter === 'completed') return ride.status === 'completed';
    if (activeFilter === 'cancelled') return ride.status === 'cancelled';
    return true;
  });

  // Limit to last 30 trips if "All Rides" is selected and no date is chosen
  if (activeFilter === 'all' && !filterDate) {
    filteredRides = filteredRides.slice(0, 30);
  }


  return (
    <div className={styles.dashboard}>
      {/* Sidebar */}
      <aside className={styles.sidebar}>
        <Link href="/booking" className={styles.sidebarLink}>
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M19 17h2c.6 0 1-.4 1-1v-3c0-.9-.7-1.7-1.5-1.9C18.7 10.6 16 10 16 10s-1.3-1.4-2.2-2.3c-.5-.4-1.1-.7-1.8-.7H5c-.6 0-1.1.4-1.4.9l-1.4 2.9A3.7 3.7 0 0 0 2 12v4c0 .6.4 1 1 1h2"/><circle cx="7" cy="17" r="2"/><path d="M9 17h6"/><circle cx="17" cy="17" r="2"/></svg>
          Book a Ride
        </Link>
        <div className={`${styles.sidebarLink} ${styles.active}`}>
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
          My Rides
        </div>
        <div className={styles.sidebarLink}>
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><rect x="2" y="5" width="20" height="14" rx="2" ry="2"/><line x1="2" y1="10" x2="22" y2="10"/></svg>
          Wallet
        </div>
        <div className={styles.sidebarLink}>
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/></svg>
          Saved Places
        </div>
        
        <div className={styles.sidebarSpacer}></div>
        <div className={styles.sidebarLink}>
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M3 18v-6a9 9 0 0 1 18 0v6"/><path d="M21 19a2 2 0 0 1-2 2h-1a2 2 0 0 1-2-2v-3a2 2 0 0 1 2-2h3zM3 19a2 2 0 0 0 2 2h1a2 2 0 0 0 2-2v-3a2 2 0 0 0-2-2H3z"/></svg>
          Help & Support
        </div>
      </aside>

      {/* Main Content */}
      <main className={styles.mainContent}>
        
        {/* Header */}
        <div className={styles.header}>
          <div className={styles.headerText}>
            <h1 className={styles.title}>My Rides</h1>
            <p className={styles.subtitle}>Track and manage all your ride bookings</p>
          </div>
          <Link href="/booking" className={styles.bookBtn}>
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5"><line x1="12" y1="5" x2="12" y2="19"></line><line x1="5" y1="12" x2="19" y2="12"></line></svg>
            Book a New Ride
          </Link>
        </div>

        {/* Stats Grid */}
        <div className={styles.statsGrid}>
          <div className={`${styles.statCard} ${styles.blue}`}>
            <div className={styles.statIcon}>
              <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M19 17h2c.6 0 1-.4 1-1v-3c0-.9-.7-1.7-1.5-1.9C18.7 10.6 16 10 16 10s-1.3-1.4-2.2-2.3c-.5-.4-1.1-.7-1.8-.7H5c-.6 0-1.1.4-1.4.9l-1.4 2.9A3.7 3.7 0 0 0 2 12v4c0 .6.4 1 1 1h2"/><circle cx="7" cy="17" r="2"/><path d="M9 17h6"/><circle cx="17" cy="17" r="2"/></svg>
            </div>
            <div className={styles.statInfo}>
              <h3>{totalRides}</h3>
              <p>Total Rides</p>
              <span>Since you joined</span>
            </div>
          </div>
          
          <div className={`${styles.statCard} ${styles.green}`}>
            <div className={styles.statIcon}>
              <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg>
            </div>
            <div className={styles.statInfo}>
              <h3>{completedRides}</h3>
              <p>Completed</p>
              <span>{successRate}% success rate</span>
            </div>
          </div>
          
          <div className={`${styles.statCard} ${styles.red}`}>
            <div className={styles.statIcon}>
              <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><circle cx="12" cy="12" r="10"/><line x1="15" y1="9" x2="9" y2="15"/><line x1="9" y1="9" x2="15" y2="15"/></svg>
            </div>
            <div className={styles.statInfo}>
              <h3>{cancelledRides}</h3>
              <p>Cancelled</p>
              <span>{cancelRate}% cancellation</span>
            </div>
          </div>
        </div>

        {/* Filters */}
        <div className={styles.filterSection}>
          <div className={styles.filterTabs}>
            <button className={`${styles.filterBtn} ${activeFilter === 'all' ? styles.active : ''}`} onClick={() => setActiveFilter('all')}>All Rides</button>
            <button className={`${styles.filterBtn} ${activeFilter === 'today' ? styles.active : ''}`} onClick={() => setActiveFilter('today')}>Today&apos;s Rides</button>
            <button className={`${styles.filterBtn} ${activeFilter === 'completed' ? styles.active : ''}`} onClick={() => setActiveFilter('completed')}>Completed</button>
            <button className={`${styles.filterBtn} ${activeFilter === 'cancelled' ? styles.active : ''}`} onClick={() => setActiveFilter('cancelled')}>Cancelled</button>
          </div>
          
          <div 
            className={styles.datePickerBtn} 
            style={{ position: 'relative' }}
            onClick={() => datePickerRef.current?.showPicker()}
          >
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><rect x="3" y="4" width="18" height="18" rx="2" ry="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/></svg>
            {filterDate ? new Date(filterDate).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }) : 'Select Date'}
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><polyline points="6 9 12 15 18 9"/></svg>
            <input 
               ref={datePickerRef}
               type="date"
               value={filterDate}
               onChange={(e) => {
                 setFilterDate(e.target.value);
                 if (e.target.value) setActiveFilter('all');
               }}
               style={{ position: 'absolute', top: 0, left: 0, width: 0, height: 0, opacity: 0, pointerEvents: 'none' }}
            />
          </div>
        </div>

        {/* Rides List */}
        <div className={styles.ridesList} key={activeFilter}>
          {filteredRides.length === 0 ? (
            <div className={styles.emptyState}>
              <p>No rides found.</p>
              <Link href="/booking" className={styles.bookBtn}>Book a Ride</Link>
            </div>
          ) : (
            filteredRides.map((ride) => (
              <div key={ride.id} className={styles.rideCard}>
                
                <div className={styles.cardMain}>
                  <div className={styles.cardHeader}>
                    <div className={styles.dateBlock}>
                      <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round"><rect x="3" y="4" width="18" height="18" rx="2" ry="2"></rect><line x1="16" y1="2" x2="16" y2="6"></line><line x1="8" y1="2" x2="8" y2="6"></line><line x1="3" y1="10" x2="21" y2="10"></line></svg>
                      {ride.createdAt?.toDate().toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })}, {ride.createdAt?.toDate().toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' })}
                    </div>
                    
                    <div className={`${styles.statusPill} ${activeStatuses.includes(ride.status) ? styles.upcoming : styles[ride.status]}`}>
                      {activeStatuses.includes(ride.status) ? 'UPCOMING' : ride.status.toUpperCase()}
                    </div>
                  </div>
                  
                  <div className={styles.locations}>
                    <div className={styles.locRow}>
                      <div className={styles.dot}></div>
                      <span className={styles.address}>{ride.pickup?.address || 'Unknown Pickup'}</span>
                    </div>
                    <div className={styles.locLine}></div>
                    <div className={styles.locRow}>
                      <div className={styles.square}></div>
                      <span className={styles.address}>{ride.destination?.address || 'Unknown Destination'}</span>
                    </div>
                  </div>
                </div>

                <div className={styles.cardSidebar}>
                  <div className={styles.fareRow}>
                    <div className={styles.fareLabels}>
                      <span className={styles.fareTitle}>
                        {ride.status === 'completed' ? 'Fare Paid' : activeStatuses.includes(ride.status) ? 'Estimated Fare' : 'Fare'}
                      </span>
                      <div className={styles.vehiclePill}>
                        <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5"><path d="M19 17h2c.6 0 1-.4 1-1v-3c0-.9-.7-1.7-1.5-1.9C18.7 10.6 16 10 16 10s-1.3-1.4-2.2-2.3c-.5-.4-1.1-.7-1.8-.7H5c-.6 0-1.1.4-1.4.9l-1.4 2.9A3.7 3.7 0 0 0 2 12v4c0 .6.4 1 1 1h2"/><circle cx="7" cy="17" r="2"/><path d="M9 17h6"/><circle cx="17" cy="17" r="2"/></svg>
                        {ride.vehicleType?.toUpperCase() || 'CAB'}
                      </div>
                    </div>
                    <div className={styles.fareAmount}>₹{ride.fareEstimate}</div>
                  </div>
                  
                  {activeStatuses.includes(ride.status) ? (
                    <Link href="/booking" className={`${styles.actionBtn} ${styles.btnSolid}`}>
                      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5"><circle cx="12" cy="12" r="10"/><circle cx="12" cy="12" r="3"/></svg>
                      Track Ride
                    </Link>
                  ) : (
                    <button className={`${styles.actionBtn} ${styles.btnOutline}`} onClick={() => setSelectedRide(ride)}>
                      View Details &rarr;
                    </button>
                  )}
                </div>

              </div>
            ))
          )}
        </div>
      </main>

      {/* Ride Details Modal */}
      {selectedRide && (
        <div className={styles.modalOverlay} onClick={() => setSelectedRide(null)}>
          <div className={styles.modalContent} onClick={e => e.stopPropagation()}>
            <div className={styles.modalHeader}>
              <h2>Ride Details</h2>
              <button className={styles.closeBtn} onClick={() => setSelectedRide(null)}>
                <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line></svg>
              </button>
            </div>
            <div className={styles.modalBody}>
              <div className={styles.modalDetailRow}>
                <span className={styles.modalDetailLabel}>Status</span>
                <span className={`${styles.statusPill} ${styles[selectedRide.status]}`}>
                  {selectedRide.status?.toUpperCase()}
                </span>
              </div>
              <div className={styles.modalDetailRow}>
                <span className={styles.modalDetailLabel}>Date & Time</span>
                <span className={styles.modalDetailValue}>
                  {selectedRide.createdAt?.toDate().toLocaleString('en-US', { month: 'short', day: 'numeric', year: 'numeric', hour: '2-digit', minute: '2-digit' })}
                </span>
              </div>
              <div className={styles.modalDetailRow}>
                <span className={styles.modalDetailLabel}>Pickup</span>
                <span className={styles.modalDetailValue}>{selectedRide.pickup?.address}</span>
              </div>
              <div className={styles.modalDetailRow}>
                <span className={styles.modalDetailLabel}>Dropoff</span>
                <span className={styles.modalDetailValue}>{selectedRide.destination?.address}</span>
              </div>
              <div className={styles.modalDetailRow}>
                <span className={styles.modalDetailLabel}>Vehicle Type</span>
                <span className={styles.modalDetailValue}>{selectedRide.vehicleType?.toUpperCase() || 'CAB'}</span>
              </div>
              <div className={styles.modalDetailRow}>
                <span className={styles.modalDetailLabel}>Fare</span>
                <span className={styles.modalDetailValue}>₹{selectedRide.fareEstimate}</span>
              </div>
              <div className={styles.modalDetailRow} style={{ marginTop: '16px' }}>
                <button className={`${styles.actionBtn} ${styles.btnSolid}`} onClick={() => setSelectedRide(null)}>
                  Close
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
