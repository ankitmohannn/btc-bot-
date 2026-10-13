"""
SmartScalper V2 — Local Dashboard Web Server
Serves the interactive multi-timeframe analytics dashboard and opens the default browser.
"""

import http.server
import socketserver
import webbrowser
import os
import sys

PORT = 8080
DASHBOARD_DIR = os.path.dirname(os.path.abspath(__file__))

class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DASHBOARD_DIR, **kwargs)

def main():
    os.chdir(DASHBOARD_DIR)
    url = f"http://localhost:{PORT}/index.html"
    
    print("======================================================================")
    print("   SMARTSCALPER V2 — MULTI-TIMEFRAME ANALYTICS & MONTE CARLO DASHBOARD")
    print("======================================================================")
    print(f"[*] Dashboard URL: {url}")
    print("[*] Opening your web browser...")
    print("[*] Press Ctrl + C to stop the server.")
    print("======================================================================\n")

    try:
        webbrowser.open(url)
    except Exception as e:
        print(f"[!] Could not open browser automatically: {e}")

    try:
        with socketserver.TCPServer(("", PORT), Handler) as httpd:
            httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n[*] Dashboard server stopped.")
    except Exception as e:
        # If port 8080 is busy, try port 8085
        try:
            alt_port = 8085
            alt_url = f"http://localhost:{alt_port}/index.html"
            print(f"[*] Port {PORT} in use, switching to port {alt_port} -> {alt_url}")
            webbrowser.open(alt_url)
            with socketserver.TCPServer(("", alt_port), Handler) as httpd:
                httpd.serve_forever()
        except Exception as e2:
            print(f"[!] Server error: {e2}")

if __name__ == "__main__":
    main()
