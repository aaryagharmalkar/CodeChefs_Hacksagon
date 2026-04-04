import express from "express";
import {
  addMedicine,
  getAllMedicines,
  fetchMedicinesByDay,
  deleteMedicine,
} from "../controllers/medicineController.js";
import { authMiddleware } from "../controllers/patientController.js";

const router = express.Router();

router.post("/add", authMiddleware, addMedicine);
router.get("/all", authMiddleware, getAllMedicines);
router.get("/fetch", authMiddleware, fetchMedicinesByDay);
router.delete("/:id", authMiddleware, deleteMedicine);

export default router;