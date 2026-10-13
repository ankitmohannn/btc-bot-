import win32service, win32gui, win32ui, win32con, ctypes
from PIL import Image

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

hwnd = find_mt5()
print("MT5 HWND:", hwnd)

# Get window dimensions
left, top, right, bot = win32gui.GetWindowRect(hwnd)
w = right - left
h = bot - top
print(f"MT5 Rect: {w}x{h} at ({left}, {top})")

# Capture MT5 window DC
hwndDC = win32gui.GetWindowDC(hwnd)
mfcDC  = win32ui.CreateDCFromHandle(hwndDC)
saveDC = mfcDC.CreateCompatibleDC()

saveBitMap = win32ui.CreateBitmap()
saveBitMap.CreateCompatibleBitmap(mfcDC, w, h)
saveDC.SelectObject(saveBitMap)

# PrintWindow
ctypes.windll.user32.PrintWindow(hwnd, saveDC.GetSafeHdc(), 2) # PW_RENDERFULLCONTENT = 2

bmpinfo = saveBitMap.GetInfo()
bmpstr = saveBitMap.GetBitmapBits(True)

im = Image.frombuffer('RGB', (bmpinfo['bmWidth'], bmpinfo['bmHeight']), bmpstr, 'raw', 'BGRX', 0, 1)

savepath = r"C:\Users\aakash\.gemini\antigravity-ide\brain\13d33685-372a-4204-97f9-354731492de3\mt5_screenshot.png"
im.save(savepath)
print("Saved MT5 screenshot to:", savepath)

win32gui.DeleteObject(saveBitMap.GetHandle())
saveDC.DeleteDC()
mfcDC.DeleteDC()
win32gui.ReleaseDC(hwnd, hwndDC)
