''********************************************
''*  Audio Core 1.0 (w/Kracker 0.57)         *
''*  Author: Nick McClanahan (c) 2012        *
''*  See end of file for terms of use.       *
''********************************************
{-----------------REVISION HISTORY-----------------
1.1 - RIFF Support
Now supports audio metadata in WAV files.  

1.0 - Initial Release
}


CON _clkmode = xtal1 + pll16x
    _xinfreq = 5_000_000       '80 MHz
    buffSize = 64
    AudioCog = 0
    taglength = 32
VAR
    long parameter1, parameter2, parameter3, parameter4  
'        passbuff1    buff2        sampler    #samples 
    LONG buff1[buffSize]
    LONG buff2[buffSize]
    word headerbase
'Processing RIFF tags
    byte tagname[5]
    byte tagvalue[taglength]
    byte plTrack[taglength]
    byte plArtist[taglength]
    byte plAlbum[taglength]    
    byte plGenre[taglength]
'File data
    long filesize                                         
    long samplrate                                        
'Play Control                                             
    LONG abortplay                                        
    byte vol
'measured stack needed = 55
    LONG watch
    LONG DSPset
    LONG samplerate
    
OBJ
  SD    : "FSRW"
  spdif : "spdifOut"

PUB start(volset, mode) | i
abortptr := @abortplay
volptr := @vol
vol := volset
IF mode ==  1
  DSPset := TRUE
else
  DSPset := FALSE

return \sd.mount_explicit(0, 1, 2, 3)
  

PUB play(fileptr) | i
abortplay := 0   
headerbase := @buff1
bytefill(@pltrack, 0, taglength * 4)
sd.popen(fileptr, "r")
sd.pread(headerbase, 44)          ' Grab required headers 
bytemove(@i, headerbase+4, 4)     ' Total Filesize in bytes
bytemove(@i, headerbase+$10, 4)   ' Format size           
bytemove(@i, headerbase + $16, 2) ' Num of channels      
bytemove(@i, headerbase + $18, 4) ' Sample Rate      
samplrate:=CLKFREQ/i
bytemove(@i, headerbase + $22, 2) ' Bits per sample      

bytemove(@i, headerbase + $24, 4) ' Check for info tag      
IF i == 1414744396                ' Magic number ('INFO')
  bytemove(@i, headerbase + $28, 4) 
  sd.pread(headerbase, i + 8) 
  readtags(i+8)
ELSE
  bytemove(@i, headerbase + $28, 4)
  filesize := i        

LONGfill(@buff1, 0, buffsize)
LONGfill(@buff2, 0, buffsize)

IF DSPset == TRUE
  return Playdsp(fileptr)
else
  return playwav(fileptr)


PUB Playdsp(fileptr) | i, n, buffsel
  spdif.setBuffer(@buff1, constant(buffsize * 2))
  spdif.start(14)
  n := 0
  buffsel := 0 


  repeat
    if (abortplay == 6) OR (n < 0)
       quit
    IF (spdif.getCount & buffsize) AND (buffsel == 0)
      n := sd.pread(@buff1, constant(buffsize * 4))
      buffsel := 1   
      next
    ELSEIF (NOT (spdif.getCount & buffsize)) AND (buffsel == 1) 
        n :=sd.pread(@buff2, constant(buffsize * 4))
        buffsel := 0
      next


cogstop(0)
sd.pclose

return 0

PUB playwav(fileptr) | n,i,j, out, tags, Samples


parameter1:=@buff1[0]                                                          'Start ASM player in a new cog
parameter2:=@buff2[0]                                                                                        
parameter3:= samplrate
parameter4:= filesize >> 2
COGINIT(AudioCog, @ASMWAV,@parameter1)

n:=buffSize-1                    
j:=buffsize*4   'number of bytes to read
repeat 
  if abortplay == 6
     quit
  if (buff1[n]==0)
    j:=sd.pread(@buff1, buffSize*4) 'read data words to input stereo buffer   
  if (buff2[n]==0)
    j:=sd.pread(@buff2, buffSize*4) 'read data words to input stereo buffer
 
sd.pclose

return 0


PUB getArtist
return @plArtist
PUB getSong
return @plTrack
PUB getAlbum
return @plAlbum
PUB getGenre
return @plGenre
PUB changevol(newval) | i
vol := (newval #> 0) <# 6

PUB FileNotFound(fileptr)
result := sd.popen(fileptr, "r")
sd.pclose

PRI readtags(len)  | tagptr, i, z
tagptr := 4                                                         'Skip past INFO text in file
len -= 8                                                            'last 8 bytes contain the word DATA and the length of the audio chunk 

repeat until tagptr => len 
  bytefill(@tagvalue, 0, taglength)
  bytemove(@tagname, headerbase + tagptr, 4)                          'Fill currenttag with tagname
  bytemove(@i, headerbase +(tagptr + 4), 4)                            'Fill i with the length of the tag value            
  bytemove(@tagvalue,headerbase + (tagptr+8), (i <# taglength - 1))         'Fill currenttagvalue with tagvalue
  repeat z from 0 to 3
    IF strcomp(@@taglist[z], @tagname)
      bytemove(@plTrack[z * taglength],@tagvalue, taglength)          
  tagptr += i + 8                                                   'Increment tagptr to the next tag

bytemove(@i, headerbase + (tagptr + 4), 4)                                'Fill i with the length of Audio data
filesize := i

'File pointer is now at the begining of the audio file                  

DAT
taglist     word @tg1, @tg2, @tg3, @tg4 
tg1    BYTE "INAM",0 '      Songtag 
tg2    BYTE "IART",0 '    Artisttag 
tg3    BYTE "IPRD",0 '     Albumtag 
tg4    BYTE "IGNR",0 '     Genretag 

PUB endtrack
abortplay := 6         

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
        rdbyte volstk, volptr

        rdLONG abortstk, abortptr
        cmp abortstk, #6 wz
        IF_Z JMP #Done 

        SUB nSamples,#1
        CMP nSamples,#0 wz
        IF_Z JMP #Done

        RDLONG Right,pData
        mov    left, right
        shl    left, #16
        and    left, msbmask
        and    right, msbmask        

        sar    right, volstk
        sar    left, volstk        

        adds   left, threes
        adds   right, threes

        

        waitcnt WaitCount,dRate    
        MOV FRQA,Right
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
        WRLONG abt, abortptr
        COGID thisCog
        COGSTOP thisCog              

'Working variables
thisCog long 0
x       long 0
y       long 0
dlsb    long    1 << 9
BigWait long 100000
twos    long $8000_8000
threes  long $8000_0000
msbmask long $FFFF_0000 

abt     LONG  6        
'Loop parameters
nTable  long 0
WaitCount long 0
pData   long 0
LoopCount long 0
SizeBuff long buffsize
'Left    long 0
Right   long 0
Left    long 0
Zero    long 0
fadeperiod     long 100_000
fade    long  0         

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