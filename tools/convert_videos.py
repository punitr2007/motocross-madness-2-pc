"""
Video Converter for Motocross Madness 2 (MCM2)
==============================================
Re-encodes original AVI files (Intel Indeo IV50) into Microsoft Video 1 (MSVC/CRAM)
with Microsoft ADPCM audio for guaranteed playback on modern Windows 10/11.
Requires ffmpeg in PATH.
"""
import os
import shutil
import subprocess
import sys

def convert_videos(game_dir: str):
    ui_dir = os.path.join(game_dir, "UI")
    if not os.path.isdir(ui_dir):
        print(f"[-] UI directory not found at: {ui_dir}")
        return False

    backup_dir = os.path.join(ui_dir, "BACKUP_ORIGINAL")
    os.makedirs(backup_dir, exist_ok=True)

    videos = [
        {"name": "EVENTS.AVI",  "has_audio": False},
        {"name": "INTRO.AVI",   "has_audio": True},
        {"name": "CREDITS.AVI", "has_audio": True},
    ]

    for v in videos:
        file_path = os.path.join(ui_dir, v["name"])
        bak_path = os.path.join(backup_dir, v["name"])

        if not os.path.isfile(file_path):
            print(f"[?] File not found, skipping: {file_path}")
            continue

        if not os.path.isfile(bak_path):
            shutil.copy2(file_path, bak_path)
            print(f"[+] Backed up original: {v['name']} -> {bak_path}")

        src = bak_path
        tmp_dst = os.path.join(ui_dir, "tmp_" + v["name"])

        cmd = ["ffmpeg", "-y", "-i", src, "-c:v", "msvideo1"]
        if v["has_audio"]:
            cmd += ["-c:a", "adpcm_ms"]
        else:
            cmd += ["-an"]
        cmd.append(tmp_dst)

        print(f"[*] Re-encoding {v['name']} with msvideo1...")
        ret = subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
        if ret.returncode == 0 and os.path.isfile(tmp_dst):
            os.replace(tmp_dst, file_path)
            print(f"[+] Successfully converted {v['name']} ({os.path.getsize(file_path)} bytes)")
        else:
            print(f"[-] Failed to convert {v['name']}: {ret.stderr[-300:]}")
            if os.path.exists(tmp_dst):
                os.remove(tmp_dst)

    return True

if __name__ == "__main__":
    game_folder = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "mcm2")
    convert_videos(os.path.abspath(game_folder))
