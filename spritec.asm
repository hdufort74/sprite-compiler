;=============================================================
;SPRITE COMPILER MODULE
; by Hugo Dufort
; This module has no external dependencies.
; The only public function is compile_sprite().
; Other structures and functions are internal to the compiler and should not be modified.
; The smallest sprite it can compile is 2x1, and the largest would be 126x127.
; The horizontal dimension (width) should always be an even value (2, 4, ..) as we are working on words not bytes.
;=============================================================


CODE_PTR		fdb		s00_00,s00_0N,s00_M0,s00_MN,s_0L_00,s_0L_0N,s_0L_M0,s_0L_MN
			fdb		s_K0_00,s_K0_0N,s_K0_M0,s_K0_MN,s_KL_00,s_KL_0N,s_KL_M0,s_KL_MN

CODE_PARA		fdb		0,0,0,0
			fdb		s_0L_00_A,s_0L_0N_D,s_0L_M0_D,s_0L_MN_A
			fdb		s_K0_00_A,s_K0_0N_D,s_K0_M0_D,s_K0_MN_A
			fdb		s_KL_00_A,s_KL_0N_A,s_KL_M0_A,s_KL_MN_D

CODE_PARB		fdb		0,s00_0N_B,s00_M0_B,s00_MN_B
			fdb		0,s_0L_0N_D+1,s_0L_M0_D+1,s_0L_MN_B
			fdb		0,s_K0_0N_D+1,s_K0_M0_D+1,s_K0_MN_B
			fdb		0,s_KL_0N_B,s_KL_M0_B,s_KL_MN_D+1

CODE_LEN		fcb		s00_0N-s00_00,s00_M0-s00_0N,s00_MN-s00_M0,s_0L_00-s00_MN	;cases 0-3
			fcb		s_0L_0N-s_0L_00,s_0L_M0-s_0L_0N,s_0L_MN-s_0L_M0,s_K0_00-s_0L_MN	;cases 4-7
			fcb		s_K0_0N-s_K0_00,s_K0_M0-s_K0_0N,s_K0_MN-s_K0_M0,s_KL_00-s_K0_MN	;cases 8-11
			fcb		s_KL_0N-s_KL_00,s_KL_M0-s_KL_0N,s_KL_MN-s_KL_M0,s_END-s_KL_MN	;cases 11-15
			
;=============================================================
; Public Function compile_sprite()
; IN  regU:sprite bytes pointer (source)
; IN  regX:destination pointer (compiled code)
; IN  regA:width in bytes (2..126)
; IN  regB:height (lines) in bytes (1..127)
; OUT regX:upon returning, points to the end of the compiled data
; MODIFIED x,y,u,d
;=============================================================
Z_COUNT			fdb		0	;counts zeros (transparent bytes)
TEMP_D			fdb		0
CODE_OFS		fcb		0
LINES_CNT		fcb		0
WORDS_CNT		fcb		0
WORDS_REF		fdb		0	;<--word, number of loop turns per line
LINE_SKIP		fdb		0	;<--word, number of bytes to skip (160-2*WORDS_REF)
compile_sprite
			;clear the transparency bytes counter
			clr		Z_COUNT
			clr		Z_COUNT+1
			lsra		;we count words, not bytes, in the loop
			stb		LINES_CNT
			sta		WORDS_CNT
			clr		WORDS_REF
			sta		WORDS_REF+1
			ldd		#160
			subd		WORDS_REF
			subd		WORDS_REF			
			std		LINE_SKIP
@loop			;check end of line (EOL)
			tst		WORDS_CNT
			bne		@no_EOL	;if nonzero, not end of line
			ldd		LINE_SKIP
			addd		Z_COUNT
			std		Z_COUNT
			;reset horizontal words counter
			lda		WORDS_REF+1
			sta		WORDS_CNT
			;next line
			dec		LINES_CNT
			bne		@no_EOL	;not the last line
			ldb		#$39
			stb		,x+
			rts
@no_EOL			ldd		,u++
			std		TEMP_D
			clra
@nib_b0			bitb		#%00001111	;check if we have a right pixel (nonzero nibble)
			beq		@nib_b1
			adda		#2
@nib_b1			bitb		#%11110000	;check if we have a left pixel (nonzero nibble)
			beq		@nib_a0
			adda		#4
@nib_a0			ldb		TEMP_D
			bitb		#%00001111		;check if we have a right pixel (nonzero nibble)
			beq		@nib_a1
			adda		#8
@nib_a1			bitb		#%11110000		;check if we have a left pixel (nonzero nibble)
			beq		@count
			adda		#16
@count			pshs		u
			sta		CODE_OFS	;offset used to access the 4 LUTs (code ptr, param A, param B, code len)
			ldy		#CODE_PARA
			ldu		a,y		;load ptr to code block for A
			cmpu		#0
			beq		@skip_a	;if ptr==0, z=z+1
			;flush z count here (if nonzero)
			ldy		Z_COUNT
			jsr		__append_LEA
			clr		Z_COUNT
			clr		Z_COUNT+1
			;insert parameter A right after opcode
			lda		TEMP_D
			sta		1,u
			jmp		@test_b
@skip_a			ldd		Z_COUNT
			addd		#1
			std		Z_COUNT
@test_b			ldy		#CODE_PARB
			lda		CODE_OFS
			ldu		a,y
			cmpu		#0
			beq		@skip_b	;if ptr==0, z=z+1
			;flush z count here (if nonzero)
			ldy		Z_COUNT
			jsr		__append_LEA
			clr		Z_COUNT
			clr		Z_COUNT+1
			;insert parameter right after opcode
			ldb		TEMP_D+1
			stb		1,u
			jmp		@common
@skip_b			ldd		Z_COUNT
			addd		#1
			std		Z_COUNT
@common			;copy code
			lda		CODE_OFS	;word array offset
			ldy		#CODE_PTR
			ldu		a,y
			ldy		#CODE_LEN
			lsra
			lda		a,y
			jsr		__copy_code
			puls		u
			;manage word counter
			;inc		BYTE_COUNT
			;ldb		BYTE_COUNT
			;cmpb		#64
			dec		WORDS_CNT
			jmp		@loop
			;add RTS to end of code

;IN regX:dest (modified)
;IN regU:src (modified)
;in regA:length (modified), can be zero
__copy_code
@loop			cmpa		#0
			beq		@endit
			ldb		,u+
			stb		,x+
			deca
			jmp		@loop
@endit			rts

;IN regX:dest
;IN regY:count
__append_LEA
			cmpy		#0
			bne		@nonzero
			rts
@nonzero		pshs		d
			ldb		#$30	;LEA code
			stb		,x+
@m0			cmpy		#15		;1-15
			bgt		@m7
			tfr		y,d
			stb		,x+
			puls		d
			rts
@m7			cmpy		#127
			bgt		@m127
			tfr		y,d
			lda		#$88
			std		,x++		;16-127
			puls		d
			rts
@m127			ldb		#$89
			stb		,x+			;128+
			sty		,x++
			puls		d
			rts
			
			;define sequences here
			;0
s00_00			;empty case
			;1
s00_0N			ldb		,x
			andb		#$F0
s00_0N_B		orb		#00
			stb		,x+
			;2
s00_M0			ldb		,x
			andb		#$0F
s00_M0_B		orb		#00
			stb		,x+
			;3
s00_MN
s00_MN_B		ldb		#00
			stb		,x+
			;4
s_0L_00			lda		,x
			anda		#$F0
s_0L_00_A		ora		#00
			sta		,x+
			;5
s_0L_0N			ldd		,x
			anda		#$F0
			andb		#$F0
s_0L_0N_D		addd		#0000
			std		,x++
			;6
s_0L_M0			ldd		,x
			anda		#$F0
			andb		#$0F
s_0L_M0_D		addd		#0000
			std		,x++
			;7
s_0L_MN			lda		,x
			anda		#$F0
s_0L_MN_A		ora		#00
s_0L_MN_B		ldb		#00
			std		,x++
			;8
s_K0_00			lda		,x
			anda		#$0F
s_K0_00_A		ora		#00
			sta		,x+
			;9
s_K0_0N			ldd		,x
			anda		#$0F
			andb		#$F0
s_K0_0N_D		addd		#0000
			std		,x++
			;10
s_K0_M0			ldd		,x
			anda		#$0F
			andb		#$0F
s_K0_M0_D		addd		#0000
			std		,x++
			;11
s_K0_MN			lda		,x
			anda		#$0F
s_K0_MN_A		ora		#00
s_K0_MN_B		ldb		#00
			std		,x++
			;12
s_KL_00
s_KL_00_A		lda		#00
			sta		,x+
			;13
s_KL_0N
s_KL_0N_A		lda		#00
			ldb		1,x
			andb		#$F0
s_KL_0N_B		orb		#00
			std		,x++
			;14
s_KL_M0
s_KL_M0_A		lda		#00
			ldb		1,x
			andb		#$0F
s_KL_M0_B		orb		#00
			std		,x++
			;15
s_KL_MN
s_KL_MN_D		ldd		#0000
			std		,x++
s_END			nop
