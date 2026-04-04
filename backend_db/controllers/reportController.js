import Patient from "../models/patient";
import Report from "../models/report";

export const uploadResults = async (req, res) => {
  try {
    const patientId = req.user.id;

    console.log(`✅ `);

    res.json({
      
    });
  } catch (error) {
    console.error("❌ ", error);
    res.status(500).json({
      message: "Failed to ",
    });
  }
};

export const fetchReports = async (req, res) => {
  try {
    const patientId = req.user.id;

    console.log(`✅ `);

    res.json({
      
    });
  } catch (error) {
    console.error("❌ ", error);
    res.status(500).json({
      message: "Failed to ",
    });
  }
};