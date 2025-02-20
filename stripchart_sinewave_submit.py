import numpy as np
import matplotlib.pyplot as plt
import matplotlib.animation as animation
import sys, time, serial, csv, os
from datetime import datetime

# Set up serial connection
ser = serial.Serial(
    port='COM3', 
    baudrate=115200, 
    parity=serial.PARITY_NONE, 
    stopbits=serial.STOPBITS_TWO, 
    bytesize=serial.EIGHTBITS,
    timeout=1  # Ensures it doesn't block indefinitely
)

xsize = 1000  # Window size for the plot

# Define specific folder path for saving CSV files
base_folder = "C:\\ELEC 291\\Lab 3\\temperature_data"
os.makedirs(base_folder, exist_ok=True)

# Generate unique filename based on date/time
current_time = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
csv_filename = os.path.join(base_folder, f"serial_data_{current_time}.csv")

# Open CSV file to save data
csv_file = open(csv_filename, "w", newline='')
csv_writer = csv.writer(csv_file)
csv_writer.writerow(["Time (s)", "Temperature(C)"])  # Write header

paused = False  # Pause flag

#reset = False  # Reset flag

def toggle_pause():
    global paused
    paused = not paused  # Toggle pause state
    print("Paused" if paused else "Resumed")

def toggle_end():
    global paused
    paused = True  # Pause data collection
    print("Ending program")
    ser.close()  # Close serial connection
    csv_file.close()  # Close CSV file
    sys.exit(0)  # Exit program


def data_gen():
    t = 0  # Time counter
    time_step = 1  # Sensor takes 0.5 seconds per reading
    while True:
        while paused:
            time.sleep(0.1)  # Small delay to avoid high CPU usage
        
        line = ser.readline().decode('utf-8').strip()  # Read and decode serial data
        try:
            val = float(line)  # Convert to float
            print(f"Time: {t:.1f}s, Temperature: {val} C")  # Print data to console
            csv_writer.writerow([round(t, 1), val])  # Save data to CSV with proper time intervals
            csv_file.flush()  # Ensure data is written immediately
            yield t, val
            t += time_step  # Increment time index by 0.5 seconds
        except ValueError:
            pass  # Ignore invalid data

def run(data):
    t, y = data
    xdata.append(t)
    ydata.append(y)
    
    if t > xsize:  # Scroll window to the left
        ax.set_xlim(t - xsize, t)
    line.set_data(xdata, ydata)
    return line,

def on_close_figure(event):
    ser.close()  # Close serial connection
    csv_file.close()  # Close CSV file
    sys.exit(0)

# Initialize plot
data_gen.t = -1
fig = plt.figure()
fig.canvas.mpl_connect('close_event', on_close_figure)
ax = fig.add_subplot(111)
line, = ax.plot([], [], lw=2)
ax.set_ylim(0, 350)  # Set Y-axis limits to -50 to 50
ax.set_xlim(0, xsize)
ax.set_title("Temperature Sensor Data")
ax.set_xlabel("Time (s)")
ax.set_ylabel("Temperature (C)")
ax.grid()
xdata, ydata = [], []

# Animation function to update the plot in real time
ani = animation.FuncAnimation(fig, run, data_gen, blit=False, interval=100, repeat=False)
plt.show()



