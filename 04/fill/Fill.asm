// This file is part of www.nand2tetris.org
// and the book "The Elements of Computing Systems"
// by Nisan and Schocken, MIT Press.
// File name: projects/04/Fill.asm

// Runs an infinite loop that listens to the keyboard input.
// When a key is pressed (any key), the program blackens the screen,
// i.e. writes "black" in every pixel;
// the screen should remain fully black as long as the key is pressed. 
// When no key is pressed, the program clears the screen, i.e. writes
// "white" in every pixel;
// the screen should remain fully clear as long as no key is pressed.

// Put your code here.
	


(MAIN_LOOP)

	
// if (KBD != 0)
//   goto FILL_BLACK
@KBD
D=M
@FILL_BLACK
D;JNE

// --------------------------------------------------------------------------------
(FILL_WHITE)

// i = 8192
@8192
D=A
@i
M=D

// p = SCREEN
@SCREEN
D=A
@p
M=D

(WHITE_LOOP_START)
// if (i <= 0)
//   goto WHITE_LOOP_END
@i
D=M
@WHITE_LOOP_END
D;JLE

// *p = 0
@p
A=M
M=0

// p++
@p
M=M+1

// i--
@i
M=M-1

@WHITE_LOOP_START
0;JMP

(WHITE_LOOP_END)
@MAIN_LOOP
0;JMP

// --------------------------------------------------------------------------------
(FILL_BLACK)

// i = 8192
@8192
D=A
@i
M=D

// p = SCREEN
@SCREEN
D=A
@p
M=D


(BLACK_LOOP_START)
// if (i <= 0)
//   goto WHITE_LOOP_END
@i
D=M
@BLACK_LOOP_END
D;JLE

// *p = -1
@p
A=M
M=-1

// p++
@p
M=M+1

// i--
@i
M=M-1


@BLACK_LOOP_START
0;JMP

(BLACK_LOOP_END)

@MAIN_LOOP
0;JMP

        
