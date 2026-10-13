import win32service, win32process, win32gui, win32con, time, subprocess

# Connect to WinSta0\Default
hwinsta = win32service.OpenWindowStation('WinSta0', True, 0x10000000)
hwinsta.SetProcessWindowStation()
hdesk = win32service.OpenDesktop('Default', 0, True, 0x10000000)
hdesk.SetThreadDesktop()

exe = r"C:\Program Files\MetaTrader 5\terminal64.exe"
print(f"Starting {exe}...")

si = win32process.STARTUPINFO()
si.lpDesktop = r"WinSta0\Default"
si.dwFlags = win32process.STARTF_USESHOWWINDOW
si.wShowWindow = win32con.SW_SHOWMAXIMIZED

proc_info = win32process.CreateProcess(
    None,
    f'"{exe}"',
    None,
    None,
    True,
    win32process.NORMAL_PRIORITY_CLASS,
    None,
    r"C:\Program Files\MetaTrader 5",
    si
)

print("Started MT5 with Process ID:", proc_info[2])

for i in range(15):
    time.sleep(1)
    res = []
    def cb(hwnd, extra):
        if win32gui.IsWindowVisible(hwnd):
            cls = win32gui.GetClassName(hwnd)
            txt = win32gui.GetWindowText(hwnd)
            if 'MetaTrader' in cls or 'Exness' in txt or '279716781' in txt or 'XAUUSD' in txt:
                extra.append((hwnd, cls, txt))
    win32gui.EnumWindows(cb, res)
    if res:
        print(f"[{i+1}s] Found MT5 Window:", res)
        break
    else:
        print(f"[{i+1}s] Waiting for MT5 window...")
