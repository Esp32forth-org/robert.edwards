\ Periodic Timers ver 2 using Mini-OOF by Bob Edwards April 2022
\ this code allows multiple words to execute periodically, all with different time periods.
\ Run MAIN2 for a demo, which terminates on any key being pressed 

\ NB On entering each method, the address of the current object is top of the data stack
\ Mini-OOF expects this to be dropped from the data stack before exiting the method
\ You can see that it is often convenient to move the current object to the R stack
\ BUT the R stack must then be tidied up before exiting the method

\ Run MAIN2 to demonstrate 5 periodically timed tasks running independently without using the multitasker

FORTH DEFINITIONS
ONLY FORTH

DEFINED? *TIMERS* [IF] forget *TIMERS* [THEN] 
: *TIMERS* ;

\ TIMER class definition
OBJECT CLASS
	cell VAR STARTTIME
	cell VAR PERIOD
	cell VAR TCODE
	METHOD TSET
	METHOD TRUN
	METHOD TPRINT
END-CLASS TIMER

:noname >R 
	R@ PERIOD !									\ save the reqd period in ms
	R@ TCODE !									\ save the cfa of the word that will run periodically
	MS-TICKS R> STARTTIME !						\ save the current time since reset
; TIMER DEFINES TSET	( codetorun period -- ) \ initialises the TIMER

:noname >R
	MS-TICKS DUP								\ read the present time
	R@ STARTTIME @								\ read when this TIMER last ran
	-											\ calculate how long ago that is 
	R@ PERIOD @ >=								\ is it time to run the TCODE?
	IF
		R@ STARTTIME !							\ save the present time
		R> TCODE @ EXECUTE						\ run cfa stored in TCODE
	ELSE
		DROP R> DROP							\ else forget the present time
	THEN
; TIMER DEFINES TRUN	( -- )					\ run TCODE every PERIOD ms

:noname >R
	CR
	." STARTTIME = " R@ STARTTIME @ . CR
	." PERIOD = " R@ PERIOD @ . CR
	." TCODE = " R> TCODE @ . CR
; TIMER DEFINES TPRINT	( -- )					\ print timer variables for debug
\ end of TIMER class definition

\ Example application - 5 different tasks are started, all with different execution periods
\ Pressing any key will stop them and take you back to the forth prompt

TIMER NEW CONSTANT TIMER1
TIMER NEW CONSTANT TIMER2
TIMER NEW CONSTANT TIMER3
TIMER NEW CONSTANT TIMER4
TIMER NEW CONSTANT TIMER5

: HELLO1 ." Hi from HELLO1" CR ;
: HELLO2 ." HELLO2 here !" CR ;
: HELLO3 ." Bonjour, HELLO3 ici" CR ;
: HELLO4 ." Good day, Mate from HELLO4" CR ;
: HELLO5 ." How's it going? from HELLO5" CR ;

\ Print all timer variables
: .VARS	( -- )
	CR CR ." Timer1" CR
	TIMER1 TPRINT
	CR ." Timer2" CR
	TIMER2 TPRINT
	CR ." Timer3" CR
	TIMER3 TPRINT
	CR ." Timer4" CR
	TIMER4 TPRINT
	CR ." Timer5" CR
	TIMER5 TPRINT
;

: MAIN2	( -- )									\ demo runs until a key is pressed
	CR
	['] HELLO1 2000 TIMER1 TSET
	['] HELLO2 450 TIMER2 TSET
	['] HELLO3 3500 TIMER3 TSET
	['] HELLO4 35000 TIMER4 TSET
	['] HELLO5 2500 TIMER5 TSET					\ all timer periods and actions defined
	0
	BEGIN
		1+
		TIMER1 TRUN
		TIMER2 TRUN
		TIMER3 TRUN
		TIMER4 TRUN
		TIMER5 TRUN								\ all timers repeatedly run
	KEY? UNTIL
	CR ." The five timers TRUN methods were each run " . ." times" CR
	.VARS										\ show each timer's data
;

 \ Defining the class is moderately complicated, but notice how MAIN2 reads quite easily - using the class
 \ is quite straightforward, with the <object> <METHOD> or <object> <VAR> syntax

ONLY
