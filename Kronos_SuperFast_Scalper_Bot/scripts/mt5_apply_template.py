import win32service, win32gui, win32con, ctypes
from ctypes import wintypes

user32 = ctypes.windll.user32

hwinsta = win32service.OpenWindowStation('WinSta0', True, 0x10000000)
hwinsta.SetProcessWindowStation()
hdesk = win32service.OpenDesktop('Default', 0, True, 0x10000000)
hdesk.SetThreadDesktop()

def get_menu_text(hmenu, pos):
    buf = ctypes.create_unicode_buffer(256)
    user32.GetMenuStringW(hmenu, pos, buf, 256, win32con.MF_BYPOSITION)
    return buf.value

main_hwnd = 1377452
hmenu = user32.GetMenu(main_hwnd)
print("Root menu:", hmenu)

def walk_menu(hmenu, depth=0):
    cnt = user32.GetMenuItemCount(hmenu)
    for i in range(cnt):
        text = get_menu_text(hmenu, i)
        item_id = user32.GetMenuItemID(hmenu, i)
        sub = user32.GetSubMenu(hmenu, i)
        print("  " * depth + f"[{i}] ID={item_id} Text='{text}' Sub={sub}")
        if sub:
            walk_menu(sub, depth + 1)

walk_menu(hmenu)
