# About Project

This repository contains projects from the Computer Graphics course. The first part (folder `Part_1`) is a small wireframe renderer written in Zig that uses Raylib for windowing and drawing. The program implements a simple virtual camera (position, yaw, pitch) and perspective projection.

## Requirements
- Zig (tested with 0.16.0)
- C compiler and build tools (for example GCC/Clang on Linux, Visual Studio Build Tools or MSYS2 on Windows)
- Git

Raylib version used in development: 5.5

## Complete setup and run instructions

Below are step-by-step instructions to get a working instance on Debian/Ubuntu and on Windows (PowerShell). The project expects Raylib's headers and static library to be available; you can either build Raylib locally and set `RAYLIB_PATH` to its `src` directory, or pass `-Draylib-path="/path/to/raylib/src"` to `zig build`.

### Debian / Ubuntu (quick)
Install dependencies and Zig:
```bash
sudo apt-get update
sudo apt-get install -y git build-essential cmake pkg-config \
  libgl-dev libx11-dev libxrandr-dev libxi-dev libxxf86vm-dev libxinerama-dev libxcursor-dev zig
```
Build Raylib from source:
```bash
git clone --depth 1 https://github.com/raysan5/raylib.git
cd raylib/src
make PLATFORM=PLATFORM_DESKTOP
# Now set env var to the src directory
export RAYLIB_PATH="$PWD"
```
Build and run the project (Part_1):
```bash
cd <path-to-repo>/Part_1
zig build run
# or pass an explicit raylib path:
zig build run -Draylib-path="$PWD/../raylib/src"
```

To run with a boxes file:
```bash
zig build run -- --boxes boxes.txt
```

### Windows (PowerShell) — Visual Studio / CMake approach
1. Install Zig (download from https://ziglang.org and extract to e.g. `C:\zig`), and ensure `zig.exe` is on `PATH`.
2. Install Visual Studio Build Tools (Desktop development with C++), Git and CMake.
3. Build Raylib using CMake (Visual Studio generator):
```powershell
# in PowerShell
git clone --depth 1 https://github.com/raysan5/raylib.git C:\raylib\raylib
cd C:\raylib\raylib
mkdir build; cd build
cmake .. -G "Visual Studio 17 2022" -A x64 -DCMAKE_BUILD_TYPE=Release
cmake --build . --config Release
```
After building, ensure the `raylib` headers and the built library (e.g. `libraylib.a` or `raylib.lib`) are available. For simplicity you can set `RAYLIB_PATH` to the `src` directory:
```powershell
setx RAYLIB_PATH "C:\raylib\raylib\src"
# start a new shell to pick up the env var, or for current session:
$env:RAYLIB_PATH = 'C:\raylib\raylib\src'
```
Then build and run the project:
```powershell
Set-Location 'C:\path\to\repo\Part_1'
zig build run
# or override the path inline:
zig build run -Draylib-path="C:\raylib\raylib\src"
```

## Notes
- `build.zig` supports specifying raylib path via `-Draylib-path` or the `RAYLIB_PATH` environment variable. A sensible default is chosen based on the target OS (Linux default `/home/szp/raylib/raylib/src`, Windows default `C:\raylib\raylib\src`). If you cross-compile, you can pass the explicit `-Draylib-path` for the target.
- The project is intentionally minimal and demonstrates manual camera transforms and perspective projection rather than a full 3D engine.

## Part_1 — summary
Part_1 is a Zig + Raylib wireframe renderer implementing a basic virtual camera (manual transform + perspective projection). Controls are:

- `W`/`S`: move forward/back
- `A`/`D`: strafe left/right
- `Q`/`E`: move camera up/down (position Y)
- Left/Right arrows: yaw (rotate around Y)
- Up/Down arrows: pitch (look up/down)
- `Z`/`X`: decrease/increase focal length