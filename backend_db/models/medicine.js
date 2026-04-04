import mongoose from "mongoose";

const MedicineSchema = new mongoose.Schema(
  {
    patientId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Patient",
      required: true,
    },
    name: {
      type: String,
      required: true,
      trim: true,
    },
    type: {
      type: String,
      enum: ["tablet", "syrup", "other"],
      required: true,
    },
    // Numeric codes for standard meal-relative times (1–6)
    alarmKeys: [
      {
        type: Number,
      },
    ],
    // Free-form custom time strings e.g. "08:30 AM"
    customTimes: [
      {
        type: String,
      },
    ],
    frequency: {
      type: String,
      enum: ["Daily", "Alternate Days", "Specific Days"],
      required: true,
    },
    // Only used when frequency = "Specific Days"
    days: [
      {
        type: String,
        enum: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"],
      },
    ],
    durationDays: {
      type: Number,
      required: true,
    },
    doseCount: {
      type: Number,
      required: true,
    },
  },
  { timestamps: true }
);

export default mongoose.model("Medicine", MedicineSchema);