import express from "express";
import {
  scoreCookieTheft,
  getCookieTheftHistory,
} from "../controllers/cookieTheftController.js";

const router = express.Router();

/**
 * POST /api/assessment/cookie-theft
 * Score a cookie theft transcript
 * Body: { transcript: string, patientId: string }
 */
router.post("/cookie-theft", scoreCookieTheft);

/**
 * GET /api/assessment/cookie-theft/:patientId
 * Get cookie theft scoring history for a patient
 */
router.get("/cookie-theft/:patientId", getCookieTheftHistory);

export default router;