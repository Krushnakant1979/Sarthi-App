"use client";

import { useState } from "react";
import Link from "next/link";
import { 
  ArrowLeft, ArrowRight, CheckCircle2, UploadCloud, 
  User, Mail, Phone, Lock, MapPin, Car, Shield, 
  Trash2, AlertCircle, Clock, Check
} from "lucide-react";
import { auth, db, storage } from "@/config/firebase";
import { createUserWithEmailAndPassword, updateProfile } from "firebase/auth";
import { doc, setDoc, serverTimestamp, collection, addDoc } from "firebase/firestore";
import { ref, uploadBytes, getDownloadURL } from "firebase/storage";
import styles from "./register.module.css";

const VEHICLE_OPTIONS = [
  { id: "bike", name: "Sarthi Bike", emoji: "🛵", desc: "Motorcycle & Scooters" },
  { id: "auto", name: "Sarthi Auto", emoji: "🛺", desc: "3-Wheeler CNG / Electric" },
  { id: "cab", name: "Sarthi Cab", emoji: "🚕", desc: "Sedan, Hatchback, SUV" },
  { id: "parcel", name: "Sarthi Parcel", emoji: "📦", desc: "Quick Courier & Packages" },
];

const REQUIRED_DOCS = [
  { key: "profilePhoto", label: "Profile Photo", desc: "Clear front-facing passport style photo" },
  { key: "aadhaarCard", label: "Aadhaar Card", desc: "Front & back or original e-Aadhaar PDF/photo" },
  { key: "drivingLicence", label: "Driving Licence (DL)", desc: "Valid commercial or private driver licence" },
  { key: "rcBook", label: "RC Book (Registration)", desc: "Vehicle registration certificate copy" },
  { key: "insurance", label: "Vehicle Insurance", desc: "Active vehicle insurance certificate" },
];

// Helper to compress images client-side for lightning-fast uploads & clean storage
function compressImage(file, maxWidth = 1200, quality = 0.8) {
  return new Promise((resolve) => {
    const reader = new FileReader();
    reader.readAsDataURL(file);
    reader.onload = (event) => {
      const img = new Image();
      img.src = event.target.result;
      img.onload = () => {
        const elem = document.createElement("canvas");
        let width = img.width;
        let height = img.height;

        if (width > maxWidth) {
          height = Math.round((height * maxWidth) / width);
          width = maxWidth;
        }

        elem.width = width;
        elem.height = height;
        const ctx = elem.getContext("2d");
        ctx.drawImage(img, 0, 0, width, height);
        const dataUrl = elem.toDataURL("image/jpeg", quality);
        resolve(dataUrl);
      };
    };
  });
}

// Convert dataURL to Blob for Firebase Storage
function dataURItoBlob(dataURI) {
  const byteString = atob(dataURI.split(',')[1]);
  const mimeString = dataURI.split(',')[0].split(':')[1].split(';')[0];
  const ab = new ArrayBuffer(byteString.length);
  const ia = new Uint8Array(ab);
  for (let i = 0; i < byteString.length; i++) {
    ia[i] = byteString.charCodeAt(i);
  }
  return new Blob([ab], { type: mimeString });
}

export default function CaptainRegisterPage() {
  const [step, setStep] = useState(1);
  const [loading, setLoading] = useState(false);
  const [loadingText, setLoadingText] = useState("");
  const [error, setError] = useState("");
  const [registeredCaptain, setRegisteredCaptain] = useState(null);

  // Form Fields
  const [formData, setFormData] = useState({
    name: "",
    email: "",
    phone: "",
    password: "",
    city: "Akola",
    vehicleType: "bike",
    vehicleModel: "",
    vehicleNumber: "",
  });

  // Uploaded Document Files & Previews
  const [documents, setDocuments] = useState({
    profilePhoto: null,
    aadhaarCard: null,
    drivingLicence: null,
    rcBook: null,
    insurance: null,
  });

  const handleInputChange = (e) => {
    setFormData((prev) => ({ ...prev, [e.target.name]: e.target.value }));
    if (error) setError("");
  };

  const handleFileChange = async (key, file) => {
    if (!file) return;
    try {
      const compressedDataUrl = await compressImage(file);
      setDocuments((prev) => ({
        ...prev,
        [key]: {
          file,
          previewUrl: compressedDataUrl,
          fileName: file.name,
          size: `${Math.round(file.size / 1024)} KB`
        }
      }));
      if (error) setError("");
    } catch (err) {
      console.error("Failed to read image", err);
      setError("Failed to read selected image. Please try another file.");
    }
  };

  const handleRemoveDoc = (key) => {
    setDocuments((prev) => ({ ...prev, [key]: null }));
  };

  // Step 1 Validation
  const validateStep1 = () => {
    if (!formData.name.trim()) return "Full Name is required";
    if (!formData.email.trim()) return "Email address is required";
    if (!formData.email.includes("@")) return "Enter a valid email address";
    if (!formData.phone.trim()) return "Mobile number is required";
    if (formData.phone.replace(/\D/g, "").length < 10) return "Enter a valid 10-digit mobile number";
    if (!formData.password || formData.password.length < 6) return "Password must be at least 6 characters";
    return null;
  };

  // Step 2 Validation
  const validateStep2 = () => {
    if (!formData.vehicleType) return "Please choose a vehicle category";
    if (!formData.vehicleModel.trim()) return "Vehicle Model & Make is required (e.g. Honda Activa, Swift)";
    if (!formData.vehicleNumber.trim()) return "Vehicle Number Plate is required (e.g. MH 28 AB 1234)";
    return null;
  };

  // Step 3 Validation
  const validateStep3 = () => {
    for (const docItem of REQUIRED_DOCS) {
      if (!documents[docItem.key]) {
        return `Please upload your ${docItem.label} to proceed`;
      }
    }
    return null;
  };

  const handleNext = () => {
    if (step === 1) {
      const err = validateStep1();
      if (err) { setError(err); return; }
      setError("");
      setStep(2);
    } else if (step === 2) {
      const err = validateStep2();
      if (err) { setError(err); return; }
      setError("");
      setStep(3);
    }
  };

  const handleBack = () => {
    setError("");
    if (step > 1) setStep(step - 1);
  };

  // Final Submission to Firebase
  const handleSubmit = async (e) => {
    e.preventDefault();
    const docError = validateStep3();
    if (docError) { setError(docError); return; }

    setError("");
    setLoading(true);

    try {
      // 1. Create Firebase Auth user
      setLoadingText("Creating Captain account...");
      const userCredential = await createUserWithEmailAndPassword(
        auth,
        formData.email.trim(),
        formData.password
      );
      const user = userCredential.user;

      // Update auth display name
      try {
        await updateProfile(user, { displayName: formData.name.trim() });
      } catch (_) {}

      // 2. Upload Documents to Firebase Storage with Fallback
      setLoadingText("Uploading KYC documents...");
      const uploadedUrls = {};

      for (const docItem of REQUIRED_DOCS) {
        const docData = documents[docItem.key];
        let finalUrl = docData.previewUrl; // default fallback

        try {
          if (storage) {
            const fileBlob = dataURItoBlob(docData.previewUrl);
            const storagePath = `kyc_documents/${user.uid}/${docItem.key}_${Date.now()}.jpg`;
            const fileRef = ref(storage, storagePath);
            await uploadBytes(fileRef, fileBlob);
            finalUrl = await getDownloadURL(fileRef);
          }
        } catch (storageErr) {
          console.warn(`Storage upload failed for ${docItem.key}, using compressed data fallback:`, storageErr);
        }

        uploadedUrls[docItem.key] = finalUrl;
      }

      // 3. Save Captain document in Firestore `users/{uid}`
      setLoadingText("Registering with Admin Dashboard...");
      const cleanPlate = formData.vehicleNumber.trim().toUpperCase();

      const captainPayload = {
        uid: user.uid,
        name: formData.name.trim(),
        email: formData.email.trim(),
        phone: formData.phone.trim(),
        role: "captain",
        verificationStatus: "pending", // Appears in Pending tab of Admin Dashboard & Admin App
        vehicleType: formData.vehicleType,
        vehicleNumber: cleanPlate,
        registrationNumber: cleanPlate,
        vehicleDetails: {
          type: formData.vehicleType,
          model: formData.vehicleModel.trim(),
          registrationNumber: cleanPlate,
          rcBookUrl: uploadedUrls.rcBook,
          insuranceUrl: uploadedUrls.insurance,
        },
        profilePictureUrl: uploadedUrls.profilePhoto,
        aadhaarCardUrl: uploadedUrls.aadhaarCard,
        drivingLicenceUrl: uploadedUrls.drivingLicence,
        rcBookUrl: uploadedUrls.rcBook,
        insuranceUrl: uploadedUrls.insurance,
        vehicleInsuranceUrl: uploadedUrls.insurance,
        city: formData.city,
        ratingScore: 5.0,
        ratingCount: 0,
        isOnline: false,
        totalEarnings: 0,
        completedRidesCount: 0,
        createdAt: serverTimestamp(),
        submittedAt: serverTimestamp(),
      };

      await setDoc(doc(db, "users", user.uid), captainPayload);

      // 4. Optional: Post audit notification in admin_audit_logs
      try {
        await addDoc(collection(db, "admin_audit_logs"), {
          action: "captain_registration_submitted",
          targetId: user.uid,
          changes: {
            name: formData.name.trim(),
            vehicleType: formData.vehicleType,
            registrationNumber: cleanPlate,
            status: "pending"
          },
          adminEmail: "System Onboarding",
          createdAt: serverTimestamp()
        });
      } catch (_) {}

      // Success!
      setRegisteredCaptain({
        id: user.uid,
        name: formData.name.trim(),
        vehicleType: formData.vehicleType,
        registrationNumber: cleanPlate
      });

    } catch (err) {
      console.error("Captain Registration Error:", err);
      let msg = err.message || "Failed to register captain. Please try again.";
      if (err.code === "auth/email-already-in-use") {
        msg = "This email is already registered in Sarthi. Please use another email or contact support.";
      } else if (err.code === "auth/weak-password") {
        msg = "Password is too weak. Please use at least 6 characters.";
      }
      setError(msg);
    } finally {
      setLoading(false);
      setLoadingText("");
    }
  };

  return (
    <div className={styles.container}>
      <div className={styles.wrapper}>
        
        {/* Header */}
        <div className={styles.header}>
          <Link href="/captains" className={styles.backBtn}>
            <ArrowLeft size={16} /> Back to Captains Overview
          </Link>
          <div className={styles.badge}>
            <Shield size={12} /> Captain Onboarding Portal
          </div>
          <h1 className={styles.title}>Join Sarthi as a Captain</h1>
          <p className={styles.subtitle}>
            Register your vehicle, submit KYC documents, and start earning on your own schedule.
          </p>
        </div>

        {/* Stepper (Only when not finished) */}
        {!registeredCaptain && (
          <div className={styles.stepper}>
            <div 
              className={`${styles.stepItem} ${step === 1 ? styles.stepActive : ""} ${step > 1 ? styles.stepCompleted : ""}`}
              onClick={() => step > 1 && setStep(1)}
            >
              <div className={styles.stepNumber}>
                {step > 1 ? <Check size={16} /> : "1"}
              </div>
              <span className={styles.stepTitle}>Personal Info</span>
            </div>

            <div 
              className={`${styles.stepItem} ${step === 2 ? styles.stepActive : ""} ${step > 2 ? styles.stepCompleted : ""}`}
              onClick={() => step > 2 && setStep(2)}
            >
              <div className={styles.stepNumber}>
                {step > 2 ? <Check size={16} /> : "2"}
              </div>
              <span className={styles.stepTitle}>Vehicle Info</span>
            </div>

            <div className={`${styles.stepItem} ${step === 3 ? styles.stepActive : ""}`}>
              <div className={styles.stepNumber}>3</div>
              <span className={styles.stepTitle}>KYC Documents</span>
            </div>
          </div>
        )}

        {/* Success Screen */}
        {registeredCaptain ? (
          <div className={styles.successCard}>
            <div className={styles.successIconWrap}>
              <CheckCircle2 size={44} />
            </div>
            <h2 className={styles.successTitle}>Application Submitted!</h2>
            <p className={styles.successDesc}>
              Thank you, <strong>{registeredCaptain.name}</strong>. Your captain registration and KYC documents have been successfully sent to the <strong>Admin Dashboard</strong> and <strong>Admin App</strong> for review.
            </p>

            <div className={styles.metaBox}>
              <div className={styles.metaRow}>
                <span className={styles.metaLabel}>Captain ID</span>
                <span className={styles.metaValue}>{registeredCaptain.id.slice(0, 8).toUpperCase()}</span>
              </div>
              <div className={styles.metaRow}>
                <span className={styles.metaLabel}>Vehicle Type</span>
                <span className={styles.metaValue} style={{ textTransform: "capitalize" }}>{registeredCaptain.vehicleType}</span>
              </div>
              <div className={styles.metaRow}>
                <span className={styles.metaLabel}>Registration No.</span>
                <span className={styles.metaValue}>{registeredCaptain.registrationNumber}</span>
              </div>
              <div className={styles.metaRow}>
                <span className={styles.metaLabel}>Current Status</span>
                <span className={styles.statusPillPending}>
                  <span className={styles.statusDot}></span>
                  Pending Admin Verification
                </span>
              </div>
              <div className={styles.metaRow}>
                <span className={styles.metaLabel}>Expected Review Time</span>
                <span className={styles.metaValue} style={{ color: "var(--blue-600)" }}>2 – 4 Hours</span>
              </div>
            </div>

            <div className={styles.successButtons}>
              <Link href="/" className={styles.btnPrimary} style={{ textDecoration: "none" }}>
                Return to Home
              </Link>
              <Link href="/captains" className={styles.btnSecondary} style={{ textDecoration: "none" }}>
                Captains Page
              </Link>
            </div>
          </div>
        ) : (
          /* Form Content */
          <div className={styles.formBody}>
            {error && (
              <div className={styles.errorBanner}>
                <AlertCircle size={18} />
                <span>{error}</span>
              </div>
            )}

            {/* STEP 1: Personal Details */}
            {step === 1 && (
              <div>
                <h3 className={styles.sectionTitle}>Step 1: Personal Information</h3>
                <p className={styles.sectionDesc}>Enter your contact details to set up your Sarthi Captain profile.</p>

                <div className={styles.grid2}>
                  <div className={styles.formGroup}>
                    <label className={styles.label}>Full Name <span className={styles.req}>*</span></label>
                    <div className={styles.inputWrapper}>
                      <User size={18} className={styles.inputIcon} />
                      <input 
                        type="text" 
                        name="name" 
                        value={formData.name} 
                        onChange={handleInputChange} 
                        placeholder="e.g. Ramesh Sharma" 
                        className={styles.input} 
                        required 
                      />
                    </div>
                  </div>

                  <div className={styles.formGroup}>
                    <label className={styles.label}>Email Address <span className={styles.req}>*</span></label>
                    <div className={styles.inputWrapper}>
                      <Mail size={18} className={styles.inputIcon} />
                      <input 
                        type="email" 
                        name="email" 
                        value={formData.email} 
                        onChange={handleInputChange} 
                        placeholder="captain@example.com" 
                        className={styles.input} 
                        required 
                      />
                    </div>
                  </div>
                </div>

                <div className={styles.grid2}>
                  <div className={styles.formGroup}>
                    <label className={styles.label}>Mobile Phone Number <span className={styles.req}>*</span></label>
                    <div className={styles.inputWrapper}>
                      <Phone size={18} className={styles.inputIcon} />
                      <input 
                        type="tel" 
                        name="phone" 
                        value={formData.phone} 
                        onChange={handleInputChange} 
                        placeholder="10-digit mobile number" 
                        className={styles.input} 
                        required 
                      />
                    </div>
                    <span className={styles.hint}>Used for rider trip calls and OTP verification</span>
                  </div>

                  <div className={styles.formGroup}>
                    <label className={styles.label}>Create Password <span className={styles.req}>*</span></label>
                    <div className={styles.inputWrapper}>
                      <Lock size={18} className={styles.inputIcon} />
                      <input 
                        type="password" 
                        name="password" 
                        value={formData.password} 
                        onChange={handleInputChange} 
                        placeholder="Minimum 6 characters" 
                        className={styles.input} 
                        required 
                      />
                    </div>
                    <span className={styles.hint}>You will use this to sign into the Captain mobile app</span>
                  </div>
                </div>

                <div className={styles.formGroup}>
                  <label className={styles.label}>Operating City <span className={styles.req}>*</span></label>
                  <div className={styles.inputWrapper}>
                    <MapPin size={18} className={styles.inputIcon} />
                    <select 
                      name="city" 
                      value={formData.city} 
                      onChange={handleInputChange} 
                      className={styles.select}
                    >
                      <option value="Akola">Akola, Maharashtra</option>
                      <option value="Amravati">Amravati, Maharashtra</option>
                      <option value="Nagpur">Nagpur, Maharashtra</option>
                      <option value="Yavatmal">Yavatmal, Maharashtra</option>
                      <option value="Pune">Pune, Maharashtra</option>
                    </select>
                  </div>
                </div>

                <div className={styles.footerActions} style={{ justifyContent: "flex-end" }}>
                  <button type="button" onClick={handleNext} className={styles.btnPrimary}>
                    Continue to Vehicle Info <ArrowRight size={16} />
                  </button>
                </div>
              </div>
            )}

            {/* STEP 2: Vehicle Details */}
            {step === 2 && (
              <div>
                <h3 className={styles.sectionTitle}>Step 2: Vehicle Details</h3>
                <p className={styles.sectionDesc}>Select which vehicle you will drive and enter its official registration details.</p>

                <label className={styles.label} style={{ marginBottom: "10px" }}>
                  Select Vehicle Category <span className={styles.req}>*</span>
                </label>
                <div className={styles.vehicleGrid}>
                  {VEHICLE_OPTIONS.map((v) => (
                    <div
                      key={v.id}
                      className={`${styles.vehicleCard} ${formData.vehicleType === v.id ? styles.vehicleSelected : ""}`}
                      onClick={() => setFormData((p) => ({ ...p, vehicleType: v.id }))}
                    >
                      <span className={styles.vehicleEmoji}>{v.emoji}</span>
                      <div className={styles.vehicleName}>{v.name}</div>
                      <div className={styles.vehicleSub}>{v.desc}</div>
                    </div>
                  ))}
                </div>

                <div className={styles.grid2}>
                  <div className={styles.formGroup}>
                    <label className={styles.label}>Vehicle Model & Make <span className={styles.req}>*</span></label>
                    <input 
                      type="text" 
                      name="vehicleModel" 
                      value={formData.vehicleModel} 
                      onChange={handleInputChange} 
                      placeholder="e.g. Honda Activa 6G / Maruti Swift" 
                      className={styles.inputNoIcon} 
                      required 
                    />
                    <span className={styles.hint}>Brand name and model of your vehicle</span>
                  </div>

                  <div className={styles.formGroup}>
                    <label className={styles.label}>Number Plate / Registration No. <span className={styles.req}>*</span></label>
                    <input 
                      type="text" 
                      name="vehicleNumber" 
                      value={formData.vehicleNumber} 
                      onChange={handleInputChange} 
                      placeholder="e.g. MH 28 AB 1234" 
                      className={styles.inputNoIcon} 
                      style={{ textTransform: "uppercase", letterSpacing: "1px", fontWeight: "700" }} 
                      required 
                    />
                    <span className={styles.hint}>Format matching your official vehicle number plate</span>
                  </div>
                </div>

                <div className={styles.footerActions}>
                  <button type="button" onClick={handleBack} className={styles.btnSecondary}>
                    <ArrowLeft size={16} /> Back
                  </button>
                  <button type="button" onClick={handleNext} className={styles.btnPrimary}>
                    Continue to KYC Documents <ArrowRight size={16} />
                  </button>
                </div>
              </div>
            )}

            {/* STEP 3: KYC Documents Upload */}
            {step === 3 && (
              <div>
                <h3 className={styles.sectionTitle}>Step 3: Upload KYC Documents</h3>
                <p className={styles.sectionDesc}>
                  Please upload clear photos or scans of the 5 required documents. These will be verified in the Admin Dashboard.
                </p>

                <div className={styles.docGrid}>
                  {REQUIRED_DOCS.map((docItem) => {
                    const uploaded = documents[docItem.key];
                    return (
                      <div 
                        key={docItem.key} 
                        className={`${styles.docCard} ${uploaded ? styles.docCardUploaded : ""}`}
                      >
                        <div className={styles.docLeft}>
                          {uploaded ? (
                            <img 
                              src={uploaded.previewUrl} 
                              alt={docItem.label} 
                              className={styles.docThumbnail} 
                            />
                          ) : (
                            <div className={styles.docIconPlaceholder}>
                              <UploadCloud size={24} />
                            </div>
                          )}

                          <div className={styles.docInfo}>
                            <h4>{docItem.label} <span className={styles.req}>*</span></h4>
                            <p>{uploaded ? `${uploaded.fileName} (${uploaded.size})` : docItem.desc}</p>
                            {uploaded && (
                              <span className={styles.docBadgeOk}>
                                <Check size={14} /> Ready to Submit
                              </span>
                            )}
                          </div>
                        </div>

                        <div style={{ display: "flex", alignItems: "center" }}>
                          <label className={styles.uploadBtn}>
                            <UploadCloud size={16} />
                            <span>{uploaded ? "Change" : "Upload File"}</span>
                            <input 
                              type="file" 
                              accept="image/*" 
                              className={styles.fileInput} 
                              onChange={(e) => handleFileChange(docItem.key, e.target.files?.[0])}
                            />
                          </label>

                          {uploaded && (
                            <button 
                              type="button" 
                              className={styles.removeBtn}
                              onClick={() => handleRemoveDoc(docItem.key)}
                              title="Remove file"
                            >
                              <Trash2 size={16} />
                            </button>
                          )}
                        </div>
                      </div>
                    );
                  })}
                </div>

                <div className={styles.footerActions}>
                  <button type="button" onClick={handleBack} className={styles.btnSecondary} disabled={loading}>
                    <ArrowLeft size={16} /> Back
                  </button>
                  <button 
                    type="button" 
                    onClick={handleSubmit} 
                    className={styles.btnPrimary} 
                    disabled={loading}
                  >
                    {loading ? (
                      <>
                        <Clock size={16} className="animate-spin" />
                        <span>{loadingText || "Submitting..."}</span>
                      </>
                    ) : (
                      <>
                        <span>Submit for Admin Approval</span>
                        <CheckCircle2 size={18} />
                      </>
                    )}
                  </button>
                </div>
              </div>
            )}
          </div>
        )}

      </div>
    </div>
  );
}
