#!/usr/bin/env python3
import socket
import time
import subprocess
import os

PORT = 24712
SDMC_3DS = os.path.expanduser("~/.var/app/org.azahar_emu.Azahar/data/azahar-emu/sdmc/3ds")
TARGET = os.path.join(SDMC_3DS, "Arch3ro.3dsx")

print(f"Launching Azahar on port {PORT}...")
emu = subprocess.Popen(["flatpak", "run", "org.azahar_emu.Azahar", "-g", str(PORT), TARGET],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

time.sleep(2)

try:
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.connect(("localhost", PORT))

    def send_cmd(cmd):
        chk = sum(cmd.encode("latin-1")) % 256
        pkt = f"${cmd}#{chk:02x}"
        s.sendall(pkt.encode("latin-1"))
        # read ack '+' and response
        resp = b""
        while True:
            ch = s.recv(1)
            if ch == b"+":
                continue
            resp += ch
            if b"#" in resp and len(resp) >= 3:
                # read 2 hex checksum bytes
                resp += s.recv(2)
                break
        return resp.decode("latin-1", errors="replace")

    # Initial handshake
    send_cmd("qSupported:multiprocess+;swbreak+;hwbreak+;qRelocInsn+")
    send_cmd("vCont?")
    
    print("Continuing execution for 3 seconds...")
    # Send continue
    s.sendall(b"$vCont;c#a8")
    
    time.sleep(3)
    
    print("Sending interrupt (0x03)...")
    s.sendall(b"\x03")
    
    # Read stop packet
    stop_pkt = b""
    while True:
        ch = s.recv(1)
        if ch == b"+": continue
        stop_pkt += ch
        if b"#" in stop_pkt:
            stop_pkt += s.recv(2)
            break
    print("Stop packet:", stop_pkt.decode("latin-1", errors="replace"))

    # Read registers
    g_resp = send_cmd("g")
    print("Registers raw packet (first 100 hex chars):", g_resp[:100])
    
    # Parse ARM registers (16 32-bit registers, r0-r15)
    # The packet format is $HEX#chk
    hex_data = g_resp[1:g_resp.find("#")]
    regs = [int.from_bytes(bytes.fromhex(hex_data[i*8:(i+1)*8]), "little") for i in range(16)]
    for i in range(16):
        rname = f"r{i}" if i < 13 else ["sp", "lr", "pc"][i-13]
        print(f"{rname:4s} = 0x{regs[i]:08x}")
        
    pc = regs[15]
    lr = regs[14]
    
    # Run gdb batch to find symbol at PC and LR
    sym_pc = subprocess.run(["gdb", "-batch", "-ex", "set architecture arm", "-ex", "file tools/.templates/lovepotion.elf", "-ex", f"info line *0x{pc:x}"], capture_output=True, text=True).stdout
    print(f"PC location: {sym_pc.strip()}")
    
    sym_lr = subprocess.run(["gdb", "-batch", "-ex", "set architecture arm", "-ex", "file tools/.templates/lovepotion.elf", "-ex", f"info line *0x{lr:x}"], capture_output=True, text=True).stdout
    print(f"LR location: {sym_lr.strip()}")

finally:
    emu.kill()
    emu.wait()
