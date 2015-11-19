	code
	org 0x00B8

	sei
	lds #0x00B7          ; Initialize stack pointer
	jsr transmit_wait    ; Wait for transfer from original program to finish

	; === Transfer ROM ===
	ldx #0xF000          ; Initialize index register
loop:
	db 0xA6,0x00         ; Load byte from memory into A
	jsr transmit         ; Transmit A
	xora #0xFF           ; XOR A with 0xFF and store in A (checksumming!)
	jsr transmit         ; Transmit A
	inx                  ; Increase index register
	bne loop             ; Loop while X != 0

	; Transmit "OK"
	ldaa #'O'
	jsr transmit
	ldaa #'K'
	jsr transmit

	jmp 0xF000           ; Reset

; === Serial transmit subroutine ===
transmit:
	staa 0x13            ; Store A to 0x13 (transmit data register)

transmit_wait:           ; Wait for transfer to finish
	ldab #0x20
	bitb 0x11
	beq transmit_wait

	rts                  ; Return
