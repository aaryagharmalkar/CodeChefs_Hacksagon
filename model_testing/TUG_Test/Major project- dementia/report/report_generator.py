import csv
import os
import time

REPORT_FOLDER = "reports"

if not os.path.exists(REPORT_FOLDER):
    os.makedirs(REPORT_FOLDER)


# --------------------------------------------------
# HAND TASK REPORT
# --------------------------------------------------
def save_hand_report(command,
                     final_status,
                     movement_completed,
                     reaction_time,
                     max_angle,
                     avg_angle,
                     hand_result,
                     instruction_time):

    filename = os.path.join(
        REPORT_FOLDER,
        f"hand_task_{int(time.time())}.csv"
    )

    with open(filename, mode='w', newline='') as file:
        writer = csv.writer(file)

        writer.writerow(["Metric", "Value"])
        writer.writerow(["Task Type", "Hand Raise"])
        writer.writerow(["Instruction Time", instruction_time])
        writer.writerow(["Command Given", command])
        writer.writerow(["Final Status", final_status])
        writer.writerow(["Movement Completed", movement_completed])
        writer.writerow(["Reaction Time (s)", reaction_time])
        writer.writerow(["Maximum Shoulder Angle", max_angle])
        writer.writerow(["Average Shoulder Angle", avg_angle])
        writer.writerow(["Hand Detection Result", hand_result])
        writer.writerow(["Report Generated At", time.strftime("%Y-%m-%d %H:%M:%S")])

    print(f"Hand task report saved at {filename}")


# --------------------------------------------------
# SIT TO STAND REPORT
# --------------------------------------------------
def save_sit_to_stand_report(age_group,
                             movement_completed,
                             time_to_complete,
                             max_angle,
                             avg_angle,
                             reference_time,
                             comparison_text,
                             instruction_time):

    filename = os.path.join(
        REPORT_FOLDER,
        f"sit_to_stand_{int(time.time())}.csv"
    )

    with open(filename, mode='w', newline='') as file:
        writer = csv.writer(file)

        writer.writerow(["Metric", "Value"])
        writer.writerow(["Task Type", "Sit To Stand"])
        writer.writerow(["Instruction Time", instruction_time])
        writer.writerow(["Age Group", age_group])
        writer.writerow(["Movement Completed", movement_completed])
        writer.writerow(["Time Taken (s)", time_to_complete])
        writer.writerow(["Age Group Average Time (s)", reference_time])
        writer.writerow(["Maximum Knee Angle", max_angle])
        writer.writerow(["Average Knee Angle", avg_angle])
        writer.writerow(["Performance Comparison", comparison_text])
        writer.writerow(["Report Generated At", time.strftime("%Y-%m-%d %H:%M:%S")])

    print(f"Sit-to-Stand report saved at {filename}")


# --------------------------------------------------
# STAND TO SIT REPORT
# --------------------------------------------------
def save_stand_to_sit_report(age_group,
                             movement_completed,
                             time_to_complete,
                             max_angle,
                             avg_angle,
                             reference_time,
                             comparison_text,
                             instruction_time):

    filename = os.path.join(
        REPORT_FOLDER,
        f"stand_to_sit_{int(time.time())}.csv"
    )

    with open(filename, mode='w', newline='') as file:
        writer = csv.writer(file)

        writer.writerow(["Metric", "Value"])
        writer.writerow(["Task Type", "Stand To Sit"])
        writer.writerow(["Instruction Time", instruction_time])
        writer.writerow(["Age Group", age_group])
        writer.writerow(["Movement Completed", movement_completed])
        writer.writerow(["Time Taken (s)", time_to_complete])
        writer.writerow(["Age Group Average Time (s)", reference_time])
        writer.writerow(["Maximum Knee Angle", max_angle])
        writer.writerow(["Average Knee Angle", avg_angle])
        writer.writerow(["Performance Comparison", comparison_text])
        writer.writerow(["Report Generated At", time.strftime("%Y-%m-%d %H:%M:%S")])

    print(f"Stand-to-Sit report saved at {filename}")