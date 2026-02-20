package main

import "core:fmt"
import "core:math/rand"
import "core:strings"
import rl "vendor:raylib"

VERSION :: "0.0.1"

CELL_COLOR :: rl.RED
CELL_SIZE :: 20
WINDOW_WIDTH :: 500 
WINDOW_HEIGHT :: 660
CELLS_PER_ROW :: WINDOW_WIDTH / CELL_SIZE  // 25
CELLS_PER_COL :: WINDOW_HEIGHT / CELL_SIZE // 33


Shape :: distinct [16]u8 // 4 * 4 cells
Board :: distinct [CELLS_PER_ROW * CELLS_PER_COL]u8
State :: enum {Start, Playing, GameOver}

Game :: struct {
	board: Board,
	state: State,
	score: int,
}

// 6 basic shapes multiplied by 4 directions
// | oooo | ooo | oo | ooo | ooo |  oo |
// |      |   o | oo |  o  | o   | oo  |
SHAPES :: [24]Shape {
	// oooo
	Shape{1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0},
	Shape{0,1,0,0,0,1,0,0,0,1,0,0,0,1,0,0},
	Shape{1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0},
	Shape{0,1,0,0,0,1,0,0,0,1,0,0,0,1,0,0},
	// ooo
	//   o
	Shape{1,1,1,0,0,0,1,0,0,0,0,0,0,0,0,0},
	Shape{0,1,0,0,0,1,0,0,1,1,0,0,0,0,0,0},
	Shape{1,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0},
	Shape{1,1,0,0,1,0,0,0,1,0,0,0,0,0,0,0},
	// oo
	// oo
	Shape{1,1,0,0,1,1,0,0,0,0,0,0,0,0,0,0},
	Shape{1,1,0,0,1,1,0,0,0,0,0,0,0,0,0,0},
	Shape{1,1,0,0,1,1,0,0,0,0,0,0,0,0,0,0},
	Shape{1,1,0,0,1,1,0,0,0,0,0,0,0,0,0,0},
	// ooo
	//  o 
	Shape{1,1,1,0,0,1,0,0,0,0,0,0,0,0,0,0},
	Shape{0,1,0,0,1,1,0,0,0,1,0,0,0,0,0,0},
	Shape{0,1,0,0,1,1,1,0,0,0,0,0,0,0,0,0},
	Shape{1,0,0,0,1,1,0,0,1,0,0,0,0,0,0,0},
	// ooo
	// o
	Shape{1,1,1,0,1,0,0,0,0,0,0,0,0,0,0,0},
	Shape{1,1,0,0,0,1,0,0,0,1,0,0,0,0,0,0},
	Shape{0,0,1,0,1,1,1,0,0,0,0,0,0,0,0,0},
	Shape{1,0,0,0,1,0,0,0,1,1,0,0,0,0,0,0},
	//  oo
	// oo
	Shape{0,1,1,0,1,1,0,0,0,0,0,0,0,0,0,0},
	Shape{1,0,0,0,1,1,0,0,0,1,0,0,0,0,0,0},
	Shape{0,1,1,0,1,1,0,0,0,0,0,0,0,0,0,0},
	Shape{1,0,0,0,1,1,0,0,0,1,0,0,0,0,0,0},

}

rotate :: proc(shape_idx: u8) -> (next_idx: u8) {
	switch shape_idx {
	case 0..<4: next_idx = 4%shape_idx			
	case 4..<8: next_idx = 4%shape_idx + 4
	case 8..<12: next_idx = 4%shape_idx + 8
	case 12..<16: next_idx = 4%shape_idx + 12
	}
	return
}

render_shape :: proc(board: ^Board, x, y, shape_idx: u8) {
	assert(x >= 0 && x < CELLS_PER_ROW)	
	assert(y >= 0 && y < CELLS_PER_COL)
	assert(shape_idx >= 0 && shape_idx < 24)
	shapes := SHAPES
	for xi := 0; xi < CELLS_PER_ROW; xi+=1 {
		for yi := 0; yi < CELLS_PER_COL; yi+=1 {
			if xi >= int(x) && yi >= int(y) && xi < int(x)+4 && yi < int(y)+4 {
				sx := xi - int(x)
				sy := yi - int(y)
				shape := shapes[shape_idx]
				v := shape[sy * 4 + sx]
				board^[yi * CELLS_PER_ROW + xi] = v > 0 ? 1 : 0
			}
		}
	}
}

draw_board :: proc(board: ^Board) {
	for xi := 0; xi < CELLS_PER_ROW; xi+=1 {
		for yi := 0; yi < CELLS_PER_COL; yi+=1 {
			if board^[yi * CELLS_PER_ROW + xi] > 0 {
				rl.DrawRectangle(i32(xi*CELL_SIZE), i32(yi*CELL_SIZE), CELL_SIZE, CELL_SIZE, CELL_COLOR)
				rl.DrawRectangleLines(i32(xi*CELL_SIZE), i32(yi*CELL_SIZE), CELL_SIZE, CELL_SIZE, rl.WHITE)
			}
		}
	}
}

render_start_screen_background :: proc(board: ^Board) {
	render_shape(board, 20, 30, 0)	
	render_shape(board, 3, 4, 4)	
	render_shape(board, 7, 10, 8)	
	render_shape(board, 12, 5, 12)	
	render_shape(board, 15, 15, 16)	
	render_shape(board, 13, 20, 23)	
}

draw_when_start :: proc(game: ^Game) {
	render_start_screen_background(&game^.board)
	draw_board(&game^.board)
	rl.DrawRectangle(0, 0, WINDOW_WIDTH, WINDOW_HEIGHT, rl.Color{0, 0, 0, 192})
	text: cstring = "Press space/enter to start"
	text_width := rl.MeasureText(text, 32)
	rl.DrawText(text, (WINDOW_WIDTH-text_width)/2, (WINDOW_HEIGHT-32)/2, 32, rl.WHITE)
	version: cstring = "Version: " + VERSION
	version_width := rl.MeasureText(version, 20)
	rl.DrawText(version, WINDOW_WIDTH-version_width-20, WINDOW_HEIGHT-30, 20, rl.WHITE)
	if rl.IsKeyPressed(rl.KeyboardKey.SPACE) || rl.IsKeyPressed(rl.KeyboardKey.ENTER) do game^.state = State.Playing
}
	

draw_when_playing :: proc(game: ^Game) {
	buf: [64]byte = ---
	score := fmt.bprintf(buf[:], "Score: %d", game^.score)
	score_cstring := strings.clone_to_cstring(score)
	rl.DrawText(score_cstring, 10, 10, 20, rl.WHITE)
	if rl.IsKeyPressed(rl.KeyboardKey.M) do game^.state = State.Start
	//if rl.IsKeyPressed(rl.KeyboardKey.O) do game^.state = State.GameOver
	got_shape_idx := rand.int_range(0, 24)	
	board := game^.board
	// falling
	// a new falling
	// game over
}

draw_when_game_over :: proc(game: ^Game)  {
	text: cstring = "Game Over"
	text_width := rl.MeasureText(text, 32)
	rl.DrawText(text, (WINDOW_WIDTH-text_width)/2, (WINDOW_HEIGHT-32)/2-50, 32, rl.WHITE)
	buf: [64]byte = ---
	score := fmt.bprintf(buf[:], "Got score: %d", game^.score)
	score_cstring := strings.clone_to_cstring(score)
	score_width := rl.MeasureText(score_cstring, 32)
	rl.DrawText(score_cstring, (WINDOW_WIDTH-score_width)/2, WINDOW_HEIGHT/2-10, 32, rl.WHITE)
	restart: cstring = "Press space/enter to restart"
	restart_width := rl.MeasureText(restart, 20)
	rl.DrawText(restart, (WINDOW_WIDTH-restart_width)/2, WINDOW_HEIGHT/2+40, 20, rl.WHITE)
	if rl.IsKeyPressed(rl.KeyboardKey.SPACE) || rl.IsKeyPressed(rl.KeyboardKey.ENTER) do game^.state = State.Playing
}

main :: proc()  {
	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Tetris")
	defer rl.CloseWindow()
	rl.SetTargetFPS(30)

	game: Game

	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)
		switch game.state {
		case State.Start:
			draw_when_start(&game)
		case State.Playing:
			draw_when_playing(&game)
		case State.GameOver:
			draw_when_game_over(&game)
		}	
		rl.EndDrawing()
	}
}
