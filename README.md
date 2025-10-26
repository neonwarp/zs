# 🌀 zs for PowerShell

A blazing-fast, minimal clone of [`z`](https://github.com/rupa/z), rewritten in [Zig](https://ziglang.org/), designed for Windows PowerShell. It tracks your most-used directories and lets you jump to them quickly — no fuss, no noise.

## 🚀 Features

- Written in Zig, compiled to a small `.exe`
- Integrates with **PowerShell** without breaking your existing prompt (e.g. Starship)
- Remembers directory usage and lets you jump by fuzzy substring

## 🧭 Motivation

I built this because the existing directory-jump tools I tried kept breaking or behaving unpredictably on my Windows Dev Drive setup.

## 📦 Installation

1. **Download `zs.exe`**

   - Download the prebuilt Zig binary: [`zs.exe`](https://github.com/neonwarp/zs/releases/latest) (or build it yourself from `src/main.zig`)
   - Place it in any folder (e.g. `C:\zs\zs.exe`)

2. **Add `zs.ps1` to your PowerShell profile**

   Open (or create) your PowerShell profile:

   ```powershell
   notepad $PROFILE
   ```

   Paste the following (you can customize path):

   ```powershell
   $global:ZS_EXE_PATH = "C:\zs\zs.exe"
   . "C:\zs\zs.ps1" | Out-Null
   ```
