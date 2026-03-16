#%% Libraries

import socket
import struct
import numpy as np
import matplotlib.pyplot as plt
import argparse

#%% Definitions

# TCP Server
HOST                = "0.0.0.0"        # Listen on all network interfaces
PORT                = 5001             # TCP port to receive data

# Reception
TCP_CHUNK_SIZE      = 4 * 1024         # Size of each received TCP chunk in bytes

# Data Interpretation
SAMPLES_TO_PRINT    = 2000             # Number of samples to print to console
SAMPLES_TO_PLOT     = 500              # Number of samples to plot

#%% Functions

# Creates a TCP server socket, binds to host:port and waits for a client connection
def start_server(host, port):
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind((host, port))
    s.listen(1)
    print(f"Server listening on {host}:{port} ...")
    conn, addr = s.accept()
    print(f"Client connected from {addr}")
    return conn

# Receives the DMA buffer from the client over TCP
def receive_buffer(conn):
    header = conn.recv(4)
    if len(header) < 4:
        raise ValueError("Incomplete header received")
    bufsize = struct.unpack("<I", header)[0]
    print(f"Expecting {bufsize} bytes...")
    received_data = bytearray()
    while len(received_data) < bufsize:
        chunk = conn.recv(TCP_CHUNK_SIZE)
        if not chunk:
            break
        received_data.extend(chunk)
    print(f"Received {len(received_data)} bytes")
    return received_data

# Interprets raw bytes as 32-bit unsigned integers (little-endian)
def interpret_as_32bits(data):
    if len(data) % 4 != 0:
        raise ValueError(f"Data size ({len(data)} bytes) is not a multiple of 4")
    values = struct.unpack("<" + "I" * (len(data) // 4), data)
    return values

# Extracts the lower 16 bits of each 32-bit value and interprets them as signed integers
# ADC samples are packed in the lower 16 bits of each 32-bit AXI Stream word
def extract_lower_16bits_signed(values):
    lower_values = np.array([v & 0xFFFF for v in values], dtype=np.uint16)
    return lower_values.astype(np.int16).tolist()

# Plots ADC samples as a time-domain waveform
def plot_data(values, step=1):
    plt.figure(figsize=(12, 4))
    plt.plot(values[::step], marker="o", markersize=2, linestyle="-", linewidth=0.8)
    plt.title("ADC Captured Data (DMA)")
    plt.xlabel("Sample")
    plt.ylabel("Amplitude (16-bit signed)")
    plt.grid(True)
    plt.tight_layout()
    plt.show()

#%% Main Code

conn = None

try:
    # Configuration of argparse
    parser = argparse.ArgumentParser(description="TCP server to receive and plot DMA captured ADC data")
    parser.add_argument('--host',           type=str, default=HOST,             help="Interface to listen on (default: 0.0.0.0)")
    parser.add_argument('--port',           type=int, default=PORT,             help="TCP port to listen on (default: 5001)")
    parser.add_argument('--samples_print',  type=int, default=SAMPLES_TO_PRINT, help="Number of samples to print to console")
    parser.add_argument('--samples_plot',   type=int, default=SAMPLES_TO_PLOT,  help="Number of samples to plot")
    args = parser.parse_args()

    # Start TCP server and wait for client connection
    conn = start_server(args.host, args.port)

    with conn:
        # Receive raw bytes from the DMA buffer
        data = receive_buffer(conn)

        # Interpret raw bytes as 32-bit words
        values32 = interpret_as_32bits(data)

        # Extract lower 16 bits as signed ADC samples
        values16_signed = extract_lower_16bits_signed(values32)

        # Print first N samples to console
        print(f"\nFirst {args.samples_print} ADC samples (16-bit signed):")
        for i, v in enumerate(values16_signed[:args.samples_print]):
            print(f"  [{i:04d}] {v}")

        # Plot first N samples
        plot_data(values16_signed[:args.samples_plot], step=1)

except KeyboardInterrupt:
    print("\nInterrupted by user. Shutting down server...")

except ValueError as e:
    print(f"Data error: {e}")

except Exception as e:
    print(f"Unexpected error: {e}")

finally:
    if conn:
        conn.close()