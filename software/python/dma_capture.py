#%% Libraries

import os  
import mmap  
import time  
import struct
import argparse  

#%% Definitions

# GPIO Address
GPIO_MUX_SELECT     =   520         # Length 2 bits
GPIO_PMOD_DIVIDER   =   522         # Length 8 bits
GPIO_PMOD_ENABLE    =   530         # Length 1 bit
GPIO_LENGTH_TLAST   =   531         # Length 16 bits
GPIO_FFT_CONFIG     =   547         # Length 8 bits

# DMA Address
DMA_BASE_ADDR       = 0x40400000    # Base address of the AXI-DMA block mapped to the FPGA
DDR_DST_ADDR        = 0x1ff00000    # Physical address in DDR where the DMA will write the data
DMA_TRANSFER_SIZE   = 16 * 1024      # DMA transfer size in bytes

# AXI DMA internal register offsets
S2MM_DMACR          = 0x30          # Control the channel (reset, enable)
S2MM_DMASR          = 0x34          # Read the status (idle, error, complete)
S2MM_DA             = 0x48          # Tell him where to write in DDR
S2MM_LENGTH         = 0x58          # How many bytes to transfer

# Synchronization
DMA_READY_FLAG      = "/tmp/dma_ready"  # File created when DMA transfer completes

#%% Functions

# It goes to the offset position within the DMA register map and reads 4 bytes
def dma_reg_read(dma, offset):  
    dma.seek(offset)  
    return struct.unpack("<I", dma.read(4))[0]  

# It goes to the offset position and writes a 32-bit integer
def dma_reg_write(dma, offset, value):  
    dma.seek(offset)  
    dma.write(struct.pack("<I", value))  
    
# Enables a specific GPIO so that it can be used from the Linux file system
def export_gpio(number):  
    path = f"/sys/class/gpio/gpio{number}"  
    if not os.path.exists(path):  
        with open("/sys/class/gpio/export", "w") as f:  
            f.write(str(number))  
        time.sleep(0.05)  
    return path  

# Free up a GPIO, removing its access
def unexport_gpio(number):
    with open("/sys/class/gpio/unexport", "w") as f:
        f.write(str(number))

# Configure the GPIO direction
def set_gpio_direction(gpio_path, direction="out"):  
    with open(os.path.join(gpio_path, "direction"), "w") as f:  
        f.write(direction)  

# Write a logical value (0 or 1) to the GPIO configured as an output
def write_gpio_value(gpio_path, value):  
    with open(os.path.join(gpio_path, "value"), "w") as f:  
        f.write(str(int(bool(value))))  
        
# Enable a group of GPIOs in block
def export_gpio_block(base_gpio, bits=16, direction="out"):
    gpio_paths = []
    for i in range(bits):
        gpio_num = base_gpio + i
        path = export_gpio(gpio_num)
        set_gpio_direction(path, direction)
        gpio_paths.append(path)
    return gpio_paths

# Disable a group of GPIOs in block
def unexport_gpio_block(base_gpio, bits=16):
    for i in range(bits):
        unexport_gpio(base_gpio + i)
        
# Write several bits starting from base_gpio
def write_gpio_block(gpio_paths, value):
    bits = len(gpio_paths)
    for i in range(bits):
        bit_val = (value >> i) & 1  
        write_gpio_value(gpio_paths[i], bit_val)

# Creates the synchronization flag file to signal that DMA transfer is done
def set_dma_ready_flag(path):
    with open(path, "w") as f:
        f.write("ok")

#%% Main Code

#try: 
# Remove any leftover flag from a previous run
if os.path.exists(DMA_READY_FLAG):
    os.remove(DMA_READY_FLAG)

# Configuration of argparse
parser = argparse.ArgumentParser(description="Configure GPIO blocks for DMA")
parser.add_argument('--length_tlast', type=int,                 default=4096,           help="GPIO base number for LENGTH_TLAST (16 bits)")
parser.add_argument('--mux_select',   type=int,                 default=0b00,           help="GPIO base number for MUX_SELECT (2 bits)")
parser.add_argument('--ddr_dst_addr', type=lambda x: int(x, 0),default=DDR_DST_ADDR,   help="DDR memory address number (e.g. 0x1ff00000)")
args = parser.parse_args()

# Export GPIO Pins
gpio_mux_select_block   = export_gpio_block(GPIO_MUX_SELECT,    bits=2,     direction="out")
gpio_pmod_divider_block = export_gpio_block(GPIO_PMOD_DIVIDER,  bits=8,     direction="out")
gpio_pmod_enable_block  = export_gpio_block(GPIO_PMOD_ENABLE,   bits=1,     direction="out")
gpio_length_tlast_block = export_gpio_block(GPIO_LENGTH_TLAST,  bits=16,    direction="out")
gpio_fft_config_block   = export_gpio_block(GPIO_FFT_CONFIG,    bits=8,     direction="out")

# Write GPIO Pins
write_gpio_block(gpio_mux_select_block,     args.mux_select)    
write_gpio_block(gpio_pmod_divider_block,   1)
write_gpio_block(gpio_pmod_enable_block,    0b1)
write_gpio_block(gpio_length_tlast_block,   args.length_tlast)
write_gpio_block(gpio_fft_config_block,     0x00000A01)

# Wait for MUX to switch to the new channel (needs at least one TLAST pulse)
time.sleep(0.1)

# Open address /dev/mem
with open("/dev/mem", "r+b") as f:  

    # Map the AXI-DMA registers in memory to access them from Python
    dma = mmap.mmap(f.fileno(), 0x10000, offset=DMA_BASE_ADDR)  

    # Reset the S2MM channel by setting bit 2 (RS) of DMACR
    dma_reg_write(dma, S2MM_DMACR, 0x4)  
    time.sleep(0.01)  
    
    # Release reset by clearing DMACR, leaving the channel in IDLE
    dma_reg_write(dma, S2MM_DMACR, 0x0)  
    time.sleep(0.01)  
    
    # Set the destination address in DDR where the DMA will write incoming data
    dma_reg_write(dma, S2MM_DA, args.ddr_dst_addr)  
    
    # Enable the S2MM channel by setting bit 0 (RS=1) of DMACR
    dma_reg_write(dma, S2MM_DMACR, 0x1)  
    
    # Write the transfer length in bytes
    dma_reg_write(dma, S2MM_LENGTH, DMA_TRANSFER_SIZE)  
    print("Transfer from DMA to DDR started...")  

    # Poll the status register (DMASR) every 10 ms until the DMA responds
    timeout = 10.0
    t_start = time.time()
    while True:  
        status = dma_reg_read(dma, S2MM_DMASR)  
        
        # Bit 12 (IOC_Irq): transfer completed successfully
        if status & 0x1000: 
            print("Transfer completed successfully")
            # Signal dma_send.py that DDR data is ready
            set_dma_ready_flag(DMA_READY_FLAG)
            break  
        
        # Bits 4-7: DMA error flags (Slave Error, Decode Error, etc.)
        if status & 0xF0:   
            print(f"DMA ERROR, status: 0x{status:X}")  
            break  

        # Timeout
        if time.time() - t_start > timeout:
            print("DMA TIMEOUT: transfer did not complete")
            break

        time.sleep(0.01)
            
#finally:

    # Release GPIO Pins
    #unexport_gpio_block(GPIO_MUX_SELECT,    bits=2)
    #unexport_gpio_block(GPIO_PMOD_DIVIDER,  bits=8)
    #unexport_gpio_block(GPIO_PMOD_ENABLE,   bits=1)
    #unexport_gpio_block(GPIO_LENGTH_TLAST,  bits=16)
    #unexport_gpio_block(GPIO_FFT_CONFIG,    bits=8)
    