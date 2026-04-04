import numpy as np


# --------------------------------------------------
# SAFE NORMALIZATION
# --------------------------------------------------
def normalize_vector(v):
    """
    Safely normalize a vector.
    Avoids division-by-zero and NaN errors.
    """
    v = np.array(v, dtype=np.float32)

    if np.any(np.isnan(v)):
        return np.zeros_like(v)

    norm = np.linalg.norm(v)

    if norm < 1e-6:
        return np.zeros_like(v)

    return v / norm


# --------------------------------------------------
# GENERIC JOINT ANGLE (A-B-C)
# --------------------------------------------------
def calculate_angle(a, b, c):
    """
    Calculates angle between three points (A-B-C),
    where B is the joint (vertex).

    Returns:
        Angle in degrees (0 to 180)
    """

    a = np.array(a, dtype=np.float32)
    b = np.array(b, dtype=np.float32)
    c = np.array(c, dtype=np.float32)

    # Vectors
    ba = a - b
    bc = c - b

    # Normalize
    ba = normalize_vector(ba)
    bc = normalize_vector(bc)

    # Dot product
    dot = np.dot(ba, bc)
    dot = np.clip(dot, -1.0, 1.0)

    angle = np.degrees(np.arccos(dot))

    if np.isnan(angle):
        return 0.0

    return float(angle)


# --------------------------------------------------
# SHOULDER ELEVATION ANGLE
# --------------------------------------------------
def shoulder_elevation_angle(shoulder, elbow, hip):
    """
    Calculates shoulder elevation angle relative to torso.

    shoulder → elbow  = upper arm vector
    shoulder → hip    = torso reference vector

    Returns:
        Angle in degrees
    """

    shoulder = np.array(shoulder, dtype=np.float32)
    elbow = np.array(elbow, dtype=np.float32)
    hip = np.array(hip, dtype=np.float32)

    upper_arm = elbow - shoulder
    torso = hip - shoulder

    upper_arm = normalize_vector(upper_arm)
    torso = normalize_vector(torso)

    dot = np.dot(upper_arm, torso)
    dot = np.clip(dot, -1.0, 1.0)

    angle = np.degrees(np.arccos(dot))

    if np.isnan(angle):
        return 0.0

    return float(angle)


# --------------------------------------------------
# KNEE FLEXION ANGLE
# --------------------------------------------------
def knee_angle(hip, knee, ankle):
    """
    Calculates knee flexion angle using:
    hip → knee → ankle
    """
    return calculate_angle(hip, knee, ankle)