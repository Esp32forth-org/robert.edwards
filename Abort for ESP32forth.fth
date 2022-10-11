DEFINED? *ABORT* [IF] forget *ABORT* [THEN] 
: *ABORT* ;

\ primitive for abort"
: (abort")  ( f addr len -- )
    rot if
        type
        quit
    else
        drop drop
    then
  ;

\ stop execution of word and send error message
: abort"  ( comp: -- <str> | exec: fl -- )
    [  ' s" , ] 
    postpone (abort")
  ; immediate
