import styles from "../page.module.css";
import Link from "next/link";
import { ArrowRight, Wallet, Clock, MapPin, Car, BarChart3, Headphones, CheckCircle2 } from "lucide-react";

export const metadata = {
  title: "Captains | Sarthi",
  description: "Become a Sarthi Captain and turn your time on the road into an opportunity to earn.",
};

export default function CaptainsPage() {
  return (
    <main>
      {/* Hero Section */}
      <section className={styles.hero} style={{ minHeight: "75vh", display: "flex", alignItems: "center" }}>
        <div className={styles.heroBackground}>
          <div className={styles.glowOrb1}></div>
          <div className={styles.glowOrb2}></div>
        </div>
        <div className={styles.heroCard} style={{ margin: "0 auto", position: "relative", zIndex: 1, background: "transparent" }}>
          <div className={styles.heroLeft} style={{ display: "flex", flexDirection: "column", justifyContent: "center", background: "transparent" }}>
            <div className={styles.heroContent}>
              <h1 className={`${styles.heroTitle} ${styles.fadeUp}`} style={{ fontSize: "clamp(2.5rem, 4vw, 4.5rem)", lineHeight: "1.1" }}>
                Ride With Sarthi. <br />
                <span className={styles.textGradient}>Earn On Your Terms.</span>
              </h1>
              <p className={`${styles.heroDesc} ${styles.fadeUp} ${styles.fadeUp1}`}>
                Become a Sarthi Captain and turn your time on the road into a seamless opportunity to earn with daily payouts.
              </p>
              <div className={`${styles.heroAppButtons} ${styles.fadeUp} ${styles.fadeUp2}`} style={{ marginTop: "40px" }}>
                <button className={styles.btnNavPrimary} style={{ padding: "16px 40px", fontSize: "1.1rem", borderRadius: "999px" }}>
                  Join Sarthi Today
                </button>
              </div>
            </div>
          </div>
          <div className={styles.heroRight} style={{ background: "transparent" }}>
            <div className={`${styles.phoneContainer} ${styles.fadeUp}`}>
              <div className={styles.phoneInner}>
                <img src="/captain.jpg" alt="Sarthi Captain App" />
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
            <h2 className={styles.sectionTitle}>How to become a Captain</h2>
            <p className={styles.sectionDesc}>A simple, transparent process to get you on the road and earning.</p>
          </div>
          <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(320px, 1fr))", gap: "32px", marginTop: "48px" }}>
            {[
              { step: "01", title: "Register", desc: "Download the Captain app and create your account in minutes." },
              { step: "02", title: "Verification", desc: "Submit your driving license and vehicle documents for quick approval." },
              { step: "03", title: "Go Online", desc: "Toggle your status to online and start receiving nearby ride requests." },
              { step: "04", title: "Accept Rides", desc: "Review ride details and accept trips that perfectly fit your schedule." },
              { step: "05", title: "Complete Trip", desc: "Pick up the rider, navigate smoothly, and complete the journey." },
              { step: "06", title: "Get Paid", desc: "View your earnings instantly and enjoy seamless daily bank payouts." },
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

      {/* Captain Benefits Section */}
      <section className={styles.features} style={{ background: "var(--gray-50)", padding: "100px 0" }}>
        <div style={{ maxWidth: "1200px", margin: "0 auto", padding: "0 24px" }}>
          <div className={styles.sectionHeader}>
            <span className={styles.sectionLabel}>Features</span>
            <h2 className={styles.sectionTitle}>Captain Benefits</h2>
            <p className={styles.sectionDesc}>Everything you need to maximize your earnings and stay in control.</p>
          </div>
          <div className={styles.featureGrid}>
            {[
              { icon: <Wallet size={28} />, title: "Earn From Rides", desc: "Track earnings transparently and get paid instantly to your bank account." },
              { icon: <Clock size={28} />, title: "Flexible Availability", desc: "Be your own boss. Choose exactly when you want to go online and drive." },
              { icon: <MapPin size={28} />, title: "Smart Requests", desc: "Receive highly relevant, optimized ride requests around your current location." },
              { icon: <Car size={28} />, title: "Vehicle Options", desc: "Register multiple vehicle categories, from bikes to premium cabs." },
              { icon: <BarChart3 size={28} />, title: "Earnings Analytics", desc: "View detailed insights on completed rides, performance, and daily earnings." },
              { icon: <Headphones size={28} />, title: "24/7 Support", desc: "Dedicated Captain support team ready to assist you anytime you need help." },
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
          <h2 className={styles.ctaTitle}>Ready to become a Sarthi Captain?</h2>
          <p className={styles.ctaDesc}>Join thousands of Captains earning daily on their own terms.</p>
          <div className={styles.ctaButtons} style={{ justifyContent: "center" }}>
            <button className={styles.btnCtaPrimary}>Join Sarthi Now</button>
            <button className={styles.btnCtaOutline}>Contact Support</button>
          </div>
        </div>
      </section>
    </main>
  );
}
