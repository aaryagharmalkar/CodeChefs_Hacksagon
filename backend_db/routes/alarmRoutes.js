import express from "express";
import { authMiddleware } from "../controllers/patientController.js";
import { getTodayUpcomingAlarms, getAlarmDetailsById, markAlarmTaken, markAlarmMissed } from "../controllers/alarmController.js";

const router = express.Router();

router.get("/upcoming", authMiddleware, getTodayUpcomingAlarms);
router.get("/details", authMiddleware, getAlarmDetailsById);

router.post("/taken", markAlarmTaken);
router.post("/snooze", markAlarmMissed);

export default router;