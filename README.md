# Motocross Madness 2 — Modern PC Compatibility & Multiplayer Edition

[![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011-blue.svg)](https://microsoft.com/windows)
[![DirectX](https://img.shields.io/badge/Renderer-DirectX%207%20via%20dgVoodoo2-brightgreen.svg)](http://dege.freeweb.hu/dgVoodoo2/)
[![Multiplayer](https://img.shields.io/badge/Networking-IPXWrapper%20over%20UDP-orange.svg)](https://github.com/solemnwarning/ipxwrapper)
[![Architecture](https://img.shields.io/badge/Architecture-x86%2032--bit-lightgrey.svg)]()
[![Status](https://img.shields.io/badge/Status-Fully%20Playable-success.svg)]()

A complete, pre-configured compatibility package and reverse-engineered fix suite for **Motocross Madness 2** (Microsoft Games / Rainbow Studios, 2000), engineered to run seamlessly on modern 64-bit **Windows 10 and Windows 11** with full hardware 3D acceleration, crash-free video playback, and online IPX/UDP multiplayer lobby support.

---

## 🌟 What This Repository Solves

Motocross Madness 2 is one of the most celebrated arcade/sim motocross titles ever made, but on modern versions of Windows, the retail release suffers from multiple critical points of failure:

1. **Logo / Main Menu Crash (`0x0044c468`)**:
   - After the intro logos, the game initializes `MainDlg` (`mainmenu.dtm`) and requests background video playback (`ui\events.avi`).
   - Because Windows 10/11 dropped built-in Intel Indeo Video 5 (`IV50`) decoders, the DirectShow stream creation fails.
   - Retail `MCM2.EXE` never checked whether `PlayMovie()` succeeded. It dereferenced `[movieControl + 0x1ec]` (which was `NULL`), causing an immediate **Access Violation reading 0x00000000**.
   - **Our Fix**: Built-in binary patch for `MCM2.EXE` providing null-safety checking, clean stack-frame restoration, and universal re-encoding of all video streams (`EVENTS.AVI`, `INTRO.AVI`, `CREDITS.AVI`) to **Microsoft Video 1 (`msvc`)** with **Microsoft ADPCM audio**.

2. **Signed 32-bit Integer Video Memory Overflow (`CreateModeSurfaces` 0x004ca520)**:
   - Retail MCM2 evaluates available GPU VRAM as a signed 32-bit integer. On modern GPUs reporting 2 GB to 24 GB of VRAM, the value overflows to negative, causing surface allocation to fail immediately upon setting screen mode.
   - **Our Fix**: Pre-configured **dgVoodoo 2** reporting a calibrated 256 MB VRAM window, preventing overflow while delivering 60 FPS hardware Direct3D rendering and 16-bit color emulation under Desktop Window Manager (DWM).

3. **Multiplayer IPX Protocol Deprecation**:
   - Windows Vista and newer removed the legacy IPX/SPX network protocol stack, breaking the game's LAN and DirectPlay lobby sessions.
   - **Our Fix**: Bundled **IPXWrapper** translating IPX packets into modern UDP multicasts, accompanied by automated PowerShell launchers for 1-click room hosting and joining.

4. **Multi-Core CPU Timing Desynchronization**:
   - Modern multi-threaded CPUs cause the game's physics loop (`QueryPerformanceCounter` / `timeGetTime`) to race or drop frames.
   - **Our Fix**: Launchers enforce single-core CPU affinity (Core 0) to ensure rock-solid physics simulation and timer stability.

---

## 🚀 Quick Start Guide

### Playing Offline (Single Player)

1. Double-click **`PLAY_OFFLINE.bat`** (or execute `PLAY_OFFLINE.ps1` in PowerShell).
2. If prompted by the 3D Video Card selection dialog, select the **dgVoodoo DirectX** device (or the primary hardware adapter).
3. Enjoy full career mode, stunt quarries, Baja, Nationals, and Enduro!

### Hosting an Online Game

1. Double-click **`HOST.bat`**.
2. Enter your desired room name or code when prompted.
3. The launcher will configure firewall rules, bind IPXWrapper to UDP, and launch MCM2 directly into hosting mode.
4. Share your room code / IP address with other players.

### Joining an Online Game

1. Double-click **`JOIN.bat`**.
2. Enter the host's IP address or room code.
3. The launcher will connect your local IPXWrapper instance to the host's room.

---

## 📦 Game Files & Abandonware Status

Because **Motocross Madness 2** was released in 2000 and is no longer commercially sold or digitally distributed, it is classified as abandonware for preservation purposes.

- **Option A (Standalone Clone)**:
  This repository contains the complete preinstalled, ready-to-play configuration.
- **Option B (External Mirror / Google Drive)**:
  If you only clone the tools and scripts, or need to download a full fresh zip archive with all original tracks, bikes, and rider textures, you can access the pre-configured bundle here:
  > **Google Drive Mirror**: *[Coming Soon / Add your link here]*
  > **Internet Archive**: [Motocross Madness 2 at Archive.org](https://archive.org/details/motocross-madness-2)

---

## 🛠️ Repository Structure & Included Tools

```text
├── mcm2/                       # Ready-to-play game root directory
│   ├── MCM2.EXE                # Patched executable with null-guard and stack protection
│   ├── dgVoodoo.conf           # Calibrated DirectX 7 / VRAM wrapper configuration
│   ├── DDraw.dll, D3DImm.dll   # dgVoodoo DirectX 7 translation libraries
│   ├── ipxwrapper.dll, ini     # IPX over UDP multiplayer protocol wrapper
│   ├── PLAY_OFFLINE.bat, ps1   # Single player launcher with CPU affinity management
│   ├── HOST.bat, JOIN.bat      # Multiplayer lobby host & join scripts
│   ├── MCM2.reg                # Registry configuration for 64-bit Windows VirtualStore
│   └── UI/                     # UI assets including re-encoded msvideo1 AVI cutscenes
│       ├── EVENTS.AVI          # 144x104 Microsoft Video 1
│       ├── INTRO.AVI           # 320x240 Microsoft Video 1 + ADPCM MS Audio
│       └── CREDITS.AVI         # 640x480 Microsoft Video 1 + ADPCM MS Audio
│
├── tools/                      # Engineering & patch utilities
│   ├── patch_mcm2.py           # Automated binary patcher for vanilla MCM2.EXE
│   └── convert_videos.py       # Automated ffmpeg converter from IV50 to MS Video 1
│
├── .gitignore                  # Clean repository filter for logs and state files
└── README.md                   # Comprehensive documentation
```

---

## 🔬 Technical Deep-Dive: The Video Crash Fix

### Crash Site Disassembly (`MCM2.EXE`)

When entering single player or cycling menus, `MainDlg::HandleEvent` (`0x0044b200`) executes:

```assembly
0x0044c450: e8 7b f9 02 00      call PlayMovie("ui\\events.avi")
0x0044c455: 8b 85 58 7f 00 00   mov eax, [ebp + 0x7f58] ; eax = this->movieControl
0x0044c45b: 89 9d 78 7f 00 00   mov [ebp + 0x7f78], ebx ; movieRestartPending = 1
0x0044c461: 53                  push ebx                ; push argument 1
0x0044c462: 8b 88 ec 01 00 00   mov ecx, [eax + 0x1ec]  ; ecx = movieControl->moviePlayer
0x0044c468: 8b 11               mov edx, [ecx]          ; <-- CRASH: [0] Dereferences NULL!
0x0044c46a: ff 52 40            call dword ptr [edx+40h]
0x0044c46d: e9 3e 12 00 00      jmp 0x0044d6b0
```

### The Detour Code Cave (`0x00554F00`)

Our patch replaces the 24 bytes from `0x0044c455` to `0x0044c46d` with a jump to empty padding space at `0x00554F00`:

```assembly
; Injected at 0x0044c455:
jmp 0x00554F00
nop (19 times)

; Code Cave at 0x00554F00:
test eax, eax                     ; Did PlayMovie succeed?
jz   .failed

; --- SUCCESS BRANCH ---
mov  eax, [ebp + 0x7f58]          ; Load movieControl
mov  [ebp + 0x7f78], ebx          ; Set movieRestartPending = 1
push ebx                          ; Pass argument
mov  ecx, [eax + 0x1ec]           ; Load moviePlayer
mov  edx, [ecx]
call dword ptr [edx + 0x40]       ; Callee clears 4 bytes
jmp  .exit

; --- FAILED BRANCH ---
.failed:
mov  dword ptr [ebp + 0x7f58], 0  ; this->movieControl = NULL
mov  dword ptr [ebp + 0x7f78], 0  ; movieRestartPending = 0
; Note: No push ebx occurred, ESP is completely clean!

.exit:
jmp  0x0044d6b0                   ; Jump cleanly to function epilogue
```

To patch any vanilla retail `MCM2.EXE`, simply run:

```bash
python tools/patch_mcm2.py path/to/MCM2.EXE
```

---

## 🎬 High-Quality Video Extraction & AI Upscaling (RIFE / Real Video Enhancer)

Motocross Madness 2 shipped with three full-motion video sequences encoded in the now-deprecated Intel Indeo Video 5 (IV50) codec:
- **`INTRO.AVI`**: Main game intro cinematic (originally 320x240 @ 15 FPS).
- **`EVENTS.AVI`**: Interactive menu stunt/track preview loop (144x104 @ 15 FPS).
- **`CREDITS.AVI`**: Closing credits roll with soundtrack (640x480 @ 2 FPS).

### 1. Extracted High-Definition Video Assets

Pristine digital masters and high-definition renders have been extracted to `mcm2/UI/EXTRACTED_HQ_VIDEOS/`:
- `MCM2_Intro_Source_Master.mp4`: Lossless CRF 14 H.264 master extracted directly from the original retail video.
- `MCM2_Intro_Upscaled_1080p.mp4`: Remastered 1440x1080 (4:3) render with Lanczos edge refinement and unsharp masking.
- `MCM2_Events_Source_Master.mp4`: Event loop master.
- `MCM2_Events_Upscaled_720p.mp4`: 720p remaster of the event preview loop.
- `MCM2_Credits_Source_Master.mp4`: Lossless credits sequence with full 320kbps stereo soundtrack.
- `MCM2_Credits_Upscaled_1080p.mp4`: 1080p remaster of the credits sequence.

### 2. Using RIFE / Real Video Enhancer / Topaz

You can feed the files from `mcm2/UI/EXTRACTED_HQ_VIDEOS/` directly into **RIFE** (Real-Time Intermediate Flow Estimation) and **Real Video Enhancer** / **Real-ESRGAN**:
- **Frame Interpolation (RIFE)**: Set to `4x` to convert the original 15 FPS footage into ultra-smooth **60 FPS**.
- **Spatial Upscaling**: Upscale to `640x480` (native DirectDraw UI resolution) or `1440x1080` (nostalgic standalone viewing).

### 3. Replacing In-Game Videos with Upscaled Files

Can you replace the in-game videos with your AI-enhanced renders? **Yes!** The MCM2 engine (`MediaControl`) supports dynamic resolution surfaces via DirectShow, provided the video meets 3 technical criteria:
1. **Container**: Must be `.AVI`.
2. **Codec**: DirectShow requires a 32-bit compatible codec (`msvideo1` Microsoft Video 1, `cinepak`, or `rawvideo` uncompressed BGR24).
3. **Audio**: Must be Microsoft ADPCM (`adpcm_ms`) or PCM 16-bit 44.1kHz stereo.

To automatically convert and install any AI-upscaled video into the game:

```bash
# Replace Intro video with your RIFE-upscaled MP4:
python tools/convert_videos.py --replace INTRO.AVI --with "path/to/my_rife_upscaled.mp4" --scale 640:480

# To extract or re-generate all master MP4 files:
python tools/convert_videos.py --extract-hq
```

---


## 📜 Credits & Acknowledgments

- **Microsoft Games & Rainbow Studios**: For creating this timeless motocross classic.
- **Andrew Boudreau & Contributors**: For the exhaustive C++ reverse-engineering documentation ([MCM2 Decompilation Project](https://andrewboudreau.github.io/motocross-madness-2-decomp/)).
- **Dege**: For developing [dgVoodoo 2](http://dege.freeweb.hu/dgVoodoo2/).
- **SolemnWarning**: For developing [IPXWrapper](https://github.com/solemnwarning/ipxwrapper).
- **Punit Ranjan**: Compatibility reverse engineering, binary patching, and packaging.

---

## ⚖️ License & Disclaimer

This project is intended strictly for historical preservation, research, and non-commercial compatibility enhancements under fair-use principles. Motocross Madness 2 is a trademark of Microsoft Corporation. All trademarks, assets, and copyrights belong to their respective owners.
