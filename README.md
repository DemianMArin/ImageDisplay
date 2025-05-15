# Image 2 Tangnano20k

## Computer procedure

- Computer: START_IMAGE [Size] [Checksum] 
- FPGA: READY 
- Computer: [Image data in chunks]
- FPGA: ACK after each chunk
- Computer: END_IMAGE 
- FPGA: IMAGE_RECEIVED 

```Python
START_IMAGE = 0x01  # SOH - Start of Heading
READY = 0x06        # ACK - Acknowledge
ACK = 0x06          # Same as READY
END_IMAGE = 0x03    # ETX - End of Text
IMAGE_RECEIVED = 0x16  # SYN - Synchronous Idle
```

**Base 64**: RFC 4648
