import ctypes
from ctypes import wintypes
import subprocess
import time

user32 = ctypes.windll.user32
kernel32 = ctypes.windll.kernel32

WNDENUMPROC = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)

def enum_windows():
    found = []
    def callback(hwnd, lparam):
        if user32.IsWindowVisible(hwnd):
            length = user32.GetWindowTextLengthW(hwnd)
            if length > 0:
                buff = ctypes.create_unicode_buffer(length + 1)
                user32.GetWindowTextW(hwnd, buff, length + 1)
                title = buff.value
                if "MetaTrader" in title or "Exness" in title or "279716781" in title:
                    found.append((hwnd, title))
        return True
    
    user32.EnumWindows(WNDENUMPROC(callback), 0)
    return found

def main():
    windows = enum_windows()
    if not windows:
        print("Launching MT5...")
        subprocess.Popen([r"C:\Program Files\MetaTrader 5\terminal64.exe"])
        time.sleep(3)
        windows = enum_windows()
        
    for hwnd, title in windows:
        print(f"Brought MT5 to front: '{title}' (HWND: {hwnd})")
        user32.ShowWindow(hwnd, 9) # SW_RESTORE
        user32.ShowWindow(hwnd, 3) # SW_MAXIMIZE
        user32.SetForegroundWindow(hwnd)

if __name__ == "__main__":
    main()
