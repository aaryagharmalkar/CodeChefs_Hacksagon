import os
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '3'

import cv2
import mediapipe as mp
import numpy as np
import time

# =====================================
# MediaPipe Setup
# =====================================
mp_pose = mp.tasks.vision.PoseLandmarker
BaseOptions = mp.tasks.BaseOptions
PoseLandmarkerOptions = mp.tasks.vision.PoseLandmarkerOptions
VisionRunningMode = mp.tasks.vision.RunningMode

options = PoseLandmarkerOptions(
    base_options=BaseOptions(
        model_asset_path="pose_landmarker_full.task"
    ),
    running_mode=VisionRunningMode.VIDEO
)

landmarker = mp_pose.create_from_options(options)

# =====================================
# Patient Input
# =====================================
patient_id = input("Enter Patient ID: ")
age = int(input("Enter Age: "))

age_group = "Young Adults"
forward_ref, forward_sd = 2.2, 0.4
backward_ref, backward_sd = 2.0, 0.6

# =====================================
# Camera Setup
# =====================================
cap = cv2.VideoCapture(0)

hip_positions = []
timestamps = []

state = "WAIT"
state_start = 0

FORWARD_WINDOW = 6
BACKWARD_WINDOW = 6
motion_threshold = 8

walk_started_forward = False
walk_started_backward = False
prev_hip = None

print("\nClick camera window and press S")

# =====================================
# MAIN LOOP
# =====================================
while cap.isOpened():

    ret, frame = cap.read()
    if not ret:
        break

    frame = cv2.flip(frame, 1)
    h, w, _ = frame.shape

    rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
    mp_image = mp.Image(
        image_format=mp.ImageFormat.SRGB,
        data=rgb
    )

    ts = int(time.time()*1000)
    result = landmarker.detect_for_video(mp_image, ts)

    key = cv2.waitKey(1) & 0xFF
    elapsed = time.time() - state_start

    # ================= WAIT =================
    if state == "WAIT":

        cv2.putText(frame,"Press S to Start Test",
                    (90,250),
                    cv2.FONT_HERSHEY_SIMPLEX,
                    1,(0,255,255),3)

        if key == ord('s'):
            hip_positions.clear()
            timestamps.clear()
            state = "COUNTDOWN"
            state_start = time.time()

    # ================= COUNTDOWN =================
    elif state == "COUNTDOWN":

        remain = 3 - int(elapsed)

        cv2.putText(frame,f"Starting in {remain}",
                    (120,250),
                    cv2.FONT_HERSHEY_SIMPLEX,
                    2,(0,0,255),5)

        if elapsed >= 3:
            state = "FORWARD"
            walk_started_forward = False
            prev_hip = None

    # ================= WALK FORWARD =================
    elif state == "FORWARD":

        cv2.putText(frame,"WALK FORWARD",
                    (70,60),
                    cv2.FONT_HERSHEY_SIMPLEX,
                    1.3,(0,255,0),4)

        if result.pose_landmarks:

            lm = result.pose_landmarks[0]
            hip_x = ((lm[23].x + lm[24].x)/2) * w

            if prev_hip is not None:
                motion = abs(hip_x - prev_hip)

                if motion > motion_threshold and not walk_started_forward:
                    walk_started_forward = True
                    state_start = time.time()
                    print("Forward walking detected")

            prev_hip = hip_x

            if walk_started_forward:
                hip_positions.append(hip_x)
                timestamps.append(time.time())

        if walk_started_forward and elapsed >= FORWARD_WINDOW:
            state = "BACKWARD"
            walk_started_backward = False
            prev_hip = None

    # ================= WALK BACKWARD =================
    elif state == "BACKWARD":

        cv2.putText(frame,"NOW WALK BACK",
                    (60,60),
                    cv2.FONT_HERSHEY_SIMPLEX,
                    1.3,(255,200,0),4)

        if result.pose_landmarks:

            lm = result.pose_landmarks[0]
            hip_x = ((lm[23].x + lm[24].x)/2) * w

            if prev_hip is not None:
                motion = abs(hip_x - prev_hip)

                if motion > motion_threshold and not walk_started_backward:
                    walk_started_backward = True
                    state_start = time.time()
                    print("Backward walking detected")

            prev_hip = hip_x

            if walk_started_backward:
                hip_positions.append(hip_x)
                timestamps.append(time.time())

        if walk_started_backward and elapsed >= BACKWARD_WINDOW:
            state = "DONE"

    # ================= DONE =================
    elif state == "DONE":

        cv2.putText(frame,"TEST COMPLETE",
                    (80,250),
                    cv2.FONT_HERSHEY_SIMPLEX,
                    2,(255,0,0),5)

    cv2.imshow("Walking Assessment", frame)

    if key == ord('q'):
        break

cap.release()
cv2.destroyAllWindows()
landmarker.close()

# =====================================
# ANALYSIS
# =====================================
hip_positions = np.array(hip_positions)
timestamps = np.array(timestamps)

if len(hip_positions) < 20:
    print("\nNot enough walking data captured.")
    exit()

velocity = np.gradient(hip_positions) / np.gradient(timestamps)

forward_mask = velocity < -15
backward_mask = velocity > 15


def duration(mask):
    start=None
    total=0
    for i in range(len(mask)):
        if mask[i] and start is None:
            start=timestamps[i]
        elif not mask[i] and start is not None:
            total+=timestamps[i]-start
            start=None
    return total


forward_time = duration(forward_mask)
backward_time = duration(backward_mask)


def interpret(v, ref, sd):
    if v > ref + sd:
        return "Longer than expected range"
    elif v < ref - sd:
        return "Faster than expected range"
    else:
        return "Within expected range"

# =====================================
# FINAL REPORT
# =====================================
print("\n======================================")
print("        WALKING ASSESSMENT REPORT")
print("======================================\n")

print(f"Patient ID      : {patient_id}")
print(f"Age Group       : {age_group}")
print(f"Assessment Date : {time.strftime('%d %B %Y')}")

print("\n--------------------------------------")

print("\n1️⃣ Walking Forward")
print(f"Measured Duration : {round(forward_time,2)} seconds")
print(f"Reference Range   : {forward_ref} ± {forward_sd}")
print(f"Observation       : {interpret(forward_time,forward_ref,forward_sd)}")

print("\n2️⃣ Walking Backward")
print(f"Measured Duration : {round(backward_time,2)} seconds")
print(f"Reference Range   : {backward_ref} ± {backward_sd}")
print(f"Observation       : {interpret(backward_time,backward_ref,backward_sd)}")

print("\n--------------------------------------")

print("Overall Interpretation:")
print("Temporal walking performance evaluated")
print("against age-related reference values.")

print("\n======================================")