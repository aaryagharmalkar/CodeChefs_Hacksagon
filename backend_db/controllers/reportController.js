import Patient from "../models/patient.js";
import Report from "../models/report.js";

// router.post("/upload", authMiddleware, uploadResults);
export const uploadResults = async (req, res) => {
  try {
    const patientId = req.user.id;
    console.log(`🚀 [uploadResults] Request received → patientId=${patientId}`);

    const { mmse, voice, cookie } = req.body;

    console.log(`📋 [uploadResults] Payload → mmse=${mmse}`);
    console.log(`📋 [uploadResults] Voice →`, voice);
    console.log(`📋 [uploadResults] Cookie →`, cookie);

    // ── Validation ──
    if (mmse === undefined || mmse === null) {
      console.warn("⚠️  [uploadResults] Missing MMSE score");
      return res.status(400).json({ message: "MMSE score is required" });
    }

    // ── Compute overall risk ──
    let overallRiskLevel = "low";
    let overallScore = 0;

    if (voice?.riskScore !== undefined) {
      overallScore = voice.riskScore;

      if (overallScore > 0.7) overallRiskLevel = "high";
      else if (overallScore > 0.4) overallRiskLevel = "medium";
    }

    // ── Build cookie subdocument (may be undefined if not collected) ──
    let cookieData = undefined;
    if (cookie) {
      cookieData = {
        dementiaProbability: cookie.dementiaProbability ?? null,
        transcript: cookie.transcript ?? null,
        audioMetrics: cookie.audioMetrics
          ? {
              avg_pause_duration_seconds:
                cookie.audioMetrics.avg_pause_duration_seconds ?? null,
              pause_count: cookie.audioMetrics.pause_count ?? null,
            }
          : undefined,
        cognitiveMarkers: cookie.cognitiveMarkers
          ? {
              filler_rate: cookie.cognitiveMarkers.filler_rate ?? null,
              lexical_diversity:
                cookie.cognitiveMarkers.lexical_diversity ?? null,
              avg_sentence_length:
                cookie.cognitiveMarkers.avg_sentence_length ?? null,
              hesitation_ratio:
                cookie.cognitiveMarkers.hesitation_ratio ?? null,
              long_pause_rate:
                cookie.cognitiveMarkers.long_pause_rate ?? null,
            }
          : undefined,
      };
    }

    // ── Create Report ──
    const report = await Report.create({
      patientId,
      mmse,
      voice,
      cookie: cookieData,
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