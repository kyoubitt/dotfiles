#!/usr/bin/env python3
"""Spotify sign-in for the shell's music client (PKCE: no client secret is ever needed or stored).
   auth.py login CLIENT_ID     opens the browser, waits for Spotify's redirect, saves the tokens
   auth.py refresh CLIENT_ID   gets a fresh access token from the saved refresh token
Tokens go to ~/.local/state/zerd-music/tokens.json (mode 600). Prints "ok" or the reason it failed."""
import sys, os, json, time, base64, hashlib, secrets, threading, urllib.parse, urllib.request, subprocess
from http.server import BaseHTTPRequestHandler, HTTPServer

PORT = 8898
REDIRECT = f"http://127.0.0.1:{PORT}/callback"
SCOPES = "user-read-playback-state user-modify-playback-state user-read-currently-playing playlist-read-private playlist-read-collaborative playlist-modify-public playlist-modify-private user-library-read user-library-modify user-top-read user-read-recently-played streaming"
DIR = os.path.expanduser("~/.local/state/zerd-music")
FILE = os.path.join(DIR, "tokens.json")

def save(tok, old_refresh=None):
    os.makedirs(DIR, exist_ok=True)
    data = {"access_token": tok["access_token"], "refresh_token": tok.get("refresh_token", old_refresh),
            "expires_at": int(time.time()) + int(tok.get("expires_in", 3600)) - 60}
    fd = os.open(FILE, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as f: json.dump(data, f)

def token_request(params):
    req = urllib.request.Request("https://accounts.spotify.com/api/token", data=urllib.parse.urlencode(params).encode(),
                                 headers={"Content-Type": "application/x-www-form-urlencoded"})
    with urllib.request.urlopen(req, timeout=30) as r: return json.load(r)

def login(cid):
    verifier = secrets.token_urlsafe(64)
    challenge = base64.urlsafe_b64encode(hashlib.sha256(verifier.encode()).digest()).decode().rstrip("=")
    state = secrets.token_urlsafe(12)
    got = {}
    class H(BaseHTTPRequestHandler):
        def log_message(self, *a): pass
        def do_GET(self):
            q = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
            if urllib.parse.urlparse(self.path).path != "/callback": self.send_response(404); self.end_headers(); return
            got.update({k: v[0] for k, v in q.items()})
            self.send_response(200); self.send_header("Content-Type", "text/html"); self.end_headers()
            self.wfile.write(b"<body style='font-family:sans-serif;background:#111;color:#eee;text-align:center;padding-top:20vh'><h2>Signed in</h2><p>You can close this tab.</p></body>")
    srv = HTTPServer(("127.0.0.1", PORT), H)
    srv.timeout = 1
    url = "https://accounts.spotify.com/authorize?" + urllib.parse.urlencode({"client_id": cid, "response_type": "code", "redirect_uri": REDIRECT,
        "scope": SCOPES, "state": state, "code_challenge_method": "S256", "code_challenge": challenge})
    subprocess.Popen(["xdg-open", url], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    end = time.time() + 240
    while not got and time.time() < end: srv.handle_request()
    srv.server_close()
    if not got: print("timed out waiting for the browser"); return
    if got.get("state") != state or "code" not in got: print("sign-in was cancelled or refused: " + got.get("error", "no code")); return
    try:
        tok = token_request({"grant_type": "authorization_code", "code": got["code"], "redirect_uri": REDIRECT, "client_id": cid, "code_verifier": verifier})
    except Exception as e:
        print("Spotify refused the code: " + str(e)); return
    save(tok); print("ok")

def refresh(cid):
    try:
        old = json.load(open(FILE))
        tok = token_request({"grant_type": "refresh_token", "refresh_token": old["refresh_token"], "client_id": cid})
        save(tok, old["refresh_token"]); print("ok")
    except Exception as e:
        print("could not refresh: " + str(e))

if len(sys.argv) == 3 and sys.argv[1] == "login": login(sys.argv[2])
elif len(sys.argv) == 3 and sys.argv[1] == "refresh": refresh(sys.argv[2])
else: print("usage: auth.py login|refresh CLIENT_ID")
