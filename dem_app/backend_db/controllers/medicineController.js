import Medicine from "../models/medicine.js";
import Alarm from "../models/Alarm.js";
import Patient from "../models/patient.js";

// ─────────────────────────────────────────────
// TIME & DATE HELPERS
// ─────────────────────────────────────────────

/**
 * parseTime12hToMinutes
 * Converts a 12-hour time string to total minutes since midnight.
 * e.g. "09:00 AM" → 540,  "01:30 PM" → 810
 *
 * @param  {string} timeStr  e.g. "09:00 AM"
 * @returns {number}
 */
function parseTime12hToMinutes(timeStr) {
  const [time, meridian] = timeStr.split(" ");
  let [hours, minutes] = time.split(":").map(Number);

  if (meridian === "PM" && hours !== 12) hours += 12;
  if (meridian === "AM" && hours === 12) hours = 0;

  return hours * 60 + minutes;
}

/**
 * minutesToHHMM
 * Converts total minutes since midnight to a 12-hour time string.
 * Wraps safely past midnight using modulo.
 * e.g. 540 → "09:00 AM",  810 → "01:30 PM"
 *
 * @param  {number} minutes
 * @returns {string}
 */
function minutesToHHMM(minutes) {
  minutes = (minutes + 1440) % 1440;

  let h = Math.floor(minutes / 60);
  const m = minutes % 60;

  const meridian = h >= 12 ? "PM" : "AM";
  h = h % 12;
  if (h === 0) h = 12;

  return `${String(h).padStart(2, "0")}:${String(m).padStart(2, "0")} ${meridian}`;
}

/**
 * addMinutes
 * Shifts a 12-hour time string by a delta (positive or negative) in minutes.
 * e.g. addMinutes("09:00 AM", -15) → "08:45 AM"
 *
 * @param  {string} timeStr
 * @param  {number} delta
 * @returns {string}
 */
function addMinutes(timeStr, delta) {
  const mins = parseTime12hToMinutes(timeStr);
  return minutesToHHMM(mins + delta);
}

/**
 * normalizeMealTimes
 * Converts the mealTimes array from the Patient document into a plain object
 * keyed by meal name for easy lookup.
 * e.g. [{ meal: "breakfast", time: "09:00 AM" }] → { breakfast: "09:00 AM" }
 *
 * @param  {Array<{ meal: string, time: string }>} mealTimesArr
 * @returns {Object}
 */
function normalizeMealTimes(mealTimesArr) {
  const obj = {};
  for (const m of mealTimesArr) {
    obj[m.meal] = m.time;
  }
  return obj;
}

/**
 * resolveAlarmTime
 * Maps a standard alarm code (1–6) to its actual clock time based on
 * the patient's meal times.
 *
 * Alarm codes:
 *   1 → Before Breakfast  (-15 min)
 *   2 → After Breakfast   (+30 min)
 *   3 → Before Lunch      (-15 min)
 *   4 → After Lunch       (+30 min)
 *   5 → Before Dinner     (-15 min)
 *   6 → After Dinner      (+30 min)
 *
 * @param  {number} alarmCode
 * @param  {Array}  mealTimesArr
 * @returns {string}  e.g. "08:45 AM"
 */
function resolveAlarmTime(alarmCode, mealTimesArr) {
  const mealTimes = normalizeMealTimes(mealTimesArr);

  switch (alarmCode) {
    case 1: return addMinutes(mealTimes.breakfast, -15);
    case 2: return addMinutes(mealTimes.breakfast, +30);
    case 3: return addMinutes(mealTimes.lunch, -15);
    case 4: return addMinutes(mealTimes.lunch, +30);
    case 5: return addMinutes(mealTimes.dinner, -15);
    case 6: return addMinutes(mealTimes.dinner, +30);
    default:
      throw new Error(`Invalid alarm code: ${alarmCode}`);
  }
}

/**
 * timeToDeterministicInt32
 * Hashes a time string to a stable 32-bit integer for use as a custom alarm code.
 * Same time string always produces the same code.
 *
 * @param  {string} time  e.g. "10:30 AM"
 * @returns {number}
 */
function timeToDeterministicInt32(time) {
  let hash = 0;
  for (let i = 0; i < time.length; i++) {
    hash = (hash << 5) - hash + time.charCodeAt(i);
    hash |= 0; // force 32-bit integer
  }
  return Math.abs(hash);
}

/**
 * convert24hTo12h
 * Converts a 24-hour time string to a 12-hour time string.
 * e.g. "18:30" → "06:30 PM"
 *
 * @param  {string} time24  e.g. "18:30"
 * @returns {string}
 */
function convert24hTo12h(time24) {
  let [h, m] = time24.split(":").map(Number);

  const meridian = h >= 12 ? "PM" : "AM";
  h = h % 12;
  if (h === 0) h = 12;

  return `${String(h).padStart(2, "0")}:${String(m).padStart(2, "0")} ${meridian}`;
}

/**
 * formatDate
 * Formats a Date object as "YYYY-MM-DD".
 *
 * @param  {Date} date
 * @returns {string}
 */
function formatDate(date) {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, "0");
  const d = String(date.getDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

/**
 * addDays
 * Returns a new Date shifted by the given number of days.
 *
 * @param  {Date}   date
 * @param  {number} days
 * @returns {Date}
 */
function addDays(date, days) {
  const d = new Date(date);
  d.setDate(d.getDate() + days);
  return d;
}

/**
 * generateDailyDates
 * Generates an array of consecutive date strings starting from startDate.
 * Used for medicines with frequency = "Daily".
 *
 * @param  {Date}   startDate
 * @param  {number} durationDays
 * @returns {string[]}  e.g. ["2024-01-01", "2024-01-02", ...]
 */
function generateDailyDates(startDate, durationDays) {
  const dates = [];
  for (let i = 0; i < durationDays; i++) {
    dates.push(formatDate(addDays(startDate, i)));
  }
  return dates;
}

/**
 * generateAlternateDates
 * Generates date strings every other day (skip 1 day between doses).
 * Used for medicines with frequency = "Alternate Days".
 * Note: uses doseCount (not durationDays) as the number of actual dose dates.
 *
 * @param  {Date}   startDate
 * @param  {number} doseCount
 * @returns {string[]}
 */
function generateAlternateDates(startDate, doseCount) {
  const dates = [];
  let currentDate = new Date(startDate);

  for (let i = 0; i < doseCount; i++) {
    dates.push(formatDate(currentDate));
    currentDate = addDays(currentDate, 2);
  }

  return dates;
}

/**
 * generateSpecificDayDates
 * Generates date strings only for allowed weekdays within the duration window.
 * Used for medicines with frequency = "Specific Days".
 *
 * @param  {Date}     startDate
 * @param  {number}   durationDays   — total calendar days to scan
 * @param  {string[]} allowedDays    — e.g. ["Mon", "Wed", "Fri"]
 * @returns {string[]}
 */
function generateSpecificDayDates(startDate, durationDays, allowedDays) {
  const dates = [];
  let current = new Date(startDate);
  const dayMap = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

  for (let i = 0; i < durationDays; i++) {
    const day = dayMap[current.getDay()];
    if (allowedDays.includes(day)) {
      dates.push(formatDate(current));
    }
    current = addDays(current, 1);
  }

  return dates;
}

// ─────────────────────────────────────────────
// ATTACH ALARMS TO MEDICINE (internal helper)
// ─────────────────────────────────────────────

/**
 * attachAlarmsToMedicine
 * Internal helper — not an Express handler.
 *
 * Creates or updates Alarm documents for each alarm code and custom time,
 * pushing the new medicine's schedule dates into the appropriate alarm entry.
 * Uses upsert so alarms are shared across medicines that ring at the same time.
 *
 * @param {Object}   params
 * @param {string}   params.patientId
 * @param {Document} params.medicine     — the newly created Medicine document
 * @param {number[]} params.alarmCodes   — standard codes 1–6
 * @param {string[]} params.customTimes  — custom time strings ("HH:MM AM/PM" or "HH:MM")
 */
const attachAlarmsToMedicine = async ({ patientId, medicine, alarmCodes, customTimes }) => {
  console.log(`🚀 [attachAlarmsToMedicine] Attaching alarms → patientId=${patientId}, medicineId=${medicine._id}`);
  console.log(`📋 [attachAlarmsToMedicine] Standard alarm codes: [${alarmCodes}], custom times: [${customTimes}]`);

  const patient = await Patient.findById(patientId);
  if (!patient) throw new Error(`Patient not found for id=${patientId}`);

  const startDate = new Date();
  let dates = [];

  if (medicine.frequency === "Daily") {
    dates = generateDailyDates(startDate, medicine.durationDays);
    console.log(`📅 [attachAlarmsToMedicine] Daily schedule → ${dates.length} date(s) generated`);
  }

  if (medicine.frequency === "Alternate Days") {
    dates = generateAlternateDates(startDate, medicine.durationDays);
    console.log(`📅 [attachAlarmsToMedicine] Alternate Days schedule → ${dates.length} date(s) generated`);
  }

  if (medicine.frequency === "Specific Days") {
    dates = generateSpecificDayDates(startDate, medicine.durationDays, medicine.days);
    console.log(`📅 [attachAlarmsToMedicine] Specific Days (${medicine.days}) schedule → ${dates.length} date(s) generated`);
  }

  // ── Standard alarms ──
  for (const code of alarmCodes) {
    const resolvedTime = resolveAlarmTime(code, patient.mealTimes);
    console.log(`⏰ [attachAlarmsToMedicine] Upserting standard alarm → code=${code}, time=${resolvedTime}`);

    await Alarm.findOneAndUpdate(
      { patientId, alarmCode: code },
      {
        $setOnInsert: {
          patientId,
          alarmCode: code,
          isCustom: false,
          time: resolvedTime,
        },
        $push: {
          medicines: { medicineId: medicine._id, dates },
        },
      },
      { upsert: true }
    );
  }

  // ── Custom alarms ──
  if (customTimes?.length > 0) {
    for (const time of customTimes) {
      const time12h =
        time.includes("AM") || time.includes("PM") ? time : convert24hTo12h(time);

      const customCode = timeToDeterministicInt32(time12h);
      console.log(`⏰ [attachAlarmsToMedicine] Upserting custom alarm → time=${time12h}, code=${customCode}`);

      await Alarm.findOneAndUpdate(
        { patientId, alarmCode: customCode },
        {
          $setOnInsert: {
            patientId,
            alarmCode: customCode,
            time: time12h,
            isCustom: true,
          },
          $push: {
            medicines: { medicineId: medicine._id, dates },
          },
        },
        { upsert: true }
      );

      medicine.alarmKeys.push(customCode);
    }

    await medicine.save();
    console.log(`💾 [attachAlarmsToMedicine] Custom alarm keys saved to medicine document`);
  }

  console.log(`✅ [attachAlarmsToMedicine] All alarms attached successfully → medicineId=${medicine._id}`);
};

// ─────────────────────────────────────────────
// ADD MEDICINE
// ─────────────────────────────────────────────

/**
 * POST /api/medicine/add
 * Protected: requires valid JWT.
 *
 * Creates a new Medicine record for the authenticated patient, then creates
 * or updates the corresponding Alarm documents with the medicine's schedule dates.
 *
 * req.user: { id }  (injected by authMiddleware)
 *
 * req.body:
 *   {
 *     name        : string    (required)
 *     type        : "tablet" | "syrup" | "other"  (required)
 *     intakeTimes : string[]  (standard labels — see ALARM_LABEL_TO_CODE below)
 *     customTimes : string[]  (optional — "HH:MM AM/PM" or "HH:MM" 24h)
 *     frequency   : "Daily" | "Alternate Days" | "Specific Days"  (required)
 *     days        : string[]  (required when frequency="Specific Days" — e.g. ["Mon","Wed"])
 *     startDay    : string    (optional)
 *     doseCount   : number    (required)
 *     isCritical  : boolean   (optional, default false)
 *     durationDays: number    (required)
 *     photoUrl    : string    (optional)
 *   }
 *
 * intakeTimes valid labels:
 *   "Before Breakfast" | "After Breakfast" | "Before Lunch" |
 *   "After Lunch" | "Before Dinner" | "After Dinner"
 *
 * res 201:
 *   {
 *     success  : true
 *     message  : "Medicine added successfully"
 *     medicine : Medicine document
 *   }
 *
 * res 400: { message: "Invalid intake time: <label>" }
 * res 500: { success: false, message, error }
 */
export const addMedicine = async (req, res) => {
  try {
    const patientId = req.user.id;
    console.log(`🚀 [addMedicine] Request received → patientId=${patientId}`);

    const {
      name,
      type,
      intakeTimes = [],
      customTimes = [],
      frequency,
      days,
      startDay,
      doseCount,
      isCritical,
      durationDays,
      photoUrl,
    } = req.body;

    console.log(`📋 [addMedicine] Payload → name="${name}", type="${type}", frequency="${frequency}", durationDays=${durationDays}, doseCount=${doseCount}, isCritical=${isCritical}`);
    console.log(`📋 [addMedicine] intakeTimes=[${intakeTimes}], customTimes=[${customTimes}]`);

    // ── Convert intake time labels to alarm codes ──
    const ALARM_LABEL_TO_CODE = {
      "Before Breakfast": 1,
      "After Breakfast": 2,
      "Before Lunch": 3,
      "After Lunch": 4,
      "Before Dinner": 5,
      "After Dinner": 6,
    };

    const alarmCodes = [];
    for (const label of intakeTimes) {
      const code = ALARM_LABEL_TO_CODE[label];
      if (!code) {
        console.warn(`⚠️  [addMedicine] Unrecognised intake time label: "${label}"`);
        return res.status(400).json({ message: `Invalid intake time: ${label}` });
      }
      alarmCodes.push(code);
    }

    console.log(`🔢 [addMedicine] Resolved alarm codes: [${alarmCodes}]`);

    // ── Create Medicine document ──
    const medicine = await Medicine.create({
      patientId,
      name,
      type,
      alarmKeys: alarmCodes,
      frequency,
      days,
      startDay,
      doseCount,
      isCritical,
      durationDays,
      photoUrl,
    });

    console.log(`📝 [addMedicine] Medicine document created → medicineId=${medicine._id}`);

    // ── Attach alarms ──
    await attachAlarmsToMedicine({ patientId, medicine, alarmCodes, customTimes });

    console.log(`✅ [addMedicine] Medicine added successfully → medicineId=${medicine._id}`);
    res.status(201).json({
      success: true,
      message: "Medicine added successfully",
      medicine,
    });
  } catch (error) {
    console.error("❌ [addMedicine] Unexpected error:", error);
    res.status(500).json({
      success: false,
      message: "Failed to add medicine",
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
 * Returns all medicines scheduled for the given date, each enriched with
 * the alarm time, alarm code, and whether the alarm is custom.
 *
 * req.user:  { id }  (injected by authMiddleware)
 *
 * req.query:
 *   date : string  (required — format "YYYY-MM-DD")
 *
 * res 200:
 *   {
 *     success   : true
 *     date      : "YYYY-MM-DD"
 *     count     : number
 *     medicines : [
 *       {
 *         ...Medicine fields,
 *         alarmTime : "HH:MM AM/PM"
 *         alarmCode : number
 *         isCustom  : boolean
 *       }
 *     ]
 *   }
 *
 * res 400: { success: false, message: "date query param required (YYYY-MM-DD)" }
 * res 500: { success: false, message }
 */
export const fetchMedicinesByDay = async (req, res) => {
  try {
    const patientId = req.user.id;
    const { date } = req.query;

    if (!date) {
      console.warn(`⚠️  [fetchMedicinesByDay] Missing date query param → patientId=${patientId}`);
      return res.status(400).json({
        success: false,
        message: "date query param required (YYYY-MM-DD)",
      });
    }

    console.log(`🚀 [fetchMedicinesByDay] Fetching medicines → patientId=${patientId}, date=${date}`);

    const alarms = await Alarm.find({ patientId }).populate({
      path: "medicines.medicineId",
    });

    console.log(`📋 [fetchMedicinesByDay] Scanning ${alarms.length} alarm(s) for date=${date}`);

    const medicines = [];
    for (const alarm of alarms) {
      for (const medEntry of alarm.medicines) {
        if (medEntry.dates.includes(date)) {
          medicines.push({
            ...medEntry.medicineId.toObject(),
            alarmTime: alarm.time,
            alarmCode: alarm.alarmCode,
            isCustom: alarm.isCustom,
          });
        }
      }
    }

    console.log(`✅ [fetchMedicinesByDay] ${medicines.length} medicine(s) found for patientId=${patientId}, date=${date}`);

    res.json({
      success: true,
      date,
      count: medicines.length,
      medicines,
    });
  } catch (error) {
    console.error("❌ [fetchMedicinesByDay] Unexpected error:", error);
    res.status(500).json({
      success: false,
      message: "Failed to fetch medicines for selected date",
    });
  }
};
