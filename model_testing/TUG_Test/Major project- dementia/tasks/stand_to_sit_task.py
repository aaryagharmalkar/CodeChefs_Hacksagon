import time
import cv2
from ultralytics import YOLO
from config import *
from utils.filters import MajorityFilter
from report.report_generator import save_stand_to_sit_report
from pose_utils import knee_angle
from speech import speak

model = YOLO("yolov8n-pose.pt")


def run_stand_to_sit(cap):

    # ---------------- AGE GROUP MENU ----------------
    print("\nSelect Age Group:")
    print("1. Children (5–12 years)")
    print("2. Young Adults (18–35 years)")
    print("3. Senior Adults (36–59 years)")
    print("4. Elderly Persons (60+ years)")

    choice = input("Enter choice (1-4): ")

    if choice == "1":
        age_group = "Children (5–12 yrs)"
        reference_mean = 1.4
        reference_sd = 0.3
    elif choice == "2":
        age_group = "Young Adults (18–35 yrs)"
        reference_mean = 1.9
        reference_sd = 0.4
    elif choice == "3":
        age_group = "Senior Adults (36–59 yrs)"
        reference_mean = 1.8
        reference_sd = 0.3
    else:
        age_group = "Elderly Persons (60+ yrs)"
        reference_mean = 1.9
        reference_sd = 0.4

    # ---------------- INITIAL INSTRUCTION ----------------
    speak("Please stand straight with your feet shoulder width apart.")
    speak("Task will start in 3 seconds")

    for i in range(3, 0, -1):
        print(f"Starting in {i}...")
        time.sleep(1)

    speak("Now please sit down slowly and safely.")

    instruction_time = time.strftime("%Y-%m-%d %H:%M:%S")

    RESPONSE_LIMIT = 10
    TOTAL_ALLOWED_TIME = 20

    task_start_time = time.time()
    instruction_start_time = task_start_time

    movement_started = False
    movement_completed = False
    instruction_repeated = False

    start_time = None
    time_to_complete = None

    max_angle = 0
    angle_sum = 0
    angle_count = 0

    filter_obj = MajorityFilter(STABLE_FRAMES_REQUIRED, MAJORITY_COUNT)

    display = None
    phase_text = "Please Sit Down"

    while True:

        ret, frame = cap.read()
        if not ret:
            break

        current_time = time.time()
        total_elapsed = current_time - task_start_time
        instruction_elapsed = current_time - instruction_start_time

        results = model(frame, verbose=False)
        status = "Waiting"

        knee_avg = None

        for r in results:
            if r.keypoints is None:
                continue

            k = r.keypoints.xy[0].cpu().numpy()

            L_HIP, R_HIP = k[11], k[12]
            L_KNEE, R_KNEE = k[13], k[14]
            L_ANK, R_ANK = k[15], k[16]

            left_knee = knee_angle(L_HIP, L_KNEE, L_ANK)
            right_knee = knee_angle(R_HIP, R_KNEE, R_ANK)

            knee_avg = (left_knee + right_knee) / 2

            max_angle = max(max_angle, knee_avg)

            if knee_avg > 0:
                angle_sum += knee_avg
                angle_count += 1

            # ---------------- DETECT MOVEMENT START ----------------
            if not movement_started and knee_avg < STAND_KNEE_THRESHOLD:
                movement_started = True
                start_time = current_time
                phase_text = "Sitting Down..."
                speak("Movement detected. Continue sitting.")

            # ---------------- DETECT COMPLETION ----------------
            if movement_started and knee_avg < SIT_KNEE_THRESHOLD:
                status = "Completed"
            elif movement_started:
                status = "Sitting..."

        filter_obj.update(status)
        stable_status = filter_obj.get_majority()

        # ---------------- FIRST 10 SECONDS ----------------
        if (not movement_started and
            not instruction_repeated and
            instruction_elapsed >= RESPONSE_LIMIT):

            speak("I did not detect movement. Please sit down now.")
            instruction_repeated = True
            instruction_start_time = current_time

        # ---------------- SECOND 10 SECONDS ----------------
        elif (not movement_started and
              instruction_repeated and
              instruction_elapsed >= RESPONSE_LIMIT):

            speak("No movement detected. Task ending.")
            time_to_complete = TOTAL_ALLOWED_TIME
            break

        # ---------------- MARK COMPLETION ----------------
        if stable_status == "Completed" and not movement_completed:
            movement_completed = True
            time_to_complete = current_time - start_time
            speak("Sit down completed.")
            break

        # ---------------- DISPLAY ----------------
        display = cv2.flip(frame, 1)

        if not movement_started:
            remaining = max(0, int(TOTAL_ALLOWED_TIME - total_elapsed))
            timer_text = f"Total Time: {remaining}s"
        else:
            duration = current_time - start_time
            timer_text = f"Movement Time: {round(duration, 2)}s"

        cv2.putText(display, f"Age Group: {age_group}",
                    (30, 40), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255,255,0), 2)

        cv2.putText(display, phase_text,
                    (30, 80), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0,255,255), 2)

        cv2.putText(display, timer_text,
                    (30, 120), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0,0,255), 2)

        cv2.putText(display, f"Status: {stable_status}",
                    (30, 160), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0,255,0), 2)

        cv2.imshow("Stand To Sit", display)

        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

    # ---------------- FINAL CALCULATIONS ----------------
    avg_angle = angle_sum / angle_count if angle_count else 0

    if not movement_completed and time_to_complete is None:
        time_to_complete = TOTAL_ALLOWED_TIME

    if movement_completed:
        upper_normal = reference_mean + reference_sd
        upper_borderline = reference_mean + (2 * reference_sd)

        if time_to_complete <= upper_normal:
            comparison = "Within Normal Range"
            result_color = (0, 255, 0)
        elif time_to_complete <= upper_borderline:
            comparison = "Slightly Slower Than Average"
            result_color = (0, 255, 255)
        else:
            comparison = "Clinically Slow / Possible Mobility Risk"
            result_color = (0, 0, 255)
    else:
        comparison = "Movement Not Completed"
        result_color = (0, 0, 255)

    # ---------------- FINAL SCREEN ----------------
    if display is not None:

        final_frame = display.copy()

        cv2.putText(final_frame, "TASK COMPLETED",
                    (30, 200), cv2.FONT_HERSHEY_SIMPLEX, 1, (0,0,255), 3)

        cv2.putText(final_frame,
                    f"Total Time: {round(time_to_complete, 2)} sec",
                    (30, 240), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0,255,0), 2)

        cv2.putText(final_frame,
                    f"Result: {comparison}",
                    (30, 280), cv2.FONT_HERSHEY_SIMPLEX,
                    0.8, result_color, 2)

        cv2.imshow("Stand To Sit", final_frame)
        cv2.waitKey(6000)

    cv2.destroyWindow("Stand To Sit")

    save_stand_to_sit_report(
        age_group,
        movement_completed,
        time_to_complete,
        max_angle,
        avg_angle,
        f"{reference_mean} ± {reference_sd}",
        comparison,
        instruction_time
    )

    speak("Task finished.")