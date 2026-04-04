import Alarm from "../models/Alarm.js";
import Medicine from "../models/medicine.js";

// ─────────────────────────────────────────────
// TIME HELPER
// ─────────────────────────────────────────────

/**
 * timeToMinutes
 * Converts a time string to total minutes since midnight.
 * Supports both 12-hour ("09:30 AM") and 24-hour ("21:30") formats.
 *
 * @param  {string} timeStr
 * @returns {number|null}
 */
function timeToMinutes(timeStr) {
  if (!timeStr) return null;

  if (timeStr.includes("AM") || timeStr.includes("PM")) {
    const [time, meridian] = timeStr.split(" ");
    let [h, m] = time.split(":").map(Number);

    if (meridian === "PM" && h !== 12) h += 12;
    if (meridian === "AM" && h === 12) h = 0;

    return h * 60 + m;
  }

  // 24-hour format
  const [h, m] = timeStr.split(":").map(Number);
  return h * 60 + m;
}

// ─────────────────────────────────────────────
// GET TODAY'S UPCOMING ALARMS
// ─────────────────────────────────────────────

/**
 * GET /api/alarm/upcoming
 * Protected: requires valid JWT.
 *
 * Returns all alarms for today that are still ahead of the current time,
 * with only the medicines that are scheduled for today attached.
 * Results are sorted by alarm time (earliest first).
 *
 * req.user: { id }  (injected by authMiddleware)
 *
 * res 200:
 *   {
 *     success     : true
 *     date        : "YYYY-MM-DD"
 *     currentTime : "HH:MM"
 *     count       : number
 *     alarms      : [
 *       {
 *         alarmId   : ObjectId
 *         alarmCode : number
 *         time      : "HH:MM AM/PM"
 *         isCustom  : boolean
 *         medicines : [
 *           { id, name, type, doseCount, isCritical, durationDays }
 *         ]
 *       }
 *     ]
 *   }
 *
 * res 500: { success: false, message, error }
 */
export const getTodayUpcomingAlarms = async (req, res) => {
  try {
    const patientId = req.user.id;
    const now = new Date();
    const today = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}-${String(now.getDate()).padStart(2, "0")}`;
    const currentMinutes = now.getHours() * 60 + now.getMinutes();

    console.log(`🚀 [getTodayUpcomingAlarms] Fetching upcoming alarms → id=${patientId}, date=${today}, currentTime=${now.toTimeString().slice(0, 5)}`);

    const alarms = await Alarm.find({ patientId }).populate({
      path: "medicines.medicineId",
      select: "name type doseCount isCritical durationDays",
    });

    console.log(`📋 [getTodayUpcomingAlarms] Total alarms on record: ${alarms.length}`);

    const upcomingAlarms = alarms
      .map((alarm) => {
        const alarmMinutes = timeToMinutes(alarm.time);

        if (alarmMinutes === null || alarmMinutes <= currentMinutes) return null;

        const todaysMeds = alarm.medicines
          .filter((m) => m.dates.includes(today))
          .map((m) => ({
            id: m.medicineId._id,
            name: m.medicineId.name,
            type: m.medicineId.type,
            doseCount: m.medicineId.doseCount,
            isCritical: m.medicineId.isCritical,
            durationDays: m.medicineId.durationDays,
          }));

        if (todaysMeds.length === 0) return null;

        return {
          alarmId: alarm._id,
          alarmCode: alarm.alarmCode,
          time: alarm.time,
          isCustom: alarm.isCustom,
          medicines: todaysMeds,
        };
      })
      .filter(Boolean)
      .sort((a, b) => timeToMinutes(a.time) - timeToMinutes(b.time));

    console.log(`✅ [getTodayUpcomingAlarms] ${upcomingAlarms.length} upcoming alarm(s) returned for id=${patientId}`);

    res.json({
      success: true,
      date: today,
      currentTime: now.toTimeString().slice(0, 5),
      count: upcomingAlarms.length,
      alarms: upcomingAlarms,
    });
  } catch (error) {
    console.error("❌ [getTodayUpcomingAlarms] Unexpected error:", error);
    res.status(500).json({
      success: false,
      message: "Failed to fetch upcoming alarms",
      error: error.message,
    });
  }
};

// ─────────────────────────────────────────────
// GET ALARM DETAILS BY ID
// ─────────────────────────────────────────────

/**
 * GET /api/alarm/details?alarmId=<id>
 * Protected: requires valid JWT.
 *
 * Returns full details of a single alarm including all its attached medicines.
 *
 * req.query:
 *   alarmId : string  (required — MongoDB ObjectId of the alarm)
 *
 * res 200:
 *   {
 *     success : true
 *     alarm   : {
 *       alarmId   : ObjectId
 *       alarmCode : number
 *       time      : "HH:MM AM/PM"
 *       isCustom  : boolean
 *       createdAt : Date
 *       updatedAt : Date
 *       medicines : [
 *         {
 *           _id, name, type, frequency, durationDays, doseCount,
 *           taken, missed, delayed, isCritical, photoUrl,
 *           scheduleDates, createdAt, updatedAt
 *         }
 *       ]
 *     }
 *   }
 *
 * res 400: { success: false, message: "alarmId query param is required" }
 * res 404: { success: false, message: "Alarm not found" }
 * res 500: { success: false, message, error }
 */
export const getAlarmDetailsById = async (req, res) => {
  try {
    const { alarmId } = req.query;
    console.log(`🚀 [getAlarmDetailsById] Fetching alarm details → alarmId=${alarmId}`);

    if (!alarmId) {
      console.warn("⚠️  [getAlarmDetailsById] Missing alarmId query param");
      return res.status(400).json({
        success: false,
        message: "alarmId query param is required",
      });
    }

    const alarm = await Alarm.findOne({ _id: alarmId }).populate({
      path: "medicines.medicineId",
    });

    if (!alarm) {
      console.warn(`⚠️  [getAlarmDetailsById] Alarm not found for alarmId=${alarmId}`);
      return res.status(404).json({
        success: false,
        message: "Alarm not found",
      });
    }

    const medicines = alarm.medicines.map((m) => {
      const med = m.medicineId;
      return {
        _id: med._id,
        name: med.name,
        type: med.type,
        frequency: med.frequency,
        durationDays: med.durationDays,
        doseCount: med.doseCount,
        taken: med.taken,
        missed: med.missed,
        delayed: med.delayed,
        isCritical: med.isCritical,
        photoUrl: med.photoUrl,
        scheduleDates: m.dates,
        createdAt: med.createdAt,
        updatedAt: med.updatedAt,
      };
    });

    console.log(`✅ [getAlarmDetailsById] Alarm fetched → alarmId=${alarmId}, medicines=${medicines.length}`);

    res.json({
      success: true,
      alarm: {
        alarmId: alarm._id,
        alarmCode: alarm.alarmCode,
        time: alarm.time,
        isCustom: alarm.isCustom,
        createdAt: alarm.createdAt,
        updatedAt: alarm.updatedAt,
        medicines,
      },
    });
  } catch (error) {
    console.error("❌ [getAlarmDetailsById] Unexpected error:", error);
    res.status(500).json({
      success: false,
      message: "Failed to fetch alarm details",
      error: error.message,
    });
  }
};

// ─────────────────────────────────────────────
// MARK ALARM TAKEN
// ─────────────────────────────────────────────

/**
 * POST /api/alarm/taken
 *
 * Increments the `taken` counter on each medicine that was actually taken.
 * Only the medicine IDs explicitly passed in the request are updated —
 * allows partial takes (e.g. patient took 2 out of 3 medicines in an alarm).
 *
 * req.body:
 *   {
 *     alarmId   : string    (required — ObjectId of the alarm)
 *     medicines : string[]  (required — array of medicine ObjectIds that were taken)
 *     timestamp : string    (optional — ISO string; defaults to now if omitted)
 *   }
 *
 * res 200:
 *   {
 *     success   : true
 *     message   : "Medicines marked as taken"
 *     alarmId   : string
 *     count     : number   (how many medicine records were updated)
 *     timestamp : string
 *   }
 *
 * res 400: { success: false, message }  (missing alarmId or medicines)
 * res 404: { success: false, message: "Alarm not found" }
 * res 500: { success: false, message, error }
 */
export const markAlarmTaken = async (req, res) => {
  try {
    const { alarmId, medicines, timestamp } = req.body;
    console.log(`🚀 [markAlarmTaken] Request → alarmId=${alarmId}, medicines=[${medicines}]`);

    if (!alarmId) {
      console.warn("⚠️  [markAlarmTaken] Missing alarmId in request body");
      return res.status(400).json({
        success: false,
        message: "alarmId is required",
      });
    }

    if (!medicines || !Array.isArray(medicines) || medicines.length === 0) {
      console.warn("⚠️  [markAlarmTaken] Missing or empty medicines array");
      return res.status(400).json({
        success: false,
        message: "medicines array is required and must not be empty",
      });
    }

    const alarm = await Alarm.findOne({ _id: alarmId });
    if (!alarm) {
      console.warn(`⚠️  [markAlarmTaken] Alarm not found → alarmId=${alarmId}`);
      return res.status(404).json({
        success: false,
        message: "Alarm not found",
      });
    }

    const result = await Medicine.updateMany(
      { _id: { $in: medicines } },
      { $inc: { taken: 1 } }
    );

    console.log(`✅ [markAlarmTaken] ${result.modifiedCount}/${medicines.length} medicine(s) marked as taken → alarmId=${alarmId}`);

    res.json({
      success: true,
      message: "Medicines marked as taken",
      alarmId,
      count: result.modifiedCount,
      timestamp: timestamp || new Date().toISOString(),
    });
  } catch (error) {
    console.error("❌ [markAlarmTaken] Unexpected error:", error);
    res.status(500).json({
      success: false,
      message: "Failed to mark medicines as taken",
      error: error.message,
    });
  }
};

// ─────────────────────────────────────────────
// MARK ALARM MISSED
// ─────────────────────────────────────────────

/**
 * POST /api/alarm/snooze
 *
 * Increments the `missed` counter on ALL medicines attached to the given alarm.
 * Triggered when the patient dismisses or ignores an alarm without taking any medicine.
 *
 * req.body:
 *   {
 *     alarmId : string  (required — ObjectId of the alarm)
 *   }
 *
 * res 200:
 *   {
 *     success : true
 *     message : "Medicines marked as missed"
 *     alarmId : string
 *     count   : number  (how many medicine records were updated)
 *   }
 *
 * res 400: { success: false, message: "alarmId is required" }
 * res 404: { success: false, message: "Alarm not found" }
 * res 500: { success: false, message, error }
 */
export const markAlarmMissed = async (req, res) => {
  try {
    const { alarmId } = req.body;
    console.log(`🚀 [markAlarmMissed] Request → alarmId=${alarmId}`);

    if (!alarmId) {
      console.warn("⚠️  [markAlarmMissed] Missing alarmId in request body");
      return res.status(400).json({
        success: false,
        message: "alarmId is required",
      });
    }

    const alarm = await Alarm.findOne({ _id: alarmId });
    if (!alarm) {
      console.warn(`⚠️  [markAlarmMissed] Alarm not found → alarmId=${alarmId}`);
      return res.status(404).json({
        success: false,
        message: "Alarm not found",
      });
    }

    const medicineIds = alarm.medicines.map((m) => m.medicineId);
    console.log(`📋 [markAlarmMissed] Marking ${medicineIds.length} medicine(s) as missed → alarmId=${alarmId}`);

    const result = await Medicine.updateMany(
      { _id: { $in: medicineIds } },
      { $inc: { missed: 1 } }
    );

    console.log(`✅ [markAlarmMissed] ${result.modifiedCount} medicine(s) marked as missed → alarmId=${alarmId}`);

    res.json({
      success: true,
      message: "Medicines marked as missed",
      alarmId,
      count: result.modifiedCount,
    });
  } catch (error) {
    console.error("❌ [markAlarmMissed] Unexpected error:", error);
    res.status(500).json({
      success: false,
      message: "Failed to mark alarm as missed",
      error: error.message,
    });
  }
};
