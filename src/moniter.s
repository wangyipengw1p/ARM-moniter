        AREA Monitor1, CODE,READONLY
        IMPORT  Getline
		EXPORT	Monitor
		EXPORT 	SendChar
		EXTERN	r14tmp
;//******************************************************
;//                   Yipeng Wang :)                    *
;//	           @Beihang University  		*
;//******************************************************
;// To do:
;// []error input in R 
;// []special print byte for m 
;// []try print10 using MUL
;//
;// Reminder: This Monitor is usually called in privileged mode. 
;//(for example, when displaying registers via the 'R/r' command) that the debugged application is running in user mode.


SWI_ANGEL EQU   0x123456        ;//SWI number for Angel semihosting   

        MACRO
$l      Exit                    ;//Angel SWI call to terminate execution
$l      MOV     r0, #0x18       ;//select Angel SWIreason_ReportException(0x18)
        LDR     r1, =0x20026    ;//report ADP_Stopped_ApplicationExit
        SWI     SWI_ANGEL       ;//ARM semihosting SWI
        MEND

        MACRO
$l      WriteC                  ;//Angel SWI call to output character in [r1]
$l      MOV     r0, #0x3        ;//select Angel SYS_WRITEC function
        SWI     SWI_ANGEL
        MEND
        
        MACRO
$l      ReadC                   ;//Angel SWI call to receive input of a character to [r0]
$l      MOV     r0, #0x7        ;//select Angel SYS_READC function
        MOV     r1, #0x0        ;//[r1] must be 0
        SWI     SWI_ANGEL
        MEND
        

        
Monitor

;// First load the stack pointer [Bing MeiYou NengLi improve]
		ADRL    r13, StackInit
		LDR     r13, [r13]
		STMFD   r13!, {r0-r12,r14}	;//save reg to stack--------------------------[original stack]

;// call the Getline routine like this
L1      BL      Getline
        LDRB    r1, [r0]        ;//get Command letter
        LDRB    r2, [r0, #1]    ;//get no. of params
        LDR     r3, [r0, #4]    ;//get 1st param
        LDR     r4, [r0, #8]    ;//get 2nd param
        LDR     r5, [r0, #12]   ;//get 3rd param
;// OK start your code here

;//COMMAND: 'Q'
		CMP		r1, #0x51		;//'Q'=0x51
		BNE		Next0
		CMP		r2, #0
		BNE		InvalidComm
		B		MonQuit			;// LDMFD

Next0
;//COMMAND: 'E'
		CMP		r1, #0x45		;//'E'=0x45
		BNE		Next1
		;//=-----------------------==============================================E=================<task 1/2019.4.14
		CMP		r2,#0
		BEQ		E_toggle		;// no argument then toggle
		CMP		r2,#1
		BNE		InvalidComm

		;//Begin: E with command
		STR		r3,EndianType
		B		Continue
		
		;//Begin: E with out command, toggling
E_toggle	LDR		r3,EndianType
		CMP		r3,#0
		MOVEQ		r3,#1
		MOVNE		r3,#0
		STR		r3,EndianType
		LDR		r3, =Messagesm
		BL		PrintNextMessage
		B		Continue
		;//==============================================================================E========end of task1/2019.4.14>

Next1
;//COMMAND: 'D'
		CMP		r1, #0x44		;//'D'=0x44
		BNE		Next2
		CMP		r2, #1
		BNE		InvalidComm
		CMP		r3, #0x10
		BNE		D_1
		MOV		r3, #10
		B		D_end
D_1		CMP		r3, #0x16
		BNE		D_2
		MOV		r3, #16
		B		D_end
D_2		CMP		r3, #0x2
		BNE		InvalidComm
		MOV		r3, #2
D_end
		STR		r3,DataFormat		;// store the assigned value
		LDR		r3, =Messagesda		;//print msg 
		BL		PrintNextMessage
		B		Continue
		

Next2
;//COMMAND: 'C'
		CMP		r1, #0x43		;//'C'=0x43
		CMPNE		r1, #"c"		;// or 'c'
		BNE		Next3
;//Task2: ========================================================================================C============<begin: task 2/2019.4.15
		;//r3 origin
		;//r4 dest
		;//r5 length
		;//---------------------------------------------still need to consider the word alligement
		CMP		r2, #3
		BNE		InvalidComm
		
		MOV		r1, r3			;//origin
		MOV		r2, r4			;//dest
		MOV		r3, r5			;//length

c_loop		;// if length > 4 bytes then copy a whole word (for efficiency)
		CMP		r3, #4
		BMI		c_loop2			;//<length> left < 8, if negative then brunch
		SUB		r3, r3, #4
		LDR		r4, [r1]
		ADD		r1, r1, #4
		STR		r4, [r2]		;//copy 4 byte, that is 1 word
		ADD		r2, r2, #4
		B		c_loop


c_loop2		;// copy the rest bytes one by one 
		CMP		r3,#0
		BEQ		loop_end
		SUB		r3, r3, #1
		LDRB		r4, [r1]		;//load a byte 
		ADD		r1, r1, #1
		STRB		r4, [r2]		;//copy 1
		ADD		r2, r2, #1
		B		c_loop2

loop_end
		LDR		r3, =Messagesc 
		BL		PrintNextMessage

		B Continue	;//========================================================C=================end of Task 2/2019.4.15>
		
Next3
;//COMMAND: 'M'				===================================================M===============================
		CMP		r1, #0x4D		;//'M'=0x4D
		BNE		Next4

		MOV		r3, r3, LSR #2		;//clear the lowest 2 bits
		MOV		r3, r3, LSL #2

		CMP		r2, #0
		BEQ		M_1
		
		CMP		r2, #1
		BNE		M_2
		;// 1 command
		LDR		r1, =MAddr
		MOV		r2, r3
		B 		M_getdata
M_2	        
		LDR		r1, =MAddr	;// guess this line missed-------------------------------!!!
		CMP		r2, #2
		BNE		InvalidComm
		;//2 commands			;// Just overwrite, do not display the content in <address>
		STR		r4, [r3]
		LDR		r3, =Messages3
		BL		PrintNextMessage
		B		M_end		
M_1		;// 0 command
		LDR		r1, =MAddr		
		LDR		r2, [r1]	
		ADD		r2, r2, #4
M_getdata
		STR		r2, [r1]	;//store address of this time
		LDR    	r2, [r2]		;//get 32bits data store in [r2]
		LDR		r1, EndianType
M_print		;// deal with endian type
		CMP		r1, #0
		BEQ		M_3
		MOV		r3, r2, lsr #24
		AND		r3, r3, #0x0ff
		
		MOV		r4, r2, lsr #16
		AND		r4, r4, #0x0ff
		MOV		r4, r4, lsl #8
		
		MOV		r5, r2, lsr #8	
		AND		r5, r5, #0x0ff
		MOV		r5, r5, lsl #16
				
		AND		r6, r2, #0x0ff
		MOV		r6, r6, lsl #24
		
		;//concatenate
		MOV 		r2, #0
		ORR		r2, r2, r6
		ORR		r2, r2, r5
		ORR		r2, r2, r4
		ORR		r2, r2, r3	
		
M_3
		LDR		r3, DataFormat		
		CMP		r3, #16
		BNE		M_print10
M_print16	
		MOV 		r0, r2
		BL		Print16
		
		MOV 		r0, #'h'		;//print character
		LDR		r1, =SendChar
		STR		r0, [r1]		;//store character to print
		WriteC					;//print character 'h'		
		b		M_end
M_print10
		CMP		r3, #10
		BNE		M_print2		
		MOV		r0, r2

		BL		Print10
		b		M_end
M_print2
		MOV		r0, r2

		BL		Print2
		MOV 		r0, #'b'		;//print character
		LDR		r1, =SendChar
		STR		r0, [r1]		;//store character to print
		WriteC					;//print character 'b'			
M_end
		LDR		r3, =Messages2
		BL		PrintNextMessage

		B Continue

Next4
;//COMMAND: 'm'
		CMP		r1, #0x6D		;//'m'=0x6D
		BNE		Next5
		MOV		r3, r3, LSR #2		;//clear the lowest 2 bits----------Don't know why, just mimic???
		MOV		r3, r3, LSL #2
;//=================================================================================m======<begin: Task 3/2019.4.14
		CMP		r2, #0
		BEQ		m_0
		CMP		r2, #1
		BEQ		m_1
		CMP		r2, #2
		BEQ		m_2
		BNE		InvalidComm

;//begin: m with param <addr> and <value>
		STR		r4, [r3]	
		LDR		r3, =Messages3
		BL		PrintNextMessage
		B		m_end

;//begin: m with no param
m_0		LDR		r1, =mAddr		
		LDR		r2, [r1]	
		ADD		r2, r2, #1
		B		m_get

;//begin: m with param <addr>
m_1		MOV		r2, r3
		LDR		r1, =mAddr

m_get	
		STR		r2, [r1]
		LDRB		r2, [r2]
		LDR		r1, EndianType

m_print		
		CMP		r1, #0
		BEQ		printm
		;// toggle the endiantype
		MOV		r3, r2
		MOV		r2, r2, LSL #24


printm
		MOV		r0, r2
		BL		PrintData
		B		m_end
		
m_2		STRB		r4, [r3]
		LDR		r3, =Messages3
		BL		PrintNextMessage
;//m end process
m_end		LDR		r3, =Messages2
		BL		PrintNextMessage

		B Continue
		;//=============================================================================m=============end Task 3/2019.4.14>



Next5
;//COMMAND: 'R' or 'r'
		CMP		r1, #0x52		;//'R'=0x52
		CMPNE	r1, #0x72		;//'r'=0x72
		BNE		Next6
		;//==================================================================================R=======<begin: Task 4/2019.5.22

		;//since the value of the register has been stored to the memory, so we just load and print

		CMP		r2, #1
		BEQ		r_pre
		CMP		r2, #2
		BEQ		r_pre
		CMP		r2, #0
		BNE		InvalidComm
	
		;//begin: r with no param, display all reg
		MOV		r6, r13
		ADD		r6, r6, #56		;//remember it's full decrease stack
		MOV		r12, #0			;//set r12 as counter
		
		
loop_print						;//loop print r0~r12, r14
		LDR		r0, [r6 , #-4]!		;//remember it's full stack, '!' means change the value of r13
		BL		PrintData		
		LDR		r3, =Messages2		;/ '\n'
		BL		PrintNextMessage
		ADD		r12, r12, #1
		CMP		r12, #14
		BNE		loop_print
		
		B		r_end
;//r with one argument				--------------------------------to be optimized: solve error input
r_pre
		;// settle the problem of decimal input
		CMP		r3, #0x10
		MOVEQ		r3, #10
		CMP		r3, #0x11
		MOVEQ		r3, #11
		CMP		r3, #0x12
		MOVEQ		r3, #12
		CMP		r3, #0x14
		MOVEQ		r3, #14
		;// branch to 2 arguments, assume correct input, which should be optimised.
		CMP		r2, #2
		BEQ		r_2
		;// printing   PC  is not allowed
		CMP		r3, #0x15
		BEQ		InvalidComm
		CMP		r3, #15
		BEQ		InvalidComm
		;// special for printing r13
		CMP		r3, #13
		BEQ		r1_13
		CMP		r3, #0x13
		BNE		r1_print
r1_13		ADRL		r0, StackInit
		BL		PrintData
		B		r_end

r1_print	CMP		r3, #14		;// special for r14
		LDREQ		r0, [r13]
		BLEQ		PrintData
		BEQ		r_end
		MOV		r6, r13			;// temp copy, just to be sure that r13 is not changed in the end
		ADD		r6, r6, #52		;// now point to r0 [in mem]
		SUB		r6, r6, r3, LSL #2	;// add r3 * 4
		LDR		r0, [r6]
		BL		PrintData
		B		r_end

r_2		
		;// change the register value, should be done in the original stack
		CMP		r3, #14
		STREQ		r4, [r13]
		BEQ		r2_end
		MOV		r6, r13			;// temp copy
		ADD		r6, r6, #52		;// now point to r0 [in mem]
		SUB		r6, r6, r3, LSL #2	;// add r3 * 4
		STR		r4, [r6]

r2_end		LDR		r3, =Messagesm		;// print msg
		BL		PrintNextMessage
		B		Continue
		
r_end		LDR		r3, =Messages2
		BL		PrintNextMessage

		B Continue	;//===========================================================R==============end of Task 4/2019.5.22>
	
Next6
;//more commands can be added here
	
	
	
InvalidComm
		LDR		r3, =Messages1
		BL		PrintNextMessage
		
Continue
        b       L1

MonQuit    
        ldmfd		r13!, {r0-r12,r14}	;//restore reg from stack
        mov		pc,r14				;//return to swi or undef


PrintNextMessage	;//output a string starting at [r3]
		STMFD	r13!, {r0-r12,r14}
		MOV		r0, #0x3			;//select Angel SYS_WRITEC function
NxtTxt	LDRB	r1, [r3], #1		;//get next character
		CMP		r1, #0				;//test for end mark
		SUBNE	r1, r3, #1			;//setup r1 for call to SWI
		SWINE	SWI_ANGEL			;//if not end, print..
		BNE		NxtTxt				;//..and loop
		LDMFD   r13!, {r0-r12,r14}
		MOV		pc, r14

Print10		;//output the string of a number at r0 in DEC format
		STMFD	r13!, {r0-r12,r14}

;//Task5: ===============================================================print10============================<Begin: task 5/2019.5.22
;//			*******************************************
;//			*    Comment one of the methods to run    *
;//			*******************************************
;//------------------------------------------------------------------------------------
;// Method 1:
;// Classic "Add 3 when greater than 4" algorithm in digital design, for binary to BCD conversion
;// The long array[39 downto 0] is constructed by (lower bits of r1) and r2,  Pseudo Code:
;//
;//	for (i = 0; i < 31; i++){							//loop1
;//		array = {array[38:0] , r0(31 - i)}
;//		for (j = 10; j > 0 j--){						//loop2
;//			if (array[4*j: 4*j-3]  > 4)  array[4*j: 4*j-3] += 3;
;//		}
;//	}
;//
;// Then the array contains the BCD code that could be printed in binary mode.
;//-------------------------
;// * this method does not use MUL, which could save a large amount of clk cycles
;// * the result is correct without any precision
;// * May not be the best method for assembly, but definately best for FPGA (:0), ranbingluan
;// * instruction count could be larger, and the method itself is not straightforward
;// * r0: original; r1, r2:shift reg; r3:count32; r4,r5: temp
		MOV		r1, #0
		MOV		r2, #0
		MOV		r3, #32			;//counter for loop1
loop10		
		SUB		r3, r3, #1
		
		;// shift r1 left, then shift the MSB in r2 to r1
		;// There's no ROL in ARM, wtf
		MOV		r1, r1, LSL #1
		MOV		r5, r2, LSR #31		
		AND		r1, r1, #0xfffffffe
		ORR		r1, r1, r5
		;// shift r2 left, then shift one bit in r0 to r2
		MOV		r4, r0, LSR r3
		AND		r4, r4, #1		;//to be shifted to shift reg, in r0
		MOV		r2, r2, LSL #1
		AND		r2, r2, #0xfffffffe
		ORR		r2, r2, r4
		
		;//loop branch for loop1
		CMP		r3, #0
		BEQ		now10print

		;// loop2: >4 then +3

		;// deal with array[35:32], no specific order required for following steps
		AND		r4, r1, #0xf
		CMP		r4, #4
		ADDGT		r4, r4, #3
		AND		r4, r4, #0xf		;//not necessary, theoratically, r4 can't be greater than 9, just for sure
		AND		r1, r1, #0xfffffff0	;//update the array
		ORR		r1, r1, r4		;//update the array
		;// deal with array[39:36]
		MOV		r4, r1, LSR #4
		CMP		r4, #4
		ADDGT		r4, r4, #3
		AND		r4, r4, #0xf		;//not necessary, just for sure
		MOV		r4, r4, LSL #4
		AND		r1, r1, #0xffffff0f
		ORR		r1, r1, r4

		MOV		r5, #32
loopAdd		;// deal with array[32:0], 4 in a loop
		SUB		r5, r5, #4
		MOV		r4, r2, LSR r5
		AND		r4, r4, #0xf
		CMP		r4, #4
		ADDGT		r4, r4, #3		;//Greater than, then add
		AND		r4, r4, #0xf		;//not necessary, just for sure
		MOV		r4, r4, LSL r5
		MOV		r7, #0xf
		MVN		r6, r7, LSL r5		;// ~(not)
		AND		r2, r2, r6
		ORR		r2, r2, r4

		CMP		r5, #0
		BNE		loopAdd

		
		B		loop10

;// now print
now10print	;// print array[39:36], which is the highest bit of decimal num
		MOV		r3, r1
		LDR		r1, =SendChar
		MOV		r0, r3, LSR #4
		ADD		r0, r0, #"0"		;// add 0's ASCII value 
		STR		r0, [r1]
		WriteC

		;// print array[35:32]
		AND		r0, r3, #0xf
		ADD		r0, r0, #"0"
		STR		r0, [r1]
		WriteC

		MOV		r5, #32

loop10print	;// loop print others
		SUB		r5, r5, #4
		MOV		r0, r2, LSR r5
		AND		r0, r0, #0xf
		ADD		r0, r0, #"0"
		STR		r0, [r1]
		WriteC

		CMP		r5, #0
		BNE		loop10print						;//*******************************************
;//----------------------------------------------------------------------------------	;//*    Comment one of the methods to run    *
;// Method 2 for print10: Here's a more straight forward method: MUL fixed point	;//*******************************************
;//  loop: {push r0 - 10*[r0 * 0.1] ; r0 <=  [r0 * 0.1];}
;//  loop: pop and print
;//    '00000000000000000000000000001010'	10^1
;//  . '00011001100110011001100110011001'	10^-1
		LDR		r1, =SendChar
		LDR		r2, zeroPointOne
		MOV		r5, #9
		MOV		r8, #0		;// r8: carry
						;// Due to the precision of 0.1, r0 - [r0 * 0.1] could > 9, where we should set the carry to 1
						;// This'll not happend theoratically is 0.1 is precise
						;// With the help of carry, the result will be correct in all condition.

looppre		
		UMULL		r12, r6, r0, r2		;// fixed point multiplication, with higher 32bits(r6) to be the integer part
							;// r12(decimal part) is dumped
							;// act as floor()
		
		MOV		r7, #10			;// r7: #10
		MUL		r3, r6, r7		;// r3: 10 * [r0 * 0.1]
		SUB		r4, r0, r3		;// r0 - 10 * [r0 * 0.1]
		MOV		r0, r6			
		ADD		r4, r4, r8		;// r8: carry
		CMP		r4, #9
		;// if > 9 then -10, and set carry to 1
		SUBHI		r4, r4, #10		;// > unsigned
		MOVHI		r8, #1
		MOVLS		r8, #0			;// <= unsigned
		STR		r4, [r13, #-4]!		;// push in the stack
		SUB		r5, r5, #1
		CMP		r5, #0
		BNE		looppre
		
		ADD		r0, r0, r8
		STR		r0, [r13, #-4]!		;// push last, which is the highest num of the decimal num

		;// now pop print
loop10p		LDR		r0, [r13]
		ADD		r0, r0, #'0'
		ADD		r13, r13, #4
		STR		r0, [r1]
		WriteC
		ADD		r5, r5, #1
		CMP		r5, #10
		BNE		loop10p

;//------------------------------------------------------------------------------------

		LDMFD		r13!, {r0-r12,r14}
		MOV		pc, r14			;//==================================print10=========end of Task 5/ 2019.5.22>


Print16		;//output the string of a number at r0 in HEX format
		STMFD		r13!, {r0-r12,r14}
		MOV		r3, r0
		MOV		r4, #8				;//nibble count = 8
		LDR		r1, =SendChar
LoopPrint16
		MOV		r0, r3, LSR #28		;//get top nibble
		CMP		r0, #9				;//0-9 or A-F
		ADDGT		r0, r0, #"A"-10		;//ASCII alphabetic
		ADDLE		r0, r0, #"0"		;//ASCI numeric
		STR		r0, [r1]			;//store character to print
		WriteC						;//print character
		MOV		r3, r3, LSL #4		;//shift left one nibble
		SUBS		r4, r4, #1			;//decrement nibble count
		BNE		LoopPrint16			;//if more do next nibble
		LDMFD		r13!, {r0-r12,r14}
		MOV		pc, r14

Print2		;//output the string of a 32 bits number at r0 in bin format
		STMFD		r13!, {r0-r12,r14}
		;//==============================================================================print2====<begin:Task 6/2019.4.15	
		MOV		r3, r0
		MOV		r4, #32
		LDR		r1, =SendChar
		
		
loop_print2	SUB		r4, r4, #1
		AND		r0, r3, #0x1
		ADD		r0, r0, #"0"
		STR		r0, [r1]
		WriteC
		MOV		r3, r3, LSR #1
		CMP		r4, #0
		BNE		loop_print2  ;//if -1

		LDMFD		r13!, {r0-r12,r14}
		MOV		pc, r14		;//=================================================print2====<end of Task 6/2019.4.15

PrintData		;//output the string of a number at r0 in given format
		STMFD		r13!, {r0-r12,r14}
		
		LDR		r1, DataFormat	
		CMP		r1, #16
		BNE		Pr10
		BLEQ		Print16
		MOV 		r0, #'h'		;//print character
		LDR		r1, =SendChar
		STR		r0, [r1]		;//store character to print
		WriteC					;//print character 'h'	
		B		Printdata_end

Pr10		CMP		r1, #10
		
		BLEQ		Print10	
		BEQ		Printdata_end

		CMP		r1, #2
		BNE		Invalid
		BL		Print2	
		MOV 		r0, #'b'		;//print character
		LDR		r1, =SendChar
		STR		r0, [r1]		;//store character to print
		WriteC					;//print character 'b'
		B		Printdata_end
		
Invalid		LDR		r3, =Messagesd
		BL		PrintNextMessage
		
Printdata_end	LDMFD		r13!, {r0-r12,r14}
		MOV		pc, r14	





StackInit
        DCD     StackTop

	
        AREA stack, DATA, READWRITE
;// Place your data here
zeroPointOne	DCD	0x19999999				;//HEX form of 32bit 0.1
SendChar
		DCD 	0					;//sended char
DataFormat							;//the display of memory/register to decimal, hexadecimal or binary
		DCD		16					;//{10 | 16 | 2}, default 16
EndianType							;//the data representation to either little-endian ("E 0", default) or big-endian ("E 1").
		DCD		0					;//{0 | 1}, default 0
mAddr
		DCD		0
MAddr
		DCD		0
Messages1
		= "Invalid Command!", &0a, &0d, 0
		ALIGN
Messages2
		= &0a, &0d, 0
		ALIGN
Messages3
		= "Write Data!"
		ALIGN	
Messagesc	
		= "Copy finished.", &0a, &0d, 0
		ALIGN
Messagesm	
		= "Modified.", &0a, &0d, 0
		ALIGN
Messagesd	
		= "Invalid data format.", &0a, &0d, 0
		ALIGN
Messagesda	
		= "Dataformat changed.", &0a, &0d, 0
		ALIGN
MessagesE	
		= "Endian type changed.", &0a, &0d, 0
		ALIGN
StackBtm
        %        0x1000 
StackTop
        END

