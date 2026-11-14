# The Game in Zig using raylib

Starter template for Step 1 of building The Game in [Zig](https://ziglang.org/) using [raylib](https://github.com/raysan5/raylib)

## Requirements

1. [Zig](https://ziglang.org/download/) 0.17.0 or newer

The Emscripten SDK for the Web build is downloaded automatically by `zig build`.

## How to Run

1. Clone the repository and navigate to the project directory:
```bash
git clone <REPOSITORY_URL>
cd the-game-zig
```

2. Build and run Desktop
```bash
zig build run
```

3. Build for Web (output in `zig-out/web`)
```bash
zig build -Dtarget=wasm32-emscripten
```

4. Build and run Web locally
```bash
zig build run -Dtarget=wasm32-emscripten
```

## Assignment

1. Open `src/main.zig`
2. Complete the instructions for **Step 1**
3. Verify your changes by running the game
4. Send a link to your repository with the solution to [@ilyarsoftware](https://t.me/ilyarsoftware) to receive the next step
