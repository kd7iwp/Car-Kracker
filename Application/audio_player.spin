CON _clkmode = xtal1 + pll16x
    _xinfreq = 5_000_000       '80 MHz

    buffSize = 50
    AudioCog = 0

VAR long parameter1  'to pass @buff1 to ASM
    long parameter2  'to pass @buff2 to ASM
    long parameter3  'to pass sample rate to ASM
    long parameter4  'to pass #samples to ASM
    long buff1[buffSize]
    long buff2[buffSize]
    byte Header[44]

    byte abortplay
    byte vol
    LONG trackcomplete
'measured stack needed = 55
    
OBJ
    SD  : "FSRW"

PUB start(volset) | i
abortptr := @abortplay
volptr := @vol
vol := volset
i:= \sd.mount_explicit(0, 1, 2, 3)
trackcomplete := TRUE
return i


PUB changevol(newval) | i
i := vol
i += newval
i #>= 0
i <#= 6

vol := i

PUB play(fileptr)|n,i,j, SampleRate,Samples, cogwatch
abortplay := 0
trackcomplete := FALSE

sd.popen(fileptr, "r")

  i:=sd.pread(@Header, 44)                                                       'read data words to input stereo buffer
  SampleRate:=Header[27]<<24+Header[26]<<16+Header[25]<<8+Header[24]             'Get sample rate from header                   
  Samples:=Header[43]<<24+Header[42]<<16+Header[41]<<8+Header[40]
  Samples:=Samples>>2
  parameter1:=@buff1[0]                                                          'Start ASM player in a new cog                               
  parameter2:=@buff2[0]                                                                                                                       
  parameter3:=CLKFREQ/SampleRate  '                                                                                                           
  parameter4:=Samples                                                            '#clocks between samples'1814'for 44100ksps, 5000 'for 16ksps
  COGINIT(AudioCog, @ASMWAV,@parameter1)                                         
                                                                                'Keep filling buffers until end of file
                                                                                ' note: using alternating buffers to keep data always at the ready...
  n:=buffSize-1
  buff1[n]:=0                                 'clear filled flags at end of buffers
  buff2[n]:=0                                                                                                   
  i:=n*4   'number of bytes to read
  j:=i
  repeat while (j==i)  'repeat until end of file
    if abortplay == 6
      cogstop(audiocog) 
      quit
    if (buff1[n]==0)
      j:=sd.pread(@buff1, i) 'read data words to input stereo buffer
      buff1[n]:=1 'set filled flag   
    if (buff2[n]==0)
      j:=sd.pread(@buff2, i) 'read data words to input stereo buffer
      buff2[n]:=1 'set filled flag


cogstop(audiocog)
sd.pclose                       
trackcomplete := TRUE

PUB endtrack
abortplay := 6         

PUB checkplaying
return Trackcomplete


PUB stop
endtrack
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
        waitcnt WaitCount,dRate

        rdbyte volstk, volptr

        rdbyte abortstk, abortptr
        cmp abortstk, #6 wz
        IF_Z JMP #Done 


        RDLONG Right,pData
        MOV Left,Right
        SAR Right,volstk
        ROL Left,#16       '16 LSBs are left channel...
        SAR Left,volstk
        ADD Right,twos      'Going to cheat a bit with the LSBs here...  Probably shoud fix this!
        Add Left,twos
        MOV FRQA,Right
        
        MOV FRQB,Left'Right
        'WRLONG Zero,pData
        ADD pData,#4
        
        'loop
        DJNZ LoopCount,#MainLoop

        WRLONG Zero,pData  'clear filled flag 
        
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
SizeBuff long (buffsize-1)
'Left    long 0
Right   long 0
Left    long 0
Zero    long 0          

'setup parameters
DMaskR  long 0 'right output mask
OPinR   long 5 'right channel output pin #                        '   <---------  Change Right pin# here !!!!!!!!!!!!!!    
DMaskL  long 0 'left output mask 
OPinL   long 4 'left channel output pin #                         '   <---------  Change Left pin# here !!!!!!!!!!!!!!    
CountModeR long %00011000_00000000_00000000_00000000
CountModeL long %00011000_00000000_00000000_00000000


'input parameters
pData1   long 0 'Address of first data table        
pData2   long 0 'Address of second data table
dRate    long 5000  'clocks between samples
nSamples long 2000

abortptr long 0
volptr  long  0
abortstk long 0
volstk  long  0
 

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