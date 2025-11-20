import numpy as np
import matplotlib.pyplot as plt

def connect_points(points, density=50):
    """
    Takes a list of [x, y] coordinates and returns arrays of x and y
    values that interpolate between them using linspace.
    """
    x_all = np.array([])
    y_all = np.array([])

    for i in range(len(points) - 1):
        p1 = points[i]
        p2 = points[i+1]
        
        # Create 50 points between p1 and p2
        # This is the practical use of linspace you asked about!
        x_segment = np.linspace(p1[0], p2[0], density)
        y_segment = np.linspace(p1[1], p2[1], density)
        
        x_all = np.concatenate([x_all, x_segment])
        y_all = np.concatenate([y_all, y_segment])
        
    return x_all, y_all

# --- Define the Shapes (Key Coordinates) ---

# "S" - Approximated with points to look curvy
s_points = [
    [0.8, 1.0], [0.2, 1.0], [0.0, 0.8], # Top curve
    [0.0, 0.6], [0.8, 0.4],             # Middle stroke
    [1.0, 0.2], [0.8, 0.0], [0.2, 0.0]  # Bottom curve
]

# "W" - Sharp points
w_points = [
    [0.0, 1.0], [0.2, 0.0],   # Down
    [0.5, 0.6],               # Middle Up
    [0.8, 0.0], [1.0, 1.0]    # Up
]

# "C" - Boxy C with cut corners
c_points = [
    [1.0, 0.8], [0.8, 1.0], [0.2, 1.0], # Top
    [0.0, 0.8], [0.0, 0.2],             # Left side
    [0.2, 0.0], [0.8, 0.0], [1.0, 0.2]  # Bottom
]

# --- Generate Data ---

# Generate the dense coordinates
sx, sy = connect_points(s_points)
wx, wy = connect_points(w_points)
cx, cy = connect_points(c_points)

# Shift letters on the X-axis so they don't overlap
# S stays at 0, W moves over 1.5, C moves over 3.0
wx += 1.5
cx += 3.0

# Combine all into single arrays for plotting
final_x = np.concatenate([sx, wx, cx])
final_y = np.concatenate([sy, wy, cy])

# --- Plotting ---

plt.figure(figsize=(10, 4))

# You can use 'plot' for lines, or 'scatter' for dots
plt.scatter(final_x, final_y, color='blue', s=10, label='Data Points')

plt.title("SWC Plot using np.linspace")
plt.axis('equal')  # Ensures letters aren't stretched
plt.grid(True, alpha=0.3)
plt.legend()
plt.show()

