"""
Automated Binary Patcher for Motocross Madness 2 (MCM2.EXE)
============================================================
Fixes the modern Windows crash at 0x0044c468 during video playback / logo transition.

Technical Details:
------------------
In MainDlg::HandleEvent (0x0044b200):
When MenuSingle is initialized or toggled, it attempts to play 'ui\\events.avi'
via PlayMovie() -> MediaControl::Open() -> DirectShow IAMMultiMediaStream.

On modern Windows, legacy Indeo Video 5 (IV50) codecs are unavailable or fail to connect.
If PlayMovie() fails, it returns 0 (EAX = 0) and leaves moviePlayer as NULL.
Retail MCM2.EXE never checks EAX:
  0x0044c455: 8b 85 58 7f 00 00   mov eax, [ebp + 0x7f58] (movieControl)
  0x0044c45b: 89 9d 78 7f 00 00   mov [ebp + 0x7f78], ebx (movieRestartPending = 1)
  0x0044c461: 53                  push ebx
  0x0044c462: 8b 88 ec 01 00 00   mov ecx, [eax + 0x1ec]  (moviePlayer = NULL!)
  0x0044c468: 8b 11               mov edx, [ecx]          (CRASH: dereferencing NULL)
  0x0044c46a: ff 52 40            call [edx + 0x40]

This patch intercepts execution at 0x0044c455 right after call PlayMovie:
- Tests EAX (the return code of PlayMovie).
- If EAX != 0: Executes original path (loads moviePlayer, calls slot 16).
- If EAX == 0: Safely sets this->movieControl = NULL and movieRestartPending = 0,
  keeps ESP clean (no unmatched push ebx), and jumps straight to function exit (0x0044d6b0).
- Because movieControl is set to NULL, timers and UI buttons will never attempt
  to dereference moviePlayer.
"""
import os
import shutil
import struct
import sys

IMAGE_BASE = 0x00400000
HOOK_OFFSET = 0x0004c455
HOOK_VA = IMAGE_BASE + HOOK_OFFSET
CAVE_OFFSET = 0x00154F00
CAVE_VA = IMAGE_BASE + CAVE_OFFSET
EXIT_VA = 0x0044d6b0

ORIG_BYTES = bytes([
    0x8b, 0x85, 0x58, 0x7f, 0x00, 0x00,  # mov eax, [ebp + 0x7f58]
    0x89, 0x9d, 0x78, 0x7f, 0x00, 0x00,  # mov [ebp + 0x7f78], ebx
    0x53,                                # push ebx
    0x8b, 0x88, 0xec, 0x01, 0x00, 0x00,  # mov ecx, [eax + 0x1ec]
    0x8b, 0x11,                          # mov edx, [ecx]
    0xff, 0x52, 0x40                     # call [edx + 0x40]
])

def patch_executable(exe_path: str):
    if not os.path.isfile(exe_path):
        print(f"[-] Error: File not found: {exe_path}")
        return False

    bak_path = exe_path + ".bak"
    if not os.path.exists(bak_path):
        shutil.copy2(exe_path, bak_path)
        print(f"[+] Created backup: {bak_path}")

    with open(exe_path, "rb") as f:
        data = bytearray(f.read())

    # Check if already patched
    current_hook = bytes(data[HOOK_OFFSET:HOOK_OFFSET+5])
    expected_hook = bytes([0xE9]) + struct.pack('<i', CAVE_VA - (HOOK_VA + 5))
    if current_hook == expected_hook:
        print("[*] Executable is already patched with null-safety hook.")
        return True

    # Verify original bytes
    current_bytes = bytes(data[HOOK_OFFSET:HOOK_OFFSET+24])
    if current_bytes != ORIG_BYTES:
        print(f"[-] Warning: Target bytes at 0x{HOOK_VA:08x} do not match expected retail bytes.")
        print(f"    Expected: {ORIG_BYTES.hex(' ')}")
        print(f"    Found:    {current_bytes.hex(' ')}")
        ans = input("Proceed anyway? (y/n): ").strip().lower()
        if ans != 'y':
            return False

    # Build code cave
    code = bytearray()
    code += b'\x85\xc0'  # test eax, eax
    jz_pos = len(code)
    code += b'\x74\x00'  # jz .failed (rel8 placeholder)

    # Success branch:
    code += b'\x8b\x85\x58\x7f\x00\x00'  # mov eax, [ebp + 0x7f58]
    code += b'\x89\x9d\x78\x7f\x00\x00'  # mov [ebp + 0x7f78], ebx
    code += b'\x53'                      # push ebx
    code += b'\x8b\x88\xec\x01\x00\x00'  # mov ecx, [eax + 0x1ec]
    code += b'\x8b\x11'                  # mov edx, [ecx]
    code += b'\xff\x52\x40'              # call [edx + 0x40]
    jmp_exit_pos = len(code)
    code += b'\xeb\x00'                  # jmp .exit (rel8 placeholder)

    # Failed branch:
    failed_pos = len(code)
    code[jz_pos + 1] = failed_pos - (jz_pos + 2)
    code += b'\xc7\x85\x58\x7f\x00\x00\x00\x00\x00\x00'  # mov dword ptr [ebp + 0x7f58], 0
    code += b'\xc7\x85\x78\x7f\x00\x00\x00\x00\x00\x00'  # mov dword ptr [ebp + 0x7f78], 0

    # Exit branch:
    exit_pos = len(code)
    code[jmp_exit_pos + 1] = exit_pos - (jmp_exit_pos + 2)
    jmp_va = CAVE_VA + len(code)
    disp32 = EXIT_VA - (jmp_va + 5)
    code += b'\xe9' + struct.pack('<i', disp32)

    # Build hook (5 bytes JMP + 19 NOPs)
    hook = bytearray(expected_hook)
    hook += b'\x90' * (24 - len(hook))

    # Apply patches
    data[HOOK_OFFSET:HOOK_OFFSET+24] = hook
    data[CAVE_OFFSET:CAVE_OFFSET+len(code)] = code

    with open(exe_path, "wb") as f:
        f.write(data)

    print(f"[+] Successfully patched {exe_path}!")
    print(f"    Hook at 0x{HOOK_VA:08x} -> Cave at 0x{CAVE_VA:08x} ({len(code)} bytes)")
    return True

if __name__ == "__main__":
    target = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "mcm2", "MCM2.EXE")
    target = os.path.abspath(target)
    patch_executable(target)
