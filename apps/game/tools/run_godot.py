#!/usr/bin/env python3
"""Run headless Godot with bounded execution and fail on script errors."""
import os
import selectors
import signal
import subprocess
import sys
import time


def main():
    process = subprocess.Popen(
        ["godot", *sys.argv[1:]], stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT, start_new_session=True,
    )
    selector = selectors.DefaultSelector()
    selector.register(process.stdout, selectors.EVENT_READ)
    deadline = time.monotonic() + 600
    pending = b""
    result = None
    try:
        while selector.get_map():
            if time.monotonic() >= deadline:
                print("Godot exceeded the 10 minute command timeout", file=sys.stderr)
                result = 124
                break
            for key, _ in selector.select(timeout=0.2):
                data = os.read(key.fd, 65536)
                if not data:
                    selector.unregister(key.fileobj)
                    continue
                sys.stdout.buffer.write(data)
                sys.stdout.buffer.flush()
                pending = (pending + data)[-131072:]
                if b"SCRIPT ERROR:" in pending:
                    print("Godot script error; stopping CI command", file=sys.stderr)
                    result = 1
                    break
            if result is not None:
                break
        if result is None:
            return process.wait(timeout=max(1, deadline - time.monotonic()))
        return result
    finally:
        selector.close()
        if process.poll() is None:
            os.killpg(process.pid, signal.SIGKILL)
        process.wait()


if __name__ == "__main__":
    sys.exit(main())
