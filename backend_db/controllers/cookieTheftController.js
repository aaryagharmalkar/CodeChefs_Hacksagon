import { exec } from "child_process";
import path from "path";
import fs from "fs";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Path to Python script
const pythonScriptPath = path.join(
  __dirname,
  "../python_models/cookie_theft_scorer.py"
);

/**
 * Score a cookie theft transcript using the Python model
 * POST /api/assessment/cookie-theft
 */
export const scoreCookieTheft = async (req, res) => {
  try {
    const { transcript, patientId } = req.body;

    // Validate input
    if (!transcript || transcript.trim().length === 0) {
      return res.status(400).json({
        error: "Transcript is required and cannot be empty",
      });
    }

    if (!patientId) {
      return res.status(400).json({ error: "Patient ID is required" });
    }

    // Create a temporary file to store the transcript
    const tempDir = path.join(__dirname, "../temp");
    if (!fs.existsSync(tempDir)) {
      fs.mkdirSync(tempDir, { recursive: true });
    }

    const tempFilePath = path.join(
      tempDir,
      `transcript_${Date.now()}_${patientId}.txt`
    );
    fs.writeFileSync(tempFilePath, transcript);

    // Execute Python script
    return new Promise(() => {
      exec(
        `python "${pythonScriptPath}" "${tempFilePath}"`,
        { timeout: 30000 },
        (error, stdout, stderr) => {
          // Clean up temp file
          try {
            fs.unlinkSync(tempFilePath);
          } catch (e) {
            console.error("Error cleaning up temp file:", e);
          }

          if (error) {
            console.error("Python script error:", error);
            console.error("Python stderr:", stderr);
            return res.status(500).json({
              error: "Failed to score transcript",
              details: stderr,
            });
          }

          try {
            const result = JSON.parse(stdout);
            return res.json({
              success: true,
              patientId,
              score: result,
              timestamp: new Date(),
            });
          } catch (parseError) {
            console.error("JSON parse error:", parseError);
            return res.status(500).json({
              error: "Failed to parse scoring results",
              details: stdout,
            });
          }
        }
      );
    });
  } catch (error) {
    console.error("Cookie theft scoring error:", error);
    return res.status(500).json({
      error: "Server error during cookie theft assessment",
      details: error.message,
    });
  }
};

/**
 * Get scoring history for a patient
 * GET /api/assessment/cookie-theft/:patientId
 */
export const getCookieTheftHistory = async (req, res) => {
  try {
    const { patientId } = req.params;

    // TODO: Fetch from database
    // For now, return placeholder
    res.json({
      patientId,
      history: [],
      message: "Cookie theft scoring history will be stored in database",
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};