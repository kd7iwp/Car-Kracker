CON _clkmode = xtal1 + pll16x
    _xinfreq = 5_000_000       '80 MHz

    buffSize = 100

VAR long parameter1  'to pass @buff1 to ASM
    long parameter2  'to pass @buff2 to ASM
    long parameter3  'to pass sample rate to ASM
    long parameter4  'to pass #samples to ASM
    long buff1[buffSize]
    long buff2[buffSize]
    byte Header[44]
    byte trackcomplete


    byte abortplay
    
OBJ
    SD  : "FSRW"



PUB start | i
i:= \sd.mount_explicit(0, 1, 2, 3)
abortptr := @abortplay
return i

PUB play(fileptr)|n,i,j, SampleRate,Samples


abortplay := 0
trackcomplete :=0
sd.popen(fileptr, "r")
   


  i:=sd.pread(@Header, 44) 'read data words to input stereo buffer
  SampleRate:=Header[27]<<24+Header[26]<<16+Header[25]<<8+Header[24]
  Samples:=Header[43]<<24+Header[42]<<16+Header[41]<<8+Header[40]
  Samples:=Samples>>2
    

  'Start ASM player in a new cog
  parameter1:=@buff1[0]
  parameter2:=@buff2[0]
  parameter3:=CLKFREQ/SampleRate  '#clocks between samples'1814'for 44100ksps,  5000 'for 16ksps
  parameter4:=Samples
  n:=buffSize-1
  j:=buffsize*4   'number of bytes to read

  COGNEW(@ASMWAV,@parameter1)      

  repeat while (j==buffsize*4) 'repeat until end of file
    if abortplay == 1
      quit
    if (buff1[n]==0)
      j:=sd.pread(@buff1, buffSize*4) 'read data words to input stereo buffer   
    if (buff2[n]==0)
      j:=sd.pread(@buff2, buffSize*4) 'read data words to input stereo buffer

  IF abortplay <> 1
    trackcomplete := 1

SD.pclose


PUB checktrack

return trackcomplete



PUB stopplaying

abortplay := 1
trackcomplete :=0



PUB trackinfo(ArtStrPtr, AlbStrPtr, TrackStrPtr, PlayfilePtr)  | tens, i, c

CDInfoString[2] := BYTE[PlayfilePtr][0]
CDInfoString[3] := BYTE[PlayfilePtr][1]



\SD.popen(@CDInfoString,"r")


C := 0
i := 0

repeat until C == $0D
  c := SD.pgetc
  BYTE[AlbStrPtr][i] := c
  i++ 
BYTE[AlbStrPtr][I-1] := 0 

C := 0
i := 0
SD.pgetc
repeat until C == $0D 
  c := SD.pgetc
  BYTE[ArtStrPtr][i] := c 
  i++
BYTE[ArtStrPtr][I-1] := 0

i := 0
repeat while c > 0 
  c := SD.pgetc
  IF c == $0A 
    IF (SD.pgetc == BYTE[PlayfilePtr][3]) AND (SD.pgetc == BYTE[PlayfilePtr][4])
      SD.pgetc
      repeat until C == $0D                                                                                              
        c := SD.pgetc
        BYTE[TrackStrPtr][i] := c 
        i++
      BYTE[TrackStrPtr][I-1] := 0
      quit

SD.pclose


{{
Repeat while c > 0
  c := SD.pgetc
  IF c == $0A
    IF (SD.pgetc == tens) AND (SD.pgetc == tracknum)
      SD.pgetc
      repeat i from 0 to 31 
        c := SD.pgetc
        BYTE[trackStrPtr][i] := c
        IF c < 30  
          BYTE[TrackStrPtr][i] := 0
           
BYTE[TrackStrPtr][31] := 0            
}}   
'Line Terminator: $0D, $0A
'Comma: $2C





PUB checkplaying
return abortplay


PUB stop
stopplaying
sd.unmount

 
DAT
  ORG 0
ASMWAV
'load input parameters from hub to cog given address in par
        movd    :par,#pData1             
        mov     x,par
        mov     y,#4  'input 4 parameters
:par    rdlong  0,x
        add     :par,dlsb
        add     x,#4
        djnz    y,#:par

setup
        'setup output pins
        MOV abortstk,#0  

        MOV DMaskR,#1
        ROL DMaskR,OPinR
        OR DIRA, DMaskR
        MOV DMaskL,#1
        ROL DMaskL,OPinL
        OR DIRA, DMaskL
        'setup counters
        OR CountModeR,OPinR
        MOV CTRA,CountModeR
        OR CountModeL,OPinL
        MOV CTRB,CountModeL
        'Wait for SPIN to fill table
        MOV WaitCount, CNT
        ADD WaitCount,BigWait
        WAITCNT WaitCount,#0
        'setup loop table
        MOV LoopCount,SizeBuff  
        'ROR LoopCount,#1    'for stereo
        MOV pData,pData1
        MOV nTable,#1
        'setup loop counter
        MOV WaitCount, CNT
        ADD WaitCount,dRate


MainLoop
        SUB nSamples,#1
        CMP nSamples,#0 wz
        IF_Z JMP #Done

        rdbyte abortstk, abortptr
        cmp abortstk, #1 wz
        IF_Z JMP #Done 


        waitcnt WaitCount,dRate

        RDLONG Right,pData
        ADD Right,twos      'Going to cheat a bit with the LSBs here...  Probably shoud fix this!    
        MOV FRQA,Right
        ROL Right,#16       '16 LSBs are left channel...
        MOV FRQB,Right
        WRLONG Zero,pData
        ADD pData,#4

        'loop
        DJNZ LoopCount,#MainLoop
        
        MOV LoopCount,SizeBuff        
        'switch table       ?
        CMP nTable,#1 wz
        IF_Z JMP #SwitchToTable2
SwitchToTable1
        MOV nTable,#1
        MOV pData,pData1
        JMP #MainLoop
SwitchToTable2
        MOV nTable,#2
        MOV pData,pData2
        JMP #MainLoop
        
                
Done
         'now stop
        COGID thisCog
        COGSTOP thisCog          

'Working variables
thisCog long 0
x       long 0
y       long 0
dlsb    long    1 << 9
BigWait long 100000
twos    long $8000_8000
        
'Loop parameters
nTable  long 0
WaitCount long 0
pData   long 0
LoopCount long 0
SizeBuff long buffsize
'Left    long 0
Right   long 0
Zero    long 0
abortptr long 0-0
abortstk byte          

'setup parameters
DMaskR  long 0 'right output mask
OPinR   long 4 'right channel output pin #                        '   <---------  Change Right pin# here !!!!!!!!!!!!!!    
'26 is connected
DMaskL  long 0 'left output mask 
OPinL   long 5 'left channel output pin #                         '   <---------  Change Left pin# here !!!!!!!!!!!!!!    
CountModeR long %00011000_00000000_00000000_00000000
CountModeL long %00011000_00000000_00000000_00000000


'input parameters
pData1   long 0 'Address of first data table        
pData2   long 0 'Address of second data table
dRate    long 5000  'clocks between samples
nSamples long 2000

CDInfoString byte "CD01.txt",0

{{
                            TERMS OF USE: MIT License

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
}}