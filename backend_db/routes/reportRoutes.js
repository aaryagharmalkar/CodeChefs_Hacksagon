import express from "express";
import {uploadResults, fetchReports} from "../controllers/reportController.js";
import { authMiddleware } from "../controllers/patientController.js";

const router = express.Router();

router.post("/upload", authMiddleware, uploadResults);
router.get("/history", authMiddleware, fetchReports);

export default router;
