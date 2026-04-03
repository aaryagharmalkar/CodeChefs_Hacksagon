import mongoose from "mongoose";

// Add Taken and Missed fields to generate reports later

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

    alarmKeys: [
      {
        type: Number,
        required: true,
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

    taken: {
      type: Number,
      required: false,
      default: 0
    },

    missed: {
      type: Number,
      required: false,
      default: 0
    },

    delayed: {
      type: Number,
      required: false,
      default: 0
    },

    photoUrl: {
      type: String,
      required: false,
    },

    isCritical: {
      type: Boolean,
      default: false,
    },
  },
  { timestamps: true }
);

export default mongoose.model("Medicine", MedicineSchema);