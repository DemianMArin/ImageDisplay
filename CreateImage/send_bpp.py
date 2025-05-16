#!/usr/bin/env python3

import serial
import time
import argparse
import os
import binascii
import sys

# Control characters for protocol 
START_IMAGE = 0x01  # SOH - Start of Heading
READY = 0x06        # ACK - Acknowledge
ACK = 0x06          # Same as READY
END_IMAGE = 0x03    # ETX - End of Text
IMAGE_RECEIVED = 0x16  # SYN - Synchronous Idle

# Chunk size in bytes (adjust based on your system's buffer size)
CHUNK_SIZE = 10240
BYTES_IN_BASE64 = 10240

def send_image(port_name, image_path, timeout=1000):
    # Open the serial port
    try:
        ser = serial.Serial(
            port=port_name,
            baudrate=500000,
            bytesize=serial.EIGHTBITS,
            parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE,
            timeout=1  # Read timeout in seconds
        )
    except serial.SerialException as e:
        print(f"Error opening serial port: {e}")
        return False
    
    print(f"Connected to {port_name} at 500kbps")
    
    # Read the Base64 image data
    try:
        with open(image_path, 'r') as f:
            base64_data = f.read().strip()
        
        # Verify that we have the expected image size
        if len(base64_data) != BYTES_IN_BASE64:
            print(f"Warning: Expected {BYTES_IN_BASE64} bytes, but got {len(base64_data)} bytes")
            
    except Exception as e:
        print(f"Error reading image file: {e}")
        ser.close()
        return False
    
    print(f"Image loaded: {len(base64_data)} bytes")
    
    # Calculate simple checksum
    checksum = sum(base64_data.encode()) % 256
    
    # State machine for communication
    state = "INIT"
    attempts = 0
    start_time = time.time()
    chunk_index = 0
    
    while state != "DONE" and (time.time() - start_time) < timeout:
        if state == "INIT":
            # Send start image command with size and checksum
            header = bytes([START_IMAGE]) + str(len(base64_data)).encode() + b"," + str(checksum).encode()
            ser.write(header)
            print(f"Sent START_IMAGE command: {header}")
            state = "WAIT_READY"
            attempts = 0
        
        elif state == "WAIT_READY":
            # Wait for READY response
            response = ser.read(1)
            if response and response[0] == READY:
                print("Received READY signal from FPGA")
                state = "SEND_DATA"
                chunk_index = 0
            else:
                attempts += 1
                if attempts >= 3:
                    print("FPGA not responding with READY. Retrying...")
                    state = "INIT"
                    time.sleep(0.1)
        
        elif state == "SEND_DATA":
            # Send data in chunks
            chunk = base64_data[chunk_index:chunk_index+CHUNK_SIZE].encode()
            ser.write(chunk)
            print(f"Sent chunk {chunk_index//CHUNK_SIZE + 1}/{int(BYTES_IN_BASE64/CHUNK_SIZE)} ({len(chunk)} bytes)")
            state = "WAIT_ACK"
            attempts = 0
        
        elif state == "WAIT_ACK":
            # Wait for ACK after each chunk
            response = ser.read(1)
            if response and response[0] == ACK:
                chunk_index += CHUNK_SIZE
                if chunk_index >= len(base64_data):
                    state = "SEND_END"
                else:
                    state = "SEND_DATA"
            else:
                attempts += 1
                if attempts >= 3:
                    print(f"No ACK received for chunk {chunk_index//CHUNK_SIZE + 1}. Resending...")
                    state = "SEND_DATA"
                    time.sleep(0.1)
        
        elif state == "SEND_END":
            # Send end of image marker
            ser.write(bytes([END_IMAGE]))
            print("Sent END_IMAGE marker")
            state = "WAIT_COMPLETE"
            attempts = 0
        
        elif state == "WAIT_COMPLETE":
            # Wait for image received confirmation
            response = ser.read(1)
            if response and response[0] == IMAGE_RECEIVED:
                print("FPGA confirmed image reception")
                state = "DONE"
            else:
                attempts += 1
                if attempts >= 3:
                    print("No completion confirmation. Sending END_IMAGE again...")
                    state = "SEND_END"
                    time.sleep(0.1)
    
    # Close the serial port
    ser.close()
    
    if state == "DONE":
        print(f"Image transfer completed in {time.time() - start_time:.2f} seconds")
        return True
    else:
        print("Image transfer timed out or failed")
        return False

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Send Base64 encoded image to FPGA via UART')
    parser.add_argument('port', help='Serial port (e.g., COM3 or /dev/ttyUSB0)')
    parser.add_argument('image', help='Path to Base64 encoded image file')
    
    args = parser.parse_args()
    
    send_image(args.port, args.image)
