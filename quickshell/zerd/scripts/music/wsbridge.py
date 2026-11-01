#!/usr/bin/env python3
"""A tiny WebSocket client over stdio, so the shell needs no extra packages.
   wsbridge.py PORTFILE   waits for PORTFILE (a port number), connects to ws://127.0.0.1:PORT,
   sends every line read on stdin as a text frame and prints every text frame it receives as one line."""
import base64, os, socket, struct, sys, threading, time

def main(portfile):
    port = None
    for _ in range(150):
        try:
            port = int(open(portfile).read().strip()); break
        except Exception:
            time.sleep(0.2)
    if port is None: sys.exit(2)
    s = socket.create_connection(("127.0.0.1", port), timeout=10)
    key = base64.b64encode(os.urandom(16)).decode()
    s.sendall(("GET / HTTP/1.1\r\nHost: 127.0.0.1:%d\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n"
               "Sec-WebSocket-Key: %s\r\nSec-WebSocket-Version: 13\r\n\r\n" % (port, key)).encode())
    buf = b""
    while b"\r\n\r\n" not in buf:
        chunk = s.recv(4096)
        if not chunk: sys.exit(3)
        buf += chunk
    head, buf = buf.split(b"\r\n\r\n", 1)
    if b" 101 " not in head.split(b"\r\n")[0]: sys.exit(3)
    s.settimeout(None)
    lock = threading.Lock()

    def send(data, op=1):
        b = bytearray([0x80 | op]); n = len(data)
        if n < 126: b.append(0x80 | n)
        elif n < 65536: b.append(0x80 | 126); b += struct.pack(">H", n)
        else: b.append(0x80 | 127); b += struct.pack(">Q", n)
        mask = os.urandom(4); b += mask; b += bytes(c ^ mask[i % 4] for i, c in enumerate(data))
        with lock: s.sendall(bytes(b))

    def pump():
        for line in sys.stdin:
            line = line.strip()
            if line:
                try: send(line.encode())
                except Exception: break
        os._exit(0)
    threading.Thread(target=pump, daemon=True).start()

    def need(n):
        nonlocal buf
        while len(buf) < n:
            chunk = s.recv(65536)
            if not chunk: sys.exit(0)
            buf += chunk
        out, buf = buf[:n], buf[n:]
        return out

    msg = b""
    while True:
        h = need(2); fin = h[0] & 0x80; op = h[0] & 0x0F; n = h[1] & 0x7F
        if n == 126: n = struct.unpack(">H", need(2))[0]
        elif n == 127: n = struct.unpack(">Q", need(8))[0]
        data = need(n)
        if op == 8: sys.exit(0)
        if op == 9: send(data, 10); continue
        if op in (1, 0):
            msg += data
            if fin:
                sys.stdout.write(msg.decode("utf-8", "replace").replace("\n", " ") + "\n"); sys.stdout.flush(); msg = b""

main(sys.argv[1])
