#!/usr/bin/env python3
"""Eski yordamchi skript — desktop ALFAPOS endi o‘z relayini o‘zi ishga tushiradi.

Faqat desktop dastursiz sinov uchun: Mac USB printer → TCP 9100.
Asosiy yo‘l: Desktop Sozlamalar → Mobil relay yoqilgan, telefon kompyuter IP ga ulanadi.
"""
import os
import socket
import subprocess
import sys
import tempfile

PRINTER_QUEUE = "Xprinter_XP_365B"
HOST = "0.0.0.0"
PORT = 9100
DOTS_PER_MM = 203 / 25.4


def png_dimensions(path: str) -> tuple[int, int] | None:
    try:
        with open(path, "rb") as f:
            if f.read(8) != b"\x89PNG\r\n\x1a\n":
                return None
            f.read(4)
            if f.read(4) != b"IHDR":
                return None
            w = int.from_bytes(f.read(4), "big")
            h = int.from_bytes(f.read(4), "big")
            return w, h
    except OSError:
        return None


def forward_to_lp(data: bytes) -> None:
    is_png = data.startswith(b"\x89PNG\r\n\x1a\n")
    suffix = ".png" if is_png else ".bin"
    fd, path = tempfile.mkstemp(prefix="alfapos_relay_", suffix=suffix)
    try:
        os.write(fd, data)
        os.close(fd)
        lp_args = ["lp", "-d", PRINTER_QUEUE]
        if is_png:
            dims = png_dimensions(path)
            if dims is not None:
                w_px, h_px = dims
                if w_px <= 480 and h_px <= 360:
                    w_mm = max(1, round(w_px / DOTS_PER_MM))
                    h_mm = max(1, round(h_px / DOTS_PER_MM))
                    lp_args += ["-o", f"PageSize=Custom.{w_mm}x{h_mm}mm"]
            lp_args += ["-o", "fit-to-page", path]
        else:
            lp_args += ["-o", "raw", path]
        proc = subprocess.run(lp_args, capture_output=True)
        if proc.returncode != 0:
            err = proc.stderr.decode("utf-8", errors="replace").strip()
            print(f"lp xato ({proc.returncode}): {err}", flush=True)
        else:
            out = proc.stdout.decode("utf-8", errors="replace").strip()
            kind = "PNG" if is_png else "RAW"
            print(f"Chop etildi ({kind}): {len(data)} bayt — {out}", flush=True)
    finally:
        try:
            os.remove(path)
        except OSError:
            pass


def main() -> None:
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    sock.bind((HOST, PORT))
    sock.listen(5)
    print(f"Relay: {HOST}:{PORT} → lp -d {PRINTER_QUEUE}", flush=True)
    print("To'xtatish: Ctrl+C yoki tools/start_printer_relay.sh --stop", flush=True)
    while True:
        conn, addr = sock.accept()
        try:
            chunks: list[bytes] = []
            conn.settimeout(3.0)
            while True:
                try:
                    part = conn.recv(65536)
                except socket.timeout:
                    break
                if not part:
                    break
                chunks.append(part)
            data = b"".join(chunks)
            if data:
                print(f"Qabul: {addr[0]}:{addr[1]} ({len(data)} bayt)", flush=True)
                forward_to_lp(data)
        finally:
            conn.close()


if __name__ == "__main__":
    try:
        main()
    except OSError as e:
        if getattr(e, "errno", None) == 48:
            print(
                f"Port {PORT} band — relay allaqachon ishlayapti.\n"
                f"Tekshirish: tools/start_printer_relay.sh --status\n"
                f"Qayta ishga tushirish: tools/start_printer_relay.sh --restart",
                flush=True,
            )
            sys.exit(0)
        raise
    except KeyboardInterrupt:
        sys.exit(0)
