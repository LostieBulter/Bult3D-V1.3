# Bult 3D

A free 3D animation tool for Windows, made with Godot 4.

Import 3D models, animate them with a timeline and keyframes, render videos, or export your animated model to use it in your own games.

**Download the program (free):** https://lostiebulter.itch.io/bult3d

## Features

- Timeline with keyframes for objects, cameras, lights and bones
- Multiple animations per object ("idle", "run", "jump"...), switchable at any time
- Import `.glb` / `.gltf` models with skeletons and pose their bones (simple two-bone IK included)
- Shapes, lights, cameras, video and music inside the scene
- Render to MP4 or frame by frame
- Export the whole project to `.glb` / `.gltf` with all the animations. In Godot, each animation appears by name in the `AnimationPlayer` node
- Editable collisions per model, with the option to disable them per object
- PNG / JPG textures, with transparency and pixel-art (unsmoothed) display for small images
- Save and open projects (`Ctrl+S`)

The program interface is in Spanish. The release package includes a guide in English and Spanish.

## Quick controls

| Key | Action |
|-----|--------|
| `Shift+T` | Open the animations panel of the selected object |
| `Shift+O` | Edit the object's origin |
| `Shift+C` | Collision size and position |
| `Ctrl+S` | Save the project |
| `Ctrl+Z` / `Ctrl+Y` | Undo / redo |

## Requirements

Developed and tested on a modest laptop: Windows 11, Intel Celeron N4500, 8 GB of RAM and integrated Intel UHD graphics. It runs smoothly with lightweight models; very heavy models made for offline rendering may slow it down.

## Export limitations

The `.glb` / `.gltf` export includes models, skeletons and animations. It does not include video, music, animated light intensity or collisions, and curve interpolation is exported with normal easing. Objects attached to a bone are exported as separate objects.

## Run from source

1. Install [Godot Engine](https://godotengine.org) 4.x (developed with 4.7).
2. Open the `bult-3d-motor` folder as a project in Godot.
3. Press Play.

FFmpeg is not included in this repository. MP4 rendering needs `ffmpeg.exe` from [ffmpeg.org](https://ffmpeg.org); in the released program it goes in a folder named `ffmpeg` next to the executable.

## Status

Version 1.0, made by one person, so bugs are possible. Issues and suggestions are welcome.

## License

The source code of Bult 3D is available under CC BY-NC 4.0 (see LICENSE):
you can use and modify it, but you must give credit to LostieBulter, link to this
repository, indicate changes, and you can't use the code commercially.

Animations, videos and models you create with Bult 3D are yours and can be used
commercially. The license only covers the program's source code.

Bult 3D uses Godot Engine (MIT license) and FFmpeg (not included), which have their own licenses.

## Credits

Made with Godot Engine. Directed and tested by LostieBulter; the code was written with the help of Claude (Anthropic).
