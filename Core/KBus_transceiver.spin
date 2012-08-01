{{
********************************************
*  K-Bus Transceiver   V1.22               *
*  Author: Nick McClanahan (c) 2012        *
*  See end of file for terms of use.       *
********************************************
                                                        
                                                           CIRCUIT:
USAGE: Transmit and Receive on an ISO 9141 data bus.               3.3v
'Revision History                                                                        
V1.22: Added                                                    10k                      
       Metric / Imperial Switch                           TXPIN ───┻──┳──── Ibus Data 
V1.21: Added                                                             │                
       Parse External Temp,                               RXPIN ─────  ┌─ Ibus Gnd  
       Coolant temp, converted to deg. F                             22k │  │             
       RPM and Speed in mph                                                             
       Experimental:                      
       Sending text to Nav display        

}}

CON
 _clkmode = xtal1 + pll16x ' Crystal and PLL settings.
 _xinfreq = 5_000_000 ' 5 MHz crystal (5 MHz x 16 = 80 MHz).

'contention MS
'K-Bus has no hardware contention.  We'll give this many ms after the last message before we send  
ContentionMS = 20

'K-Bus baud - usually 9600.  Might work with KWP, although KWP uses a different rate
KBusBaud = 9600

'1 for kph/ deg c, 0 for mph / deg f
metric = 0  

OBJ
  pst    : "FullDuplexSerial_binary.spin"                   ' Serial communication object

VAR
BYTE inputbuffer[32]
BYTE RADstring[32]
'Radio string length max is 11 char

PUB start(rxpin,txpin)
''Start the Serial transceiver with the given RX / TX pins 
pst.Start(rxpin, txpin, %0110, KBusBaud)
return @inputbuffer 

PUB sendcode(codeptr) | i, codelen, checksum
''Send the code stored as Hex at the location given by codeptr, Checksum is automatically calculated
''Code format is $SRC $LEN $DEST $CODE $Checksum.  Codes sent with this method need everything but the checksum
''$LEN = length (in Bytes) of $CODE + 2

checksum := 0
codelen := byte[codeptr+1] <#  32

'Contention check
repeat until pst.rxtime(ContentionMS) == -1  
  
repeat i from 0 to codelen
  pst.tx(byte[codeptr+i])
  checksum ^= byte[codeptr+i]
pst.tx(checksum)

PUB waitforcode | inbyte, inputindex
''Blocking wait for an incoming code.  The returning code is stored in 'inputbuffer'

repeat
  inbyte := pst.rxtime(1)   'Wait for quiet on line to avoid grabbing half a code
  IF inbyte < 0            'We've found quiet
    repeat                    'Loop until we find a transmission
      inbyte := pst.rxtime(5)
      IF inbyte > -1
        inputbuffer[0] := inbyte
        inputbuffer[1] := pst.rxtime(10)  <#  32              'In case we grab a code mid-transmit, limit the length to 32 bytes
        repeat inputindex from 2 to inputbuffer[1]+1          
          inputbuffer[inputindex] := pst.rxtime(10)           'or 1.6 seconds 
        return TRUE 
 


PUB OutTemp :Temp | i
'' parses a code stored in inputbuffer.  If it's the KMB weather report, the outside temp is returned
repeat i from 1 to BYTE[@TempCode][0]
  if (BYTE[@TempCode][i] == inputbuffer[i-1]) OR (BYTE[@TempCode][i] == 0)
    Temp := 1   
  else
    Temp := -1
    Return TEMP 

IF metric == 0                         
  Temp := (inputbuffer[5] * 9 / 5) + 32
Else
  Temp := inputbuffer[5]


PUB CoolTemp :Temp | i
'' parses a code stored in inputbuffer.  If it's the KMB coolant temp, the temp is returned
repeat i from 1 to BYTE[@TempCode][0]
  if (BYTE[@TempCode][i] == inputbuffer[i-1]) OR (BYTE[@TempCode][i] == 0)
    Temp := 1   
  else
    Temp := -1
    Return TEMP 

IF metric == 0                         
  Temp := (inputbuffer[5] * 9 / 5) + 32
Else
  Temp := inputbuffer[5]      



PUB RPMs :RPM | i
'' parses a code stored in inputbuffer.  If it's the KMB RPM report, the RPM's are returned
repeat i from 1 to BYTE[@RPMCode][0]
  if (BYTE[@RPMCode][i] == inputbuffer[i-1]) OR (BYTE[@RPMCode][i] == 0)
    RPM := 1   
  else
    RPM := -1
    Return RPM 

RPM := inputbuffer[5] * 100

PUB Speed :mph | i
'' parses a code stored in inputbuffer.  If it's the KMB speed report, the speed is returned in mph
repeat i from 1 to BYTE[@RPMCode][0]
  if (BYTE[@RPMCode][i] == inputbuffer[i-1]) OR (BYTE[@RPMCode][i] == 0)
    mph := 1   
  else
    mph := -1
    Return mph 

IF metric == 0
  mph := (inputbuffer[4] * 5 / 8)
ELSE
  mph := inputbuffer[4]

PUB Odometer :miles | i
'' sends an odometer request and parses the response.  odometer result in miles is returned
sendcode(@OdometerReq)
Checkforcode(75)

BYTE[@miles][2] :=  inputbuffer[6]
BYTE[@miles][1] :=  inputbuffer[5]
BYTE[@miles][0] :=  inputbuffer[4]

IF metric == 0
  Miles := (Miles * 5 /8 )



PUB checkforcode(ms) | inbyte, inputindex, holdtime
'' Non blocking code check.  gives up after ms specified
BYTEFILL(@inputbuffer, 0, 32)

ms #>= 10
holdtime := cnt
holdtime += ms * 80000

repeat
  IF cnt > holdtime
    return -1  

  inbyte := pst.rxtime(1)   'Wait for quiet on line to avoid grabbing half a code
  IF inbyte < 0            'We've found quiet
    repeat                    'Loop until we find a transmission
      inbyte := pst.rxtime(10)
      IF cnt > holdtime
        return -1  

      IF inbyte > -1
        inputbuffer[0] := inbyte
        inputbuffer[1] := pst.rxtime(50)  <#  32              'In case we grab a code mid-transmit, limit the length to 32 bytes
        repeat inputindex from 2 to inputbuffer[1]+1          
          inputbuffer[inputindex] := pst.rxtime(10)           'or 1.6 seconds 
        return 1
 
PUB codecompare(codeptr) | i, codelen
'' Compare a code stored at codeptr (everthing but the checksum) to the input buffer
codelen := byte[codeptr+1] 

repeat i from 0 to codelen
  if byte[codeptr + i] == inputbuffer[i]
    result := TRUE
  else
    return FALSE 



    
PUB sendtext(strptr)
'' Send text stored at ptr to the RAD
BYTEFILL(@radstring, 0, 32)
radstring[0] := $C8
radstring[1] := 5 + strsize(strptr)
radstring[2] := $80
radstring[3] := $23 
radstring[4] := $42
radstring[5] := $32

bytemove(@radstring+6, strptr, strsize(strptr))
sendcode(@radstring)


PUB sendnav(strptr, pos)
'' Send text stored at ptr to the NAV at index position given
'A5 62 01 nn <text>                        

BYTEFILL(@radstring, 0, 32)
radstring[0] := $F0 
radstring[1] := 6 + strsize(strptr)
radstring[2] := $3B
radstring[3] := $A5
radstring[4] := $62 
radstring[5] := $01
radstring[6] := pos

bytemove(@radstring+7, strptr, strsize(strptr))
sendcode(@radstring)


PUB textscroll(strptr) | strlen, i
'' Send text stored at ptr to the RAD, scroll it if too long
BYTEFILL(@radstring, 0, 32) 
radstring[0] := $C8
radstring[1] := 5 + 11
radstring[2] := $80
radstring[3] := $23 
radstring[4] := $42
radstring[5] := $32

strlen := strsize(strptr)
repeat i from 0 to strlen - 11 
  bytemove(@radstring+6, strptr+i, 11)
  sendcode(@radstring)
  IF i == 0
    waitcnt(clkfreq + cnt)
  ELSE
    waitcnt(clkfreq /5 + cnt)

PUB DecToStr(value, strptr) | i, x, strloc
strloc := 0
  x := value == NEGX                                                            'Check for max negative
  if value < 0
    value := ||(value+x)                                                        'If negative, make positive; adjust for max negative
    BYTE[strptr][strloc] := "-"                                                                   'and output sign
    strloc++

  i := 1_000_000_000                                                            'Initialize divisor

  repeat 10                                                                     'Loop for 10 digits
    if value => i                                                               
      BYTE[strptr][strloc] := value / i + "0" + x*(i == 1)                      'If non-zero digit, output digit; adjust for max negative
      strloc++
      value //= i                                                               'and digit from value
      result~~                                                                  'flag non-zero found
    elseif result or i == 1
      BYTE[strptr][strloc] := "0"
      strloc++                                                                 'If zero digit (or only digit) output it
    i /= 10                                                                     'Update divisor

BYTE[strptr][strloc] := 0
   
PUB wait(ms) | i
i := clkfreq / 1000 * ms
waitcnt(i + cnt)

DAT

           TempCode     BYTE $04
                        BYTE $80, $00, $BF, $19

           RPMCode      BYTE $04
                        BYTE $80, $00, $BF, $18

           OdometerReq  BYTE $44, $03, $80, $16 

{{
  
┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                   TERMS OF USE: MIT License                                                  │                                                            
├──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation    │ 
│files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,    │
│modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software│
│is furnished to do so, subject to the following conditions:                                                                   │
│                                                                                                                              │
│The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.│
│                                                                                                                              │
│THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE          │
│WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR         │
│COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,   │
│ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                         │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
}}  