#%% Libraries

import os
import mmap
import time
import socket
import argparse

#%% Definitions

# Destination TCP server
HOST                = "192.168.18.14"   # IP address of the receiving PC
PORT                = 5001              # TCP port on which the destination PC is listening

# DMA Buffer Address
DDR_SRC_ADDR        = 0x1ff00000        # Physical start address of the DMA buffer in DDR
DMA_TRANSFER_SIZE   = 16 * 1024          # DMA transfer size in bytes

# TCP Transmission
TCP_CHUNK_SIZE      = 16 * 1024          # Size of each TCP chunk sent to the server

# Synchronization
DMA_READY_TIMEOUT   = 15.0              # Maximum seconds to wait for the DMA flag

#%% Functions

# Waits until dma_capture.py signals that the DMA transfer is complete
def wait_for_dma_ready(path, timeout):
    print("Waiting for DMA transfer to complete...")
    t_start = time.time()
    while not os.path.exists(path):
        if time.time() - t_start > timeout:
            raise TimeoutError("Timed out waiting for DMA ready flag")
        time.sleep(0.05)
    os.remove(path)
    print("DMA ready flag received. Reading DDR buffer...")

# Opens the DMA buffer from /dev/mem as a read-only memory map
def open_dma_buffer(size, offset):
    if not os.path.exists("/dev/mem"):
        raise FileNotFoundError("/dev/mem not found")
    f = open("/dev/mem", "rb")
    return mmap.mmap(f.fileno(), size, offset=offset, access=mmap.ACCESS_READ)

# Creates a TCP socket and connects to the destination server
def create_socket(host, port):
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.connect((host, port))
    return s

# Sends the DMA buffer contents over TCP in chunks
def send_buffer(sock, mem, size, chunk_size):
    sock.sendall(size.to_bytes(4, "little"))
    offset = 0
    while offset < size:
        chunk = mem[offset: offset + chunk_size]
        if not chunk:
            break
        sock.sendall(chunk)
        offset += chunk_size

#%% Main Code

sock    = None
dma_mem = None

try:
    # Configuration of argparse
    parser = argparse.ArgumentParser(description="Read DMA buffer from DDR and send it over TCP")
    parser.add_argument('--ddr_src_addr', type=lambda x: int(x, 0),default=DDR_SRC_ADDR,  help="Physical DDR address to read from (e.g. 0x1ff00000)")
    parser.add_argument('--host',         type=str,                 default=HOST,          help="IP address of the destination TCP server")
    parser.add_argument('--port',         type=int,                 default=PORT,          help="TCP port of the destination server")
    args = parser.parse_args()

    # Wait until dma_capture.py confirms the DMA transfer is done
    wait_for_dma_ready("/tmp/dma_ready", DMA_READY_TIMEOUT)

    # Open the DDR memory region where the DMA stored the captured data
    dma_mem = open_dma_buffer(DMA_TRANSFER_SIZE, args.ddr_src_addr)

    # Connect to the destination TCP server
    sock = create_socket(args.host, args.port)
    print(f"Connected to {args.host}:{args.port}. Sending DMA buffer...")

    # Send the DMA buffer contents over TCP
    send_buffer(sock, dma_mem, DMA_TRANSFER_SIZE, TCP_CHUNK_SIZE)
    print(f"Buffer sent successfully ({DMA_TRANSFER_SIZE} bytes).")

except TimeoutError as e:
    print(f"Synchronization error: {e}")
except FileNotFoundError as e:
    print(f"Device error: {e}")
except ConnectionRefusedError:
    print(f"Connection refused: could not reach {args.host}:{args.port}")
except KeyboardInterrupt:
    print("\nInterrupted by user. Closing connection...")
except Exception as e:
    print(f"Unexpected error: {e}")

finally:
    # Release resources
    if sock:
        sock.close()
    if dma_mem:
        dma_mem.close()