; Quikman for Commodore VIC20
; written by Robert Hurst <robert@hurst-ri.us>
; using Commodore VICMON (SYS 45056)
; original version: Fall 1984
;
; disassembled: 23-Oct-2008
; re-assembled: 27-Oct-2008
;
; to assemble this source using cc65.org project:
;   ca65.exe --cpu 6502 --listing quikman.s
;   ld65.exe -C doc/vic20.cfg -o quikman.prg quikman.o
;
; to run the binary using viceteam.org project:
;   xvic -memory none -ntsc -sound -joydev1 2 -autostart quikman.prg
;
; pertinent VIC20 symbols
JIFFYH		= $A0
JIFFYM		= $A1
JIFFYL		= $A2		; jiffy-clock low byte value
SCRNPAGE	= $0288		; screen memory page (unexpanded = $1E)
CTRLCSHIFT	= $028D		; keyboard flag: control/commodore/shift
CASSBUFF	= $033C		; cassette buffer
VIC			= $9000		; start of video interface chip registers
CHROUT		= $FFD2
GETIN		= $FFE4
;
; my symbol / memory map
PPILLTIMER	= $10		; powerpill effectiveness timer
FRUITTIMER	= $39		; 0 - 242
FRUITFLAG	= $3A		; zero or non-zero, if fruit has been activated
PPILLFLAG	= $3B		; just ate a powerpill this turn (0=no)
CHOMP		= $3C		; pointer into sound effect for fruit and fleeing monsters
CHEWING		= $3D		; flag whether quikman just ate a dot or not
DIGIT		= $3E		; award points at this digit place
POINTS		= $3F		; how many points scored
OLDDIR		= $40		; direction sprite was last moving in
NEWDIR		= $41		; direction sprite wants to take, if valid by MAZEMOVE
JOYVAL		= $42		; last joystick read value
QMANDIR		= $43		; quikman's current direction (0=right,1=down,2=left,3=up)
LIVES		= $44		; 0 - 3
MAZE		= $45		; maze color: 3 (cyan) or 6 (blue)
FLASHPILL	= $46		; powerpill blink counter (0-30)
BANNERTIMER	= $47		; time for banner to display
BANNERFLAG	= $48		; 0=author, 1=instructions
FRUITLEVEL	= $49		; 0 - 12
DOTS		= $4A		; 0 - 174
PENALTY		= $4B		; $4B-$4E monsters are free-to-roam flag
;			= $4F		; $4F-$52 monsters current direction (0=right,1=down,2=left,3=up)
;			= $53		; $53,$55,$57,$59 monster's knowledge of quikman's "X" coord was
;			= $54		; $54,$56,$58,$5A monster's knowledge of quikman's "Y" coord was
;			= $61		; $61-$64 monster array for its next best move
;			= $69		; temporary var
FLEEINGSCORE= $70		; fleeing monster score: 2, 4, 8, 16
;			= $FC		; $FC,$FD is screen cell pointer for sprite's "home" position
;			= $FE		; $FE,$FF is color cell pointer for same
;
; program indirects (my sprite registers)
SPRITE		= $02A1		; bitmask 0-7 controls sprite on/off
SPRITEX		= $02A2		; $02A2,A4,A6,A8,AA,AC,AE,B0 each "X" coordinate
SPRITEY		= $02A3		; $02A3,A5,A7,A9,AB,AD,AF,B1 each "Y" coordinate
SPRITECLR	= $02B2		; $02B2-$02B9 color
SPRITEIMG1	= $02BA		; $02BA-$02C1 low-byte of SPRITE image
SPRITEIMG2	= $02C2		; $02C2-$02C9 hi-byte of SPRITE image
SPRITELAST	= $02CC		; $02CC-$02DC keep last state of SPRITE registers
SAVEBACK	= $02DD		; $02DD-$02FC keep what's under the sprite's 2x2 matrix
;
EXTRAQMAN	= $03E0		; bonus quickman flag (0=unused)
;
; other constants
FRUITCELL	= $1F1B		; screen cell address of fruit
FRUITCELLCLR= $971B		; color cell address of fruit
;
; uses standard VIC20 (unexpanded)
		.segment "STARTUP"
;
; starting load address:
; LOAD "QUIKMAN.PRG",8,1
		.word	$1001
;
; 0 SYS4110
BASIC:	.byte	$0B, $10, $00, $00, $9E, $34, $31, $31, $30, $00, $00, $00, $00
;
; Main entry point into the game
START:
		JSR REDRAW
RESTART:
		NOP
		NOP
		NOP
		JSR INITVARS
		LDA #$0E		; black / blue
		STA VIC+$0F		; background / border color
		LDA #$08		; lock uppercase / graphic set
		JSR CHROUT
		LDX #$FF		; set for $1C00
		STX VIC+$05		; use programmable char set
		INX				; mute
		STX VIC+$0E		; aux color / volume
		LDA #$80+$15	; set for videoram @ $1E00 with 21-columns
		STA VIC+$02		; video matrix address + columns
		LDA #$B0		; $B0 = 10110000 = 24 rows + 8x8 height
		STA VIC+$03		; rows / character height
		SEI
		LDX #<BACKGROUND	;$4D
		LDY #>BACKGROUND	;$10
		STX $0314
		STY $0315
		CLI
		LDA #$06			; blue
		STA MAZE
@loop1:	JSR GETIN			; get keyboard
		CMP #$88			; got F7 ?
		BNE @loop1			; try again ...
		BEQ RESET			; game starts!
;
;($104D)
BACKGROUND:
		LDA JIFFYL
		AND #$07
		BEQ @skip1
		LDA DOTS
		CMP #$AE			; All 174 dots been eaten?
		BNE @skip2
@skip1:	JMP MAZEPAINT
@skip2:	JMP EFFECTS			; which will return here (JSR)
;
;($105F)
SR105F:
		JSR SR1500
		NOP
		NOP
		NOP
		JSR SR14A0		; sound effects
		JSR GAMEOVER	; a routine in custom character area
		JMP $EABF		; jump to hardware IRQ
;
;($106E)
SR106E:
		LDA #$09
		STA CHOMP
		LDA JIFFYL
@loop1:	CMP JIFFYL
		BEQ @loop1		; wait up to a jiffy
		TYA
		LSR
		TAX
		LDA CAGEDATA,X	; load waiting room time
		LSR
		LSR
		STA PENALTY,X	; monster is waiting
		RTS
;
; game reset
RESET:
		LDA #$FF		; -1 will become 0 at start of "next" level
		STA FRUITLEVEL
		LDA #$03		; start with 3-lives
		STA LIVES
		LDX #$00		; reset score
@loop1:	LDA #$B0		; each digit to "0"
		STA SCORE,X		; into savebuffer
		INX				; do next digit
		CPX #$06		; all 6 of them
		BNE @loop1
;
;($1097)
RESETSND:
		LDA #$00
		TAX
@loop1:	STA VIC+$0A,X	; reset sound channels
		INX
		CPX #$04
		BNE @loop1
		STA SPRITE		; turn off all sprites
		JSR SPRITES		; redraw sprites
		LDA #$0F
		STA VIC+$0E		; volume mute
		JSR REDRAW		; refresh screen
;
;($10B0)
RESETCHR:
		LDX #$05
@loop1:	LDA QUIKMANCLR-1,X ; reset monsters starting colors
		STA SPRITECLR-1,X ; into their sprite color registers
		DEX
		BNE @loop1
@loop2:	LDA #$78		; reset monsters as chasing
		STA SPRITEIMG1+1,X		; into their sprite register
		LDA #$1D		; reset monsters character
		STA $02C3,X		; into their sprite register
		INX
		CPX #$04
		BNE @loop2
		LDX LIVES		; paint lives remaining
@loop3:	LDA #$2D		; quikman character
		STA $1FE2,X		; bottom-left of screen
		LDA #$07		; use yellow
		STA $97E2,X		; and paint it
		DEX
		NOP
		NOP
		BNE @loop3
		LDY FRUITLEVEL
@loop4:	CPY #$0C		; are we at the last level (key)?
		BCC @skip1
		LDY #$0C		; only keys remain
@skip1:	LDA FRUIT,Y		; fruit character
		STA $1FF1,X		; bottom right of screen
		LDA FRUITCLR,Y	; get its color
		STA $97F1,X		; and paint it
		CPY #$00		; did we paint the cherry yet?
		BEQ SR1100		; if so, we're done
		INX
		STX $FF
		LDA FRUITLEVEL
		SEC
		SBC $FF
		TAY
		CPX #$07		; no more than 7 fruits to display
		BNE @loop4
;
;($1100)
SR1100:
		LDX #$00
		STX SPRITE		; turn off all sprites
		STX QMANDIR		; start off going RIGHT
		STX JOYVAL		; preload last joystick value as going RIGHT
		JSR SPRITES		; redraw sprites
		LDX #$00
@loop1:	LDA STARTPOS,X	; reset each sprite starting position
		STA SPRITE+1,X
		INX
		CPX #$0A		; 5 sprites per X,Y coordinate pair
		BNE @loop1
		LDA #$1C		; always point quikman sprite image
		STA SPRITEIMG2	; to $1CE8 ... stupid?
		LDA #$E8
		STA SPRITEIMG1
		LDA #$1F		; turn on sprites 0-4
		STA SPRITE
		JSR SPRITES		; redraw sprites
		LDX #$00
@loop2:	LDA $C378,X		; print READY from ROM
		AND #$BF
		ORA #$80
		STA $1F19,X
		LDA #$07		; make it yellow
		STA $9719,X
		INX
		CPX #$05
		BNE @loop2		; how geeky is that?
		LDA JIFFYL
		STA $FF			; save this jiffy
@loop3:	LDA JIFFYL
		SEC
		SBC $FF
		CMP #$80		; wait 2+ seconds
		BNE @loop3
		LDX #$00
		LDA #$20		; erase READY
@loop4:	STA $1F19,X
		INX
		CPX #$05
		BNE @loop4
;
; we're ready to play now!
		JSR ZEROVARS
		NOP
		NOP
		NOP
;
;($1160)
PLAYLOOP:
		LDA #$00
		STA $00
		STA $01
		LDA QMANDIR
		STA OLDDIR		; save last direction quikman was going in
		LDA JOYVAL
		STA NEWDIR		; do the same for the joystick
		JSR MAZEMOVE
		BCS @skip1		; is the direction valid?
		LDA JOYVAL		; nope
		STA QMANDIR		; request quikman to move in direction of joystick
		CLC
		BCC @skip2
@skip1:	LDA QMANDIR
		STA NEWDIR
		JSR MAZEMOVE	; keep the current direction going?
@skip2:	LDA SPRITEX
		BNE @skip3		; is quikman at end of tunnel left?
		LDA #$9E
		STA SPRITEX		; put quikman at beginning of tunnel right
@skip3:	CMP #$A0		; is quikman at end of tunnel right?
		BNE @skip4
		LDA #$00
		STA SPRITEX		; put quikman at beggining of tunnel left
@skip4:	LDX #$00
		LDA SPRITEX
		AND #$07
		CMP #$04		; is quikman in the middle of a left/right cell?
		BNE @skip5
		LDA QMANDIR
		EOR #$02
		TAY
		INX
		BNE @skip6
@skip5:	LDA SPRITEY
		AND #$07
		CMP #$04		; is quikman in the middle of an up/down cell?
		BNE @skip6
		LDY QMANDIR
		CPY #$01
		BEQ @next
		LDY #$00
@next:	INX
@skip6:	CPX #$00
		BEQ YUMMY
		LDA SAVEBACK,Y	; retrieve the character from quikman's saveback buffer
		TAX
		LDA #$20
		STA SAVEBACK,Y	; replace the cell quikman is on with an empty space
		CPX #$1E		; is it a dot?
		BNE POWERUP
		LDA #$01
		STA POINTS		; score 1
		STA CHEWING		; quikman has to chew this dot, monsters keep movin'
		LDA #$0A		; score it @ 10-point digit
		STA DIGIT
;
;($11D4)
EATING:	INC DOTS		; ate a dot, account for it
		LDA DOTS
		CMP #$AE		; are all dots eaten?
		BNE YUMMY
;===	end of level	===
		JSR SPRITES		; redraw sprites
		LDA #$00
		STA $FF
@Loop:	LDA #$03		; turn maze cyan
		STA MAZE
		LDY #$00
		LDX #$00
@loop5:	INX				; bad wait loop
		BNE @loop5
		INY
		BNE @loop5
		LDA #$06
		STA MAZE		; turn maze blue
@loop6:	INX				; bad wait loop
		BNE @loop6
		INY
		BNE @loop6
		INC $FF
		LDA $FF
		CMP #$04
		BNE @Loop
		JMP NEXTLEVEL	; complete
;
;($1206)
POWERUP:
		CPX #$22
		BCC @skip1		; is X < 34 ?
		CPX #$2A		; no, is X >= 42 ?
		BCS YUMMY		; ate a piece of fruit?
		TXA				; YUMMY!
		SEC
		SBC #$22		; strip off char code for score index
		TAX
		LDA FRUITSCORE,X
		STA POINTS		; award points
		LDA #$09
		STA DIGIT		; in hundreds
		STA CHOMP
		CLC
		BCC YUMMY
@skip1:	CPX #$1F		; ate a powerpill?
		BNE YUMMY
		LDA #$05
		STA POINTS		; award 5-points
		LDA #$0A
		STA DIGIT		; score @ 10-digit
		STA PPILLFLAG
		BNE EATING		; powerpills are dots on steroids, account for it
;
;($1231)
YUMMY:
		LDA FRUITFLAG
		BNE @skip3		; is fruit already on display?
		LDA DOTS
		CMP #$4B		; has the 75th dot been eaten?
		BEQ @skip1
		CMP #$7D		; has the 125th dot been eaten?
		BNE @skip3
@skip1:	LDX FRUITLEVEL	; prepare thy bonus
		CPX #$0C		; reach the last level?
		BCC @skip2
		LDX #$0C		; only the key is left, and it leaves a bad metallic after-taste
@skip2:	LDA FRUIT,X
		STA FRUITCELL	; display fruit
		LDA FRUITCLR,X
		STA FRUITCELLCLR
		LDA #$F2		; 242-moves and counting
		STA FRUITTIMER	; reset fruit timer
		STA FRUITFLAG
@skip3:	LDA FRUITTIMER	; fruit is on display
		BEQ @skip4		; nothing to do
		DEC FRUITTIMER	; remove a tick
		BNE @skip4		; there is still time left
		LDA #$20		; time's up!
		STA FRUITCELL	; no more fruit
@skip4:	LDA DOTS
		CMP #$4C		; has the 76th dot been eaten?
		BEQ @skip5
		CMP #$7E		; has the 126th dot been eaten?
		BNE @skip6
@skip5:	LDA #$00
		STA FRUITFLAG	; more fruit on this level
;
@skip6:	LDA PPILLFLAG
		BEQ @skip8		; just swallowed a powerpill?
		LDA FRUITLEVEL
		ASL				; multiply 8
		ASL
		ASL
		STA $FF			; shrink powerpill effectiveness per level
		LDA #$F8
		SEC
		SBC $FF
		STA PPILLTIMER	; set powerpill timer
		LDY #$00
@loop1:	LDX PENALTY,Y
		BNE @skip7		; is monster waiting in cage already?
		LDA #$06		; no, make monster blue
		STA SPRITECLR+1,Y
		LDA #$80		; make monster fleeing (0)
		STA SPRITEIMG1+1,Y
@skip7:	INY
		CPY #$04
		BNE @loop1
@skip8:	LDA PPILLTIMER
		BEQ CHASING		; are monsters fleeing?
		CMP #$41		; yes ... but are they
		BCS @skipA		; getting confidence back?
		AND #$08		; yes, let's warn quikman
		BEQ @skipA
		LDY #$00
@loop2:	LDA SPRITEIMG1+1,Y
		CMP #$80		; is monster fleeing?
		BNE @skip9
		LDA SPRITECLR+1,Y
		EOR #$07		; flash white / blue
		STA SPRITECLR+1,Y
@skip9:	INY
		CPY #$04
		BNE @loop2
@skipA:	DEC PPILLTIMER	; drain powerpill
		BNE SR12D3		; is there still power left?
;
;($12C1)
; restore all monsters to their default colors and chase mode
CHASING:
		LDY #$00
@loop:	LDA MONSTERCLR,Y
		STA SPRITECLR+1,Y
		LDA #$78		; restore monster chasing image (/)
		STA SPRITEIMG1+1,Y
		INY
		CPY #$04		; four monsters
		BNE @loop
;
;($12D3)
SR12D3:
		JSR PAUSING		; is the action pausing?
		NOP
		NOP
		LDX #$00
		LDA PPILLFLAG
		BEQ @skip1		; just swallowed a powerpill?
		LDA #$00		; yes ...
		STA $3B			; account for that action
		LDA #$02		; start scoring @ 200-points
		STA FLEEINGSCORE
@skip1:	LDY #$00
SR12E8:	LDA SPRITEX
		CMP SPRITEX+2,Y
		BNE @skip3
		LDA SPRITEY
		SEC
		SBC SPRITEY+2,Y
		BCS @skip2
		EOR #$FF
@skip2:	CMP #$05
		BCS @skip3
		LDX #$FF
		BNE ENGAGED		; is quikman engaged with a monster?
@skip3:	LDA SPRITEY
		CMP SPRITEY+2,Y
		BNE NEXTKISS
		LDA SPRITEX
		SEC
		SBC SPRITEX+2,Y
		BCS @skip4
		EOR #$FF
@skip4:	CMP #$05
		BCS NEXTKISS
		LDX #$FF
		BNE ENGAGED		; is quikman engaged with a monster?
;
;($131E)
NEXTKISS:
		INY				; increment for next
		INY				; X,Y coord pair check
		CPY #$08
		BCC SR12E8
		BCS MONSTERS	; quikman is still freely running!
;
;($1326)
ENGAGED:
		TYA
		LSR
		TAX
		LDA SPRITEIMG1+1,X
		CMP #$80		; is monster fleeing?
		BEQ CAUGHTONE	; ahah!
		LDY #$00		; ooops... quikman got it
		LDX #$00
@loop2:	INX				; bad wait loop
		BNE @loop2
		INY
		BNE @loop2
		DEC LIVES
		BNE DEAD		; any lives remaining?
		JMP RESTART		; game over
;
;($1341)
DEAD:
		LDX LIVES
		LDA #$20
		STA $1FE3,X		; erase avatar
		JMP DEATH
;
;($134B)
CAUGHTONE:
		LDA #$09
		STA DIGIT		; in hundreds
		LDA FLEEINGSCORE
		STA POINTS		; fleeing monster score
		ASL				; next is worth x2 bonus
		STA FLEEINGSCORE
		LDA #$78
		STA SPRITEIMG1+1,X		; reset monster as chasing
		LDA MONSTERCLR,X
		STA SPRITECLR+1,X
		TXA
		ASL
		TAX
		LDA #$50		; reset "X" coord in cage
		STA $02A4,X
		LDA #$58		; reset "Y" coord in cage
		STA $02A5,X
		NOP
		JSR SR106E
		CLC
		BCC NEXTKISS	; is there another monster here?
;
;($1375)
MONSTERS:
		SEI				; lock-out any background changes
QUIKMAN:
		LDA PPILLTIMER
		AND #$01		; during fleeing mode, all monsters move
		BNE CONT		; every-other frame, regardless
		LDA #$01
		STA $00			; start with monster #1
;
;($1380)
DOMONSTER:
		ASL
		STA $01
		LDY $00
		LDX $4A,Y
		BEQ ITMOVES		; is this monster free to roam?
		DEX				; no, countdown to freedom
		STX $4A,Y
;
;($138C)
NEXTMONSTER:
		INC $00			; process next monster
		LDA $00
		CMP #$05		; all 5-sprites processed?
		BCC DOMONSTER
CONT:	JSR $1CCF		; issues
		JMP PLAYLOOP
;
ITMOVES:
		LDX $01			; get pairing index
		LDA SPRITEX,X
		CMP #$50
		BNE @skip1
		LDA SPRITEY,X
		CMP #$58
		BNE @skip1		; is monster in cage ($50,$58 coord) doorway ?
		LDA #$57		; could have just used DEC SPRITEY,X instead
		STA SPRITEY,X	; move it a pixel UP to force it through the closed door
		LDX #$03
		STX $4E,Y		; make direction UP to get out of cage
		BNE @skip3
@skip1:	LDA SPRITEX,X
		BNE @skip2		; is monster against the left-side of the tunnel?
		LDX $00
		STA $4E,X		; force a change of direction to the right
@skip2:	CMP #$9F		; is monster against the right-side of the tunnel?
		BNE @skip3
		LDX $00
		LDA #$02
		STA $4E,X		; force a change of direction to the left
@skip3:	LDY #$00
		LDX #$00
@loop1:	STX $61,Y		; preset move priority as 0=right,1=down,2=left,3=up
		INY
		INX
		CPX #$04
		BCC @loop1
		LDY $01			; start of monster's calculated move
		LDA SPRITEX,Y
		AND #$07
		BEQ @skip4		; is monster horizontally aligned with a screen cell?
		LDA SPRITEY,Y
		AND #$07
		BNE @skip5		; is monster vertically aligned with a screen cell?
@skip4:	JSR SR1457		; yes, check to see if a direction change is in its future
		CLC
		BCC @skip6
@skip5:	LDX $4E,Y		; not in a position to make a direction change,
		STX $61			; so just keep monster going in its current direction
@skip6:	LDY #$00
		STY $04
@loop2:	LDX $61,Y
		TXA
		LDX $00
		EOR $4E,X
		CMP #$02
		BEQ @skip7		; don't allow monsters to reverse direction on their own
		LDX $61,Y
		STX NEWDIR
		LDY $00
		LDX $4E,Y
		STX OLDDIR
		JSR MAZEMOVE	; validate
		BCC MAKEMOVE	; is this a good move?
@skip7:	INC $04
		LDY $04
		CPY #$04
		BNE @loop2
		JMP NEXTMONSTER
		NOP				; legacy reasons
;
; preload $61-$64 with "best" moves this monster can make
; to give quikman the kiss of death
;($1418)
AI:
		LDX $01
		LDA $51,X		; retrieve this monster's "X" knowledge where quikman was
		SEC
		SBC SPRITEX,X
		BCS @skip1
		LDY #$02
		STY $61			; LEFT is best
		LDY #$00
		STY $64			; RIGHT is worst
		BEQ @skip2
@skip1:	LDY #$00
		STY $61			; RIGHT is best
		LDY #$02
		STY $64			; LEFT is worst
@skip2:	LDA $52,X		; retrieve this monster's "Y" knowledge where quikman was
		SEC
		SBC SPRITEY,X
		BCS @skip3
		LDY #$03
		STY $62			; UP is 2nd best
		LDY #$01
		STY $63			; DOWN is 3rd best
		RTS
@skip3:	LDY #$01		; DOWN is 2nd best
		STY $62
		LDY #$03		; UP is 3rd best
		STY $63
		RTS
;
;($144E)
MAKEMOVE:
		LDY $00			; commit to this move
		LDX NEWDIR
		STX $4E,Y		; save as monster's current direction
		JMP NEXTMONSTER
;
; prioritize monster move, based upon its current location in respect to
; its knowledge where quikman was considered last.
;$(1457)
SR1457:
		JSR AI			; make monsters with varying intelligence
		LDX $01
		LDA $51,X
		SEC
		SBC SPRITEX,X
		BCS @skip1
		EOR #$FF
@skip1:	STA $69
		LDA $52,X
		SEC
		SBC SPRITEY,X
		BCS @skip2
		EOR #$FF
@skip2:	CMP $69
		BCC @skip3		; can monster improve upon order of choices?
		NOP
		LDX $61			; swap 1st & 2nd choices
		LDY $62
		STX $62
		STY $61
		LDY $63			; swap 3rd & 4th choices
		LDX $64
		STY $64
		STX $63
@skip3:	LDA $10
		BEQ @fini		; monsters are in chase mode
		LDX #$00
@loop1:	LDA $61,X
		PHA
		INX
		CPX #$04
		BNE @loop1
		LDX #$00
@loop2:	PLA
		STA $61,X		; reverse logic when in flee mode
		INX
		CPX #$04
		BNE @loop2
@fini:	RTS
;
; some sound effects and extras
;($14A0)
SR14A0:
		LDA CHEWING
		BEQ @skip1
		LDA #$91		; start with an odd frequency
		STA VIC+$0C		; ignite a voice
@skip1:	LDA #$00		; dot is swallowed
		STA CHEWING
		LDA VIC+$0C
		BEQ @next1		; is this voice mute?
		LDA VIC+$0C
		AND #$01
		BEQ @skip3		; is it even?
		LDA VIC+$0C
		CLC
		ADC #$10		; increase tone
		CMP #$F1
		BCC @skip2		; is voice too high?
		SEC
		SBC #$01		; make it even
@skip2:	STA VIC+$0C
		CLC
		BCC @next1		; goto next effect
@skip3:	LDA VIC+$0C
		SEC
		SBC #$10		; drain tone
		STA VIC+$0C
@next1:	LDX CHOMP
		BEQ @skip4
		LDA SNDBIT,X	; load tone data
		STA VIC+$0B
		DEC CHOMP
@skip4:	LDA VIC+$0E
		BNE @next2
		STA EXTRAQMAN	; reset bonus when volume is mute
@fini:	RTS
@next2:	LDA EXTRAQMAN
		BNE @fini
		LDA SCORE+1
		CMP #$B1		; did quikman just score 10,000-points?
		BNE @fini
		STA EXTRAQMAN
		INC LIVES		; reward
		LDA #$09
		STA CHOMP		; make some noise
		RTS
;
;($1500)
SR1500:
		LDY #$00
SR1502:	STY $03F0
		LDA $03F0
		ASL
		STA $03F1
		ASL
		STA $03F2
		CLC
		BCC SR1567		; go there to check this, then come back (JSR)
SR1513:	LDA CAGEDATA,Y
		BEQ AWARENESS	; is monster "smart"?  Red one is ...
		CMP JIFFYL		; no, so check as often as it waits
		BEQ AWARENESS	; is its wait time equal to the jiffy clock?
SR151C:	LDY $03F0
		INY
		CPY #$04
		BNE SR1502
		RTS
;
; update this monster's awareness to where quikman is
;($1525)
AWARENESS:
		LDY $03F1
		LDX SPRITEX
		STX $53,Y
		LDX SPRITEY
		STX $54,Y
		CLC
		BCC SR151C
;
;($1535)
NEXTLEVEL:
		JSR INITVARS
		LDX #$04
@loop1:	LDA $4A,X
		LDY FRUITLEVEL
		INY
@loop2:	LSR
		DEY
		BNE @loop2
		STA $4A,X		; after each level, the monsters dispatch quicker
		DEX
		BNE @loop1
		JMP RESETSND
;
;($154B)
RESURRECT:
		JSR INITVARS
		JMP RESETCHR
;
;($1551)
PAUSING:
		LDA CTRLCSHIFT	; is the player holding down any
		BNE PAUSING		; control, commodore, shift key(s)?
		RTS
;
;($1557)
		.byte	$00, $00, $00, $00, $00, $00
SNDBIT:	.byte	$00, $00, $C0, $B8, $B0, $A8, $B0, $B8, $C0, $C8
;
;($1567)
SR1567:
		LDY $03F2
		LDA DOTS
		CMP #$AA		; make them all "smart" when nearing the end
		BCS AWARENESS
		BCC SR1513
;
;($1572)
		.byte	$00, $00, $00, $00
;
;($1576)
INITVARS:
		LDY #$00
@loop:	LDX CAGEDATA,Y
		STX PENALTY,Y
		INY
		CPY #$10
		BNE @loop
		RTS
;
;($1583)	zero $3A - $43
ZEROVARS:
		LDY #$3A
		LDX #$00
@loop:	STX $00,Y
		INY
		CPY #$44
		BNE @loop
		RTS
;
;($158F)
ADDSCORE:
		LDY POINTS
		BNE @skip1
		RTS
@skip1:	LDX DIGIT
@loop1:	LDA ScreenData,X
		CMP #$B9		; reach "9" ?
		BEQ @skip2
		INC ScreenData,X		; ding!
		DEY
		BNE @skip1
		RTS
@skip2:	LDA #$B0
		STA ScreenData,X		; wrap to "0"
		DEX				; and increment next order
		CLC
		BCC @loop1
;
;$(15AD)
JOYSTICK:
		LDX JOYVAL		; recall last joystick value
		LDA #$00
		STA $9113
		LDA #$7F
		STA $9122
		LDA $9120
		AND #$80		; JOY 3
		BNE @skip1
		LDX #$00
@skip1:	LDA #$FF
		STA $9122
		LDY $9111
		TYA
		AND #$08
		BNE @skip2
		LDX #$01
@skip2:	TYA
		AND #$10
		BNE @skip3
		LDX #$02
@skip3:	TYA
		AND #$04
		BNE @skip4
		LDX #$03
@skip4:	STX JOYVAL		; save
		RTS
;
;($15E2) Refresh screen
REDRAW:
		INC FRUITLEVEL
		LDA #$93		; Shift-HOME is clearscreen
		JSR	CHROUT		; print it
		LDX #$14		; skip 1st row -- scoring information
		LDY #$00
@loop:	LDA ScreenData,X
		STA $1E00,X
		LDA ScreenData+$0100,Y
		STA $1F00,Y
		INY
		INX
		BNE @loop
		STX DOTS		; and no dots are eaten (yet)
		RTS
;
;($1600)
BANNERMSG:
				;©1984 ROBERT HURST
		.byte	$3F, $B1, $B9, $B8, $B4, $A0, $92, $8F, $82, $85, $92, $94, $A0, $88, $95, $92, $93, $94
				;PRESS 'F7' TO PLAY
		.byte	$90, $92, $85, $93, $93, $A0, $A7, $86, $B7, $A7, $A0, $94, $8F, $A0, $90, $8C, $81, $99
;
;($1624)		cherry, strawberry, 2-peach, 2-apple, 2-pineapple, 2-tbird, 2-bell, key
FRUIT:	.byte	$22, $23, $24, $24, $25, $25, $26, $26, $27, $27, $28, $28, $29
;
;($1631)		red, red, 2-yellow, 2-red, 2-green, 2-magenta, 2-yellow, cyan
FRUITCLR:
		.byte	$02, $02, $07, $07, $02, $02, $05, $05, $04, $04, $07, $07, $03
;($163E)
STARTPOS:
		.byte	$50, $88, $50, $48, $50, $58, $60, $58, $40, $58
;
;($1648)
;animate the quikman
ANIMQMAN:
		LDX #$50		; closed mouth
		LDA JIFFYL
		AND #$04		; flip every 4-jiffies
		BEQ @skip1
		LDA QMANDIR		; take 0=right,1=down,2=left,3=up value
		ASL				; multiply by 8 to get address
		ASL
		ASL
		CLC
		ADC #$58		; add base offset
		TAX
@skip1:	LDY #$00
@loop1:	LDA $1D00,X		; copy a quikman image
		STA $1CE8,Y		; into its sprite
		INX
		INY
		CPY #$08
		BNE @loop1
		RTS
;
; if move is valid, carry flag will be clear on return
;($1668)
MAZEMOVE:
		LDY $01			; get X,Y coord index
		LDA OLDDIR		; get the last direction moving
		AND #$01		; mask UP/DOWN
		BEQ @skip1		; is direction LEFT/RIGHT?
		INY				; no, then fetch the "Y" coordinate
@skip1:	LDA SPRITEX,Y	; get one of sprite's coord
		AND #$07
		BEQ MAZEANY		; at a crossroad?  check move in any 4-directions
		LDA NEWDIR
		CMP OLDDIR
		BEQ MYMOVE		; still want to move in the same direction?
		EOR OLDDIR
		CMP #$02
		BEQ MYMOVE		; is this a reverse direction request?
		SEC				; no new move made
		RTS
;
;($1686)
MAZEANY:
		JSR SPRITEPREP
		LDA $FD
		SEC				; this should point to >ScreenData
		SBC #$07		; reset screen hi-byte back into saved maze data
		STA $FD
		LDX NEWDIR
		CPX #$02
		BCS @skip2		; is X (2=left) or (3=up)?
		LDA $FC			; no
		CLC
		ADC PEEKAHEAD,X	; look (0=right) or (1=down)
		BCC @skip1
		INC $FD
@skip1:	STA $FC
		CLC
		BCC @skip4		; go validate
@skip2:	LDA $FC
		SEC
		SBC PEEKAHEAD-2,X
		BCS @skip3		; look (2=left) or (3=up)
		DEC $FD
@skip3:	STA $FC
@skip4:	LDY #$00		; validate
		LDA ($FC),Y
		CMP #$31		; is this direction into a maze wall?
		BCC MYMOVE		; good move?
		RTS
;
; continue this sprite's move in whatever is loaded in NEWDIR
;($16BA)
MYMOVE:
		LDA NEWDIR
		ASL				; 0=0, 1=2, 2=4, 3=6
		TAX
		LDY $01
		LDA INERTIA,X
		CLC
		ADC SPRITEX,Y
		STA SPRITEX,Y
		LDA INERTIA+1,X
		CLC
		ADC SPRITEY,Y
		STA SPRITEY,Y
		CLC
		RTS
;
;($16D6)
PEEKAHEAD:	.byte	$01, $15
INERTIA:	.byte	$01, $00, $00, $01, $FF, $00, $00, $FF
FRUITSCORE:	.byte	$01, $03, $05, $07, $0A, $14, $1E, $32
			.byte	$00, $00, $00, $00, $00, $00, $00, $00
;($16F0)
CAGEDATA:	.byte	$00, $30, $70, $F0
			.byte	$02, $03, $02, $00, $A0, $18, $A0, $18, $A0, $18, $A0, $18
;
; Maze data ($1700 - $18FF)
; Screen size: 24-rows by 21-columns
ScreenData:
SCORE	= $1706
		.byte	$93, $83, $8F, $92, $85, $BA, $B0, $B0, $B0, $B0, $B0, $B0, $A0, $A0, $A0, $B0, $B2, $B0, $B0, $B0, $B0
		.byte	$37, $3A, $3A, $3A, $3A, $3A, $3A, $3A, $3A, $3A, $3D, $3A, $3A, $3A, $3A, $3A, $3A, $3A, $3A, $3A, $38
		.byte	$39, $1E, $1E, $1E, $1E, $1E, $1E, $1E, $1E, $1E, $39, $1E, $1E, $1E, $1E, $1E, $1E, $1E, $1E, $1E, $39
		.byte	$39, $1E, $37, $38, $1E, $37, $3A, $3A, $38, $1E, $39, $1E, $37, $3A, $3A, $38, $1E, $37, $38, $1E, $39
		.byte	$39, $1F, $35, $36, $1E, $35, $3A, $3A, $36, $1E, $32, $1E, $35, $3A, $3A, $36, $1E, $35, $36, $1F, $39
		.byte	$39, $1E, $1E, $1E, $1E, $1E, $1E, $1E, $1E, $1E, $1E, $1E, $1E, $1E, $1E, $1E, $1E, $1E, $1E, $1E, $39
		.byte	$39, $1E, $37, $38, $1E, $31, $1E, $33, $3A, $3A, $3D, $3A, $3A, $34, $1E, $31, $1E, $37, $38, $1E, $39
		.byte	$39, $1E, $39, $39, $1E, $39, $1E, $1E, $1E, $1E, $39, $1E, $1E, $1E, $1E, $39, $1E, $39, $39, $1E, $39
		.byte	$39, $1E, $35, $36, $1E, $3B, $3A, $3A, $34, $20, $32, $20, $33, $3A, $3A, $3C, $1E, $35, $36, $1E, $39
		.byte	$39, $1E, $1E, $1E, $1E, $39, $20, $20, $20, $20, $20, $20, $20, $20, $20, $39, $1E, $1E, $1E, $1E, $39
		.byte	$35, $3A, $3A, $38, $1E, $39, $20, $37, $3A, $3A, $C5, $3A, $3A, $38, $20, $39, $1E, $37, $3A, $3A, $36
		.byte	$3A, $3A, $3A, $36, $1E, $32, $20, $39, $20, $20, $20, $20, $20, $39, $20, $32, $1E, $35, $3A, $3A, $3A
		.byte	$20, $20, $20, $20, $1E, $20, $20, $35, $3A, $3A, $3A, $3A, $3A, $36, $20, $20, $1E, $20, $20, $20, $20
		.byte	$3A, $3A, $3A, $38, $1E, $31, $20, $20, $20, $20, $20, $20, $20, $20, $20, $31, $1E, $37, $3A, $3A, $3A
		.byte	$37, $3A, $3A, $36, $1E, $32, $20, $33, $3A, $3A, $3D, $3A, $3A, $34, $20, $32, $1E, $35, $3A, $3A, $38
		.byte	$39, $1E, $1E, $1E, $1E, $1E, $1E, $1E, $1E, $1E, $39, $1E, $1E, $1E, $1E, $1E, $1E, $1E, $1E, $1E, $39
		.byte	$39, $1E, $33, $38, $1E, $33, $3A, $3A, $34, $1E, $32, $1E, $33, $3A, $3A, $34, $1E, $37, $34, $1E, $39
		.byte	$39, $1F, $1E, $39, $1E, $1E, $1E, $1E, $1E, $1E, $20, $1E, $1E, $1E, $1E, $1E, $1E, $39, $1E, $1F, $39
		.byte	$3B, $34, $1E, $32, $1E, $31, $1E, $33, $3A, $3A, $3D, $3A, $3A, $34, $1E, $31, $1E, $32, $1E, $33, $3C
		.byte	$39, $1E, $1E, $1E, $1E, $39, $1E, $1E, $1E, $1E, $39, $1E, $1E, $1E, $1E, $39, $1E, $1E, $1E, $1E, $39
		.byte	$39, $1E, $33, $3A, $3A, $3E, $3A, $3A, $34, $1E, $32, $1E, $33, $3A, $3A, $3E, $3A, $3A, $34, $1E, $39
		.byte	$39, $1E, $1E, $1E, $1E, $1E, $1E, $1E, $1E, $1E, $1E, $1E, $1E, $1E, $1E, $1E, $1E, $1E, $1E, $1E, $39
		.byte	$35, $3A, $3A, $3A, $3A, $3A, $3A, $3A, $3A, $3A, $3A, $3A, $3A, $3A, $3A, $3A, $3A, $3A, $3A, $3A, $36
		.byte	$A0, $A0, $A0, $A0, $A0, $A0, $A0, $A0, $A0, $A0, $A0, $A0, $A0, $A0, $A0, $A0, $A0, $A0, $A0, $A0, $A0
;
; sprite colors (0-7)
QUIKMANCLR:
		.byte	$07		; yellow
MONSTERCLR:
		.byte	$02, $05, $03, $07	; red, green, cyan, yellow
		.byte	$00, $00, $00		; not used
;
;($1900) recolor maze paint every 8-jiffies ...
MAZEPAINT:
		LDX #$00
@loop:	LDA ScreenData,X
		CMP #$31
		BCC @skip1
		CMP #$3F
		BCS @skip1
		LDA MAZE
		STA $9600,X
@skip1:	LDA ScreenData+$0100,X
		CMP #$31
		BCC @skip2
		CMP #$3F
		BCS @skip2
		LDA MAZE
		STA $9700,X
@skip2:	INX
		BNE @loop
;
; powerpill flash every 30-jiffies
EFFECTS:
		LDA FLASHPILL
		CMP #$1E		; 30-jiffies?
		BNE @skip1
		LDX #$00		; reset counter
		STX FLASHPILL
@loop1:	LDA $1CF8,X		; custom graphic char
		EOR $8288,X		; rom graphic char
		STA $1CF8,X		; redraw 8x8 char cell
		INX
		CPX #$08
		BNE @loop1
		LDA #$FE		; render monster feet
		EOR $1D7F		; custom graphic char
		STA $1D7F		; redraw agressive monster
		STA $1D87		; redraw fleeing monster
@skip1:	INC FLASHPILL
		INC BANNERTIMER
		LDA VIC+$0E
		BNE @skip3		; playing?
		LDX BANNERTIMER	; no, could replace this with JIFFYL
		BNE @skip3
		LDX #$00
		INC BANNERFLAG
		LDA BANNERFLAG
		AND #$01
		BEQ @skip2
		LDX #$12
@skip2:	LDY #$00
@loop2:	LDA BANNERMSG,X
		STA $1FE5,Y
		INX
		INY
		CPY #$12
		BNE @loop2
@skip3:	LDA VIC+$0E
		BEQ @top		; playing?
		LDX #$00		; yes
@loop3:	LDA SCORE,X		; check current score against high score
		CMP ScreenData+$0F,X
		BCC @top		; is quikman beating the high score?
		BNE @skip4		; yes!
		INX
		CPX #$06
		BNE @loop3
@skip4:	LDX #$00
@loop4:	LDA SCORE,X		; woot!
		STA ScreenData+$0F,X
		INX
		CPX #$06
		BNE @loop4
@top:	LDX #$00		; refresh top line
@loop5:	LDA ScreenData,X
		STA $1E00,X
		INX
		CPX #$15
		BNE @loop5
		JSR ANIMQMAN	; update area pointed to by SPRITEIMG1&2
		JSR JOYSTICK
		JSR ADDSCORE
		STY POINTS
		JMP SR105F
;
;($19AD)
DEATH:
		SEI			; don't bother with anything else
		LDA #$01	; only feature quikman dying
		STA SPRITE
		JSR SPRITES	; redraw sprites
		LDA #$50	; low-order byte of 1st quikman image
		STA SPRITEIMG1
		LDA #$20
		STA $03A5	; rotate quikman 8 times
@loop1:	LDA #$1D	; 2nd page where quikman is on
		STA SPRITEIMG2
		LDA SPRITEIMG1
		CMP #$70	; are we at the 4th quikman image?
		BCC @skip
		LDA #$50	; reset to 1st quikman image
@skip:	CLC
		ADC #$08	; advance to next image
		STA SPRITEIMG1
		JSR SPRITES	; redraw sprites
		LDY #$D0
@loop2:	INX
		BNE @loop2	; bad wait loop
		INY
		BNE @loop2
		DEC $03A5
		BNE @loop1	; repeat next sequence
		CLI			; resume dazzling effects
		JMP RESURRECT
;
;($19E8)
		.byte	$00, $00, $00, $00
;
;($19EC)	my very own sprite routines
; custom hack for this maze game implementation
SPRITES:
		LDA #$00		; start with sprite #0
		STA $02CB
		STA $00			; current sprite # to render
sprloop:
		ASL
		STA $01			; current sprite (x2) pairing index
		ASL
		ASL
		STA $02			; current sprite (x8) image index
		LDX $00
		LDA SPRITE
		AND SPRITEMASK,X
		BEQ @skip2		; nothing to do?
		LDA SPRITELAST	; what state was this sprite before?
		AND SPRITEMASK,X
		BEQ @skip1		; it was "off"
		JMP ANIMSPRITE	; was "on" before, and we still want it "on"
@skip1:	JMP ANIMSPRNOW	; skip the erase, go turn it "on"
@skip2:	LDA SPRITELAST
		AND SPRITEMASK,X
		BEQ NEXTSPRITE	; still nothing to do?  Then do nothing ...
		JSR ERASESPRITE	; make this sprite disappear
NEXTSPRITE:
		INC $00
		LDA $00
		CMP #$05		; only 5-sprites needed in this game
		BNE sprloop
		LDX #$00
@loop2:	LDA SPRITE,X	; save copy of current sprite registers
		STA SPRITELAST,X
		INX
		CPX #$11		; all 17 values, not including colors
		BNE @loop2
		RTS				; fini
;
;($1A33)	erasure part 1
LASTSPRITEPREP:
		LDA $01			; 0, 2, 4, 6, 8
		CLC
		ADC #$CD		; set register = "last"
		BNE SPRITEPREP2
;
; prepares the following registers:
; $FC/$FD	screen cell pointer for sprite's "home" position
; $FE/$FF	color cell pointer for same
;($1A3A)	erasure part 1
SPRITEPREP:
		LDA $01			; 0, 2, 4, 6, 8 index
		CLC
		ADC #$A2		; set register = "current"
SPRITEPREP2:
		TAX				; save this coordinate register index
		LDA $0200,X		; get "X" coordinate
		CMP #$A0		; is "X" at or beyond last column?
		BCC @skip1
		SBC #$A0		; subtract 160-pixels wide
@skip1:	LSR				; and divide by 8-pixel width
		LSR
		LSR
		STA $FC			; save column offset from left
		STA $FE			; save column offset from left
		LDA SCRNPAGE	; get high order byte of screen memory page
		STA $FD
		LDA $F4			; get high order byte of screen color page
		AND #$FE		; make it and "even" number
		STA $FF			; save high order
		LDA $0201,X		; get "Y" coordinate
		CMP #$B8		; is "Y" at or beyond last row?
		BCC @skip2
		SBC #$B8		; subtract 184-pixels high
@skip2:	LSR				; and divide by 8-pixel height
		LSR
		LSR
		TAY
		BEQ @fini		; if on top row, no math required
@loop1:	LDA $FC			; get column offset
		CLC
		ADC #$15		; add 21 for next row
		BCC @skip3		; overflow to next page?
		INC $FD			; yes, increment high order bytes
		INC $FF
@skip3:	STA $FC			; save column offset
		STA $FE
		DEY
		BNE @loop1		; do for each "row"
@fini:	RTS
;
;prepares saveback buffers for restoring, should a larger-numbered sprite be
;overlapping any part of a smaller-numbered sprite
;($1A7D)	erasure part 2
PREPMATRIX:
		LDY #$00		; top-left sprite cell
		STY $FB
		LDA $01			; 0, 2, 4, 6, 8 index
		ASL				; x2
		TAX
		STA $03			; save my custom char #
@loop1:	LDA #$01		; "white" color
		STA CASSBUFF,X	; 2x2 cell saveback buffer
		LDA ($FC),Y		; retrieve screen cell
@retry:	CMP $03
		BCC @skip1		; is A < $03 ?
		CMP #$1E
		BCS @skip1		; is A >= $1E ?
;there is a sprite # greater than us on top ...
		STX $04			; save X index
		PHA				; push A to stack
		TAX
		LDA CASSBUFF,X	;
		LDX $04
		STA CASSBUFF,X
		PLA				; pop A from stack
		TAX
		LDA SAVEBACK,X
		LDX $04
		CLC
		BCC @retry
@skip1:	STA SAVEBACK,X
		INX
		TYA
		LDY $FB
		CLC
		ADC CHARMATRIX,Y
		TAY
		INC $FB
		LDA $FB
		CMP #$03		; truncated from 4 to 3-cells
		BNE @loop1
		RTS
;
;puts the sprite character matrix on the screen
;($1AC1)
PLACEMATRIX:
		LDY #$00
		STY $FB
		LDX $00
		LDA $01
		ASL
		PHA
@loop1:	PLA
		STA ($FC),Y
		CLC
		ADC #$01
		PHA
		LDA SPRITECLR,X
		STA ($FE),Y
		TYA
		LDY $FB
		CLC
		ADC CHARMATRIX,Y
		TAY
		INC $FB
		LDA $FB
		CMP #$03		; truncated from 4 to 3-cells
		BNE @loop1
		PLA
		RTS
;
;restores the sprite's saveback buffer to the screen squares it occupies
;($1AE9)	erasure part 3
RESTOREMATRIX:
		LDY #$00
		STY $FB
		LDA $01
		ASL				; x2
		TAX
@loop1:	LDA SAVEBACK,X	; recover character
		STA ($FC),Y		; restore to screen
		LDA #$01
		NOP
		STA ($FE),Y		; and leave "white" behind
		INX
		TYA
		LDY $FB
		CLC
		ADC CHARMATRIX,Y
		TAY
		INC $FB
		LDA $FB
		CMP #$03		; truncated from 4 to 3-cells
		BNE @loop1
		RTS
;
;render sprite within its character matrix by merging its image over its saveback
;($1B0D)
RENDER:
		LDX $00
		LDA SPRITEIMG1,X
		STA $05
		LDA SPRITEIMG2,X
		STA $06
		LDX $01
		LDA SPRITEY,X
		AND #$07
		STA $03
		TAX				; X will hold the sprite's Y coord
		LDY #$00		; erase temp image matrix area
		TYA
@loop1:	STA CASSBUFF+$20,Y
		INY
		CPY #$18		; customized from 4 to 3 character cells
		BNE @loop1
		TAY				; copy 8x8 character image into temp matrix
@loop2:	LDA ($05),Y		; $05/$06 points to character matrix
		STA CASSBUFF+$20,X
		INX
		INY
		CPY #$08
		BNE @loop2
		LDX $01
		LDA SPRITEX,X
		AND #$07		; get modulos on X coordinate
		TAY
		BEQ @skip1		; if its zero, no shifting required
@loop3:	LDA #$00
		LDX $03
@loop4:	CLC
		ROR CASSBUFF+$20,X
		ROR CASSBUFF+$30,X
		INX
		CLC
		ADC #$01
		CMP #$08
		BNE @loop4
		DEY
		BNE @loop3
@skip1:	STY $FB			; Y is always zero here
@loop5:	LDA $01			; index x2
		ASL				; and x2 = x4
		CLC
		ADC $FB
		TAX
		LDA #$1C		; 1st page is where sprites are stored
		STA $06
		LDA SAVEBACK,X
		CMP #$80		; is character reversed?
		BCC @skip2
		LDY #$80		; yes, use start of ROM character set
		STY $06
@skip2:	AND #$1F		; get modulos of first 32-characters
		ASL				; and multiply by 8-pixel height
		ASL
		ASL
		STA $05			; save as low-order byte index
		LDA SAVEBACK,X
		AND #$60		; mask 01100000
		LSR				; divide by 16
		LSR
		LSR
		LSR
		LSR
		CLC
		ADC $06			; add result to high-order page index
		STA $06
		LDY #$00
		LDA $FB
		ASL
		ASL
		ASL
		TAX
@loop6:	LDA ($05),Y		; copy 8x8 character image into behind matrix
		STA CASSBUFF+$40,X
		INX
		INY
		CPY #$08
		BNE @loop6
		INC $FB
		LDA $FB
		CMP #$03
		BNE @loop5
		LDY #$00
@loop7:	STY $FB
		LDA CASSBUFF+$40,Y
		EOR CASSBUFF+$20,Y
		AND CASSBUFF+$20,Y
		CMP CASSBUFF+$20,Y
		BEQ @skip3
		LDX $00
		LDA SPRITEMASK,X
		ORA $02CB
		STA $02CB
@skip3:	LDA $02
		ASL
		ASL
		CLC
		ADC $FB
		TAX
		LDY $FB
		LDA	CASSBUFF+$20,Y
		ORA CASSBUFF+$40,Y
		STA $1C00,X
		INY
		CPY #$18		; customized from 4 to 3 character cells
		BNE @loop7
		RTS
;
;($1BD9)
ANIMSPRITE:
		JSR ERASESPRITE
ANIMSPRNOW:
		JSR SPRITEPREP
		JSR PREPMATRIX
		JSR RENDER
		JSR PLACEMATRIX
		JMP NEXTSPRITE
;
;$(1BEB)
ERASESPRITE:
		JSR LASTSPRITEPREP
		JSR PREPMATRIX
		JSR RESTOREMATRIX
		RTS
;
;($1BF5 - $1BFF)
CHARMATRIX:
		.byte	$15, $EC, $15
SPRITEMASK:
		.byte	$01, $02, $04, $08, $10, $20, $40, $80
;
; Custom character data ($1C00 - $1DFF)
GraphicData:
		.byte	$3E, $7C, $F8, $F0, $F0, $F8, $7C, $3E
		.byte	$00, $FF, $00, $00, $00, $00, $81, $42
		.byte	$00, $00, $00, $18, $18, $00, $00, $00
		.byte	$00, $FF, $00, $00, $00, $00, $FF, $00
		.byte	$38, $7C, $FE, $92, $FE, $FE, $FE, $AA
		.byte	$00, $FF, $00, $00, $00, $00, $00, $00
		.byte	$00, $00, $00, $00, $00, $00, $00, $00
		.byte	$00, $FC, $02, $01, $01, $02, $FC, $00
		.byte	$38, $7C, $FE, $92, $FE, $FE, $FE, $AA
		.byte	$00, $FF, $00, $00, $00, $00, $FF, $00
		.byte	$00, $00, $00, $00, $00, $00, $00, $00
		.byte	$18, $24, $42, $42, $42, $42, $42, $42
		.byte	$38, $7C, $FE, $92, $FE, $FE, $FE, $AA
		.byte	$00, $FF, $00, $00, $00, $00, $FF, $00
		.byte	$42, $42, $42, $42, $42, $42, $42, $42
		.byte	$00, $FF, $00, $00, $00, $00, $FF, $00
		.byte	$38, $7C, $FE, $92, $FE, $FE, $FE, $AA
		.byte	$00, $FF, $00, $00, $00, $00, $FF, $00
		.byte	$00, $00, $00, $00, $00, $00, $00, $00
		.byte	$42, $42, $42, $42, $42, $42, $24, $18
;
;($1CA0)
GAMEOVER:
		LDA VIC+$0E		; no sound?
		BEQ @skip1
		RTS				; yes, must be playing game
@skip1:	LDY #$00		; no, paint for banners
		LDA #$03		; use cyan
@loop1:	STA $97E3,Y		; color RAM
		INY
		CPY #$15		; do the whole row
		BNE @loop1
		LDA #$20		; use a space
		STA $1FE3
		STA $1FF7
		LDX FRUITLEVEL
		CPX #$0C
		BCC @skip2
		LDX #$0C
@skip2:	LDA FRUIT,X
		STA FRUITCELL	; display final level achieved
		LDA FRUITCLR,X
		STA FRUITCELLCLR
		RTS
;
;($1CCF)
SR1CCF:
		LDA CHEWING		; is quikman eating a dot?
		CLI
		BNE @skip1
		JSR SPRITES
		RTS
@skip1:	JSR SPRITES
		PLA
		PLA
		JMP QUIKMAN
;
; resume graphic character data
;($1CE0)
		.byte	$00, $00, $00, $00, $00, $00, $00, $00	;
		.byte	$3C, $7E, $FF, $FF, $FF, $FF, $7E, $3C	; ] pacman animated
		.byte	$00, $00, $00, $18, $18, $00, $00, $00	; ^ dot
		.byte	$00, $3C, $7E, $7E, $7E, $7E, $3C, $00	; <- powerpill animated
		.byte	$00, $00, $00, $00, $00, $00, $00, $00	;   empty space
		.byte	$92, $54, $28, $C6, $28, $54, $92, $00	; ! explosion
		.byte	$04, $08, $18, $24, $62, $F7, $F2, $60	; " cherry
		.byte	$10, $7C, $FE, $AA, $D6, $AA, $54, $28	; # strawberry
		.byte	$20, $10, $7C, $FE, $FE, $FE, $7C, $38	; $ peach
		.byte	$08, $10, $7C, $FE, $FE, $FE, $7C, $28	; % apple
		.byte	$08, $10, $38, $38, $7C, $FE, $FE, $6C	; & pear
		.byte	$10, $30, $92, $FE, $7C, $38, $10, $28	; ' tbird
		.byte	$10, $38, $7C, $7C, $7C, $7C, $FE, $10	; ( bell
		.byte	$18, $24, $18, $08, $08, $18, $08, $18	; ) key
		.byte	$3C, $7E, $FF, $FF, $FF, $FF, $7E, $3C	; * pacman closed
		.byte	$3E, $7C, $F8, $F0, $F0, $F8, $7C, $3E	; + pacman right
		.byte	$3C, $7E, $FF, $FF, $E7, $C3, $81, $00 ; , pacman down
		.byte	$7C, $3E, $1F, $0F, $0F, $1F, $3E, $7C	; - pacman left
		.byte	$00, $81, $C3, $E7, $FF, $FF, $7E, $3C	; . pacman up
		.byte	$38, $7C, $FE, $92, $FE, $FE, $FE, $AA	; / ghost chasing
		.byte	$38, $7C, $FE, $92, $FE, $82, $FE, $AA	; 0 ghost fleeing
		.byte	$18, $24, $42, $42, $42, $42, $42, $42	; 1 maze wall north
		.byte	$42, $42, $42, $42, $42, $42, $24, $18	; 2 maze wall south
		.byte	$00, $3F, $40, $80, $80, $40, $3F, $00	; 3 maze wall west
		.byte	$00, $FC, $02, $01, $01, $02, $FC, $00	; 4 maze wall east
		.byte	$42, $41, $40, $40, $40, $20, $1F, $00	; 5 maze wall s-w elbow
		.byte	$42, $82, $02, $02, $02, $04, $F8, $00	; 6 maze wall s-e elbow
		.byte	$00, $1F, $20, $40, $40, $40, $41, $42	; 7 maze wall n-w elbow
		.byte	$00, $F8, $04, $02, $02, $02, $82, $42	; 8 maze wall n-e elbow
		.byte	$42, $42, $42, $42, $42, $42, $42, $42	; 9 maze wall vertical
		.byte	$00, $FF, $00, $00, $00, $00, $FF, $00	; : maze wall horizontal
		.byte	$42, $41, $40, $40, $40, $40, $41, $42	; ; maze wall west tee
		.byte	$42, $82, $02, $02, $02, $02, $82, $42	; < maze wall east tee
		.byte	$00, $FF, $00, $00, $00, $00, $81, $42	; = maze wall north tee
		.byte	$42, $81, $00, $00, $00, $00, $FF, $00	; > maze wall south tee
		.byte	$3C, $42, $99, $A1, $A1, $99, $42, $3C	; ? copyright symbol
