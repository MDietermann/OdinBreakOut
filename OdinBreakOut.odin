package OdinBreakOut

import rl "vendor:raylib"
import "core:math"
import "core:math/linalg"
import "core:fmt"

// Game Values
SCREEN_SIZE :: 320; // Size of the game screen for Zoom
BACKGROUND_COLOR :: rl.Color { 45, 45, 45, 255 }; // Background color of the game
SCORE_TEXT_COLOR :: rl.Color { 255, 255, 255, 255 }; // Color of the score text
gameStarted: bool; // Flag to check if the game has started
gameOver: bool; // Flag to check if the game is over
score: int; // Player's score

blockColorScore: [BLOCK_COLOR]int = {
    .Yellow = 1,
    .Green = 2,
    .Purple = 4,
    .Red = 8,
};

player_lives: int = 0; // Player's lives, not used in this version but can be added later

// Values for the paddle
PADDLE_COLOR :: rl.Color { 0, 140, 0, 255 }; // Color of the paddle
PADDLE_WIDTH :: 50; // Width of the paddle
PADDLE_HEIGHT :: 6; // Height of the paddle
PADDLE_SPEED :: 200; // Speed of the paddle movement
PADDLE_POS_Y :: 260; // Y position of the paddle
paddlePosX: f32; // X position of the paddle

// Values for the ball
BALL_COLOR :: rl.Color { 255, 90, 40, 255 }; // Color of the ball
BALL_RADIUS :: 4; // Radius of the ball
BALL_START_Y :: 160; // Initial Y position of the ball
BALL_SPEED :: 260; // Speed of the ball
ballPos: rl.Vector2; // Position of the ball
ballDir: rl.Vector2; // Direction of the ball

// Values for the Blocks
// Color of the blocks
BLOCK_COLOR :: enum {
    Yellow,
    Green,
    Purple,
    Red,
};

blockColorValues: [BLOCK_COLOR]rl.Color = {
    .Yellow = { 253, 249, 150, 255 },
    .Green = { 180, 245, 190, 255 },
    .Purple = { 170, 120, 250, 255 },
    .Red = { 250, 90, 85, 255 },
};

BLOCK_OUTLINE_COLOR_LIGHT :: rl.Color { 200, 200, 150, 100 }; // Color of the block outlines
BLOCK_OUTLINE_COLOR_DARK :: rl.Color { 0, 0, 50, 100 }; // Color of the block outlines
NUM_BLOCKS_X :: 10; // Number of columns of blocks
NUM_BLOCKS_Y :: 8; // Number of rows of blocks
BLOCK_HEIGHT :: 10; // Height of each block
BLOCK_WIDTH :: 28; // Width of each block
blocks: [NUM_BLOCKS_X][NUM_BLOCKS_Y]bool; // 2D array to store block states
rowColors: [NUM_BLOCKS_Y]BLOCK_COLOR = {
    .Red,
    .Red,
    .Purple,
    .Purple,
    .Yellow,
    .Yellow,
    .Green,
    .Green,
}

StopProcess :: proc(textureArray: [dynamic]rl.Texture2D) {
    rl.CloseAudioDevice(); // Close the audio device

    for texture in textureArray {
        // Unload each texture in the dynamic array
        rl.UnloadTexture(texture); 
    }

    rl.CloseWindow(); // Close the window and OpenGL context
}

Restart :: proc() {
    // Center the paddle at the start
    paddlePosX = ( SCREEN_SIZE - PADDLE_WIDTH ) / 2; 

    // Set the initial position of the ball
    ballPos = { SCREEN_SIZE / 2, BALL_START_Y }; 

    // Reset game over flag
    gameOver = false;

    // Reset the game started flag
    gameStarted = false; 

    if player_lives <= 0 {
        // Reset player lives if they are less than or equal to 0
        player_lives = 3; 

        // Reset the score
        score = 0;
    
        // Initialize Blocks
        for x in 0..<NUM_BLOCKS_X {
            for y in 0..<NUM_BLOCKS_Y {
                // Set all blocks to active
                blocks[x][y] = true; 
            }
        }
    }
}

Reflect :: proc(dir, normal: rl.Vector2) -> rl.Vector2 {
    newDirection: rl.Vector2 = linalg.reflect(dir, linalg.normalize(normal));
    
    // Normalize the new direction
    return linalg.normalize0(newDirection); 
}

CalculateBlockRect :: proc(x, y: int) -> rl.Rectangle {
    // Calculate the rectangle for the block based on its position
    return {
        x = f32( 20 + x * BLOCK_WIDTH ), // X position with padding
        y = f32( 40 + y * BLOCK_HEIGHT ), // Y position with padding
        width = BLOCK_WIDTH,
        height = BLOCK_HEIGHT
    }; 
}

BlockExists :: proc(x, y: int) -> bool {
    // Out of bounds Check
    if x < 0 || y < 0 || x >= NUM_BLOCKS_X || y >= NUM_BLOCKS_Y {
        return false; 
    }

    // Return the state of the block
    return blocks[x][y]; 
}

main :: proc() {
    rl.SetConfigFlags({
        // Enable V-Sync on GPU
        .VSYNC_HINT, 
    });

    // Initialize the window with a size of 1280x1280 and title "Odin Breakout"
    rl.InitWindow(1280, 1280, "Odin Breakout");

    // Initialize the audio device
    rl.InitAudioDevice();

    // Set the game to run at 60 frames per second
    rl.SetTargetFPS(60); 

    // Load Textures
    dynamicTextureArray: [dynamic]rl.Texture2D; // Dynamic array to hold textures

    // Texture for the paddle
    // Add paddle texture to the dynamic array
    paddleTexture := rl.LoadTexture("assets/paddle.png");
    // Add paddle texture to the dynamic array
    append(&dynamicTextureArray, paddleTexture); 

    // Texture for the ball
    ballTexture := rl.LoadTexture("assets/ball.png");
    // Add ball texture to the dynamic array
    append(&dynamicTextureArray, ballTexture); 

    // Load Sounds
    // Load sound for hitting a block
    hitBlockSound := rl.LoadSound("assets/hit_block.wav"); 
    // Load sound for hitting the paddle
    hitPaddleSound := rl.LoadSound("assets/hit_paddle.wav"); 
    // Load sound for game over
    gameOverSound := rl.LoadSound("assets/game_over.wav"); 

    // Initialize paddle position
    Restart(); 

    for !rl.WindowShouldClose() {
        // Get the time elapsed since the last frame
        dt: f32; 
      
        if !gameStarted {
            // Oscillate ball position horizontally
            ballPos = { 
                SCREEN_SIZE / 2 + f32(math.cos(rl.GetTime()) * SCREEN_SIZE / 2.5), 
                BALL_START_Y
            }

            // Start game
            if rl.IsKeyPressed(.SPACE) {
                // Center the paddle
                paddleCenter: rl.Vector2 = { paddlePosX + PADDLE_WIDTH / 2, PADDLE_POS_Y }; 

                // Vector from ball to paddle center
                ballToPaddle: rl.Vector2 = paddleCenter - ballPos; 

                // Normalize the direction vector
                ballDir = linalg.normalize0(ballToPaddle); 

                // Start the game when space is pressed
                gameStarted = true; 
            }
        } else if gameOver {
            if rl.IsKeyPressed(.SPACE) {
                // Restart the game when space is pressed
                Restart(); 
                gameOver = false; 
            }
        } else {
            // Get the time since the last frame
            dt = rl.GetFrameTime(); 
        }

        // Store the previous position of the ball
        previousBallPos: rl.Vector2 = ballPos; 
        // Update ball position based on direction and speed
        ballPos += ballDir * BALL_SPEED * dt; 
        paddleMoveVelocity: f32;

        if rl.IsKeyDown(.LEFT) {
            // Move paddle left
            paddleMoveVelocity = -PADDLE_SPEED; 
        } else if rl.IsKeyDown(.RIGHT) {
            // Move paddle right
            paddleMoveVelocity = PADDLE_SPEED; 
        } else {
            // No movement
            paddleMoveVelocity = 0; 
        }

        // Restart the game if 'R' is pressed
        if rl.IsKeyDown(.R) {
            Restart(); 
        }

        // Close the window if 'ESC' is pressed
        if rl.IsKeyDown(.ESCAPE) {
            StopProcess(dynamicTextureArray); 
        }

        // Update paddle position based on input
        paddlePosX += paddleMoveVelocity * dt; 

        // Keep paddle within screen bounds
        paddlePosX = rl.Clamp(paddlePosX, 0, SCREEN_SIZE - PADDLE_WIDTH); 

        // Create a rectangle for the paddle
        paddleRect: rl.Rectangle = {
            x = paddlePosX,
            y = PADDLE_POS_Y,
            width = PADDLE_WIDTH,
            height = PADDLE_HEIGHT
        }; 

        // Check for ball collision with the paddle
        if rl.CheckCollisionCircleRec(ballPos, BALL_RADIUS, paddleRect) {
            collisionNormal: rl.Vector2;
            if previousBallPos.y < paddleRect.y + paddleRect.height {
                // Ball is above the paddle
                collisionNormal += { 0, -1 }; 

                // Position ball above the paddle
                ballPos.y = paddleRect.y - BALL_RADIUS; 
            }

            if previousBallPos.y > paddleRect.y + paddleRect.height {
                // Ball is below the paddle
                collisionNormal += { 0, 1 };

                // Position ball below the paddle
                ballPos.y = paddleRect.y + paddleRect.height + BALL_RADIUS; 
            }

            if previousBallPos.x < paddleRect.x {
                // Ball is to the left of the paddle
                collisionNormal += { -1, 0 }; 

                // Position ball to the left of the paddle
                ballPos.x = paddleRect.x - BALL_RADIUS; 
            }

            if previousBallPos.x > paddleRect.x + paddleRect.width {
                // Ball is to the right of the paddle
                collisionNormal += { 1, 0 }; 

                // Position ball to the right of the paddle
                ballPos.x = paddleRect.x + paddleRect.width + BALL_RADIUS; 
            }

            if collisionNormal != 0 {
                // Reflect the ball direction based on collision normal
                ballDir = Reflect(ballDir, collisionNormal);
            }

            // Play sound when hitting the paddle
            rl.PlaySound(hitPaddleSound); 
        }

        blockXLoop: for x in 0..<NUM_BLOCKS_X {
            for y in 0..<NUM_BLOCKS_Y {
                if !blocks[x][y] {
                    // Skip inactive blocks
                    continue; 
                }

                blockRect: rl.Rectangle = CalculateBlockRect(x, y);

                // Check for ball collision with the block
                if rl.CheckCollisionCircleRec(ballPos, BALL_RADIUS, blockRect) {
                    collisionNormal: rl.Vector2 = { 0, 0 }; 

                    // Determine the collision normal based on the previous position of the ball
                    if previousBallPos.y < blockRect.y {
                        // Ball is above the block
                        collisionNormal += { 0, -1 }; 
                    } 
                    
                    if previousBallPos.y > blockRect.y + blockRect.height {
                        // Ball is below the block
                        collisionNormal += { 0, 1 }; 
                    }

                    if previousBallPos.x < blockRect.x {
                        // Ball is to the left of the block
                        collisionNormal += { -1, 0 }; 
                    } 
                    
                    if previousBallPos.x > blockRect.x + blockRect.width {
                        // Ball is to the right of the block
                        collisionNormal += { 1, 0 }; 
                    }

                    if BlockExists(x + int(collisionNormal.x), y) {
                        // Reset horizontal collision normal if there's a block
                        collisionNormal.x = 0; 
                    }

                    if BlockExists(x, y + int(collisionNormal.y)) {
                        // Reset vertical collision normal if there's a block
                        collisionNormal.y = 0; 
                    }

                    if collisionNormal != { 0, 0 } {
                        // Reflect the ball direction based on collision normal
                        ballDir = Reflect(ballDir, collisionNormal);
                    }

                    // Deactivate the block after collision
                    blocks[x][y] = false; 

                    // Increment the score
                    rowColor: BLOCK_COLOR = rowColors[y]; 
                    score += blockColorScore[rowColor];

                    // Play sound when hitting a block
                    rl.PlaySound(hitBlockSound);

                    // Exit the loop after hitting a block
                    break blockXLoop; 
                }
            }
        }

        // Check for ball collision with the screen edges
        // Right Edge Collision
        if ballPos.x + BALL_RADIUS > SCREEN_SIZE {
            // Position ball at the right edge
            ballPos.x = SCREEN_SIZE - BALL_RADIUS;
            
            // Reverse horizontal direction on right edge collision
            ballDir = Reflect(ballDir, { -1, 0 });
        }

        // Left Edge Collision
        if ballPos.x - BALL_RADIUS < 0 {
            // Position ball at the left edge
            ballPos.x = BALL_RADIUS; 

            // Reverse horizontal direction on left edge collision
            ballDir = Reflect(ballDir, { 1, 0 });
        }
        
        // Top Edge Collision
        if ballPos.y - BALL_RADIUS < 0 {
            // Position ball at the top edge
            ballPos.y = BALL_RADIUS; 

            // Reverse vertical direction on top edge collision
            ballDir = Reflect(ballDir, { 0, 1 });
        }

        // Bottom Edge Collision
        if !gameOver && ballPos.y > SCREEN_SIZE + BALL_RADIUS {
            // Decrease player lives
            player_lives -= 1;

            if player_lives <= 0 {
                // Set game over flag if no lives left
                gameOver = true; 

                // Play game over sound
                rl.PlaySound(gameOverSound);
            } else {
                // Reset the game if lives are left
                Restart(); 
            }
        }

        rl.BeginDrawing();
        rl.ClearBackground(BACKGROUND_COLOR); // Clear the screen with a light blue color

        // Set the zoom level based on screen height
        camera: rl.Camera2D = {
            zoom = f32(rl.GetScreenHeight() / SCREEN_SIZE), 
        }

        // Begin 2D mode with the camera
        rl.BeginMode2D(camera); 

        // Draw the paddle with color
        // rl.DrawRectangleRec(paddleRect, PADDLE_COLOR); 

        // Draw the paddle with texture
        rl.DrawTextureV(paddleTexture, { paddlePosX, PADDLE_POS_Y }, rl.Color { 255, 255, 255, 255 });

        // Draw the ball with color
        // rl.DrawCircleV(ballPos, BALL_RADIUS, BALL_COLOR); 

        // Draw the ball with texture
        rl.DrawTextureV(ballTexture, { ballPos.x - BALL_RADIUS, ballPos.y - BALL_RADIUS }, rl.Color { 255, 255, 255, 255 });

        for x in 0..<NUM_BLOCKS_X {
            for y in 0..<NUM_BLOCKS_Y {
                if blocks[x][y] == false {
                    continue; // Skip inactive blocks
                }

                // Create a rectangle for the block
                blockRect: rl.Rectangle = CalculateBlockRect(x, y);

                // Top-left corner of the block
                topLeft: rl.Vector2 = { 
                    blockRect.x, 
                    blockRect.y 
                }; 
                
                // Top Right Corner of the block
                topRight: rl.Vector2 = {
                    blockRect.x + blockRect.width, 
                    blockRect.y 
                }

                // Bottom Left Corner of the block
                bottomLeft: rl.Vector2 = {
                    blockRect.x, 
                    blockRect.y + blockRect.height 
                }

                // Bottom Right Corner of the block
                bottomRight: rl.Vector2 = {
                    blockRect.x + blockRect.width, 
                    blockRect.y + blockRect.height 
                }


                // Draw the block
                rl.DrawRectangleRec(blockRect, blockColorValues[rowColors[y]]); 

                // Draw top edge
                rl.DrawLineEx(topLeft, topRight, 1, BLOCK_OUTLINE_COLOR_LIGHT); 

                // Draw left edge
                rl.DrawLineEx(topLeft, bottomLeft, 1, BLOCK_OUTLINE_COLOR_LIGHT); 

                // Draw right edge
                rl.DrawLineEx(bottomRight, topRight, 1, BLOCK_OUTLINE_COLOR_DARK); 

                // Draw bottom edge
                rl.DrawLineEx(bottomRight, bottomLeft, 1, BLOCK_OUTLINE_COLOR_DARK); 

            }
        }

        // UI
        // Create the score text
        scoreText := fmt.ctprint("Score: ", score); 

        // Draw the score at the top left
        rl.DrawText(scoreText, 5, 5, 10, SCORE_TEXT_COLOR); 

        // Create the lives text
        livesText := fmt.ctprint("Lives: ", player_lives); 
        livesTextWitdh := rl.MeasureText(livesText, 10);

        // Draw the lives at the top right
        rl.DrawText(livesText, SCREEN_SIZE - livesTextWitdh - 10, 5, 10, SCORE_TEXT_COLOR); 

        // Start Screen
        if !gameStarted {
            // Create the start text
            startText := fmt.ctprint("Press SPACE to start.\n\nControls: LEFT/RIGHT to move paddle"); 

            // Measure the width of the start text
            startTextWidth := rl.MeasureText(startText, 15); 

            // Draw the start text in the center
            rl.DrawText(startText, (SCREEN_SIZE - startTextWidth) / 2, BALL_START_Y - 30, 15, SCORE_TEXT_COLOR); 
        }

        // Game Over Screen
        if gameOver {
            // Create the game over text
            gameOverText := fmt.ctprintf("Score: %v.\n\nReset: SPACE", score); 

            // Measure the width of the game over text
            gameOverTextWidth := rl.MeasureText(gameOverText, 15); 

            // Draw the game over text in the center
            rl.DrawText(gameOverText, (SCREEN_SIZE - gameOverTextWidth) / 2, BALL_START_Y - 30, 15, SCORE_TEXT_COLOR); 
        }
        
        // End 2D mode
        rl.EndMode2D(); 
        
        rl.EndDrawing();
        
        // Free Temp Allocated Memory
        free_all(context.temp_allocator);
    }

    StopProcess(dynamicTextureArray); // Stop the process and unload textures
}