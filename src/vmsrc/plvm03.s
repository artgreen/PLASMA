;**********************************************************
;*
;*              APPLE /// PLASMA INTERPETER
;*
;*             SYSTEM ROUTINES AND LOCATIONS
;*
;**********************************************************
;
; HARDWARE REGISTERS
;
MEMBANK =	$FFEF
XPAGE	=	$1600
;*
;* VM ZERO PAGE LOCATIONS
;*
ESTKSZ	=	$20
ESTK	=	$C0
ESTKL	=	ESTK
ESTKH	=	ESTK+ESTKSZ/2
VMZP	=	ESTK+ESTKSZ
IFP	=	VMZP
IFPL	=	IFP
IFPH	=	IFP+1
IFPX	=	XPAGE+IFPH
IP     	=	IFP+2
IPL	=	IP
IPH	=	IP+1
IPX	=	XPAGE+IPH
IPY	=	IP+2
TMP	=	IP+3
TMPL	=	TMP
TMPH	=	TMP+1
TMPX	=	XPAGE+TMPH
NPARMS	=	TMPL
FRMSZ	=	TMPH
DVSIGN	=	TMP+2
ESP     =       TMP+2
SRC	=	$06
SRCL	=	SRC
SRCH	=	SRC+1
SRCX	=	XPAGE+SRCH
DST	=	SRC+2
DSTL	=	DST
DSTH	=	DST+1
DSTX	=	XPAGE+DSTH
;*
;* SOS
;*
	!MACRO	SOS .CMD, .LIST	{
	BRK
	!BYTE	.CMD
	!WORD	.LIST
	}
;*
;* INTERPRETER INSTRUCTION POINTER INCREMENT MACRO
;*
	!MACRO	INC_IP	{
	INY
	BNE	*+4
	INC	IPH
	}
;*
;* INTERPRETER HEADER+INITIALIZATION
;*
	SEGSTART	=	$A000
	*=	SEGSTART-$0E
	!TEXT	"SOS NTRP"
	!WORD	$0000
	!WORD	SEGSTART
	!WORD	SEGEND-SEGSTART
	
	+SOS	$40, SEGREQ	; ALLOCATE SEG 1 AND MAP IT
	BNE	PRHEX
	LDA	#$01
	STA	MEMBANK
	LDA	#$00		; CLEAR ALL EXTENDED POINTERS
	STA	TMPX
	STA	SRCX
	STA	DSTX
	STA	IFPX		; INIT FRAME POINTER
	LDA	#<SEGSTART
	STA	IFPL
	LDA	#>SEGSTART
	STA	IFPH
        LDX	#ESTKSZ/2	; INIT EVAL STACK INDEX
	JMP	SOSCMD
SEGREQ	!BYTE	4
	!WORD	$2001
	!WORD	$9F01
	!BYTE	$10
	!BYTE	$00
PRHEX	PHA
	LSR
	LSR
	LSR
	LSR
	CLC
	ADC	#'0'
	CMP	#':'
	BCC	+
	ADC	#6
+	STA	$480
	PLA
	AND	#$0F
	ADC	#'0'
	CMP	#':'
	BCC	+
	ADC	#6
+	STA	$880
FAIL	RTS	
;*
;* SYSTEM INTERPRETER ENTRYPOINT
;*
INTERP	LDY	#$00
	STY	IPX
	PLA
        STA     IPL
        PLA
        STA     IPH
	INY
	BNE	FETCHOP
;*
;* ENTER INTO USER BYTECODE INTERPRETER
;*
XINTERP	PLA
        STA     TMPL
        PLA
        STA     TMPH
	LDY	#$03
	LDA     (TMP),Y
        STA	IPX
	DEY
	LDA     (TMP),Y
        STA	IPH
	DEY
	LDA     (TMP),Y
	STA	IPL
        DEY
	BEQ	FETCHOP
;*
;* INTERP BYTECODE
;*
NEXTOPH	INC	IPH
	BNE	FETCHOP
DROP	INX
NEXTOP	INY
	BEQ	NEXTOPH
FETCHOP LDA	(IP),Y
	STA	*+4
	JMP	(OPTBL)
;*
;* INTERNAL DIVIDE ALGORITHM
;*
_NEG 	LDA	#$00
	SEC
	SBC	ESTKL,X
	STA	ESTKL,X
	LDA	#$00
	SBC	ESTKH,X
	STA	ESTKH,X
	RTS
_DIV	STY	IPY
	LDA	ESTKH,X
	AND	#$80
	STA	DVSIGN
	BPL	_DIV1
	JSR	_NEG
	INC	DVSIGN
_DIV1 	LDA	ESTKH+1,X
	BPL	_DIV2
	INX
	JSR	_NEG
	DEX
	INC	DVSIGN
	BNE	_DIV3
_DIV2 	ORA	ESTKL+1,X	; DVDNDL
	BNE	_DIV3
	STA	TMPL
	STA	TMPH
	RTS
_DIV3 	LDY	#$11		; #BITS+1
	LDA	#$00
	STA	TMPL		; REMNDRL
	STA	TMPH		; REMNDRH
_DIV4 	ASL	ESTKL+1,X	; DVDNDL
	ROL	ESTKH+1,X	; DVDNDH
	DEY
	BCC	_DIV4
	STY	ESTKL-1,X
_DIV5 	ROL	TMPL		; REMNDRL
	ROL	TMPH		; REMNDRH
	LDA	TMPL		; REMNDRL
	SEC
	SBC	ESTKL,X		; DVSRL
	TAY
	LDA	TMPH		; REMNDRH
	SBC	ESTKH,X		; DVSRH
	BCC	_DIV6
	STA	TMPH		; REMNDRH
	STY	TMPL		; REMNDRL
_DIV6 	ROL	ESTKL+1,X	; DVDNDL
	ROL	ESTKH+1,X	; DVDNDH
	DEC	ESTKL-1,X
	BNE	_DIV5
	LDY	IPY
	RTS
;*
;* OPCODE TABLE
;*
	!ALIGN	255,0
OPTBL 	!WORD	ZERO,ADD,SUB,MUL,DIV,MOD,INCR,DECR		; 00 02 04 06 08 0A 0C 0E
	!WORD	NEG,COMP,BAND,IOR,XOR,SHL,SHR,IDXW		; 10 12 14 16 18 1A 1C 1E
	!WORD	LNOT,LOR,LAND,LA,LLA,CB,CW,SWAP			; 20 22 24 26 28 2A 2C 2E
	!WORD	DROP,DUP,PUSH,PULL,BRGT,BRLT,BREQ,BRNE		; 30 32 34 36 38 3A 3C 3E
	!WORD	ISEQ,ISNE,ISGT,ISLT,ISGE,ISLE,BRFLS,BRTRU	; 40 42 44 46 48 4A 4C 4E
	!WORD	BRNCH,IBRNCH,CALL,ICAL,ENTER,LEAVE,RET,NEXTOP 	; 50 52 54 56 58 5A 5C 5E
	!WORD	LB,LW,LLB,LLW,LAB,LAW,DLB,DLW			; 60 62 64 66 68 6A 6C 6E
	!WORD	SB,SW,SLB,SLW,SAB,SAW,DAB,DAW			; 70 72 74 76 78 7A 7C 7E
;*
;* MUL TOS-1 BY TOS
;*
MUL	STY	IPY
	LDY	#$00
	STY	TMPL		; PRODL
	STY	TMPH		; PRODH
	LDY	#$10
MUL1 	LSR	ESTKH,X		; MULTPLRH
	ROR	ESTKL,X		; MULTPLRL
	BCC	MUL2
	LDA	ESTKL+1,X	; MULTPLNDL
	CLC
	ADC	TMPL		; PRODL
	STA	TMPL
	LDA	ESTKH+1,X	; MULTPLNDH
	ADC	TMPH		; PRODH
	STA	TMPH
MUL2 	ASL	ESTKL+1,X	; MULTPLNDL
	ROL	ESTKH+1,X	; MULTPLNDH
	DEY
	BNE	MUL1
	INX
	LDA	TMPL		; PRODL
	STA	ESTKL,X
	LDA	TMPH		; PRODH
	STA	ESTKH,X
	LDY	IPY
	JMP	NEXTOP
;*
;* NEGATE TOS
;*
NEG 	LDA	#$00
	SEC
	SBC	ESTKL,X
	STA	ESTKL,X
	LDA	#$00
	SBC	ESTKH,X
	STA	ESTKH,X
	JMP	NEXTOP
;*
;* DIV TOS-1 BY TOS
;*
DIV 	JSR	_DIV
	INX
	LSR	DVSIGN		; SIGN(RESULT) = (SIGN(DIVIDEND) + SIGN(DIVISOR)) & 1
	BCS	NEG
	JMP	NEXTOP
;*
;* MOD TOS-1 BY TOS
;*
MOD	JSR	_DIV
	INX
	LDA	TMPL		; REMNDRL
	STA	ESTKL,X
	LDA	TMPH		; REMNDRH
	STA	ESTKH,X
	LDA	DVSIGN		; REMAINDER IS SIGN OF DIVIDEND
	BMI	NEG
	JMP	NEXTOP
;*
;* ADD TOS TO TOS-1
;*
ADD 	LDA	ESTKL,X
	CLC
	ADC	ESTKL+1,X
	STA	ESTKL+1,X
	LDA	ESTKH,X
	ADC	ESTKH+1,X
	STA	ESTKH+1,X
	INX
	JMP	NEXTOP
;*
;* SUB TOS FROM TOS-1
;*
SUB 	LDA	ESTKL+1,X
	SEC
	SBC	ESTKL,X
	STA	ESTKL+1,X
	LDA	ESTKH+1,X
	SBC	ESTKH,X
	STA	ESTKH+1,X
	INX
	JMP	NEXTOP
;
;*
;* SHIFT TOS-1 LEFT BY 1, ADD TO TOS-1
;*
IDXW 	LDA	ESTKL,X
	ASL
	ROL	ESTKH,X
	CLC
	ADC	ESTKL+1,X
	STA	ESTKL+1,X
	LDA	ESTKH,X
	ADC	ESTKH+1,X
	STA	ESTKH+1,X
	INX
	JMP	NEXTOP
;*
;* INCREMENT TOS
;*
INCR 	INC	ESTKL,X
	BNE	INCR1
	INC	ESTKH,X
INCR1 	JMP	NEXTOP
;*
;* DECREMENT TOS
;*
DECR 	LDA	ESTKL,X
	BNE	DECR1
	DEC	ESTKH,X
DECR1 	DEC	ESTKL,X
	JMP	NEXTOP
;*
;* BITWISE COMPLIMENT TOS
;*
COMP 	LDA	#$FF
	EOR	ESTKL,X
	STA	ESTKL,X
	LDA	#$FF
	EOR	ESTKH,X
	STA	ESTKH,X
	JMP	NEXTOP
;*
;* BITWISE AND TOS TO TOS-1
;*
BAND 	LDA	ESTKL+1,X
	AND	ESTKL,X
	STA	ESTKL+1,X
	LDA	ESTKH+1,X
	AND	ESTKH,X
	STA	ESTKH+1,X
	INX
	JMP	NEXTOP
;*
;* INCLUSIVE OR TOS TO TOS-1
;*
IOR 	LDA	ESTKL+1,X
	ORA	ESTKL,X
	STA	ESTKL+1,X
	LDA	ESTKH+1,X
	ORA	ESTKH,X
	STA	ESTKH+1,X
	INX
	JMP	NEXTOP
;*
;* EXLUSIVE OR TOS TO TOS-1
;*
XOR 	LDA	ESTKL+1,X
	EOR	ESTKL,X
	STA	ESTKL+1,X
	LDA	ESTKH+1,X
	EOR	ESTKH,X
	STA	ESTKH+1,X
	INX
	JMP	NEXTOP
;*
;* SHIFT TOS-1 LEFT BY TOS
;*
SHL	STY	IPY
	LDA	ESTKL,X
	CMP	#$08
	BCC	SHL1
	LDY	ESTKL+1,X
	STY	ESTKH+1,X
	LDY	#$00
	STY	ESTKL+1,X
	SBC	#$08
SHL1 	TAY
	BEQ	SHL3
SHL2 	ASL	ESTKL+1,X
	ROL	ESTKH+1,X
	DEY
	BNE	SHL2
SHL3 	INX
	LDY	IPY
	JMP	NEXTOP
;*
;* SHIFT TOS-1 RIGHT BY TOS
;*
SHR	STY	IPY
	LDA	ESTKL,X
	CMP	#$08
	BCC	SHR2
	LDY	ESTKH+1,X
	STY	ESTKL+1,X
	CPY	#$80
	LDY	#$00
	BCC	SHR1
	DEY
SHR1 	STY	ESTKH+1,X
	SEC
	SBC	#$08
SHR2 	TAY
	BEQ	SHR4
	LDA	ESTKH+1,X
SHR3 	CMP	#$80
	ROR
	ROR	ESTKL+1,X
	DEY
	BNE	SHR3
	STA	ESTKH+1,X
SHR4 	INX
	LDY	IPY
	JMP	NEXTOP
;*
;* LOGICAL NOT
;*
LNOT	LDA	ESTKL,X
	ORA	ESTKH,X
	BEQ	LNOT1
	LDA	#$FF
LNOT1	EOR	#$FF
	STA	ESTKL,X
	STA	ESTKH,X
	JMP	NEXTOP
;*
;* LOGICAL AND
;*
LAND 	LDA	ESTKL,X
	ORA	ESTKH,X
	BEQ	LAND1
	LDA	ESTKL+1,X
	ORA	ESTKH+1,X
	BEQ	LAND1
	LDA	#$FF
LAND1 	STA	ESTKL+1,X
	STA	ESTKH+1,X
	INX
	JMP	NEXTOP
;*
;* LOGICAL OR
;*
LOR 	LDA	ESTKL,X
	ORA	ESTKH,X
	ORA	ESTKL+1,X
	ORA	ESTKH+1,X
	BEQ	LOR1
	LDA	#$FF
LOR1 	STA	ESTKL+1,X
	STA	ESTKH+1,X
	INX
	JMP	NEXTOP
;*
;* SWAP TOS WITH TOS-1
;*
SWAP	STY	IPY
	LDA	ESTKL,X
	LDY	ESTKL+1,X
	STA	ESTKL+1,X
	STY	ESTKL,X
	LDA	ESTKH,X
	LDY	ESTKH+1,X
	STA	ESTKH+1,X
	STY	ESTKH,X
	LDY	IPY
	JMP	NEXTOP
;*
;* DUPLICATE TOS
;*
DUP 	DEX
	LDA	ESTKL+1,X
	STA	ESTKL,X
	LDA	ESTKH+1,X
	STA	ESTKH,X
	JMP	NEXTOP
;*
;* PUSH FROM EVAL STACK TO CALL STACK
;*
PUSH 	LDA	ESTKL,X
	PHA
	LDA	ESTKH,X
	PHA
	INX
	JMP	NEXTOP
;*
;* PULL FROM CALL STACK TO EVAL STACK
;*
PULL 	DEX
	PLA
	STA	ESTKH,X
	PLA
	STA	ESTKL,X
	JMP	NEXTOP
;*
;* CONSTANT
;*
ZERO 	DEX
	LDA	#$00
	STA	ESTKL,X
	STA	ESTKH,X
	JMP	NEXTOP
CB 	DEX
	+INC_IP
	LDA	(IP),Y
	STA	ESTKL,X
	LDA	#$00
	STA	ESTKH,X
	JMP	NEXTOP
;*
;* LOAD ADDRESS & LOAD CONSTANT WORD (SAME THING, WITH OR WITHOUT FIXUP)
;*
LA	=	*
CW	DEX
	+INC_IP
 	LDA	(IP),Y
	STA	ESTKL,X
	+INC_IP
 	LDA	(IP),Y
	STA	ESTKH,X
	JMP	NEXTOP
;*
;* LOAD VALUE FROM ADDRESS TAG
;*
LB 	LDA	ESTKL,X
	STA	TMPL
	LDA	ESTKH,X
	STA	TMPH
	STY	IPY
	LDY	#$00
	LDA	(TMP),Y
	STA	ESTKL,X
	STY	ESTKH,X
	LDY	IPY
	JMP	NEXTOP
LW 	LDA	ESTKL,X
	STA	TMPL
	LDA	ESTKH,X
	STA	TMPH
       	STY	IPY
	LDY	#$00
	LDA	(TMP),Y
	STA	ESTKL,X
	INY
	LDA	(TMP),Y
	STA	ESTKH,X
	LDY	IPY
	JMP	NEXTOP
;*
;* LOAD ADDRESS OF LOCAL FRAME OFFSET
;*
LLA 	+INC_IP
 	LDA	(IP),Y
	DEX
	CLC
	ADC	IFPL
	STA	ESTKL,X
	LDA	#$00
	ADC	IFPH
	STA	ESTKH,X
	JMP	NEXTOP
;*
;* LOAD VALUE FROM LOCAL FRAME OFFSET
;*
LLB 	+INC_IP
 	LDA	(IP),Y
	STY	IPY
	TAY
	DEX
	LDA	(IFP),Y
	STA	ESTKL,X
	LDA	#$00
	STA	ESTKH,X
	LDY	IPY
	JMP	NEXTOP
LLW 	+INC_IP
 	LDA	(IP),Y
	STY	IPY
	TAY
	DEX
	LDA	(IFP),Y
	STA	ESTKL,X
	INY
	LDA	(IFP),Y
	STA	ESTKH,X
	LDY	IPY
	JMP	NEXTOP
;*
;* LOAD VALUE FROM ABSOLUTE ADDRESS
;*
LAB 	+INC_IP
	LDA	(IP),Y
	STA	TMPL
	+INC_IP
	LDA	(IP),Y
	STA	TMPH
	STY	IPY
	LDY	#$00
	LDA	(TMP),Y
	DEX
	STA	ESTKL,X
	STY	ESTKH,X
	LDY	IPY
	JMP	NEXTOP
LAW 	+INC_IP
	LDA	(IP),Y
	STA	TMPL
	+INC_IP
	LDA	(IP),Y
	STA	TMPH
	STY	IPY
	LDY	#$00
	LDA	(TMP),Y
	DEX
	STA	ESTKL,X
	INY
	LDA	(TMP),Y
	STA	ESTKH,X
	LDY	IPY
	JMP	NEXTOP
;*
;* STORE VALUE TO ADDRESS
;*
SB 	LDA	ESTKL+1,X
	STA	TMPL
	LDA	ESTKH+1,X
	STA	TMPH
	LDA	ESTKL,X
	STY	IPY
	LDY	#$00
	STA	(TMP),Y
	INX
	INX
	LDY	IPY
	JMP	NEXTOP
SW 	LDA	ESTKL+1,X
	STA	TMPL
	LDA	ESTKH+1,X
	STA	TMPH
	STY	IPY
	LDY	#$00
	LDA	ESTKL,X
	STA	(TMP),Y
	INY
	LDA	ESTKH,X
	STA	(TMP),Y
	INX
	INX
	LDY	IPY
	JMP	NEXTOP
;*
;* STORE VALUE TO LOCAL FRAME OFFSET
;*
SLB 	+INC_IP
 	LDA	(IP),Y
	STY	IPY
	TAY
	LDA	ESTKL,X
	STA	(IFP),Y
	INX
	LDY	IPY
	JMP	NEXTOP
SLW 	+INC_IP
 	LDA	(IP),Y
	STY	IPY
	TAY
	LDA	ESTKL,X
	STA	(IFP),Y
	INY
	LDA	ESTKH,X
	STA	(IFP),Y
	INX
	LDY	IPY
	JMP	NEXTOP
;*
;* STORE VALUE TO LOCAL FRAME OFFSET WITHOUT POPPING STACK
;*
DLB 	+INC_IP
	LDA	(IP),Y
	STY	IPY
	TAY
	LDA	ESTKL,X
	STA	(IFP),Y
	LDY	IPY
	JMP	NEXTOP
DLW 	+INC_IP
	LDA	(IP),Y
	STY	IPY
	TAY
	LDA	ESTKL,X
	STA	(IFP),Y
	INY
	LDA	ESTKH,X
	STA	(IFP),Y
	LDY	IPY
	JMP	NEXTOP
;*
;* STORE VALUE TO ABSOLUTE ADDRESS
;*
SAB 	+INC_IP
	LDA	(IP),Y
	STA	TMPL
	+INC_IP
	LDA	(IP),Y
	STA	TMPH
	LDA	ESTKL,X
	STY	IPY
	LDY	#$00
	STA	(TMP),Y
	INX
	LDY	IPY
	JMP	NEXTOP
SAW 	+INC_IP
	LDA	(IP),Y
	STA	TMPL
	+INC_IP
	LDA	(IP),Y
	STA	TMPH
	STY	IPY
	LDY	#$00
	LDA	ESTKL,X
	STA	(TMP),Y
	INY
	LDA	ESTKH,X
	STA	(TMP),Y
	INX
	LDY	IPY
	JMP	NEXTOP
;*
;* STORE VALUE TO ABSOLUTE ADDRESS WITHOUT POPPING STACK
;*
DAB 	+INC_IP
	LDA	(IP),Y
	STA	TMPL
	+INC_IP
	LDA	(IP),Y
	STA	TMPH
	STY	IPY
	LDY	#$00
	LDA	ESTKL,X
	STA	(TMP),Y
	LDY	IPY
	JMP	NEXTOP
DAW 	+INC_IP
	LDA	(IP),Y
	STA	TMPL
	+INC_IP
	LDA	(IP),Y
	STA	TMPH
	STY	IPY
	LDY	#$00
	LDA	ESTKL,X
	STA	(TMP),Y
	INY
	LDA	ESTKH,X
	STA	(TMP),Y
	LDY	IPY
	JMP	NEXTOP
;*
;* COMPARES
;*
ISEQ	STY	IPY
	LDY	#$00
	LDA	ESTKL,X
	CMP	ESTKL+1,X
	BNE	ISEQ1
	LDA	ESTKH,X
	CMP	ESTKH+1,X
	BNE	ISEQ1
	DEY
ISEQ1 	STY	ESTKL+1,X
	STY	ESTKH+1,X
	INX
	LDY	IPY
	JMP	NEXTOP
ISNE	STY	IPY
	LDY	#$FF
	LDA	ESTKL,X
	CMP	ESTKL+1,X
	BNE	ISNE1
	LDA	ESTKH,X
	CMP	ESTKH+1,X
	BNE	ISNE1
	INY
ISNE1 	STY	ESTKL+1,X
	STY	ESTKH+1,X
	INX
	LDY	IPY
	JMP	NEXTOP
ISGE	STY	IPY
	LDY	#$00
	LDA	ESTKL+1,X
	CMP	ESTKL,X
	LDA	ESTKH+1,X
	SBC	ESTKH,X
	BVC	ISGE1
	EOR	#$80
ISGE1 	BMI	ISGE2
	DEY
ISGE2 	STY	ESTKL+1,X
	STY	ESTKH+1,X
	INX
	LDY	IPY
	JMP	NEXTOP
ISGT	STY	IPY
	LDY	#$00
	LDA	ESTKL,X
	CMP	ESTKL+1,X
	LDA	ESTKH,X
	SBC	ESTKH+1,X
	BVC	ISGT1
	EOR	#$80
ISGT1 	BPL	ISGT2
	DEY
ISGT2 	STY	ESTKL+1,X
	STY	ESTKH+1,X
	INX
	LDY	IPY
	JMP	NEXTOP
ISLE	STY	IPY
	LDY	#$00
	LDA	ESTKL,X
	CMP	ESTKL+1,X
	LDA	ESTKH,X
	SBC	ESTKH+1,X
	BVC	ISLE1
	EOR	#$80
ISLE1 	BMI	ISLE2
	DEY
ISLE2 	STY	ESTKL+1,X
	STY	ESTKH+1,X
	INX
	LDY	IPY
	JMP	NEXTOP
ISLT	STY	IPY
	LDY	#$00
	LDA	ESTKL+1,X
	CMP	ESTKL,X
	LDA	ESTKH+1,X
	SBC	ESTKH,X
	BVC	ISLT1
	EOR	#$80
ISLT1 	BPL	ISLT2
	DEY
ISLT2 	STY	ESTKL+1,X
	STY	ESTKH+1,X
	INX
	LDY	IPY
	JMP	NEXTOP
;*
;* BRANCHES
;*
BRTRU 	INX
	LDA	ESTKH-1,X
	ORA	ESTKL-1,X
	BNE	BRNCH
NOBRNCH	+INC_IP
	+INC_IP
	JMP	NEXTOP
BRFLS 	INX
	LDA	ESTKH-1,X
	ORA	ESTKL-1,X
	BNE	NOBRNCH
BRNCH	LDA	IPH
	STA	TMPH
	LDA	IPL
	+INC_IP
	CLC
	ADC	(IP),Y
	STA	TMPL
	LDA	TMPH
	+INC_IP
	ADC	(IP),Y
	STA	IPH
	LDA	TMPL
	STA	IPL
	DEY
	DEY
	JMP	NEXTOP
BREQ 	INX
	LDA	ESTKL-1,X
	CMP	ESTKL,X
	BNE	NOBRNCH
	LDA	ESTKL-1,X
	CMP	ESTKL,X
	BEQ	BRNCH
	BNE	NOBRNCH
BRNE 	INX
	LDA	ESTKL-1,X
	CMP	ESTKL,X
	BNE	BRNCH
	LDA	ESTKL-1,X
	CMP	ESTKL,X
	BEQ	NOBRNCH
	BNE	BRNCH
BRGT 	INX
	LDA	ESTKL-1,X
	CMP	ESTKL,X
	LDA	ESTKH-1,X
	SBC	ESTKH,X
	BMI	BRNCH
	BPL	NOBRNCH
BRLT 	INX
	LDA	ESTKL,X
	CMP	ESTKL-1,X
	LDA	ESTKH,X
	SBC	ESTKH-1,X
	BMI	BRNCH
	BPL	NOBRNCH
IBRNCH	LDA	IPL
	CLC
	ADC	ESTKL,X
	STA	IPL
	LDA	IPH
	ADC	ESTKH,X
	STA	IPH
	INX
	JMP	NEXTOP
;*
;* CALL INTO ABSOLUTE ADDRESS (NATIVE CODE)
;*
CALL 	+INC_IP
	LDA	(IP),Y
	STA	CALLADR+1
	+INC_IP
	LDA	(IP),Y
	STA	CALLADR+2
	LDA	IPX
	PHA
	LDA	IPH
	PHA
	LDA	IPL
	PHA
	TYA
	PHA
CALLADR	JSR	$FFFF
	PLA
	TAY
	PLA
	STA	IPL
	PLA
	STA	IPH
	PLA
	STA	IPX
	JMP	NEXTOP
;*
;* INDIRECT CALL TO ADDRESS (NATIVE CODE)
;*
ICAL 	LDA	ESTKL,X
	STA	ICALADR+1
	LDA	ESTKH,X
	STA	ICALADR+2
	INX
	LDA	IPX
	PHA
	LDA	IPH
	PHA
	LDA	IPL
	PHA
	TYA
	PHA
ICALADR	JSR	$FFFF
	PLA
	TAY
	PLA
	STA	IPL
	PLA
	STA	IPH
	PLA
	STA	IPX
	JMP	NEXTOP
;*
;* ENTER FUNCTION WITH FRAME SIZE AND PARAM COUNT
;*
ENTER 	+INC_IP
	LDA	(IP),Y
	STA	FRMSZ
	+INC_IP
	LDA	(IP),Y
	STA	NPARMS
	STY	IPY
        LDA	IFPL
	PHA
	SEC
	SBC	FRMSZ
	STA	IFPL
	LDA	IFPH
	PHA
	SBC	#$00
	STA	IFPH
	LDY	#$01
	PLA
	STA	(IFP),Y
	DEY
	PLA
	STA	(IFP),Y
	LDA	NPARMS
	BEQ	ENTER5
	ASL
	TAY
	INY
ENTER4  LDA	ESTKH,X
	STA	(IFP),Y
	DEY
	LDA	ESTKL,X
	STA	(IFP),Y
	DEY
	INX
	DEC	NPARMS
	BNE	ENTER4
ENTER5  LDY	IPY
	JMP	NEXTOP
;*
;* LEAVE FUNCTION
;*
LEAVE 	LDY	#$01
	LDA	(IFP),Y
	DEY
	PHA
	LDA	(IFP),Y
	STA	IFPL
	PLA
	STA	IFPH
RET 	RTS
SOSCMD	=	*
	!SOURCE "vmsrc/soscmd.a"
SEGEND	=	*