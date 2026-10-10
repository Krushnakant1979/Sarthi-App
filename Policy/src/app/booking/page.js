"use client";
import { useEffect, useState, Suspense, useRef } from "react";
import { useAuth } from "@/context/AuthContext";
import { useRouter, useSearchParams } from "next/navigation";
import dynamic from "next/dynamic";
import { db, rtdb } from "@/config/firebase";
import { collection, addDoc, doc, updateDoc, serverTimestamp, onSnapshot, getDoc } from "firebase/firestore";
import { ref, onValue, get as rtdbGet } from "firebase/database";
import { geocode, getDirections, decodePolyline, autocomplete } from "@/lib/olamaps";

function calculateDistance(lat1, lon1, lat2, lon2) {
  const p = Math.PI / 180;
  const a = 0.5 - Math.cos((lat2 - lat1) * p) / 2 + 
            Math.cos(lat1 * p) * Math.cos(lat2 * p) * 
            (1 - Math.cos((lon2 - lon1) * p)) / 2;
  return 12742 * Math.asin(Math.sqrt(a)) * 1000;
}
import { FARE_RULES, calculateFare } from "@/lib/fare";
import styles from "./booking.module.css";

const OlaMap = dynamic(() => import("@/components/OlaMap"), {
  ssr: false,
  loading: () => <div className={styles.loader}>Initializing map...</div>
});

function BookingContent() {
  const { user, loading: authLoading, activeRideId } = useAuth();
  const router = useRouter();
  const searchParams = useSearchParams();

  const [pickup, setPickup] = useState("");
  const [drop, setDrop] = useState("");
  
  // Ride Selection State
  const [loadingRides, setLoadingRides] = useState(false);
  const [rideOptions, setRideOptions] = useState([]);
  const [selectedRide, setSelectedRide] = useState(null);
  const [routeData, setRouteData] = useState(null);
  
  // Booking Status State
  const [bookingStatus, setBookingStatus] = useState(null); // 'searching', 'accepted', 'arriving', 'in_progress', 'completed'
  const [currentRideId, setCurrentRideId] = useState(null);
  
  // Active Ride Tracking State
  const [activeRide, setActiveRide] = useState(null);
  const [captainData, setCaptainData] = useState(null);
  const [captainLocation, setCaptainLocation] = useState(null);

  useEffect(() => {
    if (activeRideId && !currentRideId) {
      const timeout = setTimeout(() => {
        setCurrentRideId(activeRideId);
      }, 0);
      return () => clearTimeout(timeout);
    }
  }, [activeRideId, currentRideId]);

  // Autocomplete State
  const [pickupSuggestions, setPickupSuggestions] = useState([]);
  const [showPickupSuggestions, setShowPickupSuggestions] = useState(false);
  const isSelectingPickup = useRef(false);

  useEffect(() => {
    const fetchSuggestions = async () => {
      if (isSelectingPickup.current) {
        isSelectingPickup.current = false;
        return;
      }
      if (pickup.trim().length > 2) {
        const results = await autocomplete(pickup);
        setPickupSuggestions(results);
      } else {
        setPickupSuggestions([]);
      }
    };

    const debounceId = setTimeout(() => {
      fetchSuggestions();
    }, 400);

    return () => clearTimeout(debounceId);
  }, [pickup]);

  const handlePickupSelect = (description) => {
    isSelectingPickup.current = true;
    setPickup(description);
    setShowPickupSuggestions(false);
  };

  const [dropSuggestions, setDropSuggestions] = useState([]);
  const [showDropSuggestions, setShowDropSuggestions] = useState(false);
  const isSelectingDrop = useRef(false);

  useEffect(() => {
    const fetchDropSuggestions = async () => {
      if (isSelectingDrop.current) {
        isSelectingDrop.current = false;
        return;
      }
      if (drop.trim().length > 2) {
        const results = await autocomplete(drop);
        setDropSuggestions(results);
      } else {
        setDropSuggestions([]);
      }
    };

    const debounceId = setTimeout(() => {
      fetchDropSuggestions();
    }, 400);

    return () => clearTimeout(debounceId);
  }, [drop]);

  const handleDropSelect = (description) => {
    isSelectingDrop.current = true;
    setDrop(description);
    setShowDropSuggestions(false);
  };

  useEffect(() => {
    if (!authLoading && !user) {
      router.push("/login");
    }
  }, [user, authLoading, router]);

  useEffect(() => {
    const p = searchParams.get("pickup");
    const d = searchParams.get("drop");
    const timeout = setTimeout(() => {
      if (p) setPickup(p);
      if (d) setDrop(d);
    }, 0);
    return () => clearTimeout(timeout);
  }, [searchParams]);

  // Firestore Snapshot Listener for Live Tracking
  useEffect(() => {
    if (!currentRideId) return;
    
    const unsubscribe = onSnapshot(doc(db, "ride_requests", currentRideId), async (snapshot) => {
      if (snapshot.exists()) {
        const data = snapshot.data();
        setActiveRide(data);
        setBookingStatus(data.status);
        
        // If captain assigned, fetch their data once
        if (data.assignedCaptainId && !captainData) {
          try {
            const capDoc = await getDoc(doc(db, "users", data.assignedCaptainId));
            if (capDoc.exists()) setCaptainData(capDoc.data());
          } catch (err) {
            console.error("Failed to fetch captain data", err);
          }
        }
        
        // Clear captain data and location if no captain is assigned anymore
        if (!data.assignedCaptainId) {
          setCaptainData(null);
          setCaptainLocation(null);
        }
      }
    });
    
    return () => unsubscribe();
  }, [currentRideId, captainData]);

  // RTDB Listener for Live Captain Location
  useEffect(() => {
    if (!activeRide?.assignedCaptainId) return;
    if (activeRide.status === 'completed' || activeRide.status === 'cancelled') return;

    const locRef = ref(rtdb, `live/captains/${activeRide.assignedCaptainId}`);
    const unsubscribe = onValue(locRef, (snapshot) => {
      if (snapshot.exists()) {
        const loc = snapshot.val();
        if (loc.lat && loc.lng) {
          setCaptainLocation([loc.lng, loc.lat]); // MapLibre needs [lng, lat]
        }
      } else if (!captainLocation && activeRide.pickup) {
        // Fallback: If no live location is available yet, default to slightly offset from pickup
        setCaptainLocation([activeRide.pickup.lng - 0.001, activeRide.pickup.lat - 0.001]);
      }
    });

    return () => unsubscribe();
  }, [activeRide?.assignedCaptainId, activeRide?.status, activeRide?.pickup]);

  // Restore route polyline if missing on page reload
  useEffect(() => {
    if (activeRide?.pickup && activeRide?.destination && !routeData) {
      const restoreRoute = async () => {
        try {
          const dir = await getDirections(
            activeRide.pickup.lat, 
            activeRide.pickup.lng, 
            activeRide.destination.lat, 
            activeRide.destination.lng
          );
          if (dir) {
            const pts = decodePolyline(dir.polyline);
            setRouteData({ 
              points: pts, 
              pickup: activeRide.pickup, 
              drop: activeRide.destination 
            });
          }
        } catch (err) {
          console.error("Failed to restore route line:", err);
        }
      };
      restoreRoute();
    }
  }, [activeRide, routeData]);


  const handleFindRides = async () => {
    if (!pickup || !drop) return alert("Please enter both pickup and destination");
    setLoadingRides(true);
    
    try {
      const pLoc = await geocode(pickup);
      const dLoc = await geocode(drop);
      
      if (!pLoc || !dLoc) {
        alert("Could not find locations. Try being more specific.");
        setLoadingRides(false);
        return;
      }
      
      const dir = await getDirections(pLoc.lat, pLoc.lng, dLoc.lat, dLoc.lng);
      if (!dir) {
        alert("Could not find a route between these locations.");
        setLoadingRides(false);
        return;
      }
      
      const pts = decodePolyline(dir.polyline);
      setRouteData({ points: pts, pickup: pLoc, drop: dLoc, distance: dir.distanceMeters, duration: dir.durationSeconds });
      
      // Fetch dynamic fare rules from Firestore to ensure exact parity with mobile app
      const rules = { bike: FARE_RULES.bike, auto: FARE_RULES.auto, cab: FARE_RULES.cab, parcel: FARE_RULES.parcel };
      try {
        for (const type of ['bike', 'auto', 'cab', 'parcel']) {
          const rDoc = await getDoc(doc(db, "fare_rules", `${type}_default`));
          if (rDoc.exists()) {
            const data = rDoc.data();
            rules[type] = {
              baseFare: data.baseFare || rules[type].baseFare,
              includedDistanceKm: data.includedDistanceKm || rules[type].includedDistanceKm,
              ratePerKm: data.ratePerKm || rules[type].ratePerKm,
              ratePerMinute: data.ratePerMinute || rules[type].ratePerMinute,
              minimumFare: data.minimumFare || rules[type].minimumFare
            };
          }
        }
      } catch (err) {
        console.warn("Failed to fetch dynamic fare rules, using fallbacks.", err);
      }
      
      const options = [
        { id: "bike", name: "Sarthi Bike", fare: calculateFare(dir.distanceMeters, dir.durationSeconds, rules.bike), time: Math.ceil(dir.durationSeconds / 60) },
        { id: "auto", name: "Sarthi Auto", fare: calculateFare(dir.distanceMeters, dir.durationSeconds, rules.auto), time: Math.ceil(dir.durationSeconds / 60) },
        { id: "cab", name: "Sarthi Cab", fare: calculateFare(dir.distanceMeters, dir.durationSeconds, rules.cab), time: Math.ceil(dir.durationSeconds / 60) },
        { id: "parcel", name: "Sarthi Parcel", fare: calculateFare(dir.distanceMeters, dir.durationSeconds, rules.parcel), time: Math.ceil(dir.durationSeconds / 60) }
      ];
      
      setRideOptions(options);
      setSelectedRide(options[0]); // default to first
    } catch (e) {
      console.error(e);
      alert("Error finding rides");
    } finally {
      setLoadingRides(false);
    }
  };

  const handleConfirmRide = async () => {
    if (!selectedRide || !routeData) return;
    setBookingStatus("searching");
    setCaptainLocation(null);
    setCaptainData(null);
    
    const otp = Math.floor(1000 + Math.random() * 9000).toString();
    
    // ── Generate sequential routing queue ──
    let routingQueue = [];
    try {
      const liveSnapshot = await rtdbGet(ref(rtdb, 'live/captains'));
      if (liveSnapshot.exists()) {
        const data = liveSnapshot.val();
        let nearby = [];
        
        for (const [captainId, loc] of Object.entries(data)) {
          if (loc.lat && loc.lng) {
            const dist = calculateDistance(routeData.pickup.lat, routeData.pickup.lng, loc.lat, loc.lng);
            if (dist <= 6000) {
              nearby.push({ id: captainId, distance: dist });
            }
          }
        }
        
        nearby.sort((a, b) => a.distance - b.distance);
        const topNearest = nearby.slice(0, 20);
        
        for (const cap of topNearest) {
          const cDoc = await getDoc(doc(db, "users", cap.id));
          if (cDoc.exists()) {
            const cData = cDoc.data();
            if (cData.role === 'captain' && 
                cData.vehicleType === selectedRide.id && 
                cData.verificationStatus === 'verified') {
              routingQueue.push(cap.id);
            }
          }
        }
      }
    } catch (e) {
      console.warn("Failed to build routing queue:", e);
    }
    
    try {
      const docRef = await addDoc(collection(db, "ride_requests"), {
        userId: user.uid,
        riderName: user.displayName || user.email?.split('@')[0] || 'User',
        riderPhone: user.phoneNumber || '',
        status: "searching",
        otp: otp,
        routingQueue: routingQueue,
        currentRouteIndex: 0,
        routeStartedAt: serverTimestamp(),
        pickup: {
          lat: routeData.pickup.lat,
          lng: routeData.pickup.lng,
          address: routeData.pickup.address || 'User pickup location'
        },
        destination: {
          lat: routeData.drop.lat,
          lng: routeData.drop.lng,
          address: routeData.drop.address || 'User destination'
        },
        distanceMeters: Math.round(routeData.distance),
        fareEstimate: Math.round(selectedRide.fare),
        fareBreakdown: {
          baseFare: Math.round(selectedRide.fare),
          distanceFare: 0,
          timeFare: 0,
          total: Math.round(selectedRide.fare)
        },
        vehicleType: selectedRide.id,
        paymentMethod: 'cash',
        paymentStatus: 'pending',
        appliedOfferCode: null,
        discountAmount: 0,
        createdAt: serverTimestamp()
      });
      
      setCurrentRideId(docRef.id);
    } catch (err) {
      console.error("Failed to book:", err);
      alert("Booking failed. Please try again.");
      setBookingStatus(null);
    }
  };

  const handleCancelRide = async () => {
    if (!currentRideId) {
      setBookingStatus(null);
      return;
    }
    try {
      await updateDoc(doc(db, "ride_requests", currentRideId), {
        status: "cancelled"
      });
    } catch (err) {
      console.error("Failed to cancel ride:", err);
    }
    setBookingStatus(null);
    setCurrentRideId(null);
    setActiveRide(null);
    setCaptainData(null);
    setCaptainLocation(null);
  };

  if (authLoading || !user) return <div className={styles.loader}>Loading...</div>;

  return (
    <div className={styles.bookingContainer}>
      <div className={styles.mapSection}>
        <OlaMap 
          routeCoordinates={routeData?.points} 
          pickupLocation={routeData?.pickup}
          dropLocation={routeData?.drop}
          captainLocation={captainLocation} 
          vehicleType={activeRide?.vehicleType || selectedRide?.id} 
        />
      </div>

      <div className={styles.uiSection}>
        {bookingStatus === "searching" ? (
          <div className={styles.searchingCard}>
            <div className={styles.radarSpinner}></div>
            <h2>Looking for Captains...</h2>
            <p>We are connecting you to the nearest {selectedRide?.name}. Please do not close this window.</p>
            <button className={styles.cancelBtn} onClick={handleCancelRide}>
              Cancel Ride
            </button>
          </div>
        ) : bookingStatus === "accepted" || bookingStatus === "arriving" || bookingStatus === "arrived" ? (
          <div className={styles.activeCard}>
            <div className={styles.statusBadge}>
              {bookingStatus === 'arrived' ? 'Captain has arrived!' : bookingStatus === 'arriving' ? 'Captain is arriving' : 'Captain is on the way'}
            </div>
            
            <div className={styles.captainInfo}>
              <div className={styles.captainAvatar}>
                {captainData?.firstName?.[0] || 'C'}
              </div>
              <div className={styles.captainDetails}>
                <h3>{captainData?.firstName} {captainData?.lastName}</h3>
                <p>{captainData?.vehicleNumber || 'Vehicle Assigned'} • {activeRide?.vehicleType?.toUpperCase()}</p>
                <div className={styles.rating}>★ {captainData?.rating || '4.8'}</div>
              </div>
            </div>
            
            <div className={styles.otpBox}>
              <p>Provide this OTP to start the ride</p>
              <h2>{activeRide?.otp}</h2>
            </div>
            
            <button className={styles.cancelBtn} onClick={handleCancelRide}>
              Cancel Ride
            </button>
          </div>
        ) : bookingStatus === "in_progress" ? (
          <div className={styles.activeCard}>
            <div className={styles.statusBadgeProgress}>Ride in Progress</div>
            <h2>Enjoy your ride!</h2>
            <p>Heading to {activeRide?.destination?.address}</p>
            
            <div className={styles.otpBox}>
              <p>Estimated Fare</p>
              <h2>₹{activeRide?.fareEstimate}</h2>
            </div>
          </div>
        ) : bookingStatus === "completed" ? (
          <div className={styles.activeCard}>
            {activeRide?.paymentStatus === 'paid' ? (
              <>
                <div className={styles.statusBadgeCompleted}>Payment Successful</div>
                <h2>Thank you for riding with Sarthi!</h2>
                <p>Your payment of ₹{activeRide?.fareEstimate} was received.</p>
                
                <button className={styles.bookBtn} onClick={() => {
                  setBookingStatus(null);
                  setCurrentRideId(null);
                  setRouteData(null);
                  setRideOptions([]);
                  setActiveRide(null);
                  setCaptainData(null);
                  setCaptainLocation(null);
                }}>
                  Done
                </button>
              </>
            ) : (
              <>
                <div className={styles.statusBadgeProgress}>Payment Required</div>
                <h2>You have arrived!</h2>
                <p>Please pay the final fare to complete the ride.</p>
                
                <div className={styles.fareBox}>
                  <p>Total Fare</p>
                  <h1>₹{activeRide?.fareEstimate}</h1>
                </div>
                
                <button className={styles.bookBtn} onClick={async () => {
                  try {
                    await updateDoc(doc(db, "ride_requests", currentRideId), {
                      paymentStatus: 'paid'
                    });
                    // UI will automatically update via the onSnapshot listener
                  } catch (err) {
                    console.error("Payment update failed", err);
                    alert("Payment failed to process. Please try again.");
                  }
                }}>
                  Pay ₹{activeRide?.fareEstimate}
                </button>
              </>
            )}
          </div>
        ) : rideOptions.length > 0 ? (
          <div className={styles.card}>
            <button className={styles.backBtn} onClick={() => setRideOptions([])}>← Back</button>
            <h1 className={styles.title}>Select a Ride</h1>
            <div className={styles.rideList}>
              {rideOptions.map((ride) => (
                <div 
                  key={ride.id} 
                  className={`${styles.rideOption} ${selectedRide?.id === ride.id ? styles.selected : ''}`}
                  onClick={() => setSelectedRide(ride)}
                >
                  <div className={styles.rideInfo}>
                    <h3>{ride.name}</h3>
                    <p>{ride.time} mins away</p>
                  </div>
                  <div className={styles.ridePrice}>₹{ride.fare}</div>
                </div>
              ))}
            </div>
            <button className={styles.bookBtn} onClick={handleConfirmRide}>
              Confirm {selectedRide?.name}
            </button>
          </div>
        ) : (
          <div className={styles.card}>
            <button className={styles.backBtn} onClick={() => router.push('/')}>← Back</button>
            <h1 className={styles.title}>Book a Ride</h1>
            
            <div className={styles.inputGroup} style={{ position: "relative" }}>
              <div className={styles.dot}></div>
              <input 
                type="text" 
                placeholder="Enter Pickup Location" 
                value={pickup}
                onChange={(e) => {
                  setPickup(e.target.value);
                  setShowPickupSuggestions(true);
                }}
                onFocus={() => setShowPickupSuggestions(true)}
                onBlur={() => setTimeout(() => setShowPickupSuggestions(false), 200)}
                className={styles.locationInput}
              />
              {showPickupSuggestions && pickupSuggestions.length > 0 && (
                <ul className="suggestionsList" style={{ top: '100%' }}>
                  {pickupSuggestions.map((s) => (
                    <li key={s.place_id} onMouseDown={() => handlePickupSelect(s.description)}>
                      <span>{s.description}</span>
                    </li>
                  ))}
                </ul>
              )}
            </div>

            <div className={styles.inputGroup} style={{ position: "relative" }}>
              <div className={styles.square}></div>
              <input 
                type="text" 
                placeholder="Enter Destination" 
                value={drop}
                onChange={(e) => {
                  setDrop(e.target.value);
                  setShowDropSuggestions(true);
                }}
                onFocus={() => setShowDropSuggestions(true)}
                onBlur={() => setTimeout(() => setShowDropSuggestions(false), 200)}
                className={styles.locationInput}
              />
              {showDropSuggestions && dropSuggestions.length > 0 && (
                <ul className="suggestionsList" style={{ top: '100%' }}>
                  {dropSuggestions.map((s) => (
                    <li key={s.place_id} onMouseDown={() => handleDropSelect(s.description)}>
                      <span>{s.description}</span>
                    </li>
                  ))}
                </ul>
              )}
            </div>

            <button 
              className={styles.bookBtn} 
              onClick={handleFindRides} 
              disabled={loadingRides}
            >
              {loadingRides ? "Searching..." : "Find Rides"}
            </button>
          </div>
        )}
      </div>
    </div>
  );
}

export default function BookingPage() {
  return (
    <Suspense fallback={<div className={styles.loader}>Loading map...</div>}>
      <BookingContent />
    </Suspense>
  );
}
