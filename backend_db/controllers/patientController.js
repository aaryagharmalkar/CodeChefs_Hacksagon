import bcrypt from "bcrypt";
import jwt from "jsonwebtoken";

import Patient from "../models/patient.js";
import Medicine from "../models/medicine.js";

// ─────────────────────────────────────────────
// AUTH MIDDLEWARE
// ─────────────────────────────────────────────

/**
 * authMiddleware
 * Verifies the JWT token attached to every protected request.
 *
 * Header:
 *   Authorization: Bearer <token>
 */
export const authMiddleware = (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader) {
      console.warn("⚠️  [authMiddleware] No Authorization header provided");
      return res.status(401).json({ message: "No token" });
    }

    const token = authHeader.split(" ")[1]; // Bearer <token>
    const decoded = jwt.verify(token, process.env.JWT_SECRET);

    req.user = decoded;
    console.log(`🔐 [authMiddleware] Token verified for user id=${decoded.id}`);
    next();
  } catch (err) {
    console.warn("⚠️  [authMiddleware] Invalid or expired token →", err.message);
    return res.status(401).json({ message: "Invalid token" });
  }
};

// ─────────────────────────────────────────────
// SIGNUP
// ─────────────────────────────────────────────

/**
 * POST /api/patient/signup
 * req.body:
 *   {
 *     name     : string  (required)
 *     phone    : string  (required, must be unique)
 *     password : string  (required, will be hashed)
 *   }
 *
 * res 200:
 *   {
 *     token   : string   (JWT, expires in 5h)
 *     patient : { id, phone, name }
 *   }
 */
export const signup = async (req, res) => {
  try {
    const { name, age, gender, phone, password } = req.body;
    console.log(`🚀 [signup] Attempting signup → name="${name}", phone="${phone}"`);

    const existingPatient = await Patient.findOne({ phone });
    if (existingPatient) {
      console.warn(`⚠️  [signup] phone "${phone}" is already registered`);
      return res.status(400).json({ message: "Patient already exists" });
    }

    const hashedPassword = await bcrypt.hash(password, 10);

    const newPatient = new Patient({ name, age, gender, phone, password: hashedPassword });
    const savedPatient = await newPatient.save();
    console.log(`📝 [signup] Patient saved to DB → id=${savedPatient._id}`);

    const token = jwt.sign(
      { id: savedPatient._id, phone: savedPatient.phone },
      process.env.JWT_SECRET,
      { expiresIn: "5h" }
    );

    console.log(`✅ [signup] Signup successful → id=${savedPatient._id}`);
    res.json({
      token,
      patient: {
        id: savedPatient._id,
        phone: savedPatient.phone,
        name: savedPatient.name,
      },
    });
  } catch (err) {
    console.error("❌ [signup] Unexpected error:", err);
    res.status(500).json({
      message: "Server error",
      error: err.message,
      stack: err.stack,
    });
  }
};

// ─────────────────────────────────────────────
// SIGNIN
// ─────────────────────────────────────────────

/**
 * POST /api/patient/signin
 *
 * req.body:
 *   {
 *     phone    : string  (required)
 *     password : string  (required)
 *   }
 *
 * res 200:
 *   {
 *     token   : string   (JWT, expires in 5h)
 *     patient : { id, phone, name }
 *   }
 */
export const signin = async (req, res) => {
  try {
    const { phone, password } = req.body;
    console.log(`🚀 [signin] Attempting signin → phone="${phone}"`);

    const patient = await Patient.findOne({ phone });
    if (!patient) {
      console.warn(`⚠️  [signin] No patient found for phone="${phone}"`);
      return res.status(404).json({ message: "Patient not found" });
    }

    const isMatch = await bcrypt.compare(password, patient.password);
    if (!isMatch) {
      console.warn(`⚠️  [signin] Wrong password for phone="${phone}"`);
      return res.status(400).json({ message: "Invalid credentials" });
    }

    const token = jwt.sign(
      { id: patient._id, phone: patient.phone, name: patient.name },
      process.env.JWT_SECRET,
      { expiresIn: "5h" }
    );

    console.log(`✅ [signin] Signin successful → id=${patient._id}`);
    res.json({
      token,
      patient: { id: patient._id, phone: patient.phone, name: patient.name },
    });
  } catch (err) {
    console.error("❌ [signin] Unexpected error:", err);
    res.status(500).json({
      message: "Server error",
      error: err.message,
      stack: err.stack,
    });
  }
};

// ─────────────────────────────────────────────
// FETCH PATIENT INFO
// ─────────────────────────────────────────────

/**
 * GET /api/patient/
 * Protected: requires valid JWT.
 *
 * req.user: { id, phone, name }  (injected by authMiddleware)
 *
 * res 200: Patient document (password excluded)
 *   {
 *     _id, name, phone, mealTimes, createdAt, updatedAt
 *   }
 */
export const fetchPatientInfo = async (req, res) => {
  try {
    const patientId = req.user.id;
    console.log(`🚀 [fetchPatientInfo] Fetching profile → id=${patientId}`);

    const patient = await Patient.findById(patientId).select("-password");
    if (!patient) {
      console.warn(`⚠️  [fetchPatientInfo] No patient found for id=${patientId}`);
      return res.status(404).json({ message: "Patient not found" });
    }

    console.log(`✅ [fetchPatientInfo] Profile fetched → id=${patientId}`);
    res.json(patient);
  } catch (err) {
    console.error("❌ [fetchPatientInfo] Unexpected error:", err);
    res.status(500).json({ message: "Server error" });
  }
};
