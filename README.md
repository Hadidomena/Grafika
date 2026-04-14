# About Project
## Reason for Existance
This repository contains my projects from the subject **Computer Graphics**. I used them to learn basics of Zig.

## Needed Resources
- **Zig** - used version = 0.16.0
- **Raylib** - used version = 5.5

## How to get them

### On Debian/Ubuntu
Zig
```bash
sudo apt-get update && sudo apt-get install -y zig
```
Raylib
```bash
sudo apt-get update && sudo apt-get install -y libgl-dev libx11-dev libxrandr-dev libxi-dev libxxf86vm-dev libxinerama-dev libxcursor-dev
```
- Ensure `raylib` is available. You can either:
	- build raylib locally and set `RAYLIB_PATH` to its `src` directory, or
	- pass `-Draylib-path="/path/to/raylib/src"` to `zig build` when building application.

### On Windows

# Parts

## Part_1
Part_1 is a Zig + Raylib wireframe renderer implementing a basic virtual camera (manual transform + perspective projection).

Program modes
- Load with preset edges:
	- `zig build run`
- Load box set from a .txt file:
	- `zig build run -- --boxes boxes.txt`

Example:
```bash
export RAYLIB_PATH="$HOME/raylib/raylib/src"
zig build run
# or run with a boxes file:
zig build run -- --boxes boxes.txt
```

File format for `--boxes` (each line creates a box from two opposite corners):
```text
-1 -1 -1 1 1 1
0 0 -3 2 2 -1
```

Controls (default keys):

- `W`/`S`: move forward/back
- `A`/`D`: strafe left/right
- `Q`/`E`: move camera up/down (position Y)
- Left/Right arrows: yaw (rotate around Y)
- Up/Down arrows: pitch (look up/down)
- `Z`/`X`: decrease/increase focal length

## Part 2
# Notes
- If your environment fails to fetch Zig, prefer downloading Zig from the official index or pin a specific release tarball.