import os
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '3'

import cv2
import mediapipe as mp
import numpy as np
from scipy.signal import savgol_filter
import time

# -----------------------------
# MediaPipe Setup
# -----------------------------
mp_pose = mp.tasks.vision.PoseLandmarker
BaseOptions = mp.tasks.BaseOptions
PoseLandmarkerOptions = mp.tasks.vision.PoseLandmarkerOptions
VisionRunningMode = mp.tasks.vision.RunningMode

model_path = "pose_landmarker_full.task"

options = PoseLandmarkerOptions(
    base_options=BaseOptions(model_asset_path=model_path),
    running_mode=VisionRunningMode.VIDEO
)

landmarker = mp_pose.create_from_options(options)


# -----------------------------
# Patient Input
# -----------------------------
patient_id = input("Enter Patient ID: ")
age = int(input("Enter Age: "))

# Age-based reference selection
if age < 40:
    age_group = "Young Adults"
    ref_time = 1.6
    ref_sd = 0.3
elif 40 <= age < 65:
    age_group = "Senior Adults"
    ref_time = 1.5
    ref_sd = 0.3
else:
    age_group = "Elderly Persons"
    ref_time = 2.0
    ref_sd = 0.5


# -----------------------------
# Camera Setup
# -----------------------------
cap = cv2.VideoCapture(0)

angles = []
timestamps = []
recording = False
start_angle = None
rotation_complete = False

print("Press 's' to start 360° turn test.")
print("Press 'q' to quit.")

# -----------------------------
# MAIN LOOP
# -----------------------------
while cap.isOpened():
    ret, frame = cap.read()
    if not ret:
        break

    rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
    mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)

    timestamp_ms = int(time.time() * 1000)
    result = landmarker.detect_for_video(mp_image, timestamp_ms)

    live_angle_deg = 0

    if result.pose_landmarks:
        landmarks = result.pose_landmarks[0]

        left = landmarks[11]
        right = landmarks[12]

        x_diff = right.x - left.x
        y_diff = right.y - left.y

        angle = np.arctan2(y_diff, x_diff)

        if recording:
            if start_angle is None:
                start_angle = angle

            angles.append(angle)
            timestamps.append(time.time())

            # Unwrap live
            unwrapped = np.unwrap(angles)
            live_rotation = unwrapped[-1] - unwrapped[0]
            live_angle_deg = np.degrees(live_rotation)

            # AUTO STOP at 360°
            if abs(live_angle_deg) >= 360:
                rotation_complete = True
                recording = False

    # -----------------------------
    # Draw Live Angle Counter
    # -----------------------------
    cv2.putText(frame,
                f"Rotation: {int(live_angle_deg)} deg",
                (30, 50),
                cv2.FONT_HERSHEY_SIMPLEX,
                1,
                (0, 255, 0),
                2)

    cv2.imshow("360 Turn Test", frame)

    key = cv2.waitKey(30) & 0xFF

    if key == ord('s'):
        print("Recording started...")
        recording = True
        rotation_complete = False
        angles = []
        timestamps = []
        start_angle = None

    elif key == ord('q'):
        break

    # If rotation done, break loop automatically
    if rotation_complete:
        break

# -----------------------------
# Cleanup
# -----------------------------
cap.release()
cv2.destroyAllWindows()
landmarker.close()

# -----------------------------
# ANALYSIS + CLINICAL REPORT
# -----------------------------
if len(angles) > 20:

    angles = np.unwrap(angles)
    angles_smooth = savgol_filter(angles, 11, 3)

    time_array = np.array(timestamps)

    total_angle_rad = angles_smooth[-1] - angles_smooth[0]
    total_angle_deg = np.degrees(total_angle_rad)

    turn_time = time_array[-1] - time_array[0]

    angular_velocity = np.gradient(angles_smooth) / np.gradient(time_array)
    angular_velocity = savgol_filter(angular_velocity, 11, 3)
    velocity_deg = np.degrees(np.abs(angular_velocity))
    velocity_rad = np.gradient(angles_smooth) / np.gradient(time_array)
    velocity_rad = savgol_filter(velocity_rad, 21, 3)  # stronger smoothing
    velocity_deg = np.degrees(np.abs(velocity_rad))
    max_velocity_deg = np.percentile(velocity_deg, 90)

    # -----------------------------
    # Duration Conclusion
    # -----------------------------
    lower_limit = ref_time - ref_sd
    upper_limit = ref_time + ref_sd

    if turn_time > upper_limit:
        duration_comment = "Longer than ideal reference range."
    elif turn_time < lower_limit:
        duration_comment = "Shorter than expected reference range."
    else:
        duration_comment = "Within expected reference range."

    # -----------------------------
    # Velocity Conclusion
    # -----------------------------
    if max_velocity_deg > 180:
        velocity_comment = "Turning speed is higher than typical reference values."
    elif 140 <= max_velocity_deg <= 180:
        velocity_comment = "Turning speed falls within age-related reference range."
    elif 100 <= max_velocity_deg < 140:
        velocity_comment = "Turning speed is lower than ideal reference range."
    else:
        velocity_comment = "Turning speed is reduced compared to reference values."

    # -----------------------------
    # Pause Detection
    # -----------------------------
    velocity_threshold = np.radians(10)  # 10 deg/s threshold
    min_pause_duration = 0.2  # seconds

    low_velocity = np.abs(angular_velocity) < velocity_threshold

    pause_events = 0
    pause_start = None

    for i in range(len(low_velocity)):
        if low_velocity[i]:
            if pause_start is None:
                pause_start = time_array[i]
        else:
            if pause_start is not None:
                duration = time_array[i] - pause_start
                if duration >= min_pause_duration:
                    pause_events += 1
                pause_start = None

    pauses = pause_events

    # -----------------------------
    # PRINT FINAL REPORT
    # -----------------------------
    print("\n\n==============================")
    print("360° Turning Assessment Report")
    print("==============================\n")

    print(f"Patient ID: {patient_id}")
    print(f"Age: {age} years")
    print(f"Age Group: {age_group}")
    print(f"Date of Assessment: {time.strftime('%d %b %Y')}\n")

    # Turn Completion
    print("1️⃣ Turn Completion\n")

    if 330 <= abs(total_angle_deg) <= 390:
        print("✔ Full 360° turn completed independently.\n")
    else:
        print("✖ Full 360° turn not completed.\n")

    # Turn Duration
    print("2️⃣ Turn Duration\n")
    print(f"Measured Turn Duration: {round(turn_time,2)} seconds")
    print(f"Reference ({age_group}): {ref_time} ± {ref_sd} s")
    print(f"Conclusion: {duration_comment}\n")

    # Turning Speed
    print("3️⃣ Turning Speed (Maximum Speed During 360° Turn)\n")
    print(f"Measured Turning Speed: {round(max_velocity_deg,2)}°/s")
    print("Reference Categories:")
    print(">180°/s  | Typical in young adults")
    print("140–180°/s | Age-appropriate")
    print("100–140°/s | Mild reduction")
    print("<100°/s | Reduced")
    print(f"Conclusion: {velocity_comment}\n")

    # Pauses (No interpretation)
    print("4️⃣ Hesitation / Pauses\n")
    print(f"Observed Pauses: {pauses}\n")

    # Overall Summary
    print("🧾 Summary for Clinician\n")
    print("Turn performance evaluated against age-based reference values.")
    print("Duration and turning speed conclusions provided above.")
    print("Pause count reported without classification.")
    print("\n================================\n")

else:
    print("\nNot enough rotation data captured.")