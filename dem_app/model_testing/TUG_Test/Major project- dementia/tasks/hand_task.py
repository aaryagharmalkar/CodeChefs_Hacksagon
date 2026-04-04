import time
import cv2
import random
from ultralytics import YOLO
from config import *
from utils.filters import MajorityFilter
from report.report_generator import save_hand_report
from pose_utils import shoulder_elevation_angle
from speech import speak

model = YOLO("yolov8n-pose.pt")

def run_hand_task(cap):

    RESPONSE_TIME_LIMIT = 10
    OBSERVATION_TIME = 20

    instruction_time = time.strftime("%Y-%m-%d %H:%M:%S")
    command = random.choice(["left", "right"])

    speak(f"Raise your {command} hand")

    # ---- MASTER TIMERS ----
    task_start_time = time.time()
    phase_start_time = time.time()
    observation_start_time = None

    phase = "initial"  # initial → repeat → observation

    reaction_time = None
    final_status = "No Response"
    exit_reason = "No Response"

    filter_obj = MajorityFilter(STABLE_FRAMES_REQUIRED, MAJORITY_COUNT)

    max_angle = 0
    angle_sum = 0
    angle_count = 0

    correct_hand_raised = False
    wrong_hand_raised_flag = False
    raised_hand_detected = "None"

    task_finished = False
    display = None

    while True:

        ret, frame = cap.read()
        if not ret:
            break

        current_time = time.time()
        phase_elapsed = current_time - phase_start_time

        results = model(frame, verbose=False)

        status = "Minimal"
        pose_detected = False

        for r in results:
            if r.keypoints is None:
                continue

            pose_detected = True
            k = r.keypoints.xy[0].cpu().numpy()

            L_SH, R_SH = k[5], k[6]
            L_EL, R_EL = k[7], k[8]
            L_HIP, R_HIP = k[11], k[12]

            left_angle = shoulder_elevation_angle(L_SH, L_EL, L_HIP)
            right_angle = shoulder_elevation_angle(R_SH, R_EL, R_HIP)

            correct_angle = left_angle if command == "left" else right_angle
            opposite_angle = right_angle if command == "left" else left_angle

            correct_angle = min(correct_angle, 170)

            max_angle = max(max_angle, correct_angle)

            if correct_angle > 0:
                angle_sum += correct_angle
                angle_count += 1

            if left_angle > right_angle and left_angle >= ARM_MIN_ANGLE:
                raised_hand_detected = "Left"
            elif right_angle > left_angle and right_angle >= ARM_MIN_ANGLE:
                raised_hand_detected = "Right"
            else:
                raised_hand_detected = "None"

            if correct_angle >= ARM_PARTIAL_ANGLE:
                correct_hand_raised = True

            if opposite_angle >= ARM_PARTIAL_ANGLE:
                wrong_hand_raised_flag = True

            if correct_angle >= ARM_FULL_ANGLE:
                status = "Full"
            elif ARM_PARTIAL_ANGLE <= correct_angle < ARM_FULL_ANGLE:
                status = "Partial"

        if pose_detected:
            filter_obj.update(status)

        stable_status = filter_obj.get_majority()

        # ================= RESPONSE STATE MACHINE =================

        # 1️⃣ Movement detected
        if phase in ["initial", "repeat"] and stable_status in ["Partial", "Full"]:
            reaction_time = current_time - task_start_time
            observation_start_time = current_time
            phase = "observation"
            speak("Movement detected. Please hold your hand steady")

        # 2️⃣ Initial phase timeout → repeat instruction
        elif phase == "initial" and phase_elapsed >= RESPONSE_TIME_LIMIT:
            speak(f"I did not see movement. Please raise your {command} hand again")
            phase = "repeat"
            phase_start_time = current_time

        # 3️⃣ Repeat phase timeout → end task
        elif phase == "repeat" and phase_elapsed >= RESPONSE_TIME_LIMIT:
            speak("No movement detected")
            final_status = "No Response"
            exit_reason = "No response after repeat instruction"
            task_finished = True

        # 4️⃣ Observation phase
        if phase == "observation" and not task_finished:

            observation_elapsed = current_time - observation_start_time

            if stable_status == "Full":
                final_status = "Full"
            elif stable_status == "Partial" and final_status != "Full":
                final_status = "Partial"

            if observation_elapsed >= OBSERVATION_TIME:
                exit_reason = "Observation completed"
                task_finished = True

        # ================= DISPLAY =================

        display = cv2.flip(frame, 1)

        # Instruction text (changes if repeated)
        if phase == "initial":
            instruction_text = f"Raise your {command.upper()} hand"
        elif phase == "repeat":
            instruction_text = f"PLEASE Raise your {command.upper()} hand"
        else:
            instruction_text = f"Hold your {command.upper()} hand steady"

        # Timer text
        if phase in ["initial", "repeat"]:
            remaining = max(0, int(RESPONSE_TIME_LIMIT - phase_elapsed))
            timer_text = f"Time to respond: {remaining}s"
        else:
            observation_elapsed = current_time - observation_start_time
            remaining = max(0, int(OBSERVATION_TIME - observation_elapsed))
            timer_text = f"Observation time: {remaining}s"

        cv2.putText(display, instruction_text,
                    (30, 40), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0,255,255), 2)

        cv2.putText(display, timer_text,
                    (30, 80), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0,0,255), 2)

        cv2.putText(display, f"Detected Raised: {raised_hand_detected}",
                    (30, 120), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (255,200,0), 2)

        cv2.putText(display, f"Movement Status: {stable_status}",
                    (30, 160), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0,255,0), 2)

        if reaction_time:
            cv2.putText(display, f"Reaction Time: {reaction_time:.2f}s",
                        (30, 200), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (255,0,0), 2)

        cv2.imshow("Hand Task", display)

        if task_finished:
            break

        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

    # ================= FINAL RESULT =================

    total_task_time = time.time() - task_start_time

    if correct_hand_raised and not wrong_hand_raised_flag:
        hand_result = "Correct Hand Raised"
    elif wrong_hand_raised_flag and not correct_hand_raised:
        hand_result = "Wrong Hand Raised"
    elif correct_hand_raised and wrong_hand_raised_flag:
        hand_result = "Both Hands Raised"
    else:
        hand_result = "No Hand Raised"

    avg_angle = angle_sum / angle_count if angle_count else 0

    if display is not None:
        final_frame = display.copy()

        cv2.putText(final_frame, "TASK COMPLETED",
                    (30, 240), cv2.FONT_HERSHEY_SIMPLEX, 1, (0,0,255), 3)

        cv2.putText(final_frame, f"Total Time: {total_task_time:.2f}s",
                    (30, 280), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (255,255,0), 2)

        cv2.imshow("Hand Task", final_frame)
        cv2.waitKey(3000)
        cv2.destroyWindow("Hand Task")

    speak("Task completed")

    save_hand_report(
        command,
        final_status,
        final_status == "Full",
        reaction_time,
        max_angle,
        avg_angle,
        hand_result,
        instruction_time
    )
