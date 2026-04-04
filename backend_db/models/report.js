import mongoose from "mongoose";

const reportSchema = new mongoose.Schema(
  {
    patientId: { type: mongoose.Schema.Types.ObjectId, ref: "Patient", required: true },
  },
  
  { timestamps: true }
);

const Report = mongoose.model("Report", reportSchema);
export default Report;
