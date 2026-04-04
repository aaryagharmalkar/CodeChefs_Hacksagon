import express from "express";
import multer from "multer";
import path from "path";
import fs from "fs";
import {
  processAudioCognitive,
  getAssessmentHistory,
} from "../controllers/cookieTheftController.js";

const router = express.Router();

// Ensure temp/audio directory exists
const audioDir = path.join(process.cwd(), "temp/audio");
if (!fs.existsSync(audioDir)) {
  fs.mkdirSync(audioDir, { recursive: true });
}

// Configure multer for audio file uploads
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, audioDir);
  },
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname);
    cb(null, `audio_${Date.now()}${ext}`);
  },
});

const upload = multer({
  storage: storage,
  limits: { fileSize: 50 * 1024 * 1024 }, // 50 MB max
  fileFilter: (req, file, cb) => {
    // Accept audio/* MIME types OR .wav files
    const isAudioMime = file.mimetype.startsWith("audio/");
    const isWavFile = file.originalname.toLowerCase().endsWith(".wav");

    if (isAudioMime || isWavFile) {
      cb(null, true);
    } else {
      console.log("File rejected. MIME:", file.mimetype, "Name:", file.originalname);
      cb(new Error("Only audio files are allowed"));
    }
  },
});

/**
 * POST /api/assessment/cookie-theft
 * Process audio file through cognitive pipeline
 * File: audio file (required)
 * Body: { patientId: string }
 */
router.post("/cookie-theft", upload.single("audio"), processAudioCognitive);

/**
 * GET /api/assessment/cookie-theft/:patientId
 * Get assessment history for a patient
 */
router.get("/cookie-theft/:patientId", getAssessmentHistory);

export default router;
