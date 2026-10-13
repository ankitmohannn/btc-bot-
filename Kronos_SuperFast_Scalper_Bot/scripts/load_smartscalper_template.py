import win32service, win32gui, win32con, ctypes, time, os

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
print("MT5 HWND:", mt5_hwnd)
if not mt5_hwnd:
    print("MT5 not running.")
    exit(1)

# Bring MT5 to foreground
user32.SetForegroundWindow(mt5_hwnd)
time.sleep(0.5)

# Trigger Load Template dialog
print("Sending WM_COMMAND 32899 (Load Template)...")
user32.PostMessageW(mt5_hwnd, win32con.WM_COMMAND, 32899, 0)
time.sleep(1.0)

# Find Open dialog
def find_open_dialog():
    res = []
    def cb(hwnd, extra):
        if win32gui.IsWindowVisible(hwnd) and win32gui.GetClassName(hwnd) == '#32770':
            txt = win32gui.GetWindowText(hwnd)
            if 'Open' in txt or 'Load' in txt:
                extra.append(hwnd)
    win32gui.EnumWindows(cb, res)
    return res[0] if res else None

dlg = find_open_dialog()
print("Found Open Dialog:", dlg)

if dlg:
    state = {'edit_hwnd': None, 'open_btn_hwnd': None}
    
    def cb_child(hwnd, extra):
        cls = win32gui.GetClassName(hwnd)
        txt = win32gui.GetWindowText(hwnd)
        if cls == 'Edit' and state['edit_hwnd'] is None:
            parent = win32gui.GetParent(hwnd)
            p_cls = win32gui.GetClassName(parent) if parent else ""
            if 'Combo' in p_cls:
                state['edit_hwnd'] = hwnd
        if cls == 'Button' and ('Open' in txt or txt == '&Open'):
            state['open_btn_hwnd'] = hwnd

    win32gui.EnumChildWindows(dlg, cb_child, None)
    print("Edit HWND:", state['edit_hwnd'])
    print("Open Button HWND:", state['open_btn_hwnd'])

    tpl_path = r"C:\Users\aakash\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Profiles\Templates\SmartScalper_V2.tpl"
    if state['edit_hwnd'] and state['open_btn_hwnd']:
        buf = ctypes.create_unicode_buffer(tpl_path)
        user32.SendMessageW(state['edit_hwnd'], win32con.WM_SETTEXT, 0, buf)
        time.sleep(0.5)
        user32.SendMessageW(state['open_btn_hwnd'], win32con.BM_CLICK, 0, 0)
        print("Clicked Open button!")
        time.sleep(1.5)

# Check if an EA dialog or any confirmation dialog opened
def find_all_popups():
    res = []
    def cb(hwnd, extra):
        if win32gui.IsWindowVisible(hwnd) and win32gui.GetClassName(hwnd) == '#32770':
            extra.append((hwnd, win32gui.GetWindowText(hwnd)))
    win32gui.EnumWindows(cb, res)
    return res

popups = find_all_popups()
print("Popups after load:", popups)
for phwnd, ptitle in popups:
    # Look for OK button to accept EA settings if prompted
    def cb_btn(h, extra):
        txt = win32gui.GetWindowText(h)
        if txt == 'OK' or txt == '&OK':
            user32.SendMessageW(h, win32con.BM_CLICK, 0, 0)
            print(f"Clicked OK on dialog '{ptitle}'")
    win32gui.EnumChildWindows(phwnd, cb_btn, None)
