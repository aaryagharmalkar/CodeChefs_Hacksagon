import os
import sys
import time
from pathlib import Path


def import_major_tasks(major_dir: Path):
    previous_cwd = Path.cwd()

    try:
        os.chdir(major_dir)
        if str(major_dir) not in sys.path:
            sys.path.insert(0, str(major_dir))

        from tasks.sit_to_stand_task import run_sit_to_stand
        from tasks.stand_to_sit_task import run_stand_to_sit

        return run_sit_to_stand, run_stand_to_sit
    finally:
        os.chdir(previous_cwd)


def resolve_pose_model(base_dir: Path) -> Path:
    candidates = [
        base_dir / "pose_landmarker_full.task",
        base_dir / "walk-f and b" / "pose_landmarker_full.task",
        base_dir / "main" / "pose_landmarker_full.task",
    ]

    for candidate in candidates:
        if candidate.exists():
            return candidate

    raise FileNotFoundError("pose_landmarker_full.task not found")


def create_pose_landmarker(model_path: Path):
    import mediapipe as mp

    mp_pose = mp.tasks.vision.PoseLandmarker
    BaseOptions = mp.tasks.BaseOptions
    PoseLandmarkerOptions = mp.tasks.vision.PoseLandmarkerOptions
    VisionRunningMode = mp.tasks.vision.RunningMode

    options = PoseLandmarkerOptions(
        base_options=BaseOptions(model_asset_path=str(model_path)),
        running_mode=VisionRunningMode.VIDEO,
    )

    return mp_pose.create_from_options(options)


def run_walk_phase(cap, base_dir: Path):
    import cv2
    import mediapipe as mp
    import numpy as np

    model_path = resolve_pose_model(base_dir)
    landmarker = create_pose_landmarker(model_path)

    hip_positions = []
    timestamps = []

    state = "FORWARD"
    prev_hip = None

    direction_history = []
    walk_started_backward = False

    print("\n[Stage] Walk → Turn → Return")

    try:
        while cap.isOpened():
            ret, frame = cap.read()
            if not ret:
                break

            frame = cv2.flip(frame, 1)
            _, frame_width, _ = frame.shape

            rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)

            ts = int(time.time() * 1000)
            result = landmarker.detect_for_video(mp_image, ts)

            if result.pose_landmarks and len(result.pose_landmarks) > 0:
                lm = result.pose_landmarks[0]
                hip_x = ((lm[23].x + lm[24].x) / 2) * frame_width

                if prev_hip is not None:
                    movement = hip_x - prev_hip

                    if movement > 5:
                        direction = "right"
                    elif movement < -5:
                        direction = "left"
                    else:
                        direction = "still"

                    direction_history.append(direction)

                    # TURN DETECTION
                    if state == "FORWARD" and len(direction_history) > 10:
                        last = direction_history[-10:]
                        if "left" in last and "right" in last:
                            print("Turn detected")
                            state = "BACKWARD"

                    # BACKWARD START
                    if state == "BACKWARD" and abs(movement) > 5:
                        walk_started_backward = True

                prev_hip = hip_x

                hip_positions.append(hip_x)
                timestamps.append(time.time())

            # DISPLAY
            if state == "FORWARD":
                cv2.putText(frame, "WALK FORWARD",
                            (60, 60), cv2.FONT_HERSHEY_SIMPLEX,
                            1.2, (0, 255, 0), 4)

            elif state == "BACKWARD":
                cv2.putText(frame, "RETURN BACK",
                            (60, 60), cv2.FONT_HERSHEY_SIMPLEX,
                            1.2, (255, 200, 0), 4)

                # EXIT CONDITION (FIXED)
                if walk_started_backward and prev_hip is not None:
                    if abs(movement) < 2:   # user slowed/stopped
                        print("Return complete")
                        break

            cv2.imshow("TUG Walk Phase", frame)

            if cv2.waitKey(1) & 0xFF == ord('q'):
                break

        return True

    finally:
        landmarker.close()
        cv2.destroyAllWindows()

def main():
    base_dir = Path(__file__).resolve().parent
    major_dir = base_dir / "Major project- dementia"

    run_sit_to_stand, run_stand_to_sit = import_major_tasks(major_dir)

    import cv2

    print("\n===== PURE TUG TEST START =====")

    cap = cv2.VideoCapture(0)
    if not cap.isOpened():
        print("Camera could not be opened.")
        return

    try:
        os.chdir(major_dir)

        print("\n[Stage 1] Sit-to-Stand")
        run_sit_to_stand(cap)

        # ✅ START TIMER HERE (AFTER STANDING)
        tug_start = time.time()

        print("\n[Stage 2] Walk + Turn + Return")
        os.chdir(base_dir)
        ok = run_walk_phase(cap, base_dir)
        if not ok:
            print("Walk failed")
            return

        print("\n[Stage 3] Stand-to-Sit")
        os.chdir(major_dir)
        run_stand_to_sit(cap)

        # ✅ STOP TIMER AFTER SITTING
        tug_end = time.time()
        total_time = tug_end - tug_start

        print("\n==============================")
        print("        TUG RESULT")
        print("==============================")
        print(f"Total TUG Time: {round(total_time,2)} seconds")

        if total_time < 10:
            risk = "Low Risk"
        elif total_time < 14:
            risk = "Moderate Risk"
        else:
            risk = "High Fall Risk"

        print(f"Risk Level: {risk}")
        print("==============================")

    finally:
        cap.release()
        cv2.destroyAllWindows()

if __name__ == "__main__":
    main()