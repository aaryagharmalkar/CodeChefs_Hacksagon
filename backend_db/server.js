import express from "express";
import mongoose from "mongoose";
import dotenv from "dotenv";

import patientRoutes from "./routes/patientRoutes.js";
import medicineRoutes from "./routes/medicineRoutes.js";
import alarmRoutes from "./routes/alarmRoutes.js";
import reportRoutes from "./routes/reportRoutes.js";

dotenv.config();

const app = express();
app.use(express.json());

// ── MongoDB connection ──
mongoose
  .connect(process.env.MONGO_URI)
  .then(() => console.log("✅ MongoDB connected"))
  .catch((err) => console.error("❌ MongoDB connection error:", err));

// ── Routes ──
app.use("/api/patient", patientRoutes);     // signup, signin, profile, meal times, alerts
app.use("/api/medicine", medicineRoutes);   // add medicine, fetch by day
app.use("/api/alarm", alarmRoutes);         // upcoming alarms, details, taken, missed
app.use("/api/report", reportRoutes);      // health assessments, reports

app.listen(5000, "0.0.0.0", () => console.log("🚀 Server running on port 5000"));