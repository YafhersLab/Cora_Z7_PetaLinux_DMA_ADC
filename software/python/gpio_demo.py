#%% Libraries

import os  
import time  
import argparse

#%% Definitions

GPIO_LED2_RED    = 512
GPIO_LED2_GREEN  = 513
GPIO_LED2_BLUE   = 514
GPIO_LED1_RED    = 515
GPIO_LED1_GREEN  = 516
GPIO_LED1_BLUE   = 517
GPIO_BTN_RIGHT   = 518
GPIO_BTN_LEFT    = 519

#%% Functions

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

# Read the current value (0 or 1) of the GPIO configured as input
def read_gpio_value(gpio_path):
    with open(os.path.join(gpio_path, "value"), "r") as f:
        return int(f.read().strip())   

def parse_rgb(bits):
    # Valida que sean exactamente 3 bits de 0s y 1s
    if len(bits) != 3 or not all(b in '01' for b in bits):
        raise argparse.ArgumentTypeError(f"'{bits}' is not valid. Use 3 bits, example: 010")
    return int(bits[0]), int(bits[1]), int(bits[2])

#%% Main Code

try:
    print("GPIO Test Demo - Outputs and Inputs")
    
    # Configuration of argparse
    parser = argparse.ArgumentParser(description="RGB LED control on Cora Z7")
    parser.add_argument('--led1', type=parse_rgb, default='100', help="RGB bits for LED1, example: 010 (R=0,G=1,B=0)")
    parser.add_argument('--led2', type=parse_rgb, default='001', help="RGB bits for LED2, example: 110 (R=1,G=1,B=0)")
    args = parser.parse_args()
    
    # Extract colors
    led1_r, led1_g, led1_b = args.led1
    led2_r, led2_g, led2_b = args.led2
    print(f"LED1 -> R={led1_r} G={led1_g} B={led1_b}")
    print(f"LED2 -> R={led2_r} G={led2_g} B={led2_b}")
    
    # Export GPIO Pins
    gpio_led1_red   = export_gpio(GPIO_LED1_RED)  
    gpio_led1_green = export_gpio(GPIO_LED1_GREEN)  
    gpio_led1_blue  = export_gpio(GPIO_LED1_BLUE) 
    gpio_led2_red   = export_gpio(GPIO_LED2_RED)  
    gpio_led2_green = export_gpio(GPIO_LED2_GREEN)  
    gpio_led2_blue  = export_gpio(GPIO_LED2_BLUE) 
    gpio_btn_left   = export_gpio(GPIO_BTN_LEFT)
    gpio_btn_right  = export_gpio(GPIO_BTN_RIGHT)
    
    # Direction Configuration
    set_gpio_direction(gpio_led1_red,   "out")  
    set_gpio_direction(gpio_led1_green, "out")  
    set_gpio_direction(gpio_led1_blue,  "out") 
    set_gpio_direction(gpio_led2_red,   "out")  
    set_gpio_direction(gpio_led2_green, "out")  
    set_gpio_direction(gpio_led2_blue,  "out") 
    set_gpio_direction(gpio_btn_left,   "in") 
    set_gpio_direction(gpio_btn_right,  "in") 
    
    # Write GPIO Pins
    write_gpio_value(gpio_led1_red,      led1_r)  
    write_gpio_value(gpio_led1_green,    led1_g)  
    write_gpio_value(gpio_led1_blue,     led1_b)  
    write_gpio_value(gpio_led2_red,      led2_r)  
    write_gpio_value(gpio_led2_green,    led2_g)  
    write_gpio_value(gpio_led2_blue,     led2_b)  
    time.sleep(1) 
         
    # Loop to read GPIO Inputs
    while True:
        btn_left = read_gpio_value(gpio_btn_left)
        btn_right = read_gpio_value(gpio_btn_right)
        print(f"BTN_LEFT={btn_left}, BTN_RIGTH={btn_right}")
        time.sleep(0.05)
        
except PermissionError:
    
    print("Error: You need superuser permissions to use GPIOs")
    exit(1)      
        
finally: 
    
    # Release GPIO Pins
    unexport_gpio(GPIO_LED1_RED)
    unexport_gpio(GPIO_LED1_GREEN)
    unexport_gpio(GPIO_LED1_BLUE)
    unexport_gpio(GPIO_LED2_RED)
    unexport_gpio(GPIO_LED2_GREEN)
    unexport_gpio(GPIO_LED2_BLUE)
    unexport_gpio(GPIO_BTN_LEFT)
    unexport_gpio(GPIO_BTN_RIGHT)