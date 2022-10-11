\ RECORDFILE allows the programmer to make as many files on the SPIFFS drive as he wants, loaded from
\ a single source file on the PC. Each SPIFFS file is defined in the source file as
\ RECORDFILE /spiffs/yourfilename
\ text text text
\ text text text
\ etc
\ <EOF>
\ ... and repeat as many times as you want a SPIFF file to be created and filled

\ N.B. <EOF> which stands for 'end of file' MUST be located on column 0 else it won't terminate the file
\ Have a look at 'Record stream input to file test.fth' and try it out - it creates three small SPIFFS files
\ Just make sure to load this code first
\ Then load 'Record stream input to file test.fth' like you would any other forth code
\ You'll see the files being loaded and after all is finished
\ you can use VISUAL EDIT /spiffs/yourfilename to check the contents is what you expect!

\ These chars terminate all text lines in a file
create crlf 13 C, 10 C, 

\ Records the input stream to a spiffs file until an <EOF> marker is encountered, then close file
: RECORDFILE  ( "filename" "filecontents" "<EOF>" -- )
    bl parse                                \ read the filename ( a n )
    W/O CREATE-FILE throw >R                \ create the file to record to - put file id on R stack
    BEGIN
        tib #tib accept                     \ read a line of the file from the input stream
        tib over                         
        S" <EOF>" startswith?               \ does the line start with <EOF> ?
        DUP IF
            swap drop                       \ Yes, so drop the end line of the file containing <EOF>
        ELSE
            swap
            tib swap
            R@ WRITE-FILE throw             \ No, so write the line to the open file
            crlf 2 R@ WRITE-FILE throw      \ and terminate line with cr-lf
        THEN
    UNTIL                                   \ repeat until <EOF> found
    R> CLOSE-FILE throw                     \ Close the file
;

\ This was originally written to provides files for 'Batch file for ESP32forth.fth'
