import express from "express";
import {
  authMiddleware,
  signup,
  signin,
  fetchPatientInfo,
  updateMealTimes,
  getAlerts,
} from "../controllers/patientController.js";

const router = express.Router();

router.get("/", authMiddleware, fetchPatientInfo);
router.get("/alerts", authMiddleware, getAlerts);

router.post("/signup", signup);
router.post("/signin", signin);

router.put("/updateTimes", authMiddleware, updateMealTimes);

export default router;
