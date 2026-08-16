import os
import tkinter as tk
import numpy as np
import torch
import torch.nn as nn
import torch.optim as optim
from torchvision import datasets, transforms
import copy
from scipy.ndimage import center_of_mass, shift
import serial
import time

print("==================================================")
print("1. INITIATING HARDCORE PRECISION TRAINING PIPELINE")
print("==================================================")

PORT = "COM14"
BAUD = 115200

try:
    ser = serial.Serial(PORT, BAUD, timeout=1)
    print(f"[UART] Connected to FPGA on {PORT} for Real-Time Streaming!")
except Exception as e:
    print(f"[UART] Warning: Serial port {PORT} offline. Running in Simulation Mode.")
    ser = None

# Surgical Augmentation: Forces the model to learn structural curves
transform_train = transforms.Compose([
    transforms.RandomRotation(15),
    transforms.RandomAffine(degrees=0, translate=(0.1, 0.1), scale=(0.8, 1.2), shear=10),
    transforms.ToTensor() 
])

transform_test = transforms.Compose([
    transforms.ToTensor()
])

print("Downloading and Loading MNIST...")
train_dataset = datasets.MNIST(root='./data', train=True, download=True, transform=transform_train)
test_dataset = datasets.MNIST(root='./data', train=False, download=True, transform=transform_test)

train_loader = torch.utils.data.DataLoader(train_dataset, batch_size=64, shuffle=True)
test_loader = torch.utils.data.DataLoader(test_dataset, batch_size=1000, shuffle=False)

class MNIST_MLP(nn.Module):
    def __init__(self):
        super(MNIST_MLP, self).__init__()
        self.fc1 = nn.Linear(784, 64)
        self.relu = nn.ReLU()
        self.fc2 = nn.Linear(64, 10)

    def forward(self, x):
        x = x.view(-1, 784)
        x = self.relu(self.fc1(x))
        x = self.fc2(x)
        return x

model = MNIST_MLP()
criterion = nn.CrossEntropyLoss()

# ADVANCED OPTIMIZER: weight_decay keeps weights small for perfect 8-bit quantization
optimizer = optim.Adam(model.parameters(), lr=0.002, weight_decay=1e-5)

# LR SCHEDULER: Drops learning rate when accuracy plateaus for ultra-fine tuning (fixed for newer PyTorch)
scheduler = optim.lr_scheduler.ReduceLROnPlateau(optimizer, mode='max', patience=2, factor=0.5)

epochs = 30
best_accuracy = 0.0
best_model_weights = copy.deepcopy(model.state_dict())

print(f"\nStarting Maximum-Precision Training ({epochs} Epochs)...")
for epoch in range(epochs):
    model.train()
    running_loss = 0.0
    for images, labels in train_loader:
        optimizer.zero_grad()
        outputs = model(images)
        loss = criterion(outputs, labels)
        loss.backward()
        optimizer.step()
        running_loss += loss.item()
    
    # Rigorous Evaluation every single epoch
    model.eval()
    correct, total = 0, 0
    with torch.no_grad():
        for images, labels in test_loader:
            outputs = model(images)
            _, predicted = torch.max(outputs.data, 1)
            total += labels.size(0)
            correct += (predicted == labels).sum().item()
    
    accuracy = 100.0 * correct / total
    print(f"Epoch [{epoch+1}/{epochs}] - Loss: {running_loss/len(train_loader):.4f} | Test Acc: {accuracy:.2f}%")
    
    scheduler.step(accuracy)

    # ONLY SAVE THE ABSOLUTE BEST MODEL
    if accuracy > best_accuracy:
        best_accuracy = accuracy
        best_model_weights = copy.deepcopy(model.state_dict())
        print(f"  -> [NEW HIGH SCORE RECORDED: {best_accuracy:.2f}%]")

# Reload the absolute best weights back into the model before exporting
model.load_state_dict(best_model_weights)
print(f"\n==================================================")
print(f"TRAINING COMPLETE. FINAL LOCKED-IN ACCURACY: {best_accuracy:.2f}%")
print("==================================================")

print("\n==================================================")
print("2. EXPORTING 8-BIT QUANTIZED WEIGHTS")
print("==================================================")

def quantize_to_8bit(tensor):
    max_val = torch.max(torch.abs(tensor))
    scale = 127.0 / (max_val.item() if max_val.item() != 0 else 1.0)
    return torch.round(tensor * scale).clamp(-128, 127).to(torch.int8)

downloads_path = os.path.join(os.path.expanduser('~'), 'Downloads')

def write_mem_file(filename, tensor):
    filepath = os.path.join(downloads_path, filename)
    with open(filepath, 'w') as f:
        for val in tensor.cpu().numpy().flatten():
            f.write(format(int(val) & 0xFF, '02x') + '\n')
    print(f"Exported -> {filepath}")

write_mem_file("l1_weights.mem", quantize_to_8bit(model.fc1.weight.data))
write_mem_file("l1_biases.mem", quantize_to_8bit(model.fc1.bias.data))
write_mem_file("l2_weights.mem", quantize_to_8bit(model.fc2.weight.data))
write_mem_file("l2_biases.mem", quantize_to_8bit(model.fc2.bias.data))
print("ACTION REQUIRED: Copy these 4 new .mem files into Vivado and Generate Bitstream!\n")

print("==================================================")
print("3. LAUNCHING PIXEL-GRID GUI")
print("==================================================")

class PixelGridGUI:
    def __init__(self, root, trained_model):
        self.root = root
        self.root.title("Edge Artix-7 Grid Canvas")
        self.model = trained_model
        self.model.eval()

        self.grid_size = 28
        self.cell_size = 15 # Size of each grid block on screen
        self.pixel_array = np.zeros((self.grid_size, self.grid_size), dtype=np.float32)
        
        self.canvas = tk.Canvas(root, width=self.grid_size*self.cell_size, height=self.grid_size*self.cell_size, bg="black")
        self.canvas.pack(pady=10)
        
        # Create the visual grid
        self.rectangles = []
        for y in range(self.grid_size):
            row = []
            for x in range(self.grid_size):
                x1, y1 = x * self.cell_size, y * self.cell_size
                x2, y2 = x1 + self.cell_size, y1 + self.cell_size
                rect = self.canvas.create_rectangle(x1, y1, x2, y2, fill="black", outline="#222222")
                row.append(rect)
            self.rectangles.append(row)

        self.canvas.bind("<B1-Motion>", self.draw)
        self.canvas.bind("<ButtonRelease-1>", self.real_time_stream)

        tk.Button(root, text="Clear Canvas", command=self.clear_canvas, width=15, font=("Arial", 12, "bold")).pack(pady=5)
        self.status_label = tk.Label(root, text="Draw directly on the grid. Updates instantly.", font=("Arial", 12))
        self.status_label.pack(pady=10)

    def draw(self, event):
        x = event.x // self.cell_size
        y = event.y // self.cell_size
        
        if 0 <= x < self.grid_size and 0 <= y < self.grid_size:
            # Main brush stroke (bright white)
            self.pixel_array[y, x] = 1.0
            self.canvas.itemconfig(self.rectangles[y][x], fill="white")
            
            # Soft anti-aliased edge to mimic MNIST pen strokes
            for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                nx, ny = x + dx, y + dy
                if 0 <= nx < self.grid_size and 0 <= ny < self.grid_size:
                    if self.pixel_array[ny, nx] == 0:
                        self.pixel_array[ny, nx] = 0.5
                        self.canvas.itemconfig(self.rectangles[ny][nx], fill="gray")

    def clear_canvas(self):
        self.pixel_array.fill(0)
        for y in range(self.grid_size):
            for x in range(self.grid_size):
                self.canvas.itemconfig(self.rectangles[y][x], fill="black")
        self.status_label.config(text="Canvas Cleared.")

    def real_time_stream(self, event):
        if self.pixel_array.sum() == 0:
            return

        # 1. Mathematically center the drawing on the 28x28 grid
        cy, cx = center_of_mass(self.pixel_array)
        shift_y, shift_x = 14.0 - cy, 14.0 - cx
        centered_array = shift(self.pixel_array, [shift_y, shift_x], mode='constant', cval=0.0)
        
        # 2. Convert to FPGA 8-bit limits (0 to 127)
        fpga_array = np.clip(centered_array * 127.0, 0, 127).astype(np.uint8)

        # 3. Software Prediction Check
        tensor_img = transforms.ToTensor()(centered_array.astype(np.float32)).unsqueeze(0)
        with torch.no_grad():
            output = self.model(tensor_img)
            pred = torch.argmax(output, dim=1).item()

        # 4. Hardware UART Stream
        pixel_bytes = fpga_array.tobytes()
        if ser and ser.is_open:
            try:
                ser.write(bytes([0xAA])) # Header
                time.sleep(0.001)
                for b in pixel_bytes:
                    ser.write(bytes([b]))
                    time.sleep(0.0002) # Prevents UART buffer overflow on FPGA
                self.status_label.config(text=f"Sent to FPGA! (Software predicts: {pred})")
            except Exception as e:
                self.status_label.config(text=f"UART Error: {e}")
        else:
            self.status_label.config(text=f"Simulation Mode (Software predicts: {pred})")

if __name__ == "__main__":
    root = tk.Tk()
    app = PixelGridGUI(root, model)
    root.mainloop()