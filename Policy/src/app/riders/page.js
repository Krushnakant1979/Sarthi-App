import styles from "../page.module.css";
import Link from "next/link";
import { ArrowRight, Smartphone, MapPin, Car, CreditCard, Clock, FileText, Headphones, CheckCircle2 } from "lucide-react";

export const metadata = {
  title: "Riders | Sarthi",
  description: "Book your ride in just a few taps and enjoy a simple, transparent and connected travel experience.",
};

export default function RidersPage() {
  return (
    <main>
      {/* Hero Section */}
      <section className={styles.hero}>
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
        <div className={styles.heroCard} style={{ margin: "0 auto", position: "relative", zIndex: 1 }}>
          <div className={styles.heroLeft} style={{ display: "flex", flexDirection: "column", justifyContent: "center" }}>
            <div className={styles.heroContent}>
              <h1 className={`${styles.heroTitle} ${styles.fadeUp}`} style={{ fontSize: "clamp(2.5rem, 4vw, 4.5rem)", lineHeight: "1.1" }}>
                Your Destination. <br />
                <span className={styles.textGradient}>Our Responsibility.</span>
              </h1>
              <p className={`${styles.heroDesc} ${styles.fadeUp} ${styles.fadeUp1}`}>
                Book your ride in just a few taps and enjoy a simple, transparent and connected travel experience.
              </p>
              <div className={`${styles.heroAppButtons} ${styles.fadeUp} ${styles.fadeUp2}`} style={{ marginTop: "40px" }}>
                <button className={styles.btnNavPrimary} style={{ padding: "16px 40px", fontSize: "1.1rem", borderRadius: "999px" }}>
                  Download Sarthi
                </button>
              </div>
            </div>
          </div>
          <div className={styles.heroRight}>
            <div className={`${styles.phoneContainer} ${styles.fadeUp}`}>
              <div className={styles.phoneInner}>
                <img src="/user.jpg" alt="Sarthi Rider App" />
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* The Journey Section */}
      <section className={styles.features}>
        <div style={{ maxWidth: "1200px", margin: "0 auto", padding: "0 24px" }}>
          <div className={styles.sectionHeader}>
            <span className={styles.sectionLabel}>The Journey</span>
            <h2 className={styles.sectionTitle}>How to book a ride</h2>
            <p className={styles.sectionDesc}>A seamless experience from pickup to drop-off.</p>
          </div>
          <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(320px, 1fr))", gap: "32px", marginTop: "48px" }}>
            {[
              { step: "01", title: "Set Pickup", desc: "Allow location access or manually enter your pickup point." },
              { step: "02", title: "Enter Destination", desc: "Type in where you want to go to see accurate fare estimates." },
              { step: "03", title: "Choose Ride", desc: "Select from Bike, Auto, or Cab based on your budget and needs." },
              { step: "04", title: "Confirm Ride", desc: "Tap confirm and we'll instantly connect you to the nearest captain." },
              { step: "05", title: "Track Captain", desc: "Watch your captain arrive on the map in real-time." },
              { step: "06", title: "Reach Destination", desc: "Pay securely via cash or UPI and rate your journey." },
            ].map((s) => (
              <div key={s.step} className={styles.featureCard} style={{ padding: "40px 32px", position: "relative" }}>
                <div style={{ fontSize: "5rem", fontWeight: "900", color: "var(--blue-50)", position: "absolute", top: "16px", right: "24px", lineHeight: "1" }}>{s.step}</div>
                <div style={{ position: "relative", zIndex: 1 }}>
                  <h3 style={{ fontSize: "1.3rem", fontWeight: "800", color: "var(--gray-900)", marginBottom: "12px", marginTop: "20px" }}>{s.title}</h3>
                  <p style={{ color: "var(--gray-500)", lineHeight: "1.6", fontSize: "1rem" }}>{s.desc}</p>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Rider Benefits Section */}
      <section className={styles.features} style={{ background: "var(--gray-50)", padding: "100px 0" }}>
        <div style={{ maxWidth: "1200px", margin: "0 auto", padding: "0 24px" }}>
          <div className={styles.sectionHeader}>
            <span className={styles.sectionLabel}>Features</span>
            <h2 className={styles.sectionTitle}>Rider Benefits</h2>
            <p className={styles.sectionDesc}>Everything you need for a comfortable and safe journey.</p>
          </div>
          <div className={styles.featureGrid}>
            {[
              { icon: <Smartphone size={28} />, title: "Simple booking", desc: "Book your ride in just two taps with our intuitive interface." },
              { icon: <MapPin size={28} />, title: "Accurate tracking", desc: "Know exactly where your captain is with real-time GPS tracking." },
              { icon: <Car size={28} />, title: "Multiple options", desc: "Choose between bike, auto, or cab based on your specific needs." },
              { icon: <CreditCard size={28} />, title: "Transparent fares", desc: "No hidden charges. See your estimated fare before you book." },
              { icon: <Clock size={28} />, title: "Real-time status", desc: "Get live updates on your trip's progress and ETA." },
              { icon: <Headphones size={28} />, title: "Customer support", desc: "24/7 dedicated support to assist you with any issues." },
            ].map(b => (
              <div key={b.title} className={styles.featureCard}>
                <div className={styles.featureIconWrap}>{b.icon}</div>
                <h3 className={styles.featureTitle}>{b.title}</h3>
                <p className={styles.featureDesc}>{b.desc}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* CTA Section */}
      <section className={styles.ctaSection} style={{ marginTop: "0" }}>
        <div className={styles.ctaInner}>
          <h2 className={styles.ctaTitle}>Your next ride is just a few taps away.</h2>
          <p className={styles.ctaDesc}>Download the Sarthi app and start riding today.</p>
          <div className={styles.ctaButtons} style={{ justifyContent: "center" }}>
            <button className={styles.btnCtaPrimary}>Download Sarthi</button>
            <button className={styles.btnCtaOutline}>Learn More</button>
          </div>
        </div>
      </section>
    </main>
  );
}
