"""
Motocross Madness 2 (MCM2) Video Tool
======================================
1. Re-encodes videos to modern Windows-compatible DirectShow codecs (MSVC, Cinepak, Raw RGB).
2. Extracts lossless masters and upscaled MP4s for external viewing or AI enhancement.
3. Automatically converts AI-upscaled / RIFE-interpolated videos into in-game AVI format.

Usage:
    # 1. Batch convert in-game videos (fixes Indeo 5 black screen / crash):
    python tools/convert_videos.py

    # 2. Extract lossless MP4 masters to mcm2/UI/EXTRACTED_HQ_VIDEOS/:
    python tools/convert_videos.py --extract-hq

    # 3. Replace an in-game video with an AI upscaled file (e.g. from RIFE / Real Video Enhancer):
    python tools/convert_videos.py --replace INTRO.AVI --with "path/to/my_rife_upscaled.mp4"
"""

import argparse
import os
import shutil
import subprocess
import sys

TARGET_VIDEOS = {
    "INTRO.AVI": {
        "has_audio": True,
        "default_w": 320,
        "default_h": 240,
        "desc": "Main Game Intro FMV (originally 320x240 @ 15fps, scales up to 640x480+ in 4:3)"
    },
    "EVENTS.AVI": {
        "has_audio": False,
        "default_w": 144,
        "default_h": 104,
        "desc": "Menu Stunt/Track Preview Loop (144x104, 4:3 or native)"
    },
    "CREDITS.AVI": {
        "has_audio": True,
        "default_w": 320,
        "default_h": 240,
        "desc": "Ending Credits Roll (640x480 @ 2fps with soundtrack)"
    }
}

def get_ffmpeg_path():
    ffmpeg = shutil.which("ffmpeg")
    if not ffmpeg:
        print("[-] Error: ffmpeg executable was not found in your system PATH.")
        print("    Please install FFmpeg or ensure it is accessible in PATH.")
        sys.exit(1)
    return ffmpeg

def batch_convert_legacy(game_dir: str, codec: str = "msvideo1"):
    ui_dir = os.path.join(game_dir, "UI")
    if not os.path.isdir(ui_dir):
        print(f"[-] UI directory not found at: {ui_dir}")
        return False

    backup_dir = os.path.join(ui_dir, "BACKUP_IV50")
    os.makedirs(backup_dir, exist_ok=True)

    for v_name, meta in TARGET_VIDEOS.items():
        file_path = os.path.join(ui_dir, v_name)
        bak_path = os.path.join(backup_dir, v_name)

        if not os.path.isfile(file_path) and not os.path.isfile(bak_path):
            print(f"[?] File not found, skipping: {v_name}")
            continue

        # Backup pristine original if not already done
        if not os.path.isfile(bak_path) and os.path.isfile(file_path):
            shutil.copy2(file_path, bak_path)
            print(f"[+] Backed up original Indeo 5 video: {v_name} -> {bak_path}")

        src = bak_path if os.path.isfile(bak_path) else file_path
        tmp_dst = os.path.join(ui_dir, "tmp_" + v_name)

        cmd = ["ffmpeg", "-y", "-i", src, "-c:v", codec]
        if meta["has_audio"]:
            cmd += ["-c:a", "adpcm_ms"]
        else:
            cmd += ["-an"]
        cmd.append(tmp_dst)

        print(f"[*] Re-encoding {v_name} with {codec}...")
        ret = subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
        if ret.returncode == 0 and os.path.isfile(tmp_dst):
            os.replace(tmp_dst, file_path)
            print(f"[+] Successfully converted {v_name} ({os.path.getsize(file_path):,} bytes)")
        else:
            print(f"[-] Failed to convert {v_name}: {ret.stderr[-300:]}")
            if os.path.exists(tmp_dst):
                os.remove(tmp_dst)
    return True

def extract_hq_masters(game_dir: str):
    ui_dir = os.path.join(game_dir, "UI")
    backup_dir = os.path.join(ui_dir, "BACKUP_IV50")
    out_dir = os.path.join(ui_dir, "EXTRACTED_HQ_VIDEOS")
    os.makedirs(out_dir, exist_ok=True)

    print(f"[*] Extracting High Quality video masters to: {out_dir}")

    extractions = [
        ("INTRO.AVI", "MCM2_Intro_Source_Master.mp4", ["-c:v", "libx264", "-crf", "14", "-preset", "slow", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "320k"]),
        ("INTRO.AVI", "MCM2_Intro_Upscaled_1080p.mp4", ["-vf", "scale=1440:1080:flags=lanczos,unsharp=5:5:0.8:3:3:0.4", "-c:v", "libx264", "-crf", "16", "-preset", "slow", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "320k"]),
        ("EVENTS.AVI", "MCM2_Events_Source_Master.mp4", ["-c:v", "libx264", "-crf", "14", "-preset", "slow", "-pix_fmt", "yuv420p", "-an"]),
        ("EVENTS.AVI", "MCM2_Events_Upscaled_720p.mp4", ["-vf", "scale=996:720:flags=lanczos,unsharp=5:5:0.8:3:3:0.4", "-c:v", "libx264", "-crf", "16", "-preset", "slow", "-pix_fmt", "yuv420p", "-an"]),
        ("CREDITS.AVI", "MCM2_Credits_Source_Master.mp4", ["-c:v", "libx264", "-crf", "14", "-preset", "slow", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "320k"]),
        ("CREDITS.AVI", "MCM2_Credits_Upscaled_1080p.mp4", ["-vf", "scale=1440:1080:flags=lanczos,unsharp=5:5:0.8:3:3:0.4", "-c:v", "libx264", "-crf", "16", "-preset", "slow", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "320k"]),
    ]

    for src_avi, out_name, enc_args in extractions:
        src_path = os.path.join(backup_dir, src_avi)
        if not os.path.isfile(src_path):
            src_path = os.path.join(ui_dir, src_avi)
        if not os.path.isfile(src_path):
            print(f"[?] Source {src_avi} not found, skipping...")
            continue

        out_path = os.path.join(out_dir, out_name)
        print(f"[*] Exporting {out_name}...")
        cmd = ["ffmpeg", "-y", "-i", src_path] + enc_args + [out_path]
        subprocess.run(cmd, check=True)
        print(f"[+] Created: {out_name} ({os.path.getsize(out_path):,} bytes)")

def replace_in_game_video(game_dir: str, target: str, input_file: str, codec: str = "msvideo1", scale: str = None):
    target = target.upper()
    if not target.endswith(".AVI"):
        target += ".AVI"

    if target not in TARGET_VIDEOS:
        print(f"[-] Invalid target '{target}'. Expected one of: {list(TARGET_VIDEOS.keys())}")
        return False

    if not os.path.isfile(input_file):
        print(f"[-] Input file not found: {input_file}")
        return False

    ui_dir = os.path.join(game_dir, "UI")
    dst_path = os.path.join(ui_dir, target)
    tmp_path = os.path.join(ui_dir, f"tmp_{target}")

    meta = TARGET_VIDEOS[target]

    cmd = ["ffmpeg", "-y", "-i", input_file]

    # Handle resolution scaling if requested or default for events
    vf_filters = []
    if scale:
        vf_filters.append(f"scale={scale}:flags=lanczos")
    elif target == "EVENTS.AVI":
        # Keep events preview matching UI bounding box
        vf_filters.append("scale=144:104:flags=lanczos")

    if vf_filters:
        cmd += ["-vf", ",".join(vf_filters)]

    # Video Codec
    if codec == "rawvideo":
        cmd += ["-c:v", "rawvideo", "-pix_fmt", "bgr24"]
    elif codec == "cinepak":
        cmd += ["-c:v", "cinepak"]
    else:
        cmd += ["-c:v", "msvideo1"]

    # Audio Codec
    if meta["has_audio"]:
        cmd += ["-c:a", "adpcm_ms", "-ar", "44100"]
    else:
        cmd += ["-an"]

    cmd.append(tmp_path)

    print(f"[*] Transcoding '{input_file}' -> '{target}' (Codec: {codec})...")
    ret = subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
    if ret.returncode == 0 and os.path.isfile(tmp_path):
        os.replace(tmp_path, dst_path)
        print(f"[+] SUCCESS! {target} updated with upscaled video ({os.path.getsize(dst_path):,} bytes).")
        print(f"[+] You can now launch MCM2 to see your upscaled video in-game!")
        return True
    else:
        print(f"[-] Error transcoding video: {ret.stderr[-400:]}")
        if os.path.exists(tmp_path):
            os.remove(tmp_path)
        return False

def main():
    parser = argparse.ArgumentParser(description="MCM2 Video Manager & Transcoder")
    parser.add_argument("--game-dir", default=os.path.join(os.path.dirname(__file__), "..", "mcm2"),
                        help="Path to MCM2 game folder")
    parser.add_argument("--extract-hq", action="store_true",
                        help="Extract master H.264 MP4 videos to UI/EXTRACTED_HQ_VIDEOS/")
    parser.add_argument("--replace", type=str, default=None,
                        help="Target video to replace in game (INTRO.AVI, EVENTS.AVI, CREDITS.AVI)")
    parser.add_argument("--with", dest="with_file", type=str, default=None,
                        help="Path to upscaled/interpolated video (MP4/MKV/AVI)")
    parser.add_argument("--codec", choices=["msvideo1", "rawvideo", "cinepak"], default="msvideo1",
                        help="Codec for in-game playback (default: msvideo1)")
    parser.add_argument("--scale", type=str, default=None,
                        help="Optional scale filter, e.g. 640:480")

    args = parser.parse_args()
    get_ffmpeg_path()
    game_dir = os.path.abspath(args.game_dir)

    if args.replace:
        if not args.with_file:
            print("[-] Error: --replace requires --with <path_to_upscaled_video>")
            sys.exit(1)
        replace_in_game_video(game_dir, args.replace, args.with_file, codec=args.codec, scale=args.scale)
    elif args.extract_hq:
        extract_hq_masters(game_dir)
    else:
        batch_convert_legacy(game_dir, codec=args.codec)

if __name__ == "__main__":
    main()
