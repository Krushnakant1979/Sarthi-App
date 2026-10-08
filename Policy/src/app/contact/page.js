"use client";
import { useState } from "react";
import styles from "./contact.module.css";
import navStyles from "../page.module.css";
import { User, Car, Briefcase } from "lucide-react";

export default function ContactPage() {
  const [form, setForm] = useState({ name: "", email: "", phone: "", subject: "", message: "" });
  const [submitted, setSubmitted] = useState(false);
  const [loading, setLoading] = useState(false);
  const [errors, setErrors] = useState({});

  const validate = () => {
    const e = {};
    if (!form.name.trim()) e.name = "Name is required";
    if (!form.email.trim()) e.email = "Email is required";
    else if (!/\S+@\S+\.\S+/.test(form.email)) e.email = "Enter a valid email";
    if (!form.subject) e.subject = "Please select a subject";
    if (!form.message.trim()) e.message = "Message is required";
    return e;
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    const errs = validate();
    if (Object.keys(errs).length) { setErrors(errs); return; }
    setErrors({});
    setLoading(true);
    await new Promise((r) => setTimeout(r, 1500));
    setLoading(false);
    setSubmitted(true);
  };

  const handleChange = (e) => {
    setForm({ ...form, [e.target.name]: e.target.value });
    if (errors[e.target.name]) setErrors({ ...errors, [e.target.name]: "" });
  };

  return (
    <>
      <main className={styles.main} style={{ paddingTop: "120px" }}>


        {/* ── FORM + MAP ───────────────────────────────── */}
        <section className={styles.formSection}>
          <div className={styles.formWrapper}>

            {/* Form */}
            <div className={styles.formBox}>
              <h2 className={styles.formTitle}>Send us a message</h2>
              <p className={styles.formSubtitle}>Fill out the form below and we'll get back to you shortly.</p>

              {submitted ? (
                <div className={styles.successBox}>
                  <div className={styles.successIcon}>✅</div>
                  <h3 className={styles.successTitle}>Message Sent!</h3>
                  <p className={styles.successDesc}>
                    Thanks for reaching out, <strong>{form.name}</strong>. We'll reply to <strong>{form.email}</strong> within 24 hours.
                  </p>
                  <button className={styles.btnSendAnother} onClick={() => { setSubmitted(false); setForm({ name: "", email: "", phone: "", subject: "", message: "" }); }}>
                    Send Another Message
                  </button>
                </div>
              ) : (
                <form onSubmit={handleSubmit} noValidate className={styles.form}>
                  <div className={styles.formRow}>
                    <div className={styles.fieldGroup}>
                      <label className={styles.label} htmlFor="name">Full Name <span className={styles.req}>*</span></label>
                      <input
                        id="name"
                        name="name"
                        type="text"
                        placeholder="Kartik Sharma"
                        className={`${styles.input} ${errors.name ? styles.inputError : ""}`}
                        value={form.name}
                        onChange={handleChange}
                      />
                      {errors.name && <span className={styles.errorMsg}>{errors.name}</span>}
                    </div>
                    <div className={styles.fieldGroup}>
                      <label className={styles.label} htmlFor="email">Email Address <span className={styles.req}>*</span></label>
                      <input
                        id="email"
                        name="email"
                        type="email"
                        placeholder="kartik@example.com"
                        className={`${styles.input} ${errors.email ? styles.inputError : ""}`}
                        value={form.email}
                        onChange={handleChange}
                      />
                      {errors.email && <span className={styles.errorMsg}>{errors.email}</span>}
                    </div>
                  </div>

                  <div className={styles.formRow}>
                    <div className={styles.fieldGroup}>
                      <label className={styles.label} htmlFor="phone">Phone Number <span className={styles.optional}>(optional)</span></label>
                      <input
                        id="phone"
                        name="phone"
                        type="tel"
                        placeholder="+91 98765 43210"
                        className={styles.input}
                        value={form.phone}
                        onChange={handleChange}
                      />
                    </div>
                    <div className={styles.fieldGroup}>
                      <label className={styles.label} htmlFor="subject">Subject <span className={styles.req}>*</span></label>
                      <select
                        id="subject"
                        name="subject"
                        className={`${styles.input} ${styles.select} ${errors.subject ? styles.inputError : ""}`}
                        value={form.subject}
                        onChange={handleChange}
                      >
                        <option value="">Select a subject…</option>
                        <option value="ride-issue">Ride Issue</option>
                        <option value="payment">Payment / Refund</option>
                        <option value="captain-support">Captain Support</option>
                        <option value="account">Account Help</option>
                        <option value="partnership">Partnership / Business</option>
                        <option value="feedback">General Feedback</option>
                        <option value="other">Other</option>
                      </select>
                      {errors.subject && <span className={styles.errorMsg}>{errors.subject}</span>}
                    </div>
                  </div>

                  <div className={styles.fieldGroup}>
                    <label className={styles.label} htmlFor="message">Your Message <span className={styles.req}>*</span></label>
                    <textarea
                      id="message"
                      name="message"
                      rows={5}
                      placeholder="Tell us what's on your mind…"
                      className={`${styles.input} ${styles.textarea} ${errors.message ? styles.inputError : ""}`}
                      value={form.message}
                      onChange={handleChange}
                    />
                    {errors.message && <span className={styles.errorMsg}>{errors.message}</span>}
                  </div>

                  <button type="submit" className={styles.btnSubmit} disabled={loading}>
                    {loading ? (
                      <span className={styles.loader}></span>
                    ) : (
                      "Send Message →"
                    )}
                  </button>
                </form>
              )}
            </div>

            {/* Map / Info Panel */}
            <div className={styles.infoPanel}>
              <div className={styles.mapPlaceholder}>
                <iframe
                  title="Sarthi Location – Akola"
                  src="https://www.google.com/maps/embed?pb=!1m18!1m12!1m3!1d59762.24999999999!2d76.99999!3d20.69999!2m3!1f0!2f0!3f0!3m2!1i1024!2i768!4f13.1!3m3!1m2!1s0x3bd6f5f3b3f3f3f3%3A0x3f3f3f3f3f3f3f3f!2sAkola%2C%20Maharashtra!5e0!3m2!1sen!2sin!4v1700000000000"
                  width="100%"
                  height="260"
                  style={{ border: 0, borderRadius: "12px" }}
                  allowFullScreen=""
                  loading="lazy"
                  referrerPolicy="no-referrer-when-downgrade"
                />
              </div>

              <div className={styles.faqList}>
                <h3 className={styles.faqTitle}>Quick Answers</h3>
                {[
                  {
                    q: "How do I cancel a ride?",
                    a: "Open the app → My Trips → Select the active ride → Tap Cancel.",
                  },
                  {
                    q: "When will I get my refund?",
                    a: "Refunds are processed within 3-5 business days to the original payment method.",
                  },
                  {
                    q: "How do I register as a Captain?",
                    a: "Download the Sarthi Captain app and complete the onboarding with your documents.",
                  },
                ].map((faq) => (
                  <details key={faq.q} className={styles.faqItem}>
                    <summary className={styles.faqQ}>{faq.q}</summary>
                    <p className={styles.faqA}>{faq.a}</p>
                  </details>
                ))}
              </div>
            </div>
          </div>
        </section>
      </main>
    </>
  );
}
