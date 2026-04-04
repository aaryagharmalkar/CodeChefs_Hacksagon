import { exec } from "child_process";
import path from "path";
import fs from "fs";
import { fileURLToPath } from "url";
import multer from "multer";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Path to Python pipeline
const pipelinePath = path.join(
  __dirname,
  "../python_models/audio_to_cognitive_pipeline.py"
);

// Setup multer for audio file uploads
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const tempDir = path.join(__dirname, "../temp/audio"); // match what's logged
    if (!fs.existsSync(tempDir)) {
      fs.mkdirSync(tempDir, { recursive: true });
    }
    cb(null, tempDir);
  },
  filename: (req, file, cb) => {
    cb(null, `audio_${Date.now()}.wav`); // Remove patientId here
  }
});

export const uploadAudio = multer({ storage }).single("audio");

/**
 * Process audio file through cognitive pipeline
 * POST /api/assessment/cookie-theft
 */
export const processAudioCognitive = async (req, res) => {
  try {
    const { patientId } = req.body;

    // Validate
    if (!patientId) {
      return res.status(400).json({ error: "Patient ID is required" });
    }

    if (!req.file) {
      return res.status(400).json({ error: "Audio file is required" });
    }

    const audioFilePath = req.file.path;

    console.log(`Processing audio for patient: ${patientId}`);
    console.log(`Audio file: ${audioFilePath}`);

    // Execute Python pipeline
    return new Promise(() => {
    exec(
      `python "${pipelinePath}" "${audioFilePath}"`,
      { 
        timeout: 120000, 
        env: { 
          ...process.env,
          ASSEMBLYAI_API_KEY: process.env.ASSEMBLYAI_API_KEY  // ← explicit pass
        }
      },

        (error, stdout, stderr) => {
          // Clean up audio file after processing
          try {
            fs.unlinkSync(audioFilePath);
          } catch (e) {
            console.error("Error cleaning up audio file:", e);
          }

          if (error) {
            console.error("Python pipeline error:", error);
            console.error("Python stderr:", stderr);
            return res.status(500).json({
              error: "Failed to process audio",
              details: stderr,
            });
          }

          try {
            const result = JSON.parse(stdout);

            if (result.status === "error") {
              return res.status(400).json({
                error: result.error,
              });
            }

            return res.json({
              success: true,
              patientId,
              data: {
                transcript: result.transcript,
                audio_metrics: result.audio_metrics,
                dementia_probability: result.dementia_probability,
                cognitive_markers: result.cognitive_markers,
              },
              timestamp: new Date(),
            });
          } catch (parseError) {
            console.error("JSON parse error:", parseError);
            console.error("Raw stdout:", stdout);
            return res.status(500).json({
              error: "Failed to parse pipeline results",
              details: stdout,
            });
          }
        }
      );
    });
  } catch (error) {
    console.error("Audio processing error:", error);
    return res.status(500).json({
      error: "Server error during audio processing",
      details: error.message,
    });
  }
};

/**
 * Get assessment history (placeholder)
 * GET /api/assessment/cookie-theft/:patientId
 */
export const getAssessmentHistory = async (req, res) => {
  try {
    const { patientId } = req.params;
    res.json({
      patientId,
      history: [],
      message: "Assessment history will be stored in database",
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};
