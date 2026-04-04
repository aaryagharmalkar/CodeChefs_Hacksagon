import express from "express";
import { addMedicine, fetchMedicinesByDay } from "../controllers/medicineController.js";
import { authMiddleware } from "../controllers/patientController.js";

const router = express.Router();

router.post("/add", authMiddleware, addMedicine);
router.get("/fetch", authMiddleware, fetchMedicinesByDay);

export default router;