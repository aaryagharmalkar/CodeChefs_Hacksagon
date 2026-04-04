import mongoose from "mongoose";

const MealTimeSchema = new mongoose.Schema(
  {
    meal: {
      type: String,
      enum: ["breakfast", "lunch", "dinner"],
      required: true,
    },
    time: {
      type: String, // "HH:MM AM/PM"
      required: true,
    },
  },
  { _id: false }
);

const patientSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: true,
    },

    age: {
      type: String,
      required: true,
    },

    gender: {
      type: String,
      required: true,
    },

    phone: {
      type: String,
      required: true,
      unique: true,
    },

    password: {
      type: String,
      required: true,
    },

    mealTimes: {
      type: [MealTimeSchema],
      default: [
        { meal: "breakfast", time: "09:00 AM" },
        { meal: "lunch", time: "02:00 PM" },
        { meal: "dinner", time: "09:00 PM" },
      ],
      required: false,
    },
  },
  { timestamps: true }
);

const Patient = mongoose.model("Patient", patientSchema);
export default Patient;
