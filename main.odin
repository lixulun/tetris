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
	falling_shape_idx: u8,
	falling_x: u8,
	falling_y: u8,
	last_time: f64,
}

// 7 basic shapes multiplied by 4 directions
// | oooo | ooo | oo | ooo | ooo |  oo | oo  |
// |      |   o | oo |  o  | o   | oo  |  oo |
SHAPES :: [28]Shape {
	// oooo
	Shape{1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0},
	Shape{1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0},
	Shape{1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0},
	Shape{1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0},
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
	// oo
	//  oo
	Shape{1,1,0,0,0,1,1,0,0,0,0,0,0,0,0,0},
	Shape{0,1,0,0,1,1,0,0,1,0,0,0,0,0,0,0},
	Shape{1,1,0,0,0,1,1,0,0,0,0,0,0,0,0,0},
	Shape{0,1,0,0,1,1,0,0,1,0,0,0,0,0,0,0},

}

rotate :: proc(shape_idx: u8) -> (next_idx: u8) {
	switch shape_idx {
	case 0..<4: next_idx = (shape_idx+1)%4
	case 4..<8: next_idx = (shape_idx+1)%4 + 4
	case 8..<12: next_idx = (shape_idx+1)%4 + 8
	case 12..<16: next_idx = (shape_idx+1)%4 + 12
	case 16..<20: next_idx = (shape_idx+1)%4 + 16
	case 20..<24: next_idx = (shape_idx+1)%4 + 20
	case 24..<28: next_idx = (shape_idx+1)%4 + 24
	}
	return
}

render_shape :: proc(board: ^Board, shape_idx, x, y: u8 ) {
	if x < 0 || x >= CELLS_PER_ROW do return
	if y < 0 || y >= CELLS_PER_COL do return
	assert(shape_idx >= 0 && shape_idx < 28)
	shapes := SHAPES
	for xi := 0; xi < CELLS_PER_ROW; xi+=1 {
		for yi := 0; yi < CELLS_PER_COL; yi+=1 {
			if xi >= int(x) && yi >= int(y) && xi < int(x)+4 && yi < int(y)+4 {
				sx := xi - int(x)
				sy := yi - int(y)
				shape := shapes[shape_idx]
				v := shape[sy * 4 + sx]
				if v > 0 {
					board^[yi * CELLS_PER_ROW + xi] = 1
				}
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
	render_shape(board, 0, 20, 30)	
	render_shape(board, 4, 3, 4)	
	render_shape(board, 8, 7, 10)	
	render_shape(board, 12, 12, 5)	
	render_shape(board, 16, 15, 15)	
	render_shape(board, 23, 13, 20)	
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
	if rl.IsKeyPressed(rl.KeyboardKey.SPACE) || rl.IsKeyPressed(rl.KeyboardKey.ENTER) {
		board: Board
		game^.board = board
	       	game^.state = State.Playing
	}
}

reach_edge :: proc(board: ^Board, shape_idx, x, y: u8) -> bool {
	new_board := board^
	render_shape(&new_board, shape_idx, x, y)
	board_v :: proc(board: ^Board) -> int {
		total := 0
		for v in board^ {
			total += int(v)
		}	
		return total
	}
	if board_v(&new_board) - board_v(board) < 4 {
		return true	
	}
	return false
}


turn_left :: proc(game: ^Game) {
	new_x := game^.falling_x-1
	if new_x < 0 do return
	if !reach_edge(&game^.board, game^.falling_shape_idx, new_x, game^.falling_y) do game^.falling_x = new_x
	
}

turn_right :: proc(game: ^Game) {
	new_x := game^.falling_x+1
	if new_x >= CELLS_PER_ROW do return
	if !reach_edge(&game^.board, game^.falling_shape_idx, new_x, game^.falling_y) do game^.falling_x = new_x
}

fall :: proc(game: ^Game) {
	new_y := game^.falling_y+1
	if new_y >= CELLS_PER_COL do return
	if !reach_edge(&game^.board, game^.falling_shape_idx, game^.falling_x, new_y) do game^.falling_y = new_y
}

eliminate :: proc(board: ^Board) {
	last_i := 0
	for i:=0; i<=len(board); i+=CELLS_PER_ROW {
		interval := 0
		for j:=0; j<CELLS_PER_ROW; j+=1 {
			interval += int(board^[j+last_i])
		}
		if interval == int(CELLS_PER_ROW) {
			for p:=i-1; p>0; p-=CELLS_PER_ROW {
				for s:=p; s>=CELLS_PER_ROW; s-=1 {
					board[s] = board[s-CELLS_PER_ROW]
				}
				for s:=0; s<CELLS_PER_ROW; s+=1 {
					board[s] = 0	
				}
				board^[p] = board^[p-1]	
			}	
			break
		}
		last_i = i	
	}
}


draw_when_playing :: proc(game: ^Game) {
	buf: [32]byte = ---
	score := fmt.bprintf(buf[:], "Score: %d", game^.score)
	score_cstring := strings.clone_to_cstring(score)
	rl.DrawText(score_cstring, 10, 10, 20, rl.WHITE)
	if rl.IsKeyPressed(rl.KeyboardKey.UP) {
		new_shape_idx := rotate(game^.falling_shape_idx)
		if !reach_edge(&game^.board, new_shape_idx, game^.falling_x, game^.falling_y) {
			game^.falling_shape_idx = new_shape_idx
		}
		
	} else if rl.IsKeyDown(rl.KeyboardKey.LEFT) {
		turn_left(game)

	} else if rl.IsKeyDown(rl.KeyboardKey.RIGHT) {
		turn_right(game)
	}

	new_board := game^.board
	if game^.falling_x!=0 || game^.falling_y!=0 {
		render_shape(&new_board, game^.falling_shape_idx, game^.falling_x, game^.falling_y)
	}
	speed_rate := 0.5
	if rl.IsKeyDown(rl.KeyboardKey.DOWN) {
		speed_rate /= 8.0
	}
	if rl.GetTime() - game^.last_time > speed_rate {
		if game^.falling_x==0 && game^.falling_y==0 {
			game^.board = new_board
			got_shape_idx := u8(rand.int_range(0, 28))	
			game^.falling_shape_idx = got_shape_idx
			game^.falling_x = CELLS_PER_ROW / 2
			game^.falling_y = 0
		} else {
			if reach_edge(&game^.board, game^.falling_shape_idx, game^.falling_x, game^.falling_y+1) {
				game^.score += 4
				game^.board = new_board
				eliminate(&game^.board) 
				got_shape_idx := u8(rand.int_range(0, 28))	
				game^.falling_shape_idx = got_shape_idx
				game^.falling_x = CELLS_PER_ROW / 2
				game^.falling_y = 0
				if reach_edge(&game^.board, game^.falling_shape_idx, game^.falling_x, game^.falling_y+1) {
					game^.state = State.GameOver
				}

			} else {
				game^.falling_y += 1
			}
		}
		game^.last_time = rl.GetTime()	
	}
	draw_board(&new_board)
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
	if rl.IsKeyPressed(rl.KeyboardKey.SPACE) || rl.IsKeyPressed(rl.KeyboardKey.ENTER) { 
		game^ = Game {
			state = State.Playing,
			last_time = rl.GetTime() - 2,
		}
       	}
}

main :: proc()  {
	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Tetris")
	defer rl.CloseWindow()
	rl.SetTargetFPS(15)

	game := Game {
		last_time = rl.GetTime() - 2,
	}

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
