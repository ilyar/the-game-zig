const rl = @import("raylib");

pub fn main() void {
    // Configure window to be resizable
    rl.SetConfigFlags(rl.FLAG_WINDOW_RESIZABLE);
    rl.InitWindow(800, 600, "The Game");
    defer rl.CloseWindow();

    // Maximize window to fill the screen on desktop
    rl.MaximizeWindow();

    rl.SetTargetFPS(60);

    const background: rl.Color = .{ .r = 238, .g = 238, .b = 238, .a = 255 };

    while (!rl.WindowShouldClose()) {
        // Toggle fullscreen mode on F11 key press
        if (rl.IsKeyPressed(rl.KEY_F11)) {
            rl.ToggleFullscreen();
        }

        rl.BeginDrawing();
        rl.ClearBackground(background);

        // Step 1 add your shape rendering code here
        // Draw a red square using DrawRectangle
        // Draw a green circle using DrawCircle
        // Draw a blue rectangle outline using DrawRectangleLines

        rl.EndDrawing();
    }
}
