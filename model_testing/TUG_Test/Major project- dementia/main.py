import cv2
from tasks.hand_task import run_hand_task
from tasks.sit_to_stand_task import run_sit_to_stand
from tasks.stand_to_sit_task import run_stand_to_sit

cap = cv2.VideoCapture(0)

while True:
    print("\n1 - Hand Raise")
    print("2 - Sit to Stand")
    print("3 - Stand to Sit")
    print("4 - Exit")

    choice = input("Enter choice: ")

    if choice == "1":
        run_hand_task(cap)
    elif choice == "2":
        run_sit_to_stand(cap)
    elif choice == "3":
        run_stand_to_sit(cap)
    elif choice == "4":
        break

cap.release()
cv2.destroyAllWindows()