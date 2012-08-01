''********************************************
''*  K-Bus Transceiver                       *
''*  Author: Nick McClanahan (c) 2012        *
''*  See end of file for terms of use.       *
''********************************************
CON
  _clkmode = xtal1 + pll16x                             ' Crystal and PLL settings.
  _xinfreq = 5_000_000                                  ' 5 MHz crystal (5 MHz x 16 = 80 MHz).
  Menudelay = 80_000_000 * 5

OBJ
  Kbus   : "KBus_transceiver"
  debug  : "Parallax Serial Terminal" 
  Buttons: "Touch Buttons"
  music  : "music_manager"   
    
VAR
LONG incomingcode
BYTE CurrCD
BYTE CurrTrack
BYTE ButtonReader

PUB main | i 
incomingcode := Kbus.Start(27, 26)
ButtonReader := Buttons.start(clkfreq / 100)
debug.Start(115_200)

waitcnt(clkfreq * 2 + cnt)

repeat
  i := cnt + menudelay
  repeat while  cnt < i 
    case Buttons.State
      %1000_0000 : SerialRepeatMODE     'Sniffs bus and repeats over USB
      %0001_0000 : ConnectionTestMODE   'Test connection by blinking Clown Nose
      %0100_0000 : DiagnosticMODE       'Diagnostic Mode for connecting PC  
      %0010_0000 : MusicMode            'Music Mode, start with a button
  MusicMode


PUB connectionTestMode
repeat
  kbus.sendcode(@clownnose)
  waitcnt(clkfreq * 5 + cnt)

PUB MusicMode     | playerstatus, i
COGSTOP(buttonReader)
debug.Stop

music.start

kbus.sendcode(@CDAnnounce)
settrack(1,1)

repeat
  IF kbus.waitforcode == TRUE
    IF kbus.codecompare(@pollCD)
      kbus.sendcode(@CDRespond)

    IF kbus.codecompare(@cdstatusreq)
      IF playerstatus == 1
        kbus.sendcode(music.PlayingCode)
      ELSE
        kbus.sendcode(music.notplaycode)
          
    IF kbus.codecompare(@playtrack)
      kbus.sendcode(music.StartPlayCode)             
      music.startsong
      playerstatus := 1 
 
    IF kbus.codecompare(@CDButton1)
      settrack(CurrCD -1, 1)
      kbus.sendcode(music.seekingcode)
      kbus.sendcode(music.StartPlayCode)
      music.startsong
      playerstatus := 1      
 
    IF kbus.codecompare(@CDButton2) 
      settrack(CurrCD + 1, 1)
      kbus.sendcode(music.seekingcode)
      kbus.sendcode(music.StartPlayCode)
      music.startsong
      playerstatus := 1      

    IF kbus.codecompare(@ChgTrackDown) 
      settrack(CurrCD, CurrTrack -1)
      kbus.sendcode(music.seekingcode)
      playerstatus := 0
 
    IF kbus.codecompare(@ChgTrackUp) 
      settrack(CurrCD, CurrTrack +1)
      kbus.sendcode(music.seekingcode)
      playerstatus := 0


PUB diagnosticMODE 
COGSTOP(buttonReader)
debug.Stop
dira[30] := 1 'FTDI settings (tx = 30, rx = 31)
dira[31] := 0
dira[26] := 1 'Bus settings (tx = 26 rx = 27)
dira[27] := 0

repeat
  outa[26] := !ina[31]
  outa[30] := ina[27] 

PUB SerialRepeatMODE  | i
COGSTOP(buttonReader) 

repeat
  IF kbus.waitforcode == TRUE 
    repeat i from 0 to BYTE[incomingcode + 1]
      debug.hex(BYTE[incomingcode + i],2)
      debug.char(32)
    debug.newline    

PRI settrack(CD,Track)
CurrCD := CD  #> 1
CurrTrack := Track #> 1
music.settrack(CurrCD, CurrTrack)

DAT

'STEERING WHEEL
        volup        BYTE $50, $04, $68, $32, $11
        voldown      BYTE $50, $04, $68, $32, $10
        whlplus      BYTE $50, $04, $68, $3B, $01
        whlmin       BYTE $50, $04, $68, $3B, $08
        RTButton     BYTE $50, $04, $C8, $3B, $40
        Dial         BYTE $50, $04, $C8, $3B, $80 

'WINDOWS and MIRRORS
        DRwindOpen   BYTE $3F, $05, $00, $0C, $41, $01
        DRwindClose  BYTE $3F, $05, $00, $0C, $42, $01
        PRwindClose  BYTE $3F, $05, $00, $0C, $43, $01
        PRwindOpen   BYTE $3F, $05, $00, $0C, $44, $01
        DFwindOpen   BYTE $3F, $05, $00, $0C, $52, $01
        DFwindClose  BYTE $3F, $05, $00, $0C, $53, $01
        PFwindOpen   BYTE $3F, $05, $00, $0C, $54, $01
        PFwindClose  BYTE $3F, $05, $00, $0C, $55, $01

        SRoofClose   BYTE $3F, $05, $00, $0C, $7F, $01
        SRoofOpen    BYTE $3F, $05, $00, $0C, $7E, $01

        DMirrorFold  BYTE $3F, $06, $00, $0C, $01, $31, $01
        DMirrorOut   BYTE $3F, $06, $00, $0C, $01, $30, $01
        PMirrorFold  BYTE $3F, $06, $00, $0C, $02, $31, $01
        PMirrorOut   BYTE $3F, $06, $00, $0C, $02, $30, $01

'LIGHTS
        ClownNose    BYTE $3F, $05, $00, $0C, $4E, $01   
        Wrnblnk      BYTE $3f, $0b, $bf, $0c, $20, $00, $00, $00, $00, $00, $00, $06
        Wrnblnk3sec  BYTE $3f, $05, $00, $0c, $75, $01
        ParkLeft     BYTE $3f, $0b, $bf, $0c, $00, $00, $00, $40, $00, $00, $00, $06
        ParkRight    BYTE $3f, $0b, $bf, $0c, $00, $00, $00, $80, $00, $00, $00, $06
        StopLeft     BYTE $3f, $0b, $bf, $0c, $00, $00, $00, $00, $08, $00, $00, $06
        StopRight    BYTE $3f, $0b, $bf, $0c, $00, $00, $00, $00, $10, $00, $00, $06
        InteriorOut  BYTE $3F, $05, $00, $0C, $68, $01
        FogLights    BYTE $3f, $0b, $bf, $0c, $00, $00, $00, $00, $00, $00, $01, $06
        HazzAndInt   BYTE $3F, $05, $00, $0C, $70, $01 'Hazard + Interior lights

'RADIO BUTTONS
        CDButton1    BYTE $68, $05, $18, $38, $06, $01
        CDButton2    BYTE $68, $05, $18, $38, $06, $02
        CDButton3    BYTE $68, $05, $18, $38, $06, $03
        CDButton4    BYTE $68, $05, $18, $38, $06, $04
        CDButton5    BYTE $68, $05, $18, $38, $06, $05
        chgtrackDown BYTE $68, $05, $18, $38, $05, $01
        chgtrackUp   BYTE $68, $05, $18, $38, $05, $00

        RandomOn     BYTE $68, $05, $18, $38, $08, $01   
        RandomOff    BYTE $68, $05, $18, $38, $08, $00

        ScanOn       BYTE $68, $05, $18, $38, $07, $01   
        ScanOff      BYTE $68, $05, $18, $38, $07, $00

'LOCKS
        remoteHome   BYTE $00, $04, $BF, $72, $26
        remoteLock   BYTE $00, $04, $BF, $72, $16
        
        KeyInsert    BYTE $44, $05, $bf, $74, $04, $01
        KeyRemove    BYTE $44, $05, $bf, $74, $00, $FF

        Lock3        BYTE $3F, $05, $00, $0C, $4F, $01 'Lock all but driver
        LockDriver   BYTE $3F, $05, $00, $0C, $47, $01 'Lock Driver 
        TrunkOpen    BYTE $3f, $05, $00, $0c, $02, $01
                 
'MOTORS
        Wiper        BYTE $3F, $05, $00, $0C, $49, $01
        WiperFluid   BYTE $3F, $05, $00, $0C, $62, $01


'CD CHANGER
        'From Radio  $68
        playtrack     BYTE $68, $05, $18, $38, $03, $00
        stoptrack     BYTE $68, $05, $18, $38, $01, $00
        'Switch CD# (01-06)                         CD#                                       
        changecd      BYTE $68, $05, $18, $38, $06, $00        

        pollCD        BYTE $68, $03, $18, $01, $72
        CDstatusreq   BYTE $68, $05, $18, $38, $00, $00 
         
        'From CD changer ($18h)
        CDannounce    BYTE $18, $04, $FF, $02, $01
        CDrespond     BYTE $18, $04, $FF, $02, $00
         
        'CD Status                                                    dd   tt  Disc (01-06 / track)
        CDnotplay     BYTE $18, $0A, $68,  $39, $00, $02, $00, $3F, $00, $00, $00 
        CDplaying     BYTE $18, $0A, $68,  $39, $00, $09, $00, $3F, $00, $00, $00
        CDtrackend    BYTE $18, $0A, $68,  $39, $07, $09, $00, $3F, $00, $00, $00
         
        CDseek        BYTE $18, $0A, $68,  $39, $08, $09, $00, $3F, $00, $00, $00        
        CDstartplay   BYTE $18, $0A, $68,  $39, $02, $09, $00, $3F, $00, $00, $00


'ON-BOARD COMPUTER



'Other Codes






{{

Sensor options;
Rain sensor
Temperature Sensor

Remote
72 22 unlock in
72 12 lock in
72 42 boot in

VAR
'Diagnostics
WORD CoolantTemp, Airtemp, RPM, Speed

PUB realtimeDiagnostic | i
'Do some Diagnostic Display Setup

repeat
  IF kbus.checkforcode(20) > -1  
    repeat i from 0 to BYTE[incomingcode + 1]
      debug.hex(BYTE[incomingcode + i],2)
      debug.char(32)
    debug.newline  

    IF Kbus.Outtemp > -1
      airtemp := kbus.outtemp
      debug.str(string("Outside: "))
      debug.dec(Airtemp)
      debug.newline

    IF Kbus.Cooltemp > -1
      Coolanttemp := kbus.Cooltemp
      debug.str(string("Coolant: "))
      debug.dec(Coolanttemp)
      debug.newline

    IF Kbus.RPMs > -1
      RPM := kbus.RPMs
      debug.str(string("RPMs: "))
      debug.dec(RPM)
      debug.newline        

    IF Kbus.Speed > -1
      Speed := kbus.Speed
      debug.str(string("Speed: "))
      debug.dec(Speed)
      debug.newline
      


PRI Dec(value, strptr) | i, x, strloc
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


Src + Len + Dest + Data + Checksum
checksum := src ^ len ^ dest ^ byte1 + byte2 + byte3  
Len = Data bytes + 1


}}


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