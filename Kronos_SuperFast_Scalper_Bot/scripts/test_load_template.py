import win32service, win32gui, win32con, ctypes, time

user32 = ctypes.windll.user32

hwinsta = win32service.OpenWindowStation('WinSta0', True, 0x10000000)
hwinsta.SetProcessWindowStation()
hdesk = win32service.OpenDesktop('Default', 0, True, 0x10000000)
hdesk.SetThreadDesktop()

def find_mt5():
    res = []
    def cb(hwnd, extra):
        if win32gui.IsWindowVisible(hwnd):
            cls = win32gui.GetClassName(hwnd)
            if 'MetaTrader' in cls:
                extra.append(hwnd)
    win32gui.EnumWindows(cb, res)
    return res[0] if res else None

mt5_hwnd = find_mt5()
print("MT5 Main HWND:", mt5_hwnd)

# Let's post WM_COMMAND 32899 (Load Template) to MT5
# PostMessage so it doesn't block
user32.PostMessageW(mt5_hwnd, win32con.WM_COMMAND, 32899, 0)
time.sleep(1.0)

# Check if an Open dialog appeared
dialogs = []
def cb_dlg(hwnd, extra):
    if win32gui.IsWindowVisible(hwnd):
        cls = win32gui.GetClassName(hwnd)
        txt = win32gui.GetWindowText(hwnd)
        if cls == '#32770' or 'Template' in txt or 'Open' in txt:
            extra.append((hwnd, cls, txt))

win32gui.EnumWindows(cb_dlg, dialogs)
print("Found dialogs:", dialogs)
