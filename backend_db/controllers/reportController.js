import Patient from "../models/patient.js";
import Report from "../models/report.js";

// router.post("/upload", authMiddleware, uploadResults);
export const uploadResults = async (req, res) => {
  try {
    const patientId = req.user.id;
    console.log(`🚀 [uploadResults] Request received → patientId=${patientId}`);

    const { mmse, voice } = req.body;

    console.log(`📋 [uploadResults] Payload → mmse=${mmse}`);
    console.log(`📋 [uploadResults] Voice →`, voice);

    // ── Validation ──
    if (mmse === undefined || mmse === null) {
      console.warn("⚠️  [uploadResults] Missing MMSE score");
      return res.status(400).json({ message: "MMSE score is required" });
    }

    // ── Compute overall risk (simple logic, tweak later) ──
    let overallRiskLevel = "low";
    let overallScore = 0;

    if (voice?.riskScore !== undefined) {
      overallScore = voice.riskScore;

      if (overallScore > 0.7) overallRiskLevel = "high";
      else if (overallScore > 0.4) overallRiskLevel = "medium";
    }

    // ── Create Report ──
    const report = await Report.create({
      patientId,
      mmse,
      voice,
      overallRiskLevel,
      overallScore,
    });

    console.log(`📝 [uploadResults] Report created → reportId=${report._id}`);

    res.status(201).json({
      success: true,
      message: "Report uploaded successfully",
      report,
    });

  } catch (error) {
    console.error("❌ [uploadResults] Unexpected error:", error);
    res.status(500).json({
      success: false,
      message: "Failed to upload report",
      error: error.message,
    });
  }
};

// router.get("/history", authMiddleware, fetchReports);
export const fetchReports = async (req, res) => {
  try {
    const patientId = req.user.id;
    console.log(`🚀 [fetchReports] Fetching reports → patientId=${patientId}`);

    const reports = await Report.find({ patientId })
      .sort({ createdAt: -1 });

    console.log(`📊 [fetchReports] Found ${reports.length} reports`);

    res.json({
      success: true,
      count: reports.length,
      reports,
    });

  } catch (error) {
    console.error("❌ [fetchReports] Unexpected error:", error);
    res.status(500).json({
      success: false,
      message: "Failed to fetch reports",
      error: error.message,
    });
  }
};