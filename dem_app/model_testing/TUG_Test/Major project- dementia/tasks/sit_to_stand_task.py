import time
import cv2
from ultralytics import YOLO
from config import *
from utils.filters import MajorityFilter
from report.report_generator import save_sit_to_stand_report
from pose_utils import knee_angle
from speech import speak


model = YOLO("yolov8n-pose.pt")


# Age reference values (seconds)
AGE_REFERENCE = {
    "children": 1.2,
    "young": 1.4,
    "senior": 1.4,
    "elderly": 1.4
}


def run_sit_to_stand(cap):

    # ---------------- AGE INPUT ----------------
    print("\nSelect Age Group:")
    print("1. Children")
    print("2. Young Adults")
    print("3. Senior Adults")
    print("4. Elderly Persons")

    choice = input("Enter choice (1-4): ")

    age_map = {
        "1": "children",
        "2": "young",
        "3": "senior",
        "4": "elderly"
    }

    age_group = age_map.get(choice, "young")
    reference_time = AGE_REFERENCE[age_group]

    # ---------------- PREPARATION TIMER ----------------
    speak("Get ready to stand up")

    for i in range(3, 0, -1):
        ret, frame = cap.read()
        if not ret:
            break
        display = cv2.flip(frame, 1)
        cv2.putText(display, f"Starting in {i}...",
                    (200, 200), cv2.FONT_HERSHEY_SIMPLEX,
                    1.5, (0, 255, 255), 3)
        cv2.imshow("Sit To Stand", display)
        cv2.waitKey(1000)

    speak("Please stand up now")

    start_time = time.time()
    instruction_time = time.strftime("%Y-%m-%d %H:%M:%S")

    filter_obj = MajorityFilter(STABLE_FRAMES_REQUIRED, MAJORITY_COUNT)

    movement_completed = False
    time_to_complete = None
    exit_reason = "Max duration reached"

    max_angle = 0
    angle_sum = 0
    angle_count = 0

    while True:

        ret, frame = cap.read()
        if not ret:
            break

        elapsed = time.time() - start_time
        results = model(frame, verbose=False)

        status = "Not Completed"

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

            if knee_avg > STAND_KNEE_THRESHOLD:
                status = "Completed"
            elif knee_avg > SIT_KNEE_THRESHOLD:
                status = "Moving"

        filter_obj.update(status)
        stable_status = filter_obj.get_majority()

        if stable_status == "Completed" and not movement_completed:
            movement_completed = True
            time_to_complete = elapsed
            exit_reason = "Task completed successfully"
            speak("Stand up completed")

        # -------- DISPLAY --------
        display = cv2.flip(frame, 1)

        cv2.putText(display, f"Age Group: {age_group.capitalize()}",
                    (30, 40), cv2.FONT_HERSHEY_SIMPLEX,
                    0.8, (255, 255, 0), 2)

        cv2.putText(display, f"Status: {stable_status}",
                    (30, 80), cv2.FONT_HERSHEY_SIMPLEX,
                    0.8, (0, 255, 0), 2)

        cv2.putText(display, f"Timer: {elapsed:.2f} sec",
                    (30, 120), cv2.FONT_HERSHEY_SIMPLEX,
                    0.8, (255, 0, 0), 2)

        cv2.imshow("Sit To Stand", display)

        if movement_completed or elapsed > MAX_TOTAL_DURATION:
            break

        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

    avg_angle = angle_sum / angle_count if angle_count else 0

    # -------- COMPARISON WITH AGE REFERENCE --------
    if time_to_complete is not None:
        if time_to_complete > reference_time:
            comparison = (
                f"Patient took {time_to_complete:.2f}s which is MORE than "
                f"average ({reference_time}s) for {age_group} group."
            )
        else:
            comparison = (
                f"Patient took {time_to_complete:.2f}s which is WITHIN "
                f"average ({reference_time}s) for {age_group} group."
            )
    else:
        comparison = "Patient did not complete the movement."

    # -------- FINAL RESULT SCREEN --------
    final_frame = display.copy()

    cv2.putText(final_frame, "TASK FINISHED",
                (30, 200), cv2.FONT_HERSHEY_SIMPLEX,
                1, (0, 0, 255), 3)

    cv2.putText(final_frame, f"Reason: {exit_reason}",
                (30, 240), cv2.FONT_HERSHEY_SIMPLEX,
                0.7, (200, 200, 200), 2)

    cv2.putText(final_frame, comparison,
                (30, 280), cv2.FONT_HERSHEY_SIMPLEX,
                0.6, (255, 255, 255), 2)

    cv2.imshow("Sit To Stand", final_frame)

    cv2.waitKey(5000)
    cv2.destroyWindow("Sit To Stand")

    # -------- SAVE REPORT --------
    save_sit_to_stand_report(
    age_group,
    movement_completed,
    time_to_complete,
    max_angle,
    avg_angle,
    reference_time,
    comparison,
    instruction_time
)