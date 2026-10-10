"use client";
import { useState, useRef, useEffect } from "react";
import Link from "next/link";
import { Apple, Play, CheckCircle2, ArrowRight, MapPin, Circle, Car, CreditCard, ShieldCheck, Users, Clock, Smartphone, Globe } from "lucide-react";
import styles from "./page.module.css";
import { autocomplete, getPlaceDetails } from "@/lib/olamaps";
import { useRouter } from "next/navigation";
import { useAuth } from "@/context/AuthContext";

// ── Animated counter ──────────────────────────────────────────────
function AnimatedCounter({ target, suffix = "" }) {
  const [count, setCount] = useState(0);
  const ref = useRef(null);
  const started = useRef(false);

  useEffect(() => {
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting && !started.current) {
          started.current = true;
          let start = 0;
          const duration = 1800;
          const step = 16;
          const increment = target / (duration / step);
          const timer = setInterval(() => {
            start += increment;
            if (start >= target) {
              setCount(target);
              clearInterval(timer);
            } else {
              setCount(Math.floor(start));
            }
          }, step);
        }
      },
      { threshold: 0.4 }
    );
    if (ref.current) observer.observe(ref.current);
    return () => observer.disconnect();
  }, [target]);

  return <span ref={ref}>{count.toLocaleString()}{suffix}</span>;
}

export default function Page() {
  const { activeRideId } = useAuth();
  const router = useRouter();

  const [pickup, setPickup] = useState("");
  const [drop, setDrop] = useState("");
  const [showActiveRideModal, setShowActiveRideModal] = useState(false);
  
  const [pickupSuggestions, setPickupSuggestions] = useState([]);
  const [showPickupSuggestions, setShowPickupSuggestions] = useState(false);
  const [pickupCoords, setPickupCoords] = useState(null);
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

  const handlePickupSelect = async (placeId, description) => {
    isSelectingPickup.current = true;
    setPickup(description);
    setShowPickupSuggestions(false);
    const details = await getPlaceDetails(placeId);
    if (details) {
      setPickupCoords({ lat: details.lat, lng: details.lng });
    }
  };

  const [dropSuggestions, setDropSuggestions] = useState([]);
  const [showDropSuggestions, setShowDropSuggestions] = useState(false);
  const [dropCoords, setDropCoords] = useState(null);
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

  const handleDropSelect = async (placeId, description) => {
    isSelectingDrop.current = true;
    setDrop(description);
    setShowDropSuggestions(false);
    const details = await getPlaceDetails(placeId);
    if (details) {
      setDropCoords({ lat: details.lat, lng: details.lng });
    }
  };

  return (
    <>
      <main>
        {/* ── HERO ──────────────────────────────────────────────── */}
        <section className={styles.hero} id="about">
          <div className={styles.heroBackground}>
            <div className={styles.glowOrb1}></div>
            <div className={styles.glowOrb2}></div>
            {/* Floating Flowers & Vehicles */}
            <div className={`${styles.flower} ${styles.flower1}`}>🌸</div>
            <div className={`${styles.flower} ${styles.flower2}`}>🌼</div>
            <div className={`${styles.flower} ${styles.flower3}`}>🌺</div>
            <div className={`${styles.flower} ${styles.flower4}`}>🌸</div>
            <div className={`${styles.flower} ${styles.flower5}`}>🌷</div>
            <div className={`${styles.flower} ${styles.flower6}`}>🌻</div>
            <div className={`${styles.flower} ${styles.flower7}`}>🌼</div>
            <div className={`${styles.flower} ${styles.flower8}`}>🌺</div>
            <div className={`${styles.flower} ${styles.flower9}`}>🚗</div>
            <div className={`${styles.flower} ${styles.flower10}`}>🛵</div>
            <div className={`${styles.flower} ${styles.flower11}`}>🚕</div>
            <div className={`${styles.flower} ${styles.flower12}`}>🏍️</div>
          </div>
          <div className={styles.heroCard}>
            {/* Left Side (Dark) */}
            <div className={styles.heroLeft}>
              <div className={styles.heroContent}>
                <h1 className={`${styles.heroTitle} ${styles.fadeUp}`}>
                  Your Ride. <br />
                  <span className={styles.textGradient}>Your Way.</span> <br />
                  With Sarthi.
                </h1>
                <p className={`${styles.heroDesc} ${styles.fadeUp} ${styles.fadeUp1}`}>
                  Connecting you to every destination.
                </p>

                <div className={`${styles.bookingForm}`}>
                  <div className={styles.inputGroup} style={{ position: "relative" }}>
                    <div className={styles.inputIcon}>
                      <MapPin size={28} color="#111827" />
                    </div>
                    <input 
                      id="pickup-input" 
                      type="text" 
                      placeholder="Enter Pickup Location" 
                      className={styles.locationInput} 
                      value={pickup}
                      onChange={(e) => {
                        setPickup(e.target.value);
                        setShowPickupSuggestions(true);
                      }}
                      onFocus={(e) => {
                        if (activeRideId) {
                          e.target.blur();
                          setShowActiveRideModal(true);
                          return;
                        }
                        setShowPickupSuggestions(true);
                      }}
                      onBlur={() => setTimeout(() => setShowPickupSuggestions(false), 200)}
                    />
                    {showPickupSuggestions && pickupSuggestions.length > 0 && (
                      <ul className="suggestionsList">
                        {pickupSuggestions.map((s) => (
                          <li key={s.place_id} onMouseDown={() => handlePickupSelect(s.place_id, s.description)}>
                            <MapPin size={16} />
                            <span>{s.description}</span>
                          </li>
                        ))}
                      </ul>
                    )}
                  </div>
                  
                  <div className={styles.inputGroup} style={{ position: "relative" }}>
                    <div className={styles.inputIcon}>
                      <Circle size={20} color="#111827" strokeWidth={4} />
                    </div>
                    <input 
                      type="text" 
                      placeholder="Enter Drop Location" 
                      className={styles.locationInput} 
                      value={drop}
                      onChange={(e) => {
                        setDrop(e.target.value);
                        setShowDropSuggestions(true);
                      }}
                      onFocus={(e) => {
                        if (activeRideId) {
                          e.target.blur();
                          setShowActiveRideModal(true);
                          return;
                        }
                        setShowDropSuggestions(true);
                      }}
                      onBlur={() => setTimeout(() => setShowDropSuggestions(false), 200)}
                    />
                    {showDropSuggestions && dropSuggestions.length > 0 && (
                      <ul className="suggestionsList">
                        {dropSuggestions.map((s) => (
                          <li key={s.place_id} onMouseDown={() => handleDropSelect(s.place_id, s.description)}>
                            <MapPin size={16} />
                            <span>{s.description}</span>
                          </li>
                        ))}
                      </ul>
                    )}
                  </div>

                  <button 
                    onClick={(e) => {
                      e.preventDefault();
                      if (activeRideId) {
                        setShowActiveRideModal(true);
                      } else {
                        router.push(`/booking?pickup=${encodeURIComponent(pickup)}&drop=${encodeURIComponent(drop)}`);
                      }
                    }}
                    className={styles.bookRideBtn} 
                    style={{ display: "block", width: "100%", textAlign: "center", textDecoration: "none", border: "none", cursor: "pointer", fontFamily: "inherit" }}
                  >
                    Book Ride
                  </button>
                </div>
              </div>
            </div>

            {/* Right Side (Light Purple) */}
            <div className={styles.heroRight}>
              
              <div className={`${styles.phoneContainer} ${styles.fadeUp} ${styles.fadeUp2}`}>
                <div className={styles.phoneInner}>
                  <img src="/sarthi_app_mockup.png" alt="Sarthi App interface" />
                </div>

                {/* Floating Cards */}
                <div className={`${styles.floatCard} ${styles.floatCard1}`}>
                  <CheckCircle2 size={20} />
                  Create a daily ride plan
                </div>

                <div className={`${styles.floatCard} ${styles.floatCard2}`}>
                  <div className={styles.floatCard2Top}>
                    <img src="https://i.pravatar.cc/100?img=4" alt="Driver" className={styles.floatCard2Avatar} />
                    <div className={styles.floatCard2Text}>
                      <div className={styles.floatCard2Role}>Assigned to</div>
                      <div className={styles.floatCard2Name}>Kartik Sharma</div>
                    </div>
                  </div>
                </div>

                <div className={`${styles.floatCard} ${styles.floatCard3}`}>
                  Book a recurring ride
                </div>
              </div>
            </div>
          </div>
        </section>

        {/* ── QUICK BENEFITS ─────────────────────────────────────────── */}
        <section className={styles.benefits}>
          <div className={styles.benefitsGrid}>
            <div className={styles.benefitCard}>
              <div className={styles.benefitIcon}><Car size={28} /></div>
              <div className={styles.benefitText}>
                <h3 className={styles.benefitTitle}>Multiple Ride Options</h3>
                <p className={styles.benefitDesc}>Choose from Bike, Auto, Cab and Parcel services.</p>
              </div>
            </div>
            <div className={styles.benefitCard}>
              <div className={styles.benefitIcon}><MapPin size={28} /></div>
              <div className={styles.benefitText}>
                <h3 className={styles.benefitTitle}>Real-Time Tracking</h3>
                <p className={styles.benefitDesc}>Track your captain and ride in real time.</p>
              </div>
            </div>
            <div className={styles.benefitCard}>
              <div className={styles.benefitIcon}><CreditCard size={28} /></div>
              <div className={styles.benefitText}>
                <h3 className={styles.benefitTitle}>Transparent Pricing</h3>
                <p className={styles.benefitDesc}>Know your estimated fare before confirming your ride.</p>
              </div>
            </div>
            <div className={styles.benefitCard}>
              <div className={styles.benefitIcon}><ShieldCheck size={28} /></div>
              <div className={styles.benefitText}>
                <h3 className={styles.benefitTitle}>Safe & Reliable</h3>
                <p className={styles.benefitDesc}>Designed to provide a dependable transportation experience.</p>
              </div>
            </div>
          </div>
        </section>


        {/* ── RIDE OPTIONS ─────────────────────────────────────────── */}
        <section className={styles.features}>
          <div style={{ maxWidth: "1200px", margin: "0 auto", padding: "0 24px" }}>
            <div className={styles.sectionHeader}>
              <span className={styles.sectionLabel}>Ride Options</span>
              <h2 className={styles.sectionTitle}>Choose your way to travel</h2>
            </div>
            <div className={styles.rideOptionGrid}>
              {[
                { img: "/icon_bike.jpg", title: "Bike-Taxi", desc: "Beat traffic, ride quicker" },
                { img: "/icon_auto.jpg", title: "Auto", desc: "Everyday autos, made easy" },
                { img: "/icon_cab.jpg", title: "Cab", desc: "Comfort for every journey" },
                { img: "/icon_parcel.jpg", title: "Parcel", desc: "Quick, secure & insured deliveries" },
              ].map((f) => (
                <div key={f.title} className={styles.rideOptionCard}>
                  <div className={styles.rideOptionContent}>
                    <h3 className={styles.rideOptionTitle}>{f.title}</h3>
                    <p className={styles.rideOptionDesc}>{f.desc}</p>
                  </div>
                  <img src={f.img} alt={f.title} className={styles.rideOptionImg} />
                </div>
              ))}
            </div>
          </div>
        </section>


        {/* ── WHY SARTHI ─────────────────────────────────────────── */}
        <section className={styles.features} id="features">
          <div style={{ maxWidth: "1200px", margin: "0 auto", padding: "0 24px" }}>
            <div className={styles.sectionHeader}>
              <span className={styles.sectionLabel}>Why Sarthi</span>
              <h2 className={styles.sectionTitle}>Built for India, Built for You</h2>
              <p className={styles.sectionDesc}>
                Every feature is crafted with the Indian commuter in mind — 
                fast, affordable, and trustworthy.
              </p>
            </div>

            <div className={styles.featureGrid} id="features-grid">
              {[
                {
                  icon: <Users size={28} />,
                  title: "Smart Matching",
                  desc: "Connect riders with suitable nearby captains.",
                },
                {
                  icon: <MapPin size={28} />,
                  title: "Live Location",
                  desc: "Track rides and locations in real time.",
                },
                {
                  icon: <CreditCard size={28} />,
                  title: "Transparent Fares",
                  desc: "Clear pricing before confirming a ride.",
                },
                {
                  icon: <Clock size={28} />,
                  title: "Flexible Captain Experience",
                  desc: "Captains can manage their availability and rides.",
                },
                {
                  icon: <Smartphone size={28} />,
                  title: "Simple Experience",
                  desc: "Designed to keep booking and driving simple.",
                },
                {
                  icon: <Globe size={28} />,
                  title: "Connected Platform",
                  desc: "Rider, Captain and Admin systems work together.",
                },
              ].map((f) => (
                <div key={f.title} className={styles.featureCard}>
                  <div className={styles.featureIconWrap}>{f.icon}</div>
                  <h3 className={styles.featureTitle}>{f.title}</h3>
                  <p className={styles.featureDesc}>{f.desc}</p>
                </div>
              ))}
            </div>
          </div>
        </section>

        {/* ── RIDER APP SHOWCASE ───────────────────────────────── */}
        <section className={styles.appSection} id="riders">
          <div className={styles.appShowcase}>
            {/* Image */}
            <div className={styles.appImageWrap}>
              <div className={styles.appImageGlow}></div>
              <img
                src="/user.jpg"
                alt="Sarthi Rider App"
                className={styles.appPhone}
              />
            </div>
            {/* Content */}
            <div className={styles.appContent}>
              <span className={styles.appTag}>📱 For Riders</span>
              <h2 className={styles.appTitle}>Your everyday travel companion</h2>
              <p className={styles.appDesc}>
                Booking a ride has never been this easy. Open the app, enter 
                your destination, see live Captains on the map, and you&apos;re good 
                to go. Clean, intuitive, and lightning fast.
              </p>
              <ul className={styles.appFeatureList}>
                {[
                  "Live map with nearby Captains",
                  "Instant ride booking in 2 taps",
                  "Real-time trip tracking & ETA",
                ].map((item) => (
                  <li key={item} className={styles.appFeatureItem}>
                    <span className={styles.appFeatureCheck}>✓</span>
                    {item}
                  </li>
                ))}
              </ul>

            </div>
          </div>
        </section>

        {/* ── CAPTAIN APP SHOWCASE ─────────────────────────────── */}
        <section className={styles.appSection} id="captains" style={{ background: "var(--blue-50)" }}>
          <div className={`${styles.appShowcase} ${styles.reverse}`}>
            {/* Image */}
            <div className={styles.appImageWrap}>
              <div className={styles.appImageGlow}></div>
              <img
                src="/captain.jpg"
                alt="Sarthi Captain App"
                className={styles.appPhone}
              />
            </div>
            {/* Content */}
            <div className={styles.appContent}>
              <span className={styles.appTag} style={{ background: "var(--blue-800)", color: "white" }}>
                🚗 For Captains
              </span>
              <h2 className={styles.appTitle}>Drive, Earn, Repeat</h2>
              <p className={styles.appDesc}>
                Join thousands of Captains already earning with Sarthi. 
                Work on your own schedule, accept rides you want, and 
                get paid daily — directly to your bank account.
              </p>
              <ul className={styles.appFeatureList}>
                {[
                  "Zero registration fees, ever",
                  "Daily instant bank payouts",
                  "Smart navigation built-in",
                  "24/7 dedicated Captain support",
                ].map((item) => (
                  <li key={item} className={styles.appFeatureItem}>
                    <span className={styles.appFeatureCheck}>✓</span>
                    {item}
                  </li>
                ))}
              </ul>
              <button
                className={styles.btnNavPrimary}
                style={{ padding: "16px 36px", fontSize: "1rem", borderRadius: "999px" }}
              >
                Register as Captain →
              </button>
            </div>
          </div>
        </section>

        {/* ── CTA ─────────────────────────────────────────────── */}
        <section className={styles.ctaSection}>
          <div className={styles.ctaInner}>
            <h2 className={styles.ctaTitle}>Ready to ride smarter?</h2>
            <p className={styles.ctaDesc}>
              Join over 50,000 satisfied riders and 5,000 Captains in Akola and beyond.
            </p>
            <div className={styles.ctaButtons}>
              <button 
                className={styles.btnCtaPrimary}
                onClick={() => {
                  const input = document.getElementById("pickup-input");
                  if (input) {
                    input.scrollIntoView({ behavior: "smooth", block: "center" });
                    setTimeout(() => input.focus(), 600);
                  }
                }}
              >
                Book Your First Ride
              </button>
              <button className={styles.btnCtaOutline}>Join as Captain</button>
            </div>
          </div>
        </section>

        {/* ── DOWNLOAD NOW ─────────────────────────────────────────────── */}
        <section style={{ background: "var(--gray-50)", padding: "100px 24px", textAlign: "center", borderBottom: "1px solid var(--gray-200)" }}>
          <div style={{ display: "inline-block", marginBottom: "56px" }}>
            <h2 style={{ fontSize: "2.8rem", fontWeight: "900", color: "var(--gray-900)", marginBottom: "16px", letterSpacing: "-1px" }}>
              Download Now
            </h2>
            <div style={{ height: "4px", width: "100px", background: "var(--yellow-500)", margin: "0 auto", borderRadius: "2px" }}></div>
          </div>
          
          <div style={{ display: "flex", justifyContent: "center", gap: "32px", flexWrap: "wrap", maxWidth: "900px", margin: "0 auto" }}>
            {/* Card 1 - Rider */}
            <div style={{ background: "var(--white)", padding: "32px", borderRadius: "16px", boxShadow: "0 8px 30px rgba(0,0,0,0.04)", display: "flex", alignItems: "center", gap: "24px", flex: "1", minWidth: "320px", border: "1px solid var(--gray-100)" }}>
              <div style={{ display: "flex", alignItems: "center", justifyContent: "center", minWidth: "160px" }}>
                <img src="/Sarthi app user logo.png" alt="Sarthi App" style={{ width: "140px", objectFit: "contain", borderRadius: "40px" }} />
              </div>
              <div style={{ textAlign: "left", fontSize: "1.35rem", fontWeight: "600", color: "var(--gray-900)", lineHeight: "1.4" }}>
                Bike-Taxi,<br/>Auto & Cabs
              </div>
            </div>

            {/* Card 2 - Captain */}
            <div style={{ background: "var(--white)", padding: "32px", borderRadius: "16px", boxShadow: "0 8px 30px rgba(0,0,0,0.04)", display: "flex", alignItems: "center", gap: "24px", flex: "1", minWidth: "320px", border: "1px solid var(--gray-100)" }}>
              <div style={{ display: "flex", alignItems: "center", justifyContent: "center", minWidth: "160px" }}>
                <img src="/Sarthi app captain  logo.png" alt="Sarthi Captain App" style={{ width: "140px", objectFit: "contain", borderRadius: "40px" }} />
              </div>
              <div style={{ textAlign: "left", fontSize: "1.35rem", fontWeight: "600", color: "var(--gray-900)", lineHeight: "1.4" }}>
                Drive &<br/>Earn
              </div>
            </div>
          </div>
        </section>

      </main>

      {showActiveRideModal && (
        <div className={styles.modalOverlay}>
          <div className={styles.modalContent}>
            <div className={styles.modalIcon}>
              <Car size={32} color="#f59e0b" />
            </div>
            <h3>Active Ride in Progress</h3>
            <p>You already have an ongoing ride. Please complete or cancel it before booking a new one.</p>
            <div className={styles.modalActions}>
              <button 
                onClick={() => setShowActiveRideModal(false)} 
                className={styles.btnOutline}
              >
                Close
              </button>
              <button 
                onClick={() => router.push("/booking")} 
                className={styles.btnPrimary}
              >
                Go to Ride
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  );
}
