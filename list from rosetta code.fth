\ push a number to the list
0 value numbers

: push	( n -- )
	here swap numbers , , to numbers ;

\ return length u of list	
: length ( list -- u )
	0 swap begin dup while 1 under+ @ repeat drop ;

\ returns the head x of list	
: head ( list -- x )
 cell+ @ ;
 
\ print the list 
: .numbers	( list -- )
	begin 
		dup 
	while 
		dup head . @ 
	repeat 
	drop ;
	