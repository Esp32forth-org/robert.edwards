\ TCP Server and Client point-to-point demonstration

\ This code demonstrates a point-to-point TCP server on ESP32Forth machine "forth1" sending a stream of values via TCP
\ to another ESP32forth machine "forth2"
\ How to use this code:-
\ 1. Make sure you have two ESP32s loaded with ESP32forth v 7.0.7.2 or later, connected to terminals and in range of your WiFi
\ 2. Load the Mini-OOF library on the two ESP32s -  located at
\    https://github.com/PeterForth/esp32forth-addons/blob/main/mini-oof-BPaysan-by-bob-edwards.txt
\ 3. Edit the router name and password for your router in the code immediately below
\ 4. Load the edited code onto the two ESP32s.
\ 5. Run program TEST1 on one ESP32, then run program TEST2 on the other, you should see both machines connect
\    to the WiFi ... followed by
\ 6. A stream of numbers transmitted and numbers received on the terminals for each ESP32
\ 7. The presence on the network of each machine can be checked by pinging at the P.C. command prompt:
\    PING forth1 or PING forth2
\ 8. The demo can be stopped by pressing any key and both machines should disconnect from the WiFi back to the forth prompt

\ This version of the TCP CLass uses non-blocking code, so the user program can receover from a broken wifi link
\ e.g. if data isn't received within a certain time then the code will THROW a 'Connection timed out' error


\ Some more WiFi words

\ >>>>>>>>>>>>>>>>>>>>> EDIT THESE to suit your router name and password <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
z" YourRoutername"              value routername
z" YourRouterPassword"          value password  

-1 constant true
0  constant false

\ case statement
: ?dup dup if dup then ; 
internals 
: case 0 ; immediate 
: of ['] over , ['] = , ['] 0branch , here 0 , ['] drop , ; immediate 
: endof ['] branch , here 0 , swap here swap ! ; immediate 
: endcase ['] drop , begin ?dup while here swap ! repeat ; immediate 
 \ end of case statement

sockets also WiFi definitions

: status.    ( -- )                                             \ print WiFi connection status
." Current WiFi status = " 
WiFi.status
    case
        0 of ." no SSID available" endof
        1 of ." no SSID available" endof
        2 of ." scan networks complete" endof
        3 of ." connected" endof
        4 of ." connection failed" endof
        5 of ." connection lost" endof
        6 of ." disconnected" endof
        .
    endcase
    cr
;

: login ( z"machinename z"routername z"password -- )
   WIFI_MODE_STA Wifi.mode
   WiFi.begin
    begin
        WiFi.localIP 0=
    while
        100 ms
    repeat
    WiFi.localIP ." Address allotted is " ip. cr
    MDNS.begin
    if
        ." MDNS started"
    else
        ." MDNS failed"
    then
    cr ;
   
: WiFiConnect    ( z"machinename" -- )
routername password login
status.                                                         \ report our Wifi link status
;

: WiFiDisconnect    ( -- )
WiFi.disconnect                                                 \ disconnect
." Now disconnecting" cr
2000 ms        
status.                                                         \ report WiFi status again
;


\ TCP point-to-point communication class using MiniOOF on ESP32forth 7.0.7.2+
\ Bob Edwards Sept 2022

\ Requires Mini-OOF for ESP32forth loading before this file


forth definitions
only forth also WiFi also sockets

\ duplicate the 3rd item on the stack to t.o.s.
: 3rddup    ( n1 n2 n3 -- n1 n2 n3 n1 )
    >r over r> swap
;

\ duplicate the top 3 stack items
: 3dup        ( n1 n2 n3 -- n1 n2 n3 n1 n2 n3 )
    3rddup 3rddup 3rddup
;

\ duplicate nth item on the data stack, 0 pick = dup, 1 pick = over
: pick ( .... n - nth item )
    sp@ swap 1+ cells - @
;

\ duplicate the top four data stack items
: 4dup  ( n1 n2 n3 n4 -- n1 n2 n3 n4 n1 n2 n3 n4 )
    4 0 do
            3 pick
        loop
;

\ duplicate the top five data stack items
: 5dup  ( n1 n2 n3 n4 n5 -- n1 n2 n3 n4 n5 n1 n2 n3 n4 n5 )
    5 0 do
            4 pick
        loop
;

sockets definitions
only forth also WiFi also sockets

variable sockoptflag 1 sockoptflag !

\ display decoded sockaddr structure
: sockaddr.        ( sockaddr -- )
    ."     sockaddr length = " dup C@ U. cr
    ."              family = " dup 1+ C@ . cr
    ."                port = " dup ->port@ U. cr
    ."             address = " ->addr@ ip.
;

\ initialise a sockaddr structure with AF_INET and 16 byte sockaddr size, the rest all zeros
: sockaddr!        ( addr -- )
    DUP sizeof(sockaddr_in) swap C!
    1+ DUP AF_INET swap C!
    14 0 DO
        1+
        DUP 0 SWAP C!
    LOOP
    DROP
;

\ throw error 60 if period has expired - time unit is ms
: socktimeout?	( starttime period -- )
    + MS-TICKS <= IF 1 THROW THEN
;

\ Return flag=false if errno = $300E indicating word would have blocked
: sockblock?    ( n/err -- n/err flag=true | flag=false ) 
    DUP 0< 
    IF
        DROP errno $300E =       \ drop n/err as we haven't finished looping
    ELSE
        true                     \ don't drop n/err, we need the result
    THEN
;


\ Set up as a TCP Server, with timeout error (ms) if a connection is not made by a remote Client within that period
: sockaccept-nb                 ( timeoutperiod sock1 addr addrlen -- sock2/err )
    MS-TICKS >R                 \ Read the start time
    BEGIN
        4DUP                    ( timeoutperiod sock1 addr addrlen timeoutperiod sock1 addr addrlen )
        sockaccept              ( timeoutperiod sock1 addr addrlen timeoutperiod sock2/err )
        swap r@ socktimeout?    ( timeoutperiod sock1 addr addrlen sock2/err )     \ throw error 60 if timed out
        sockblock?              \ would sockaccept have blocked?
        pause
    UNTIL
    RDROP                       ( timeoutperiod sock1 addr addrlen sock2/err )     \ no it didn't block, lose start time
    >R 2drop 2drop R>           ( sock2/err )
;

\ Receive data to buffer at address a, required size n1, with a timeout error (ms ) if data is not received within that period
: recv-nb                       ( timeeoutperiod sock a n1 flags -- n2/err )
    MS-TICKS >R                 \ Read the start time
    BEGIN                       ( timeeoutperiod sock a n1 flags )
        5DUP                    ( timeeoutperiod sock a n1 flags timeeoutperiod sock a n1 flags )
        recv                    ( timeeoutperiod sock a n1 flags timeeoutperiod n/err )
        swap r@ socktimeout?    ( timeeoutperiod sock a n1 flags n/err )     \ throw error 60 if timed out
        sockblock?              \ would sockaccept have blocked?
        pause
    UNTIL
    RDROP                       ( timeeoutperiod sock a n1 flags n/err )     \ no it didn't block, lose start time
    >R 2drop 2drop drop R>      ( n2/err ) 
;
\ Send data at address a, n1 bytes long, with a timeout error (ms ) if data is not received within that period
: send-nb                       ( timeeoutperiod sock a n1 flags -- n2/err )
    MS-TICKS >R                 \ Read the start time
    BEGIN                       ( timeeoutperiod sock a n1 flags )
        5DUP                    ( timeeoutperiod sock a n1 flags timeeoutperiod sock a n1 flags )
        send                    ( timeeoutperiod sock a n1 flags timeeoutperiod n/err )
        swap r@ socktimeout?    ( timeeoutperiod sock a n1 flags n/err )     \ throw error 60 if timed out
        sockblock?              \ would sockaccept have blocked?
        pause
    UNTIL
    RDROP                       ( timeeoutperiod sock a n1 flags n/err )     \ no it didn't block, lose start time
    >R 2drop 2drop drop R>      ( n2/err )
;

\ TCP Class
OBJECT CLASS
    4 cells VAR locsockaddr                                     \ local sockaddr_in
    cell VAR locsock                                            \ local socket id
    4 cells VAR remsockaddr                                     \ remote sockaddr_in
    cell VAR remsock                                            \ remote socket id
    cell VAR remaddrlen                                         \ remote sockaddr_in length
    cell VAR timeout                                            \ maximum period before timeout occurs
    METHOD TCPCONNECT                                           \ Connect as TCP Client
    METHOD TCPLISTEN                                            \ Connect as TCP Server
    METHOD READ                                                 \ Read a data bytes
    METHOD WRITE                                                \ Write a data bytes
    METHOD CLOSE                                                \ Close a TCP Client / Server connection
    METHOD VARS.                                                \ Display all internal variables
END-CLASS TCP

\ TCP Class - Methods

\ TCPCONNECT - Initialise a TCP Client connection
:noname
    >R
    R@ locsockaddr sockaddr!
    R@ remsockaddr sockaddr!                                    \ initialise the sockaddrs
    R@ locsockaddr ->port!                                      \ save the port required in locsockaddr
    R@ locsockaddr ->addr!                                      \ save ip address in locsockaddr
    R@ timeout !                                                \ save the required timeout
    AF_INET SOCK_STREAM 0 socket DUP 0< THROW                   \ create a socket
    R@ locsock !
    R@ locsock @ R@ locsockaddr sizeof(sockaddr_in) 
    connect throw                                               \ and connect, but throw on error
    R> locsock @ NON-BLOCK DUP 0< THROW                         \ make socket non-blocking
    cr ." TCPCONNECT complete"
; TCP DEFINES TCPCONNECT                                        ( timeout ipaddrrange port obj -- )

\ TCPLISTEN - Initialise a TCP server connection - blocks execution until the client connects
:noname 
    >R
    R@ locsockaddr sockaddr!
    R@ remsockaddr sockaddr!                                    \ initialise the sockaddrs
    R@ locsockaddr ->port!                                      \ save the port we're listening on
    R@ locsockaddr ->addr!                                      \ save the ip address range we're listening out for
    R@ timeout !                                                \ save the required timeout period in ms
    AF_INET SOCK_STREAM 0 socket DUP 0< THROW                  \ create a streaming socket
     cr ." Socket created"
    DUP R@ locsock ! NON-BLOCK DUP 0< THROW                     \ set the socket to non-blocking
    cr ." Non-blocking set"
    R@ locsock @ R@ locsockaddr sizeof(sockaddr_in)
    bind DUP 0<
    IF
        errno 112 = IF
            DROP
            R@ locsock @ SOL_SOCKET SO_REUSEADDR sockoptflag
            cell setsockopt throw                               \ set socket to reuse old binding
            cr ." Reusing old socket"
        ELSE
            THROW
        THEN
    THEN
    cr ." Bind complete"
    R@ locsock @ 0 listen throw                                 \ listen for someone to connect
    cr ." Listen complete"
    sizeof(sockaddr_in) R@ remaddrlen !                         \ remsockaddr not received unless this preset 16
    R@ timeout @ R@ locsock @ R@ remsockaddr R@ remaddrlen
    sockaccept-nb                                               \ unblocks when a connection request is made
    dup -1 =
    IF
        R> CLOSE
        throw
    ELSE
        R> remsock !                                            \ store the remote socket id received
    THEN
    cr ." TCPLISTEN complete"
; TCP DEFINES TCPLISTEN                                         ( timeout ipaddrrange port obj -- )

\ Reads data from a buffer at addr, length n bytes
:noname
    >R
    R@ locsock @ -rot                                           ( timeout [remsock] addr nreqd )
    3 pick R@ timeout !                                         \ remember timeout for debug purposes
    begin
        4dup                                                    ( timeout [remsock] addr nreqd timeout [remsock] addr nreqd )
        0 recv-nb DUP 0< IF r> CLOSE THROW THEN                          ( timeout [remsock] addr nreqd nrecvd )
        dup >r -                                                ( timeout [remsock] addr nreqd-nrecvd : nrecvd )
        swap r> + swap dup 0=                                   ( timeout [remsock] addr+nrcvd nreqd-nrecvd flag )
    until
    2drop 2drop RDROP                                                ( -- )
; TCP DEFINES READ                                              ( timeout addr nreqd obj -- )


\ Write data to a buffer at addr, length n bytes
:noname
    >R
    R@ remsock @ -rot                                           ( timeout [remsock] addr nreqd )
    3 pick R@ timeout !                                         \ remember timeout for debug purposes
    begin
        4dup                                                    ( timeout [remsock] addr nreqd timeout [remsock] addr nreqd )
        0 send-nb DUP 0< IF r> CLOSE THROW THEN                          ( timeout [remsock] addr nreqd nrecvd )
        dup >r -                                                ( timeout [remsock] addr nreqd-nrecvd : nrecvd )
        swap r> + swap dup 0=                                   ( timeout [remsock] addr+nrcvd nreqd-nrecvd flag )
    until
    2drop 2drop RDROP                                                 ( -- )
; TCP DEFINES WRITE                                             ( addr n1 obj -- )

\ Close the connection
:noname 
    >R
        R@ locsock @ CLOSE-FILE drop                            \ close local socket
        R> remsock @ CLOSE-FILE drop                            \ close remote socket
; TCP DEFINES CLOSE                                             ( obj -- )

\ display TCP objects' internal data
:noname 
    >R
    cr ." locsockaddr : " R@ locsockaddr cr sockaddr.
    cr ." locksock    = " R@ locsock @ .
    cr ." remaddrlen = "  R@ remaddrlen @ .
    cr ." remsockaddr : " R@ remsockaddr cr sockaddr.
    cr ." remsock     = " R@ remsock @ .
    cr ." timeout     = " R> timeout @ .
; TCP DEFINES VARS.                                             ( -- )

\ Decode errno and display an error code
: socketError ( -- )
\    This word adapted from a word copyright Marc PETREMANN
    errno
    cr ." Error = " dup . space
    case
      1 of     ." Not owner "                      endof
      2 of     ." No such file "                   endof
      3 of     ." No such process "                endof
      4 of     ." Interrupted system "             endof
      5 of     ." I/O error "                      endof
      6 of     ." No such device "                 endof
      7 of     ." Argument list too long "         endof
      8 of     ." Exec format error "              endof
      9 of     ." Bad file number "                endof
     10 of     ." No children "                    endof
     11 of     ." No more processes "              endof
     12 of     ." Not enough core"                 endof
     13 of     ." Permission denied "              endof
     14 of     ." Bad address "                    endof
     15 of     ." Block device required "          endof
     16 of     ." Mount device busy "              endof
     17 of     ." File exists "                    endof
     18 of     ." Cross-device link "              endof
     19 of     ." No such device "                 endof
     20 of     ." Not a directory "                endof
     21 of     ." Is a directory "                 endof
     22 of     ." Invalid argument "               endof
     23 of     ." File table overflow "            endof
     24 of     ." Too many open file "             endof
     25 of     ." Not a typewriter "               endof
     26 of     ." Text file busy "                 endof
     27 of     ." File too large "                 endof
     28 of     ." No space left on "               endof
     29 of     ." Illegal seek "                   endof
     30 of     ." Read-only file system "          endof
     31 of     ." Too many links "                 endof
     32 of     ." Broken pipe "                    endof
     35 of     ." Operation would block "          endof
     36 of     ." Operation now in progress "      endof
     37 of     ." Operation already in progress "  endof
     38 of     ." Socket operation on "            endof
     39 of     ." Destination address required "   endof
     40 of     ." Message too long "               endof
     41 of     ." Protocol wrong type "            endof
     42 of     ." Protocol not available "         endof
     43 of     ." Protocol not supported "         endof
     44 of     ." Socket type not supported "      endof
     45 of     ." Operation not supported "        endof
     46 of     ." Protocol family not supported "  endof
     47 of     ." Address family not supported "   endof
     48 of     ." Address already in use "         endof
     49 of     ." Can't assign requested address " endof
     50 of     ." Network is down "                endof
     51 of     ." Network is unreachable "         endof
     52 of     ." Network dropped connection "     endof
     53 of     ." Software caused connection "     endof
     54 of     ." Connection reset by peer "       endof
     55 of     ." No buffer space available "      endof
     56 of     ." Socket is already connected "    endof
     57 of     ." Socket is not connected "        endof
     58 of     ." Can't send after shutdown "      endof
     59 of     ." Too many references "            endof
     60 of     ." Connection timed out "           endof
     61 of     ." Connection refused "             endof
     62 of     ." Too many levels of nesting "     endof
     63 of     ." File name too long "             endof
     64 of     ." Host is down "                   endof
    ." Error " .
    endcase
  ;

\ Test programs - notice how the TCP interface is greatly simplified by the TCP Class

forth definitions
only also WiFi also sockets

variable count

TCP NEW CONSTANT MYTCP                                          \ Create a TCP object called MYTCP to work with

\ TCP Server that transmits a stream of longs, one at a time, from a sawtooth waveform
: (TEST1)    ( -- )
    30000 0 9999 MYTCP TCPLISTEN                                \ Start a TCP Server and wait for a client to connect, with timeout
    0 count !                                                   \ this is used to create the sawtooth
        BEGIN
            5000 count 4 MYTCP WRITE                            \ send the data counter, timeout 5s
            cr ." transmitted data = "
            count @ .
            1 count +!                                          \ increment the data counter
            count @ 50 = if 0 count ! then                      \ limit the counter to 50 max
            25 ms
            key?                                                \ stop if key pressed
        UNTIL
    MYTCP CLOSE                                                 \ and close the connection
;

\ TCP Server that transmits a stream of longs from a sawtooth waveform - with error reporting - start this first
: TEST1    ( -- )
    cr ." Connecting to the Wifi router ..."
    z" forth1" WiFiConnect
    cr ." Waiting for a client to connect..."
    ['] (TEST1) catch dup 0<>
    IF
        socketError
    ELSE
        drop
    THEN
    WiFiDisconnect
;

\ TCP Client which receives a stream of longs from the server - notice the m/c name is forth1.local not forth1
: (TEST2)    ( -- )
    z" forth1.local" gethostbyname ->h_addr 9999                ( ipaddr port )
    MYTCP TCPCONNECT                                            \ Connect to the waiting server
    BEGIN
        5000 count 4 MYTCP READ                                 \ count = a 32 bit value from the server, timeout 5s
        cr ." received data = " count @ .
        key?
    UNTIL
    MYTCP CLOSE
;

\ TCP Client which receives a stream of longs from the server - with error reporting
\ Start this after the server is started
: TEST2        ( -- )
    cr ." Connecting to the Wifi router ..."
    z" forth2" WiFiConnect
    ['] (TEST2) catch dup 0<>
    IF
        socketError
    ELSE
        drop
    THEN
    WiFiDisconnect
;

