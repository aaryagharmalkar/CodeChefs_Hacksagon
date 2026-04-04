import mongoose from "mongoose";

const voiceSchema = new mongoose.Schema({
  riskScore: { type: Number, required: true },
  riskLevel: { type: String, required: true },
  ac:    { type: Number },
  nth:   { type: Number },
  htn:   { type: Number },
  updrs: { type: Number },
}, { _id: false });

const audioMetricsSchema = new mongoose.Schema({
  avg_pause_duration_seconds: { type: Number },
  pause_count:                { type: Number },
}, { _id: false });

const cognitiveMarkersSchema = new mongoose.Schema({
  filler_rate:          { type: Number },
  lexical_diversity:    { type: Number },
  avg_sentence_length:  { type: Number },
  hesitation_ratio:     { type: Number },
  long_pause_rate:      { type: Number },
}, { _id: false });

const cookieSchema = new mongoose.Schema({
  dementiaProbability: { type: Number },
  transcript:          { type: String },
  audioMetrics:        { type: audioMetricsSchema },
  cognitiveMarkers:    { type: cognitiveMarkersSchema },
}, { _id: false });

const reportSchema = new mongoose.Schema(
  {
    patientId: {
      type:     mongoose.Schema.Types.ObjectId,
      ref:      "Patient",
      required: true,
    },
    mmse: {
      type:     Number,
      required: true,
    },
    voice: {
      type:     voiceSchema,
      required: false,
    },
    cookie: {
      type:     cookieSchema,
      required: false,
    },
    overallRiskLevel: { type: String },
    overallScore:     { type: Number },
  },
  { timestamps: true }
);

const Report = mongoose.model("Report", reportSchema);
export default Report;