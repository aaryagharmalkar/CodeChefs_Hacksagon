import mongoose from "mongoose";

const voiceSchema = new mongoose.Schema({
  riskScore: { type: Number, required: true },
  riskLevel: { type: String, required: true },

  ac: { type: Number },
  nth: { type: Number },
  htn: { type: Number },
  updrs: { type: Number },
}, { _id: false });

const reportSchema = new mongoose.Schema(
  {
    patientId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Patient",
      required: true,
    },

    // Cognitive test
    mmse: {
      type: Number,
      required: true,
    },

    // Voice ML analysis
    voice: {
      type: voiceSchema,
      required: false,
    },

    // Optional future expansion
    overallRiskLevel: {
      type: String,
    },
    overallScore: {
      type: Number,
    },
  },
  { timestamps: true }
);

const Report = mongoose.model("Report", reportSchema);
export default Report;