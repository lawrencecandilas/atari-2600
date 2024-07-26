;This is an implementation of Tic Tac Toe for the Atari 2600.

;== History ==
;
;  Most of this stems from initial code written in 2004 when I first found
;that PDF of the Stella Programmer's Manual.  I then sought to fulfill a
;long-time childhood dream - making an Atari 2600 game.
;
;  I published that code in the AtariAge forum under a different moniker.  As
;the game code doesn't occupy much space, I decided to be silly and include a
;"Set Up" screen (something most Atari games didn't have) which allowed
;setting the screen colors, selecting the CPU strategy routine, and turning
;the sound on and off.
;
;  I've streamlined and taken all that out.  This is just the game - well, it
;does have a BRK handler and a ROM checksum routine. :P
;
;
;== Development ==
;
;  In 2004 I was using DASM, and assembling with this command:
;
;  dasm ttt.asm -f3 -ottt.bin
;
;  and then using z26 to test.  Not too bad.
;
;  But...
;
;  Recently, while finding out Javascript/WASM is now powerful enough that
;there are things like Emscripten, I ran into 8bitworkshop
;(https://8bitworkshop.com/) and saw that it ncluded a rather nice IDE for
;the 2600, including the Javatari emulator.
;
;  I was *especially pleased* to see that I could paste my old code right in
;the IDE window and immediately see the game running.
;
;So I decided to clean it up and finish it.

;* Released under GPLv3
;* Not yet tested on a real Atari 2600.  Javatari runs it fine.

		processor 6502

;VCS.H: 2600 TIA/PIA registers
VSYNC  = $00
VBLANK = $01
WSYNC  = $02
RSYNC  = $03
NUSIZ0 = $04
NUSIZ1 = $05
COLUP0 = $06
COLUP1 = $07
COLUPF = $08
COLUBK = $09
CTRLPF = $0A
REFP0  = $0B
REFP1  = $0C
PF0    = $0D
PF1    = $0E
PF2    = $0F
RESP0  = $10
POSH2  = $11
RESP1  = $11
RESM0  = $12
RESM1  = $13
RESBL  = $14
AUDC0  = $15
AUDC1  = $16
AUDF0  = $17
AUDF1  = $18
AUDV0  = $19
AUDV1  = $1A
GRP0   = $1B
GRP1   = $1C
ENAM0  = $1D
ENAM1  = $1E
ENABL  = $1F
HMP0   = $20
HMP1   = $21
HMM0   = $22
HMM1   = $23
HMBL   = $24
VDELP0 = $25
VDELP1 = $26
VDELBL = $27
RESMP0 = $28
RESMP1 = $29
HMOVE  = $2A
HMCLR  = $2B
CXCLR  = $2C

CXM0P  = $30
CXM1P  = $31
CXP0FB = $32
CXP1FB = $33
CXM0FB = $34
CXM1FB = $35
CXBLPF = $36
CXPPMM = $37
INPT0  = $38
INPT1  = $39
INPT2  = $3A
INPT3  = $3B
INPT4  = $3C
INPT5  = $3D

SWCHA  = $280
SWACNT = $281
SWCHB  = $282
SWBCNT = $283
INTIM  = $284
TIMINT = $285
TIM1T  = $294
TIM8T  = $295
TIM64T = $296
T1024T = $297
TIM1I  = $29c
TIM8I  = $29d
TIM64I = $29e
T1024I = $29f

;Program variables
SWCHB1  = $80				;Buffer for console switches state

BGC	= $81				;SCREENH screen drawing routine uses
FGC	= $82				;these to set the colors.  COLORS will
P0C	= $83				;set these per frame.  ATTRAC below
P1C	= $84				;will be added to them, to support
					;"attract mode" color cycling.

					;Graphics data pointers
					;
					;Basically, the screen is a 3x15 grid
					;of 8x7 graphics.
					;
					;The board is in the middle and the
					;top and bottom row are for score and
					;status.
					;
					;
					;  00 01 02	score/game number
					;============
					;
					;    |  |
					;  03|04|05	board row 0
					; ---+--+---
					;  06|07|08	board row 1
					; ---+--+---
					;  09|10|11	board row 2
					;    |  |
					;
					;  12 13 14	status area

					;The status area was used to show the
					;number of ties in previous versions
					;but this was removed.  It's only
					;used now to display the version
					;graphic upon start up.

					;Graphic data is fetched starting at
					;the address in each GPTRxx.

GPTR00	= $86				;top score area
GPTR00H	= $87
GPTR01	= $88
GPTR01H	= $89
GPTR02	= $8A
GPTR02H	= $8B

GPTR10	= $8C				;first row in grid
GPTR10H	= $8D
GPTR11	= $8E
GPTR11H	= $8F
GPTR12	= $90
GPTR12H	= $91

GPTR20	= $92				;second row in grid
GPTR20H	= $93
GPTR21	= $94
GPTR21H	= $95
GPTR22	= $96
GPTR22H	= $97

GPTR30	= $98				;third row in grid
GPTR30H	= $99
GPTR31	= $9A
GPTR31H	= $9B
GPTR32	= $9C
GPTR32H	= $9D

GPTR40	= $9E				;bottom score area
GPTR40H	= $9F
GPTR41	= $A0
GPTR41H	= $A1
GPTR42	= $A2
GPTR42H	= $A3

TEMP	= $A4				;temporary variable
TEMP1	= $A4				;temporary variable

DOUBLE	= $A5				;Used in screen drawing routine

PTRPTR  = $A6				;This is used to change any of the
PTRPTRH	= $A7				;graphics pointers.
					;(it points to one of the GPTR's)
					;Also used when computing ROM
					;checksum.

LSWCHB1 = $A8				;Previous console switch state.
					;So we know if the switch state has
					;changed since last frame.

					;Current game mode and number
					;
					;The MODE represents what the game is
					;doing overall - it will either be
					;in "Game Select" (GAMSEL) mode or
					;actually playing a game (PLYGAM).
					;Additional modes are for delay
					;purposes and a "service" mode to
					;display errors or the ROM checksum if
					;requested.
					;
MODE	= $A9				;current game mode
CURGAM	= $AA				;current game number

CHKFLG	= $AB

TEMP2	= $AC				;temporary

XFLAG	= $AD				;Who's X? (0 or 1)

TEMP3	= $AE				;temporary
TEMP4	= $AF				;temporary

PHASE	= $B0				;Phase of mode
					;
					;Because SCREENH has to redraw the
					;screen on a strict schedule, we split
					;up the things that each MODE does
					;into PHASES that fit into vertical
					;blank time for sure.

CHKPTR	= $B1				;16-bit pointer for ROMCHECK

SCR1	= $B1				;Score player 1
SCR2	= $B2				;Score player 2

GRID	= $B4				;9 bytes to keep track of the
					;tic-tac-toe grid.

CP	= $BD				;Current player (0 or 1)

CURSOR	= $BE				;Position of cursor at GRID

STICK	= $BF				;Joystick direction

BOUNCE	= $C0				;For a short delay between successive
					;cursor moves

UNDER	= $C1				;Character beneath cursor (for MOVE
					;routine)
BLINK	= $C2				;Cursor blink timing variable

TOPL	= $C3				;GPTR's for X and O identifiers
TOPLH	= $C4				;beneath top score area.
TOPR	= $C5
TOPRH	= $C6

NMOV	= $C7				

CPUMOD	= $C8				;this is what the CPU is doing to
					;figure out what move it should do
					;- 0 = WHOISWHO,
					;  1 = FINDWIN, 
					;  2 = FINDBLOCK,
					;  3 = find a open square)

IAM	= $C9				;This is who the CPU is.
OPPIS	= $CA				;This is who the CPU's opponent is.

RAND	= $CB				;random number, generated by an LFSR.

BOUNCE2 = $CC				;Another delay counter.

WINNER	= $CD				;Who the winner is (0 or 1)

WPSPTR  = $CE
WPSTACK = $CF

SNDPTR  = $E0				;Current sound data address 
SNDTIM	= $E2				;Timer of current sound data

CRASH   = $E3				;used to prevent infinite loops

ATTRAC	= $E4				;"Attract mode" color offset.
					;;Many Atari games will cycle colors
					;when the game is idle.  This is to
					;prevent TV burn in.  This variable is
					;added to the display colors by
					;SCREENH.  Idle modes can just
					;periodically INC this variable to
					;cycle colors.

INTLEV	= $E5				;How smart the CPU is - e.g. a random
					;number must be UNDER this value,
					;otherwise the CPU simply selects a
					;random open square.
                                        
CHKSUM  = $E6				;Holds ROM checksum when computed.

ATIMER	= $E7				;Times color cycles in idle modes

		org $F000
;----------------------------------------------------------------------------------------------------
CONFIG
					;This area of ROM is dedicated to
					;configuration values.  Values here
					;are not counted when computing the
					;ROM checksum.

MAXWIN		.byte 2		;This many wins ends game.  Anything
					;more than 10 is not supported by the
					;graphics currently.

GOOD		.byte 174		;ROM checksum should match this.

CFGBGC		.byte 7			;Colors (for color and B&W modes).
CFGBCGCOL	.byte 44
CFGFGC		.byte 3
CFGFGCCOL	.byte 54
CFGP0C		.byte 15
CFGP0CCOL	.byte 64
CFGP1C		.byte 4
CFGP1CCOL	.byte 74

		.byte 00		;Future use.
                .byte 00
                .byte 00
                .byte 00
                .byte 00
                .byte 00
                
;----------------------------------------------------------------------------------------------------
		org $F010
RESET		;Initialization.

		SEI  			;interrupt mask on (no real point to
					; this but why not).
		CLD  			;decimal mode off.
		LDX #$FF		;reset stack.
		TXS
		LDA #0			;clear TIA/RAM.
ZPCLEAR 	STA 0,X
		DEX
		BNE ZPCLEAR   

		STA SWACNT		;set all lines of Port A for input 
					; (to read controller).
		STA INPT4		;set these two lines to read joystick
		STA INPT5		; buttons (a.k.a "triggers").

		LDA #1
		STA CTRLPF		;reflected PF, SCORE off, normal
					;priority

		;Set TIA player object size
		LDA #4			;The basic concept of the display 
		STA NUSIZ0		;routine is to stagger P0 and P1 
		LDA #0			;graphic objects, giving us enough time 
		STA NUSIZ1		;between the generated player graphic
					;display to change them inbetween, so
					;we can get 3 independent objects per
					;line.
					;
					;TIA line>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
					;	
					;	P0	P1	P0
					;      xxxx    xxxx    xxxx
					;>-->-->-->-->-->-->.
					;		    |
					;		update P0 content
					;		   here

                STA AUDV0		;kill all audio
		STA AUDC0
		STA AUDF0

		STA AUDV1		;audio channel 1 is used only for a keyclick when the player
		LDA #2			;moves, so let's set channel 1 up for that.
		STA AUDF1
		LDA #9
		STA AUDC1
		
		LDA #0	
		STA MODE		;mode 0 (Select Game)
		STA CURGAM		;game 0 (P1 vs. CPU)

		LDA INTIM		;INTIM has random value on power-up
                AND #%00001111		;We'll use lower 4 bits of that to pick one of 16 RNG seeds.
                TAX			;See https://codebase64.org/doku.php?id=base:small_fast_8-bit_prng
                LDA RNDSEEDS,X
		STA RAND

		;Move players into proper centered position.
		;I know this is a crude way to do it but it works!
		STA WSYNC
		NOP
		NOP
		NOP
		NOP
		NOP
		NOP
		NOP
		NOP
		NOP
		NOP
		NOP
		NOP
		NOP
		NOP
		NOP
		NOP
		STA RESP0
		LDA #224		;do some fine adjustment to center
		STA HMP0		;it perfectly.
		STA WSYNC

		NOP
		NOP
		NOP
		NOP
		NOP
		NOP
		NOP
		NOP
		NOP
		NOP
		NOP
		NOP
		NOP
		NOP
		NOP
		NOP
		NOP
		NOP
		NOP
		NOP
		NOP
		STA RESP1
		LDA #216		;do some fine adjustment on P1 too.
		STA HMP1
		STA WSYNC
		STA HMOVE
		STA WSYNC

		;If both SELECT and START are held down on power up, go to the
		;ROM check service mode screen.
                LDA SWCHB
                AND #%00000011
                BNE SETUP2              
                JMP ROMCHECK                                
                
SETUP2
		LDA #<TITLE		;Set up my dinky little title screen,
		STA TEMP3		;and initialize all GPTR's as well.
		LDA #>TITLE		
		STA TEMP4		
		JSR SETSCR		;SETSCR will initalize them all to the
					;title screen.

		LDA #<TOPX		;Initialize top graphics pointers...
		STA TOPL
		LDA #>TOPX
		STA TOPLH
		LDA #<TOPO
		STA TOPR
		LDA #>TOPO
		STA TOPRH                            
                
                ;Fall into main loop
;----------------------------------------------------------------------------------------------------
MAIN		;Main loop

		JSR VBLANKH		;Do vertical blank + check console switches
		JSR CONSOLEH		
		JSR GameCalc      	;Do calculations during VBlank
                JSR SNDDRV		;Process sound
		JSR SCREENH		;Draw the screen
		JSR OVERSCANH      	;Do more calculations during overscan	
                JMP MAIN                     
		
;-----------------------------------------------------------------------------
BRKH		
		;BRKs shouldn't happen, but if they do, we'll go into serivce
		;mode.
                ;But to be 100% complete and compilant we need to make sure
		; this is a BRK and not an NMI for some reason.
                ;
                ;That involves getting the pushed .P value off of the stack
		; and looking at bit D4.
                ;We have to save other registers first because nothing has
		; been saved on the stack other than the PC and .P.
                PHA
                TXA
                PHA
                TSX
                INX
                INX
                LDA $0100,X
                AND #%00010000
                BNE REALBRK
	
        	;On 6502, BRK and NMI use the same hardware vector.

                ;Atari 2600 uses a 6502 derivate (known as the 6507) that
		; doesn't even have an NMI should be impossible.
                ;Included just for the heck of it, or in case your emulator is
		; inaccurate.
        	PLA
                TAX
                PLA
                RTI
REALBRK           
		;Welp, we got one.  Someone is probably trying to "fry" the
		;cartridge or game.                                 
        	LDX #$FF		;Reset stack
                TXS
                LDA #1			;Say code 1,
                LDX #CE			;say symbol "E" for Error,
                JSR SVCENT              ;setup service mode,
                JMP MAIN		;and that's it.

;-----------------------------------------------------------------------------
JUSTRTI
		;    IRQs don't exist on this platform, but here's a null
		;    handler anyway
                ;
                RTI

;-----------------------------------------------------------------------------
VBLANKH		;*** VERTICAL BLANK HANDLER
		LDA #2
		STA WSYNC  
		STA WSYNC
		STA WSYNC

		STA VSYNC 		;Begin vertical sync

VSL1		STA WSYNC 		;1st VSYNC line
VSL2		STA WSYNC 		;2nd VSYNC line

		LDA #44			;Countdown until we need to start 
		STA TIM64T		;drawing picture

VSL3		STA WSYNC 		;3rd VSYNC line
		STA VSYNC 		;(0)

		RTS
;-----------------------------------------------------------------------------
CONSOLEH	;*** CONSOLE SWITCH HANDLER
		;    This routine checks for the SELECT and START switches and
		;    changes game mode
		;    accordingly.

		LDA MODE		;Ignore switches in service mode
                CMP #2
                BNE NOTSVC
                RTS
NOTSVC		;Not in service mode at this point

		LDA SWCHB1		;Save last read switch state so we can
		STA LSWCHB1		; tell if the switch state changed

		LDA SWCHB		;Get current switch state
		STA SWCHB1		;Save it so other routines can read it
					; later.

		CMP LSWCHB1		;Any change in switch state?
		BEQ CSX			;Nope, that's all we can do here.

		LDA SWCHB1		;Well, there was a switch change,
					; let's find out which switch.
		AND #%00000010		;Was it SELECT?
		BNE CSX			;Nope, now check START

CSELECT		LDA #0			;Yeah, it was SELECT.
		STA MODE		;Drop to Select Game mode

		STA AUDV0		;Kill any audio.
		STA AUDV1

		JSR CYCLE		;Shift colors to provide further visual
					; feedback of switch press.
					;Many old Atari games do this.
                LDA #$FF                ;... and reset our timer too.
                STA ATIMER

		INC CURGAM		;Increase current game by 1
		LDA CURGAM
		CMP #4			;Highest game variation is 3 (0 to 3).
		BNE CSX	
		
		LDA #0
		STA CURGAM		;Go back to game 0 if we were at game 3

CSX	     	LDA SWCHB1		;Checking for switch change...
		AND #%00000001		;Was it START?
		BNE CSXX		;No, so exit

					;If START was pressed...
		LDA #1			; drop to Play Game mode (MODE=1)
		STA MODE	
		LDA #0			; phase 0, setup new game.
		STA PHASE
CSX1					;clear "attract mode" color offset.
		STA ATTRAC
                
CSXX		RTS			;bye.

;------------------------------------------------------------------------------
GameCalc 	;Game logic

		;First, let's see what MODE the game is in...
					;Available MODEs so far:
					;  0 - GAMSEL, Game Select mode
					;  1 - PLYGAM, Game Play mode
					;  3 - DELAY, for delays
					;255 - SERVIC, Service mode

		LDY MODE		;What phase are we in?
		LDA MODTABL,Y		;Let's get it's address ...
		STA TEMP3
		LDA MODTABH,Y
		STA TEMP4
		JMP (TEMP3)		;...and execute the mode's handler

		;**************************************************************
		;**************************************************************
		;*** MODE=0: Select Game 

GAMSEL		JSR NEXTRAND		;Cycle RNG.

		DEC ATIMER		;This is an idle mode, so we'll flip
                BNE NOCYCLE1		; colors.
                JSR CYCLE
NOCYCLE1		
		LDY CURGAM		;Sets top GPTR's to display what the
		LDA GL1,Y		; currently selected game is.
		STA TEMP
		LDA GL2,Y
		STA TEMP2

		LDY #0
		LDX TEMP
		JSR SETCHAR

		LDY #1
		LDX #CVS
		JSR SETCHAR

		LDY #2
		LDX TEMP2
		JSR SETCHAR

		LDA SWCHB1		;Checks P0 difficulty and sets bottom
		AND #%01000000		; GPTR's to display...
		BNE D1ON		;who's X and who's O (as well as
					; setting XFLAG).
		LDA #0
		STA XFLAG
		JMP GSCONT
D1ON		
		LDA #1
		STA XFLAG
GSCONT
		JSR SETTOP

GAMSELX		RTS

		;**************************************************************
		;**************************************************************
		;*** MODE=1: Play Game
					;Okay, it is necessary to divide
					;processing tasks for the Play Game
					;mode into separate phases, since a
					;task cannot run continuously as long
					;as it wants, because we have to update
					;the TIA on schedule.  

					;Therefore, we need to keep track of
					;what task (phase) we are working on so
					;we can continue processing it between
					;TIA updates.

					;When a task is completed and wants to
					;switch to another task it changes the
					;PHASE variable to the appropriate
					;handler.

PLYGAM		LDY PHASE		;So ...what phase are we in?
		LDA VECTABL,Y		;Let's get it's address ...
		STA TEMP3
		LDA VECTABH,Y
		STA TEMP4
		JMP (TEMP3)		;...and execute the phase's handler

					;Available phases so far:
					;0 - SETUP, sets up for a new game
					;1 - MOVE, processes non-CPU move
					;2 - CHECK, performs slight delay
					;     between moves and 
					;     checks for score/end conditions
					;3 - CPUMOV, processes CPU moves
					;4 - OVER, game over mode
					;5 - MATCHWIN, announce winner of a
					;     match

		;**************************************************************
		;*** MODE=1, PHASE=0: Setup a New Game (including resetting
		; scores)
SETUP		LDA #0
		STA SCR1		
		STA SCR2
	        
		;**************************************************************
SETUP1		;*** Setup a New Match (i.e., leave scores alone)
		JSR NEXTRAND		;Get a random number, and ...
                STA INTLEV		; make it the CPU's intelligence.
        	
        	LDA XFLAG		;X goes first
                STA CP                  ;Let's make X the current player
		
		JSR SETTOP		;Indicate who's X and O on display

		LDA #CSPC		;Clear grid array.
		LDY #8			
SETUPL1		STA GRID,Y
		DEY
		BPL SETUPL1

		LDA #0
		STA NMOV
		STA CPUMOD

		LDA #<NEWGAM		;Set up the board.
		STA TEMP3
		LDA #>NEWGAM
		STA TEMP4
		JSR SETSCR

		LDX SCR1		;Updates the score display at top.
		CPX #10			;If the score is 10, then we have to 
		BNE SET1		; use the "10" character.
		LDX #CTEN
SET1		LDY #0
		JSR SETCHAR
		LDX SCR2
		CPX #10
		BNE SET2
		LDX #CTEN
SET2		LDY #2
		JSR SETCHAR
                
                	
		JSR INTCRSR		;Initialize cursor

		LDA #32
		STA BOUNCE2
		LDA #2
		STA PHASE		;Setup done, so do a delay and then go
SETUPX		RTS			; into CHECK (see DELAY).

		;**************************************************************
		;*** MODE=1, PHASE=1: Get And Execute Move For A Non-CPU Player

MOVE		JSR NEXTRAND		;cycle RNG

		;Handle cursor blinking
		LDY CURSOR		;Let's either place the cursor 
		INY			; character at the cursor position, or
		INY			; the character beneath it, depending
		INY			; on the sign bit of the BLINK counter.
		LDA BLINK
		BMI BLNCHK1
                LDX #CSEL               ;CSEL=19, the cursor character.
		JMP BLNCHK2
BLNCHK1		LDX UNDER
BLNCHK2		JSR SETCHAR

		DEC BLINK		;Update blink counter.
		LDA BLINK		;Let's get it...
		BNE BLNCHK3

					;This blinks the top graphic to show
					; whose turn it is.
		LDA CP
		CLC
		ASL
		ADC #<TOPL
		STA TEMP3		
		LDA #0
		STA TEMP4
		LDY #0
		LDA #<CHARSPC
		STA (TEMP3),Y
		LDA #>CHARSPC
		INY
		STA (TEMP3),Y

BLNCHK3
		CMP #$EF		;And see if it needs to be flipped 
					; over...
		BNE TRIGCK		; if it doesn't, continue...
		JSR RESBLNK		; otherwise reset blink.
					
TRIGCK		;Check for pressed joystick buttons
		LDX CP			;Which player?
		BNE P2TRIG		;Player 1?
		LDA INPT4		;Nope, read second joystick button.
		JMP P2TRIG1		
P2TRIG		LDA INPT5		;Otherwise read first joystick button.
P2TRIG1		BMI JOYCHK		;Button pressed?
		JMP TRIGGER

JOYCHK		;Check for joystick movement
		LDA SWCHA		;Check for joystick movement.
		CMP #255		;Any?
		BNE MOVEC		;If so, process it.
	
		LDA #1
		STA BOUNCE		;If not, reset bounce ...
		RTS			; and get out.
MOVEC
		STA TEMP		;Store read joysticks whilst we check 
					; bounce.

		;- Bounce check
                LDA BOUNCE              ;This is so the cursor doesn't move
                BEQ MOVEC2		; too fast.
		DEC BOUNCE
		RTS 
MOVEC2
		;Process cursor move request
		LDY #5			;Keyclick
		JSR MKSOUND

		LDA TEMP		;Get stored joystick read.

		LDY CURSOR		;Restore character at cursor position.
		INY
		INY
		INY
		LDX UNDER
		JSR SETCHAR

		LDX CP			;Which player is this for?
		BNE P2			;Is it player 1?
		CLC			;It is, so shift upper 4 bits into
		LSR			; lower 4 bits.
		LSR
		LSR
		LSR
		STA STICK
		JMP PX
P2		AND #%00001111		;If it's player 2, mask off upper 4
PX		STA STICK		; bits.
	
		LDY CURSOR		;Get cursor position because we're
					; gonna change it.
		LDX STICK		;OK, let's find out what direction the
		TXA			; joystick was pressed ...
		AND #%00001000
		BEQ MRIGHT
		TXA
		AND #%00000100
		BEQ MLEFT
		TXA
		AND #%00000010
		BEQ MDOWN
		TXA
		AND #%00000001
		BEQ MUP
		JMP MOVEX
MRIGHT					;And move the cursor accordingly, 
					; making sure the position stays
		CPY #8			; between 0-8.
		BEQ MOVEX
		INY	
		JMP MOVEX2
MLEFT
		CPY #0
		BEQ MOVEX
		DEY
		JMP MOVEX2
MDOWN
		CPY #6
		BCS MOVEX
		INY
		INY
		INY
		JMP MOVEX2
MUP
		CPY #3
		BCC MOVEX
		DEY
		DEY
		DEY		

MOVEX2		STY CURSOR
		LDA GRID,Y
		STA UNDER
	
MOVEX		
		LDA #10			;Reset bounce.
		STA BOUNCE
		JSR RESBLNK
                RTS

		;Handle when joystick button is pressed.
TRIGGER		
		LDY CURSOR
		LDA GRID,Y		;Get character at cursor position.
		CMP #CSPC		;Is it a space (empty)?
                BEQ MOVEHERE		;All right then let's take it.
                
                LDY #0			;Otherwise play an error sound.
                JSR MKSOUND
                JMP MOVEX

MOVEHERE	;When the CPU decides what square to move at (the square will
		; be in the CURSOR variable), entering here will place the X
		; or O on the board.

		STY TEMP
		PHA		

		PLA
		LDY TEMP

		LDA #0			;This will determine whether to use
		STA CPUMOD		; the X or O...
		CLC			; ... epending on who is X and what
		EOR CP			; the current player is.
		EOR XFLAG
		AND #%00000001
		CLC
                                
		ADC #CXCHAR
				
		STA GRID,Y
		TAX

		INY
		INY
		INY
		JSR SETCHAR

		JSR INTCRSR		;Reinitialize cursor for next player.

		LDY CP
                INY
                JSR MKSOUND 

		INC CP	
		LDA CP
		AND #$00000001
		STA CP			;Change current player.

		INC NMOV		;Increment total number of moves for
					; this match.

		LDA #30
		STA BOUNCE2
		LDA #2
		STA PHASE		;End MOVE, do a small delay and then
					; CHECK.
		JMP MOVEX

		;**************************************************************
		;*** MODE=1, PHASE=2: Check for Score and End-of-game 
		;    Conditions.
		;*** Also Execute Between-Move Delay.

CHECK		;Allright, let's get inter-move delays out of the way.
		DEC BOUNCE2
		BEQ WINCHK
		RTS

WINCHK          ;OK, let's check for a win.

		LDA #0			;Initalize our winner position stack
		STA WPSPTR		; pointer.

		LDX #7
WINCHK1
		LDY WINTAB1,X		;Get first position of row/column/
					; diagonal we're checking...
		LDA GRID,Y		;Get what's in the square ...
		CMP #CSPC		; if it's a space ...
		BEQ WINCHKL		; then it can't be a win and we can
					; forget it ...
		STA TEMP		;Otherwise, save it ...
		LDY WINTAB2,X		;Get middle position of row/column/
					; diagonal we're checking...
		LDA GRID,Y		;Get what's in that square...
		CMP TEMP		;Let's compare the first two squares...
		BNE WINCHKL		;Not the same then it's not a win...
		LDY WINTAB3,X		;Get third position of row/column/
					; diagonal we're checking...
		LDA GRID,Y		;and get what's in that square...
		CMP TEMP		;Is it the same as the other two?
		BNE WINCHKL		;Nope, no winner in this row/column/
					; diagonal.

POINT		;Found a three-in-a-row.
		;(There might be two so we do a stack thing here.)
		;Add positions to our win position stack (WPSTACK).
		LDY WPSPTR
		LDA WINTAB1,X
		STA WPSTACK,Y
		INY
		LDA WINTAB2,X
		STA WPSTACK,Y
		INY
		LDA WINTAB3,X
		STA WPSTACK,Y
		INY
		STY WPSPTR

WINCHKL		DEX
		BPL WINCHK1	

		;We've checked all possible three-in-a-rows.
		;Did we find any?  WPSPTR won't be 0 if we did.
		LDA WPSPTR
		BEQ CHECK0

		;Winner detected!	
                ;Make noise
                LDY #3
                JSR MKSOUND
                
                ;Ok ... who won?
                LDY WPSTACK        	;Let's look at one of the pieces we'll           
                LDA GRID,Y		; be blinking ...
                STA WINNER              ;identify winner for WINFLASH routine
					; in MATCHWIN.
               
		CLC
		ADC XFLAG
		AND #%00000001		
		TAY			;.Y = 0 if player 1 won, 
					;     1 if player 2 won

		STY XFLAG		;Winner becomes X...

		LDA SCR1,Y		;Add one point to winners score.
		CLC			;How i wish 6502 had a INC address,Y
		ADC #1			; instruction...
		STA SCR1,Y		;
                
		LDA #128
		STA BOUNCE2
		LDA #5
                STA PHASE               ;done here, switch to MATCHWIN routine
					; next frame...
                RTS                     ;...after which MATCHWIN dumps us back
					; into CHECK.				

CHECK0		;ok, now, let's check if there's a win/draw on the match
		;(it's important to do this AFTER we check for 3 in a row!)
		LDA NMOV		;How many moves so far have there been
					; in this match?
		CMP #9			;Nine?
		BNE ENDCHK		;Nope, not a draw.
					;At this point, if 9 moves have gone
					; by, it's defintely a draw,
					;Because we already checked for
					; 3-in-a-row's.
					;So, if it is a draw...
		LDY #4			; make the draw noise.
                JSR MKSOUND             
		JSR SETUP1		; new board.
	
ENDCHK					;Check if game is over
		LDA SCR1		;Did player 1 get MAXWIN wins?
		CMP MAXWIN
		BNE DIDP2WIN
		JMP P1WIN		;...if so, player 1 won.
DIDP2WIN
		LDA SCR2		;Did player 2 get MAXWIN wins?
		CMP MAXWIN
		BNE NOWINYET
		JMP P2WIN		;...if so, player 2 won.

NOWINYET				;...otherwise we keep going.

					;Below uses CP and CURGAM to index into
					; PTABLE, which will tell us what phase
					; is needed to service the next player
					; (MOVE or CPUMOV).
		LDA CURGAM
		ASL
		CLC
		ADC CP
		TAY
		LDA PTABLE,Y
		STA PHASE
		RTS
		
P1WIN					;this declares player 1 the winner
		LDY #0
		JMP P1WC
P2WIN					;this declares player 2 the winner
		LDY #2
P1WC		LDX #CWIN
		JSR SETCHAR
ENDGAME
		JSR INTCRSR
		LDA #4			;And switch to game over mode next
		STA PHASE		; frame!
		JSR CYCLE		;This cycles the colors at this point
					;Some old Atari games cycle the colors
					; when the game ends so I did it to.
		LDA #$FF		;Prepare color cycle delay for OVER.
                STA ATIMER	
                LDY #6			;Ending sound.
                JSR MKSOUND
		RTS			;thank you for playing Tic-Tac-Toe!

		;**************************************************************
		;*** MODE=1, PHASE=4: Game Over Mode
		;Basically, do nothing until user decides to press GAME RESET
		; to start a new game.

OVER		DEC ATIMER
		BNE OVERX             
		JSR CYCLE
OVERX		RTS

		;**************************************************************
		;*** MODE=1, PHASE=5: Show Winner Of Match
MATCHWIN
		DEC BOUNCE2
		BEQ MWO
		LDA BOUNCE2
		AND #%00000010
		BEQ WINFLASH
		RTS
		
MWO		JSR SETUP1		;Make a new board
		LDA #2
		STA PHASE		;Go into CHECK, because CHECK will find
					; out whose turn it is.
		RTS

WINFLASH	
		LDA BOUNCE2
		AND #%00000100
		BEQ WINFOFF

WINFON		
		LDX WPSPTR
WINFONL		DEX
		BMI WINFONX
		LDY WPSTACK,X
                INY			;Add 3 because WPSTACK refers to grid 
                INY			; positions but SETCHAR wants screen
                INY			; positions (first 3 are score area).
		TXA
		LDX WINNER
		JSR SETCHAR
		TAX
		JMP WINFONL
WINFONX		RTS		

WINFOFF		
		LDX WPSPTR
WINFOFFL	DEX
		BMI WINFOFFX
		LDY WPSTACK,X
                INY
                INY
                INY
		TXA
		LDX #CSPC
		JSR SETCHAR
		TAX
		JMP WINFOFFL
WINFOFFX	RTS	
		
		;**************************************************************
		;*** MODE=1, PHASE=3: Get And Execute Move for a CPU Player
CPUMOV		
					;Hi, I'm your friendly neighboorhood
					; 6502 compatible CPU...                                                                                                                       
		LDA CPUMOD		;Like, um, what am I doing right now?

		BEQ WHOISWHO		;CPUMOD 0 = find out who is who
		CMP #1
                BEQ INTCHECK		;CPUMOD 1 = am I dumb and just picking
					; a random square?
                CMP #2
		BEQ FINDBLOCK		;CPUMOD 2 = try to find a blocking move
		CMP #3
		BEQ FINDWIN		;CPUMOD 3 = try to find a winning move
		JMP FINDOPEN		;Otherwise find any open square...

WHOISWHO	
		LDA #0			;okay, am I X or O...
		CLC
		EOR CP
		EOR XFLAG
		AND #%00000001
		CLC
		ADC #CXCHAR
		STA IAM			;IAM contains 10 if CPU is X, 
					;             11 if CPU is O - 
					; this corresponds to the characters in
					;GRID.
		CLC			;OK, that takes care of me, so the
					; other player must be the opposite...
		ADC #1
		AND #%00000001
		CLC
		ADC #CXCHAR
		STA OPPIS		;OPPIS will contain 10 is the opponent
					; is X, 11 if the opponent is O, again,
					; consistent with how it'si
					; represented in GRID.

		INC CPUMOD		;We know who is who now, so next task
					; at next frame please...                              
		RTS 		

INTCHECK	
		JSR NEXTRAND		;get a random number
                CMP INTLEV		;...if it's more than the CPU INT
                BCC FINDOPEN1		;...then we pick a random open square.
                INC CPUMOD		;otherwise next mode.
                RTS

FINDWIN
		LDX #23			;We are going to check through 24
					; combinations, where there are 2 of me
					; in a row, and the third open spot in 
					; the row would make a win.
FINDWIN1
		LDA WINTAB1,X		;Get first position of combo we're
					; checking...
		TAY
		LDA GRID,Y		;Get what's in the square...
		CMP IAM			;Is it me in the square?
		BNE FINDWINL		;No, next...
		LDA WINTAB2,X		;Get middle position of combo we're
					; checking...
		TAY
		LDA GRID,Y		;Get what's in that square...
		CMP IAM			;Am i there, too?
		BNE FINDWINL		;Nope, forget that...
		LDA WINTAB3,X		;Get third position (completing line)
					; we're checking...
		TAY
		LDA GRID,Y		;And get what's in that square...
		CMP #CSPC		;Is it empty?
		BNE FINDWINL		;Not empty! that other fucker blocked
					; it! :(

		STY CURSOR		;Found our winning move (yay!)...
		JMP MOVEHERE		;Go do it!
FINDWINL
		DEX
		BPL FINDWIN1

CMO
		INC CPUMOD		;We'll try to find a blocking move
					; next frame.
		RTS

FINDBLOCK
		LDX #23			;We are going to check through 24
					; combinations, where there are 2 of
					;the opponent in a row, and the third
					; open spot in the row would block his
					; or her chance to win.
FINDBLOCK1
		LDA WINTAB1,X		;Get first position of combo we're
					; checking...
		TAY
		LDA GRID,Y		;Get what's in the square...
		CMP OPPIS		;Is it that other bastard in the square?
		BNE FINDBLOCKL		;Nope.
		LDA WINTAB2,X		;Get middle position of combo we're
					; checking...
		TAY
		LDA GRID,Y		;Get what's in that square...
		CMP OPPIS		;Is that dumbass other player in this
					; square too?
		BNE FINDBLOCKL		;No...
		LDA WINTAB3,X		;Get third position (completing line)
					; we're checking...
		TAY
		LDA GRID,Y		;and get what's in that square...
		CMP #CSPC		;Is it empty?
		BNE FINDBLOCKL		;Not empty! with my superior intellect
					; I must have already blocked it.
					;Or, there's a win and another part of
					;    this program isn't recognizing
					;    it because of some weird bug) :D

		STY CURSOR		;found our blocking move...
		JMP MOVEHERE		;and do it!
FINDBLOCKL
		DEX
		BPL FINDBLOCK1

		JMP CMO			;Looks like we have to go into
					; uncharted territory...next frame,
					; that is...

FINDOPEN				;At this point it looks like I'm trying
					; to find any open square...      
		LDY #4			;Is the center square open, by any
					;chance?
		LDA GRID,Y
		CMP #CSPC
		BNE FINDOPEN1		;Nope! :(
	
		STY CURSOR		;Yep! :)
		JMP MOVEHERE		;Take it!

FINDOPEN1				;OK, so now we are left to picking a
					; random open square

		LDA #10			;Just in case my programmer did
					; something wrong
                STA CRASH
                
		JSR NEXTRAND		;Let's get a random number...
		AND #%00001111		;Make sure it's 15 or under...
		CMP #9	
		BCC FINDOPEN2		; and if it's above 8...
		SEC
		SBC #8			; subtract 8.

FINDOPEN2	
		DEC CRASH		;So in the event some bug gets us here
					; with the grid full, we're not going
					; to endlessly loop looking for squars.
                BNE FINDOPENC		;We're goig to bring up service mode
                LDA #2			; with an E002 error and die.
                LDX #CE
                JSR SVCENT                
                JMP MAIN
                
FINDOPENC	
		STA TEMP		;Stash that

FINDOPEN3
		LDY TEMP
		LDA GRID,Y
		CMP #CSPC		;Is the square open?
		BNE FNXT

		STY CURSOR		;It is!
		JMP MOVEHERE		;That's our move

FNXT
		INC TEMP		;Let's try another square...
		LDA TEMP		;(one of the squares should be open if
					; the game hasn't been declared a draw
		CMP #9			; ...)
		BNE FINDOPEN3
		LDA #0
		JMP FINDOPEN2

		RTS

		;**************************************************************
		;MODE=2, PHASE=ANY: Service Mode
                
                ;Service mode doesn't do much but display a message.
SERVIC		
		RTS

		;**************************************************************
		;MODE=3, PHASE=3: Delay
OBOUNCE		
		DEC BOUNCE2
		BNE OBX
		LDA #1
		STA PHASE
OBX		RTS

;------------------------------------------------------------------------------
SCREENH 	;*** SCREEN DRAWING HANDLER
		;Draws a frame              
		LDA INTIM		;is it time to draw the screen yet?
		BNE SCREENH		;if not then wait
		STA WSYNC
		STA VBLANK 		;End the VBLANK period with a zero.

		JSR COLORS
                
		;Begin rendering screen

		LDA BGC			
		STA COLUBK
		LDA P0C
		STA COLUP0
		STA COLUP1

		;Blank space at top to center everything
                
                LDX #15
TLOOP1		STA WSYNC		;9 lines
		DEX
               	BPL TLOOP1

		;Start score area
		LDA #0
		STA TEMP1
		STA TEMP2
		STA TEMP3
		
                LDA MODE
		CMP #2            
		BEQ SHLXXX
                
		LDA #8
		STA TEMP1
		LDA #15
		STA TEMP2
		LDA #255
		STA TEMP3               
SHLXXX
		STA WSYNC		;1 line

		;Begin generating actual score digits
		LDY #6
SHL1					;draw top score area
		LDA (GPTR00),Y
		STA GRP0
		LDA (GPTR02),Y
		TAX		
		LDA (GPTR01),Y	
		NOP
		NOP
		NOP
		NOP
		NOP
		NOP
		STA GRP1
		NOP	
		NOP
		STX GRP0
		STA WSYNC
		DEX

		DEY
		BPL SHL1

		LDA #0
		STA GRP0
		STA GRP1
		STA WSYNC
		STA WSYNC
		STA WSYNC
		STA WSYNC

		;*** Separator (7 lines)
		LDA FGC
		STA COLUPF
		LDA #255
		STA PF0
		STA PF1
		STA PF2
		STA WSYNC
		STA WSYNC	

		LDY #4
SHL2		
		LDA (TOPL),Y
		STA GRP0
		LDA (TOPR),Y
		TAX		
		LDA CHARSPC,Y	
		NOP
		NOP
		NOP
		NOP
		NOP
		NOP
		STA GRP1
		NOP	
		NOP
		STX GRP0
		STA WSYNC
		DEY
		BPL SHL2

		LDA #0
		STA GRP0
		STA GRP1
		STA WSYNC
		STA WSYNC

		;*** Middle (142 lines)

		;Top three squares
		LDA BGC
		STA COLUPF
		STA COLUBK
		
                LDX #5
TLOOP2		STA WSYNC	;5 lines
		DEX
                BPL TLOOP2

		LDA #0
		STA PF0
		STA PF1
		LDA TEMP1
		STA PF2
		STA WSYNC	;1 line

		LDA FGC
		STA COLUPF	
		STA WSYNC	;1 line

		LDX #11		;12 lines
SHL3A		
		STA WSYNC
		DEX
		BNE SHL3A

		LDA P1C
		STA COLUP0
		STA COLUP1

		LDY #6		;draw first row of game pieces
SHL3A0		
		LDA #1
		STA DOUBLE
SHL3A0_1
		STA WSYNC
		LDA (GPTR10),Y
		STA GRP0
		LDA (GPTR12),Y
		TAX		
		LDA (GPTR11),Y	
		NOP
		NOP
		NOP
		NOP
		NOP
		NOP
		STA GRP1
		NOP	
		NOP
		STX GRP0

		DEC DOUBLE
		BPL SHL3A0_1
	
		DEY
		BPL SHL3A0

		LDX #12		;13 lines
SHL3A1		
		STA WSYNC
		LDA #0
		STA GRP0
		STA GRP1
		DEX
		BNE SHL3A1

		;Upper horizontal bar of grid
		LDA TEMP2
		STA PF1
		LDA TEMP3
		STA PF2		

		LDX #7		;8 lines
SHL3B		
		STA WSYNC
		DEX
		BNE SHL3B

		;Middle three squares
		LDA #0
		STA PF0
		STA PF1
		LDA TEMP1
		STA PF2

		LDX #11		;12 lines
SHL3C		
		STA WSYNC
		DEX
		BNE SHL3C

		LDY #6		;draw second row of game pieces
SHL3C0		
		LDA #1
		STA DOUBLE
SHL3C0_1
		STA WSYNC
		LDA (GPTR20),Y
		STA GRP0
		LDA (GPTR22),Y
		TAX		
		LDA (GPTR21),Y	
		NOP
		NOP
		NOP
		NOP
		NOP
		NOP
		STA GRP1
		NOP	
		NOP
		STX GRP0
	
		DEC DOUBLE
		BPL SHL3C0_1

		DEY
		BPL SHL3C0
		
		LDX #12		;13 lines
SHL3C1		
		STA WSYNC
		LDA #0
		STA GRP0
		STA GRP1
		DEX
		BNE SHL3C1

		;Lower horizontal bar of grid
		LDA TEMP2
		STA PF1
		LDA TEMP3
		STA PF2		

		LDX #7		;8 lines
SHL3D		
		STA WSYNC
		DEX
		BNE SHL3D

		;Bottom three squares
		LDA #0
		STA PF0
		STA PF1
		LDA TEMP1
		STA PF2

		LDX #11		;12 lines
SHL3E		
		STA WSYNC
		DEX
		BNE SHL3E

		LDY #6		;draw third row of game pieces
SHL3E0		
		LDA #1
		STA DOUBLE	
SHL3E0_1
		STA WSYNC
		LDA (GPTR30),Y
		STA GRP0
		LDA (GPTR32),Y
		TAX		
		LDA (GPTR31),Y	
		NOP
		NOP
		NOP
		NOP
		NOP
		NOP
		STA GRP1
		NOP	
		NOP
		STX GRP0

		DEC DOUBLE
		BPL SHL3E0_1

		DEY
		BPL SHL3E0

		STA WSYNC	;1 line
		LDA #0
		STA GRP0
		STA GRP1

		LDX #11		;12 lines
SHL3E1		
		STA WSYNC
		DEX
		BNE SHL3E1

		STX PF0		;clear PF
		STX PF1
		STX PF2

		;*** Bottom (22 lines)

		LDX #6
SHL4
		STA WSYNC
		DEX
		BNE SHL4

		LDX FGC
		STX COLUP0
		STX COLUP1
		STX WSYNC

		LDY #6
SHL5					;draw bottom score area
		STA WSYNC
		LDA (GPTR40),Y
		STA GRP0
		LDA (GPTR42),Y
		TAX		
		LDA (GPTR41),Y	
		NOP
		NOP
		NOP
		NOP
		NOP
		NOP
		STA GRP1
		NOP	
		NOP
		STX GRP0
	
		DEY
		BPL SHL5

		STA WSYNC		;1 line
		LDA #0			
		STA GRP0
		STA GRP1

		STA WSYNC		;3 lines
		STA WSYNC
		STA WSYNC

		RTS			;that's a frame (whew!)
;------------------------------------------------------------------------------
OVERSCANH 	;*** OVERSCAN HANDLER
		LDA #0			;make sure overscan has no colors
		STA COLUBK		; so it won't look weird on emulators
                STA COLUP0
		STA COLUP1
		STA COLUPF
		STA WSYNC

		LDX #35
BURNLINES	STA WSYNC
                DEX
                BNE BURNLINES
                
		RTS

;------------------------------------------------------------------------------
		;Subroutines

MKSOUND		;Sets sound driver variables to produce a sound
		;Sound number in .Y
                LDA SNDTABL,Y
                STA SNDPTR
                LDA SNDTABH,Y
               	STA SNDPTR+1
		JMP NEWSND
                
SNDDRV		LDA SNDPTR+1
		BNE PLAYING
       		RTS
                
PLAYING         DEC SNDTIM
		BNE SUSTAIN
                
                INC SNDPTR
                INC SNDPTR
                INC SNDPTR
NEWSND          LDY #0
                LDA (SNDPTR),Y
                BNE NEXTNOTE
                
                STY SNDPTR+1
                STY AUDV0
                RTS
                
NEXTNOTE	STA AUDF0
		INY
               	LDA (SNDPTR),Y
                STA AUDC0
                INY
                LDA (SNDPTR),Y            
                STA SNDTIM
                LDA #$FF
                STA AUDV0
                
SUSTAIN
                RTS

SETCHAR		;Sets current position in .Y (0-14) to character in .X
		PHP
		PHA
                TYA
                PHA

		LDA PTRTABL,Y
		STA PTRPTR
		LDA #0
		STA PTRPTRH
		LDY #0
		LDA CHARTABL,X
		STA (PTRPTR),Y
		INY
		LDA CHARTABH,X
		STA (PTRPTR),Y

		PLA
                TAY
		PLA
		PLP
		RTS

SETSCR		;Sets all positions to characters in 15 byte table pointed to
		; by TEMP3-TEMP4.
		LDY #14
SETSCRL		LDA (TEMP3),Y
		TAX
		STY TEMP
		JSR SETCHAR
		LDY TEMP
		DEY
		BPL SETSCRL
		RTS

INTCRSR		;Initializes cursor (for MOVE routine)
		LDA #16
		STA BOUNCE
		STA BLINK
		LDA #4
		STA CURSOR
		TAY
		LDA GRID,Y
		STA UNDER
		RTS

RESBLNK		;Resets BLINK variable (for MOVE routine)
		LDA #16
		STA BLINK
		;fall into SETTOP

SETTOP		;Sets top label GPTR's according to XFLAG
		LDY XFLAG 
SETTOP1
		LDA TOPTABL,Y
		STA TOPL
		LDA TOPTABH,Y
		STA TOPLH
		INY
		LDA TOPTABL,Y
		STA TOPR
		LDA TOPTABH,Y
		STA TOPRH
		RTS
                                        
COLORS		;Set colors for this frame
		;Takes into account COLOR/B-W switch, as well as ATTRAC
		; variable for attract mode.
                
		;If we are in service mode...
                LDA MODE
                CMP #2
                BEQ COLORSSVC		;set service mode colors.             
                
                ;otherwise...
        	CLC
                LDA SWCHB1		;bit D3 will have color/B-W switch bit...				
                AND #%00001000
                LSR
                LSR
                LSR
                TAX			;and now X will be 0 if color, 1 if BW.                     
COLORS1         LDA CFGBGC,X		;set colors from ROM.
		ADC ATTRAC
                AND CMMASK,X
                STA BGC
		LDA CFGFGC,X
		ADC ATTRAC
                AND CMMASK,X
                STA FGC
		LDA CFGP0C,X
		ADC ATTRAC
                AND CMMASK,X
                STA P0C
		LDA CFGP1C,X
		ADC ATTRAC
                AND CMMASK,X
                STA P1C
		RTS
                
COLORSSVC	LDA #$71		;Set colors for service mode
		STA BGC			;This will basically turn entire
                STA FGC			; screen blue except for text.
                LDA #$0F
                STA P0C
                STA P1C
                RTS

NEXTRAND	;Get next random number
		;Uses LFSR code from here:
		;https://codebase64.org/doku.php?id=base:small_fast_8-bit_prng
                ;
		LDA RAND
        	BEQ DOEOR
         	ASL
         	BEQ NOEOR		;if the input was $80, skip the EOR
         	BCC NOEOR
DOEOR    	EOR #$1d
NOEOR  		STA RAND
		RTS

CYCLE		;cycles game colors
		INC ATTRAC		;ATTRAC is for B-W mode
                RTS

;------------------------------------------------------------------------------
SVCENT		;Setup service mode
		
                ;Service mode will:
                ;- Display a symbol in GPTR 3 - desired one should be in X.
                ;- Display a number in GTPRs 6 through 8 - desired one should
		;  be in .A
                ;- Set GPTRs to service mode grapics             
                ;- Change game mode to 2.  Mode 2 will...
                ;  - Have different color scheme
                ;  - Hold system hostage until powercycle.
                               
		LDY #0
                JSR SETCHAR               
		
                LDX #CSPC
                INY
CLRSCN          
		JSR SETCHAR
                INY
                CPY #14
                BNE CLRSCN
                
		JSR SVCSCR                         
                   
		LDA #<CHARSPC		;initialize top graphics pointers...
		STA TOPL
		STA TOPR
		LDA #>CHARSPC
		STA TOPLH
		STA TOPRH

                LDA #$02		;Set mode to 2 so SERVIC is called in
					; the main loop
                STA MODE
                
      		LDA #$FF
                STA SWCHB1    

                RTS

SVCSCR		;.A should be the number to display.
		;Can be an error code or whatever.
		;ROMCHECK uses this to communicate computed checksum.
		;
		;Basically this will convert the value in .A to individual
		; digits and set the GPTRs accordingly, using SETCHAR.

                LDX #0
		
HUND		CMP #100
                BCC TENS
    		INX
                SBC #100
                JMP HUND

TENS		
		LDY #6
		JSR SETCHAR
		LDX #0
TEN             CMP #10
                BCC ONES
                INX
                SBC #10
                JMP TEN
                
ONES            LDY #7
                JSR SETCHAR
                
                TAX
                LDY #8
                JMP SETCHAR

ROMCHECK	;Compute ROM checksum            
		LDA #$F0		;Set a pointer to bottom of ROM ($F000).
                STA CHKPTR+1		; (working our way up the pages but down
                LDA #$00		;  the bytes)
                STA CHKPTR
                STA CHKSUM		;Initialize working variable containing
                			; checksum.

		LDY #$10		;Skip first 16 bytes (config vars).

		CLC			;Prepare carry flag for math.
                
CHKSUMLOOP1     LDA (CHKPTR),Y		;Get a ROM byte ...
                
                EOR CHKSUM		;Perform CRC8 on it.
                STA CHKSUM
                ASL
                BCC UP1
                EOR #$07
UP1		EOR CHKSUM
		ASL
                BCC UP2
		EOR #$07
UP2		EOR CHKSUM
		STA CHKSUM
                
                INY                	;... and loop through each byte in page.
                BNE CHKSUMLOOP1
		                	;OK, done with that page, next one?
                LDY #$00    		; (starting on new page - set index to 0)
                
                INC CHKPTR+1		;Increment page (high byte) of pointer.
                BNE CHKSUMLOOP1		;Keep going until high byte wraps FF->00.

					
		LDX #CC			;Computed checksum is now in CHKSUM
                LDA CHKSUM		; ... so, let's display it.
                JSR SVCENT		;SVCENT sets up display and converts .A
                			; to a graphical decimal number.
                            
                LDA CHKSUM		;Moment of truth: Is the checksum right?
                CMP GOOD		;Compare against stored known good value
                			; in ROM config table.
                BEQ ROMCHECKX
		
                LDY #4			;Put a big E on the display if not matching
                LDX #CE			; known good value.
                JSR SETCHAR
ROMCHECKX       
                JMP MAIN		;Jump to main loop.

;------------------------------------------------------------------------------
		;*** Sound data
                ;*** Must be page aligned!
		org $FD00
                
SNDTABL		.byte <SOUND0,<SOUND1,<SOUND2,<SOUND3,<SOUND4,<SOUND5,<SOUND6		
SNDTABH		.byte >SOUND0,>SOUND1,>SOUND2,>SOUND3,>SOUND4,>SOUND5,>SOUND6
		;Bad move
SOUND0		.byte 8, 6,8, 0
		;P1 move
SOUND1		.byte 4, 6,2, 3, 7,2, 0
		;P2 move
SOUND2		.byte 2, 6,2, 1, 7,2, 0
		;Win
SOUND3		.byte 8,10,3, 6,10,4, 4,10,5, 2,10,6, 1,10,3, 0
		;Draw
SOUND4		.byte 1,12,6, 4,10,5, 5,12,6, 9,10,5, 1,12,4, 0                
		;Move piece
SOUND5		.byte 2,12,2, 1,12,1, 0 
		;End game
SOUND6		.byte 2,13,3, 3,13,4, 4,13,5, 5,13,7, 6,13,10, 0             

;------------------------------------------------------------------------------
		;*** Graphics
		;All characters except TOPX and TOPO are assumed to be 7 lines
		; high.
		;See character tables below to see what numbers identify what
		; characters!
		org $FE00

		;Space
CHARSPC		.byte %00000000
		.byte %00000000
		.byte %00000000
		.byte %00000000
		.byte %00000000
		.byte %00000000
		.byte %00000000

		;Numeral 0
CHAR0		.byte %01111100
		.byte %11000110
		.byte %11100110
		.byte %11010110
		.byte %11001110
		.byte %11000110
		.byte %01111100

		;Numeral 1
CHAR1		.byte %00111100
		.byte %00011000
		.byte %00011000
		.byte %00011000
		.byte %00011000
		.byte %00111000
		.byte %00011000

		;Numeral 2
CHAR2		.byte %11111110
		.byte %11000000
		.byte %01110000
		.byte %00011100
		.byte %00000110
		.byte %10000110
		.byte %01111100

		;Numeral 3
CHAR3		.byte %01111100
		.byte %10000110
		.byte %00000110
		.byte %00111100
		.byte %00000110
		.byte %11000110
		.byte %01111100

		;Numeral 4
CHAR4		.byte %00001100
		.byte %00001100
		.byte %11111110
		.byte %01101100
		.byte %00111100
		.byte %00011100
		.byte %00001100

		;Numeral 5
CHAR5		.byte %01111100
		.byte %10000110
		.byte %00000110
		.byte %10000110
		.byte %11111100
		.byte %11000000
		.byte %11111100

		;Numeral 6
CHAR6		.byte %01111100
		.byte %11000110
		.byte %11000110
		.byte %11111100
		.byte %11000000
		.byte %11000010
		.byte %01111100

		;Numeral 7
CHAR7		.byte %00110000
		.byte %00110000
		.byte %00011000
		.byte %00011000
		.byte %00001100
		.byte %10000110
		.byte %11111110

		;Numeral 8
CHAR8		.byte %01111100
		.byte %11000110
		.byte %11000110
		.byte %01111100
		.byte %11000110
		.byte %11000110
		.byte %01111100

		;Numeral 9
CHAR9		.byte %01111100
		.byte %00000110
		.byte %01111110
		.byte %11000110
		.byte %11000110
		.byte %11000110
		.byte %01111100

		;X 
CHARX		.byte %11000011
		.byte %11100111
		.byte %01111110
		.byte %00111100 
		.byte %01111110
		.byte %11100111
		.byte %11000011

		;O
CHARO		.byte %00111100
		.byte %01111110
		.byte %11100111
		.byte %11000011
		.byte %11100111
		.byte %01111110
		.byte %00111100

		;TIE
CHARTIE		.byte %01010111
		.byte %01010100
		.byte %01010111
		.byte %01010100
		.byte %01010111
		.byte %01000000
		.byte %11100000

		;WIN 
CHARWIN		.byte %11101010
		.byte %01001010
		.byte %11101110
		.byte %00000000
		.byte %01111100
		.byte %01010100
		.byte %01010100

		;(Version number; for title screen)
CHARVER		.byte %00110110
		.byte %00100100
		.byte %00010010
		.byte %10010010
		.byte %10100100
		.byte %00000000
		.byte %00000000
		
		;Selection cursor
CHARSEL		.byte %00011000
		.byte %00111100
		.byte %01111110
		.byte %00000000
		.byte %01111110
		.byte %00111100
		.byte %00011000

		;P1
CHARP1		.byte %10000111
		.byte %10000010
		.byte %10000010
		.byte %11100010
		.byte %10010010
		.byte %10010110
		.byte %11100010

		;P2
CHARP2		.byte %10000111
		.byte %10000100
		.byte %10000010
		.byte %11100001
		.byte %10010001
		.byte %10010101
		.byte %11100010

		;CPU
CHARCPU		.byte %00000111
		.byte %00100101
		.byte %00111101
		.byte %00101000
		.byte %11111000
		.byte %10000000
		.byte %11000000

		;VS 
CHARVS		.byte %00000111
		.byte %00000001
		.byte %00100111
		.byte %01010100
		.byte %01010111
		.byte %10001000
		.byte %10001000

CHAR10		;10
		.byte %11100100
		.byte %01001010
		.byte %01001010
		.byte %01001010
		.byte %01001010
		.byte %11001010
		.byte %01000100

CHARLA		;A
		.byte %11100111
		.byte %11000011
		.byte %01111110
		.byte %01100110
		.byte %00101100
		.byte %00111100
		.byte %01111110

CHARLC		;C
		.byte %00111100
		.byte %01100010
		.byte %11000000
		.byte %11000000
		.byte %11000000
		.byte %01100110
		.byte %00111100

CHARLE		;E
		.byte %11111111
		.byte %01100001
		.byte %01100100
		.byte %01111100
		.byte %01100100
		.byte %01100001
		.byte %11111111

CHARLI		;I
		.byte %01111110
		.byte %00011000
		.byte %00011000
		.byte %00011000
		.byte %00011000
		.byte %00011000
		.byte %01111110

CHARLO		;O
		.byte %00111100
		.byte %01110110
		.byte %11000011
		.byte %11000011
		.byte %11000011
		.byte %01101110
		.byte %00111100

CHARLT		;T
		.byte %00111100
		.byte %00011000
		.byte %00011000
		.byte %00011000
		.byte %00011000
		.byte %10011001
		.byte %11111111

		;Notice: the TOPX and TOPO graphics are 5 lines high, unlike
		; the other characters which are 7 lines high.
		;Small X for symbol beneath player score
TOPX		.byte %01100110
		.byte %00111100
		.byte %00011000
		.byte %00111100
		.byte %01100110

		;Small Y for symbol beneath player score
TOPO		.byte %00111100
		.byte %01100110
		.byte %01100110
		.byte %01100110
		.byte %00111100

;------------------------------------------------------------------------------
		;*** Lookup tables
		.org $FF00
                
		;GPTR tables - used by SETCHAR so we can specify a screen
		; position by number instead of the address of its GPTR.
PTRTABL
		.byte GPTR00,GPTR01,GPTR02
		.byte GPTR10,GPTR11,GPTR12
		.byte GPTR20,GPTR21,GPTR22
		.byte GPTR30,GPTR31,GPTR32
		.byte GPTR40,GPTR41,GPTR42

		;Character tables
		;...These are used so we can specify characters by a number
		; (index) instead of the full address.
		;...The numerals 0-9 are assigned the indices 0-9 to
		; facilitate easy conversion!
CHARTABL	
		.byte <CHAR0,<CHAR1,<CHAR2,<CHAR3,<CHAR4,<CHAR5
		.byte <CHAR6,<CHAR7,<CHAR8,<CHAR9
		.byte <CHARX,<CHARO
		.byte <CHARTIE,<CHARWIN
		.byte <CHARSPC,<CHARSPC,<CHARSPC
		.byte <CHARVER,<CHARSPC,<CHARSEL
		.byte <CHARP1,<CHARP2,<CHARCPU,<CHARVS
		.byte <CHAR10
                .byte <CHARLA,<CHARLC,<CHARLE,<CHARLI,<CHARLO,<CHARLT
CHARTABH
		.byte >CHAR0,>CHAR1,>CHAR2,>CHAR3,>CHAR4,>CHAR5
		.byte >CHAR6,>CHAR7,>CHAR8,>CHAR9
		.byte >CHARX,>CHARO
		.byte >CHARTIE,>CHARWIN
		.byte >CHARSPC,>CHARSPC,>CHARSPC
		.byte >CHARVER,>CHARSPC,>CHARSEL
		.byte >CHARP1,>CHARP2,>CHARCPU,>CHARVS
		.byte >CHAR10
		.byte >CHARLA,>CHARLC,>CHARLE,>CHARLI,>CHARLO,>CHARLT
                
                ;Character equates
C0	= 0
CXCHAR  = 10
;CTIE	= 12
CWIN	= 13
;CTIC	= 14
;CTAC	= 15
;CTOE	= 16
CVER	= 17
CSPC	= 18
CSEL	= 19
CP1	= 20
CP2	= 21
CCPU	= 22
CVS	= 23
CTEN	= 24
CA	= 25
CC	= 26
CE	= 27
CI	= 28
CO	= 29
CT	= 30

		;These are used to determine which symbols are displayed
		; beneath the player scores.
		;While there are only 2 symbols at the top, 3 entries are in
		; each table so we can always use an INC instruction to get to
		; the opposite symbol, whether we are using symbol index 0 or 1.
TOPTABL		.byte <TOPX,<TOPO,<TOPX
TOPTABH		.byte >TOPX,>TOPO,>TOPX

		;Game description tables - basically, what characters appear at
		; the top in Game Select mode.
		;...Character that appears left of VS
GL1		.byte CP1,CP1,CCPU,CCPU
		;...Character that appears right of VS
GL2		.byte CCPU,CP2,CP2,CCPU

		;these are what PHASEs are needed in each respective CURGAM to
		; service a player.
		;Basically, 1 means a non-CPU player, 3 means a CPU player.
PTABLE		.byte 1,3, 1,1, 3,1, 3,3

		;Screen tables
		; These represent full screens of characters (15 characters).
		;The routine SETSCR will take the address of a table here and
		; set all positions on screen according to the table.
                ;
		;Title screen
TITLE		.byte CSPC,CSPC,CSPC 
		.byte CT  ,CI  ,CC   
		.byte CT  ,CA  ,CC   
		.byte CT  ,CO  ,CE  
		.byte CSPC,CVER,CSPC
                ;Clear screen for new game
NEWGAM		.byte CSPC,CSPC,CSPC
		.byte CSPC,CSPC,CSPC
		.byte CSPC,CSPC,CSPC
		.byte CSPC,CSPC,CSPC
		.byte CSPC,CSPC,CSPC
			
		;MODE vector tables
		; These are used so we can specify MODE handlers by number
		; (index) instead of the full address.
		;
		;The MODE is the basic mode that the game is in (Game Select
		; or Game Play)
MODTABL		.byte <GAMSEL,<PLYGAM,<SERVIC
MODTABH		.byte >GAMSEL,>PLYGAM,>SERVIC
		;
                ;Game handler vector tables
                ;The MODE and PHASE variables determine what the game is doing
		; at any given frame.
                ;The variables are used as an index into these tables to figure
		; out where to jump to.
		;
		;The PHASE is what task is currently being done within the
		; current MODE.
VECTABL		.byte <SETUP,<MOVE,<CHECK,<CPUMOV,<OVER,<MATCHWIN
VECTABH		.byte >SETUP,>MOVE,>CHECK,>CPUMOV,>OVER,>MATCHWIN
		
		;These tables are used to check if there is a winner, 
                ;and for the CPU to decide its move.
WINTAB1		.byte 0,3,6, 0,1,2, 0,2, 0,2, 3,4, 6,7, 0,3, 1,4, 2,5, 0,4, 2,4            
WINTAB2		.byte 1,4,7, 3,4,5, 4,4, 2,1, 5,5, 8,8, 6,6, 7,7, 8,8, 8,8, 6,6             
WINTAB3		.byte 2,5,8, 6,7,8, 8,6, 1,0, 4,3, 7,6, 3,0, 4,1, 5,2, 4,0, 4,2

		;Used by COLORS routine.
                ;One of these masks is applied to the color variables (set
		; each frame) depending on the position of the color/B-W
		; switch.
                ;Because in 2024 we want to properly support this switch. :P
CMMASK		.byte %00001111,%11111111

		;LFSR PRNG seeds
RNDSEEDS	.byte 29,43,45,77,95,99,101,105,113,135,141,169,195,207,231,245

;------------------------------------------------------------------------------
;6507 interrupt/reset vectors

		org $FFFA

INMI  		.word JUSTRTI
IRESET		.word RESET
IIRQBRK		.word BRKH