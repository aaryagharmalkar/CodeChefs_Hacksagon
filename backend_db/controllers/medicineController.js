import Medicine from "../models/medicine.js";

// ─────────────────────────────────────────────
// ADD MEDICINE
// ─────────────────────────────────────────────

/**
 * POST /api/medicine/add
 * Protected: requires valid JWT.
 *
 * req.body:
 *   {
 *     name        : string
 *     type        : "tablet" | "syrup" | "other"
 *     intakeTimes : string[]   ("Before Breakfast" etc.)
 *     customTimes : string[]   ("HH:MM AM/PM" or "HH:MM")
 *     frequency   : "Daily" | "Alternate Days" | "Specific Days"
 *     days        : string[]   (only when frequency="Specific Days")
 *     doseCount   : number
 *     durationDays: number
 *   }
 */
export const addMedicine = async (req, res) => {
  try {
    const patientId = req.user.id;

    const {
      name,
      type,
      intakeTimes = [],
      customTimes = [],
      frequency,
      days,
      doseCount,
      durationDays,
    } = req.body;

    const ALARM_LABEL_TO_CODE = {
      "Before Breakfast": 1,
      "After Breakfast": 2,
      "Before Lunch": 3,
      "After Lunch": 4,
      "Before Dinner": 5,
      "After Dinner": 6,
    };

    const alarmKeys = [];
    for (const label of intakeTimes) {
      const code = ALARM_LABEL_TO_CODE[label];
      if (!code) {
        return res.status(400).json({ message: `Invalid intake time: ${label}` });
      }
      alarmKeys.push(code);
    }

    const medicine = await Medicine.create({
      patientId,
      name,
      type,
      alarmKeys,
      customTimes,
      frequency,
      days,
      doseCount,
      durationDays,
    });

    res.status(201).json({
      success: true,
      message: "Medicine added successfully",
      medicine,
    });
  } catch (error) {
    console.error("❌ [addMedicine]", error);
    res.status(500).json({
      success: false,
      message: "Failed to add medicine",
      error: error.message,
    });
  }
};

// ─────────────────────────────────────────────
// FETCH ALL MEDICINES FOR PATIENT
// ─────────────────────────────────────────────

/**
 * GET /api/medicine/all
 * Protected: requires valid JWT.
 *
 * Returns every medicine record for the authenticated patient.
 */
export const getAllMedicines = async (req, res) => {
  try {
    const patientId = req.user.id;
    const medicines = await Medicine.find({ patientId }).sort({ createdAt: -1 });
    res.json(medicines);
  } catch (error) {
    console.error("❌ [getAllMedicines]", error);
    res.status(500).json({
      success: false,
      message: "Failed to fetch medicines",
      error: error.message,
    });
  }
};

// ─────────────────────────────────────────────
// FETCH MEDICINES BY DAY
// ─────────────────────────────────────────────

/**
 * GET /api/medicine/fetch?date=YYYY-MM-DD
 * Protected: requires valid JWT.
 *
 * Returns all medicines that are active on the given date, based on
 * createdAt + durationDays window and frequency rules.
 *
 * Each returned medicine is enriched with:
 *   intakeTimes : string[]   (human-readable labels)
 *   customTimes : string[]   (as stored)
 */
export const fetchMedicinesByDay = async (req, res) => {
  try {
    const patientId = req.user.id;
    const { date } = req.query;

    if (!date) {
      return res.status(400).json({
        success: false,
        message: "date query param required (YYYY-MM-DD)",
      });
    }

    const targetDate = new Date(date);
    // Normalise to midnight UTC so day arithmetic is clean
    targetDate.setUTCHours(0, 0, 0, 0);

    const CODE_TO_LABEL = {
      1: "Before Breakfast",
      2: "After Breakfast",
      3: "Before Lunch",
      4: "After Lunch",
      5: "Before Dinner",
      6: "After Dinner",
    };

    const DAY_NAMES = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

    const allMedicines = await Medicine.find({ patientId });

    const active = allMedicines.filter((med) => {
      const start = new Date(med.createdAt);
      start.setUTCHours(0, 0, 0, 0);

      const end = new Date(start);
      end.setUTCDate(end.getUTCDate() + med.durationDays - 1);

      // Must be within the duration window
      if (targetDate < start || targetDate > end) return false;

      const daysSinceStart = Math.round(
        (targetDate - start) / (1000 * 60 * 60 * 24)
      );

      if (med.frequency === "Daily") return true;

      if (med.frequency === "Alternate Days") {
        return daysSinceStart % 2 === 0;
      }

      if (med.frequency === "Specific Days") {
        const dayName = DAY_NAMES[targetDate.getUTCDay()];
        return (med.days ?? []).includes(dayName);
      }

      return false;
    });

    const result = active.map((med) => ({
      ...med.toObject(),
      intakeTimes: (med.alarmKeys ?? []).map((k) => CODE_TO_LABEL[k] ?? "Unknown"),
    }));

    res.json({
      success: true,
      date,
      count: result.length,
      medicines: result,
    });
  } catch (error) {
    console.error("❌ [fetchMedicinesByDay]", error);
    res.status(500).json({
      success: false,
      message: "Failed to fetch medicines for selected date",
    });
  }
};

// ─────────────────────────────────────────────
// DELETE MEDICINE
// ─────────────────────────────────────────────

/**
 * DELETE /api/medicine/:id
 * Protected: requires valid JWT.
 *
 * Deletes a medicine by its _id, only if it belongs to the authenticated patient.
 */
export const deleteMedicine = async (req, res) => {
  try {
    const patientId = req.user.id;
    const { id } = req.params;

    const medicine = await Medicine.findOneAndDelete({ _id: id, patientId });

    if (!medicine) {
      return res.status(404).json({
        success: false,
        message: "Medicine not found or not authorized",
      });
    }

    res.json({ success: true, message: "Medicine deleted successfully" });
  } catch (error) {
    console.error("❌ [deleteMedicine]", error);
    res.status(500).json({
      success: false,
      message: "Failed to delete medicine",
      error: error.message,
    });
  }
};