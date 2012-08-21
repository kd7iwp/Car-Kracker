''********************************************
''*  Car Kracker                             *
''*  Author: Nick McClanahan (c) 2012        *
''*  See end of file for terms of use.       *
''********************************************

{{
Revision History:
0.53:           Added Datalog mode, Serial Sniffer Mode
                Version check / report

0.51:           Preferences are now stored on EEPROM for reboots
                They can be changed through a serial connection

}}



CON
  _clkmode = xtal1 + pll16x                             ' Crystal and PLL settings.
  _xinfreq = 5_000_000                                  ' 5 MHz crystal (5 MHz x 16 = 80 MHz).
  Menudelay = 80_000_000 * 4

  EEPROM_Addr   = %1010_0000   
  EEPROM_base   = $8000

OBJ
  Kbus         : "KBus_transceiver"
  debug        : "Parallax Serial Terminal" 
  Buttons      : "Touch Buttons"
  music        : "music_manager"
  i2cObject    : "i2cObject.spin"
      SD  : "FSRW"           
    
VAR
LONG incomingcode
BYTE CurrCD
BYTE CurrTrack
BYTE ButtonReader

'Variables for Config Mode
BYTE configbuffer[20]
BYTE controltype[20]
BYTE getorset[5]
BYTE bussendvalue[20]

BYTE senderlookup[3]
BYTE logfilename[10]      
LONG speed, rpm, intemp, outtemp  

PUB main | i 
i2cObject.Init(29, 28, false)
incomingcode := Kbus.Start(27, 26)
ButtonReader := Buttons.start(clkfreq / 100)
debug.Start(9600)
setled(1)

i := cnt + menudelay
repeat while cnt < i
  IF debug.rxcount > 0
    configmode

setled(0)

repeat
  i := cnt + (menudelay)
  IF EEPROM_read(112) <> 1
    repeat while  cnt < i 
      case Buttons.State
        %1000_0000 : SerialRepeatMODE     'Sniffs bus and repeats over USB
        %0001_0000 : ConnectionTestMODE   'Test connection by blinking Clown Nose
        %0100_0000 : DiagnosticMODE       'Diagnostic Mode for connecting PC  
        %0010_0000 : MusicMode            'Music Mode, start with a button

  case EEPROM_read(101)
    0 : DiagnosticMode
    1 : MusicMode
    2 : SerialRepeatMode
    3 : RemapperMode
    4 : DataLogMode
    OTHER : DiagnosticMode


PUB configmode  | controlSelected, eepromoffset
setled(2)
debug.str(string("Version"))
debug.newline      
debug.str(string("0.53"))
debug.newline

repeat while debug.rxcount > 0
  debug.rxflush

repeat
  debug.strin(@configbuffer)

  IF strcomp(@configbuffer, @testcmd)
    configblast(debug.decin)
    debug.strin(@getorset) 
    debug.strin(@configbuffer)
    next
                                
  IF strcomp(@configbuffer, @sermon)
    serialmonitormode
    next
    
  IF strcomp(@configbuffer, @combobox) 
    eepromoffset := 100 + debug.decin
    getseteeprom(eepromoffset) 
  IF strcomp(@configbuffer, @checkbox) 
    eepromoffset := 200 + debug.decin
    getseteeprom(eepromoffset)



PRI getseteeprom(eepromoffset)

debug.strin(@getorset)
  IF strcomp(@getorset, @set)
    EEPROM_set(eepromoffset,debug.decin)
  ELSE 
    sendsetting(eepromoffset,1) 
      


PUB datalogmode     | i,repeattimer, interval, repeatlimit
i := EEPROM_read(199)
repeattimer := 0
EEPROM_set(199, i + 1)
bytefill(@logfilename, 0, 10)


i:= \sd.mount_explicit(0, 1, 2, 3)

decimaltostring(EEPROM_read(199), @logfilename)


bytemove(@logfilename+strsize(@logfilename), @logfilesuffix, 5)
 


Case EEPROM_Read(119)
  0: repeatlimit := 1
  1: repeatlimit := 2
  2: repeatlimit := 10
  3: repeatlimit := 120



BYTEfill(@configbuffer,0,20)

interval := cnt + 2_400_000_000 '30 sec
'interval := cnt + 400_000_000 '5 sec

repeat
  IF kbus.checkforcode(50) > -1
    if kbus.speed > -1
      speed := kbus.speed
    if kbus.rpms > -1
      rpm := kbus.rpms
    if kbus.cooltemp > -1
      intemp := kbus.cooltemp
    if kbus.outtemp > -1
      outtemp := kbus.outtemp
      
  IF cnt > interval
    repeattimer++
    If  repeattimer == repeatlimit

      writetolog
      repeattimer := 0
    interval := cnt +2_400_000_000 '30 sec
'    interval := cnt + 400_000_000 '5 sec 
  

PRI writetolog  
setled(99)

BYTEfill(@configbuffer,0,20)

sd.popen(@logfilename, "a")

IF EEPROM_Read(202) == 0   ' time
  kbus.localtime(@configbuffer)
  sd.pputs(@configbuffer) 
  sd.pputc(",")

IF EEPROM_Read(201) == 0   ' speed
  decimaltostring(speed, @configbuffer)  
  sd.pputs(@configbuffer) 
  sd.pputc(",")

IF EEPROM_Read(204) == 0   ' RPM
  decimaltostring(rpm, @configbuffer)  
  sd.pputs(@configbuffer) 
  sd.pputc(",")

'IF EEPROM_Read(206) == 0   ' GPS
'   sd.pputc("x")
'   sd.pputc(",")
   
IF EEPROM_Read(207) == 0   ' outside temp
  decimaltostring(outtemp, @configbuffer)  
  sd.pputs(@configbuffer) 
  sd.pputc(",")

IF EEPROM_Read(208) == 0   ' inside temp
  decimaltostring(intemp, @configbuffer)  
  sd.pputs(@configbuffer) 
  sd.pputc(",")

sd.pputc("0")
sd.pputc(13)
sd.pputc(10)
sd.pclose

setled(0)
  

pri lookupmember(selected) : value   | lookupval

lookupval := BYTE[incomingcode + selected]

case lookupval
  0 :   value :=   @sndBcast  
  $18 : value :=   @sndcdw    
  $3B : value :=   @sndnav    
  $43 : value :=   @sndmenu   
  $50 : value :=   @sndmfl    
  $60 : value :=   @sndpdc    
  $68 : value :=   @sndrad    
  $6A : value :=   @snddsp    
  $80 : value :=   @sndike
  $BB : value :=   @sndtv     
  $BF : value :=   @sndlcm    
  $C0 : value :=   @sndMID    
  $C8 : value :=   @sndtel    
  $D0 : value :=   @sndnavbar 
  $E7 : value :=   @sndobctxt 
  $ED : value :=   @sndseats  
  $FF : value :=   @sndBcast
  OTHER : value :=  @sndNA
return value 



PUB serialmonitormode | i, stopflag
i := 0
stopflag := 0


repeat
  IF kbus.checkforcode(50) > -1
    repeat i from 0 to BYTE[incomingcode + 1]
      debug.hex(BYTE[incomingcode + i],2)
      debug.char(32)
    debug.newline
    debug.str(lookupmember(0))
    debug.newline             
    debug.str(lookupmember(2))
    debug.newline    
   
  IF debug.rxcount > 0
    debug.strin(@configbuffer)

    IF strcomp(@configbuffer, @seroff)
      return
    IF strcomp(@configbuffer, @sersend)
      bytefill(@bussendvalue, 0, 20)
      stopflag := 0
      i := 0 

      repeat while stopflag == 0
        debug.strin(@configbuffer)
        IF strcomp(@configbuffer, @serdone)     
          bussendvalue[1] := i -1
          codetostring(@bussendvalue)
          kbus.sendcode(@bussendvalue)
          stopflag := 1    
        ELSE
          bussendvalue[i] := debug.hexin
          i++


PRI codetostring(strptr) | i

      repeat i from 0 to BYTE[strptr + 1]
        debug.hex(BYTE[strptr + i],2)
        debug.char(32)
      debug.newline
      debug.str(@sndNA)
      debug.newline        
      debug.str(@sndNA)
      debug.newline    
    
PUB configblast(cmd)
 case cmd
   0 :  kbus.sendcode(@volup)                         
   1 :  kbus.sendcode(@voldown)                       
   2 :  kbus.sendcode(@whlplus)                       
   3 :  kbus.sendcode(@whlmin)                        
   4 :  kbus.sendcode(@RTButton)                      
   5 :  kbus.sendcode(@Dial)                          
   6 :  kbus.sendcode(@DRwindOpen)                    
   7 :  kbus.sendcode(@DRwindClose)                   
   8 :  kbus.sendcode(@PRwindClose)                   
   9 :  kbus.sendcode(@PRwindOpen)                    
   10 : kbus.sendcode(@DFwindOpen)                    
   11 : kbus.sendcode(@DFwindClose)                   
   12 : kbus.sendcode(@PFwindOpen)                    
   13 : kbus.sendcode(@PFwindClose)                                 
   14 : kbus.sendcode(@SRoofClose)                                  
   15 : kbus.sendcode(@SRoofOpen)                                   
   16 : kbus.sendcode(@DMirrorFold)                                 
   17 : kbus.sendcode(@DMirrorOut)                                  
   18 : kbus.sendcode(@PMirrorFold)                                 
   19 : kbus.sendcode(@PMirrorOut)                                  
   20 : kbus.sendcode(@ClownNose)                                   
   21 : kbus.sendcode(@Wrnblnk)                                     
   22 : kbus.sendcode(@Wrnblnk3sec)                                 
   23 : kbus.sendcode(@ParkLeft)                                                               
   24 : kbus.sendcode(@ParkRight)                     
   25 : kbus.sendcode(@StopLeft)                      
   26 : kbus.sendcode(@StopRight)                     
   27 : kbus.sendcode(@InteriorOut)                   
   28 : kbus.sendcode(@FogLightsON)                     
   29 : kbus.sendcode(@FogLightsOFF)                   
   30 : kbus.sendcode(@HazzAndInt)                   
   31 : kbus.sendcode(@remoteHome)                   
   32 : kbus.sendcode(@remoteLock)                   
   33 : kbus.sendcode(@KeyInsert)                    
   34 : kbus.sendcode(@KeyRemove)  
   35 : kbus.sendcode(@Lock3)      
   36 : kbus.sendcode(@LockDriver) 
   37 : kbus.sendcode(@TrunkOpen)  
   38 : kbus.sendcode(@Wiper)      
   39 : kbus.sendcode(@WiperFluid) 

PRI EEPROM_set(addr,byteval)
waitcnt(cnt + 100_000)
i2cObject.writeLocation(EEPROM_ADDR, addr+EEPROM_base, byteval, 16, 8)

PRI EEPROM_Read(addr) | eepromdata
eepromdata := 0
waitcnt(cnt + 100_000)
eepromdata := i2cObject.readLocation(EEPROM_ADDR, addr+EEPROM_base, 16, 8)
return eepromdata

PRI sendsetting(addr,len) |  i

i := EEPROM_Read(addr) 
IF i == 255
  debug.str(string("-1"))  
ELSE
  debug.dec(i)
debug.newline   

PUB connectionTestMode

setLED(20)
repeat
  kbus.sendcode(@clownnose)
  waitcnt(clkfreq * 5 + cnt)

PUB MusicMode     | playerstatus, i
COGSTOP(buttonReader)
debug.stop
setLED(21) 
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

PRI settrack(CD,Track)
CurrCD := CD  #> 1
CurrTrack := Track #> 1
music.settrack(CurrCD, CurrTrack)

PUB diagnosticMODE 
setLED(22)  
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
setLED(23) 

repeat
  IF kbus.waitforcode == TRUE 
    repeat i from 0 to BYTE[incomingcode + 1]
      debug.hex(BYTE[incomingcode + i],2)
      debug.char(32)
    debug.newline    

PUB remappermode   | codetosend, i,y, xmit
cogstop(Buttonreader)
setled(98)
repeat
  IF kbus.waitforcode == TRUE
    repeat y from 0 to 5
      codetosend := 0     
      i := byte[@maplist][y]
      xmit := byte[@xmitlist][y]      

      case EEPROM_read(i)
        1 :IF kbus.codecompare(@RTButton)
              codetosend :=  EEPROM_read(xmit)                                 
        2 :IF kbus.codecompare(@dial)
              codetosend :=  EEPROM_read(xmit)
        3 :IF kbus.codecompare(@Volup)        
              codetosend :=  EEPROM_read(xmit)  
        4 :IF kbus.codecompare(@VolDown)      
              codetosend :=  EEPROM_read(xmit)  
        5 :IF kbus.codecompare(@whlPlus)      
              codetosend :=  EEPROM_read(xmit)  
        6 :IF kbus.codecompare(@Whlmin)       
              codetosend :=  EEPROM_read(xmit)  
        7 :IF kbus.codecompare(@CDbutton1)    
              codetosend :=  EEPROM_read(xmit)  
        8 :IF kbus.codecompare(@CDbutton2)    
              codetosend :=  EEPROM_read(xmit)  
        9 :IF kbus.codecompare(@CDbutton3)    
              codetosend :=  EEPROM_read(xmit)  
        10:IF kbus.codecompare(@CDbutton4)    
              codetosend :=  EEPROM_read(xmit)  
        11:IF kbus.codecompare(@CDbutton5)    
              codetosend :=  EEPROM_read(xmit)  
        12:IF kbus.codecompare(@Remotelock)   
              codetosend :=  EEPROM_read(xmit)  
        13:IF kbus.codecompare(@remotehome)   
              codetosend :=  EEPROM_read(xmit)  
      case codetosend                                                                          
         1: kbus.sendcode(@TrunkOpen)
         2: kbus.sendcode(@RemoteHome)                                
         3: kbus.sendcode(@Remotelock)
         4: kbus.sendcode(@lock3)
         5: kbus.sendcode(@lockdriver)                        
         6: kbus.sendcode(@clownnose)                         
         7: kbus.sendcode(@Wrnblnk3sec)                       
         8: kbus.sendcode(@ParkLeft)                          
         9: kbus.sendcode(@ParkRight)                         
         10: kbus.sendcode(@InteriorOut)                                             
         11: kbus.sendcode(@FogLightsON)                      
         12: kbus.sendcode(@FogLightsOFF)                     
         13: kbus.sendcode(@HazzAndInt)                                                  
         14: kbus.sendcode(@sroofclose)                                                  
         15: kbus.sendcode(@sroofOpen)                                                   
         16: kbus.sendcode(@DRwindOpen)                                                  
         17: kbus.sendcode(@DRwindClose)             
         18: kbus.sendcode(@PRwindClose)
         19: kbus.sendcode(@PRwindOpen) 
         20: kbus.sendcode(@DFwindOpen) 
         21: kbus.sendcode(@DFwindClose)             
         22: kbus.sendcode(@PFwindClose)
         23: kbus.sendcode(@Wiper)      
         24: kbus.sendcode(@WiperFluid)  

      
PRI setLED(pin)  

IF pin == 0
  dira[23..20] := %0000
  outa[23..20] := %0000

ELSEIF pin == 99
  dira[23..20]:= %1111
  outa[23..20]:= %0001
  repeat 3
    waitcnt(clkfreq /5 + cnt)
    dira[23..20] *= 2 
    waitcnt(clkfreq /5 + cnt)      
  repeat 3
    waitcnt(clkfreq /5 + cnt)
    dira[23..20] /= 2 
    waitcnt(clkfreq /5 + cnt)      
  outa[23..20]:= %0000

ELSEIF pin == 98
  dira[23..20]:= %1111 
  outa[23..20]:= %0001 
  repeat 5
    waitcnt(clkfreq /5 + cnt)
    outa[23..20] <-= 1
    waitcnt(clkfreq /5 + cnt)
  outa[23..20] := %0000

ELSEIF pin == 1
  dira[23..20] := %0110
  outa[23..20] := %0110

ELSEIF pin == 2
  dira[23..20] := %1001
  outa[23..20] := %1001

ELSE
  dira[23..20] := %0000
  outa[23..20] := %0000
  dira[pin]~~
  outa[pin]~~

PRI decimaltostring(value,strptr) | i,x

  x := value == NEGX                                           
  if value < 0
    value := ||(value+x)                                       
    byte[strptr] := "-"
    strptr++    
                                                               
  i := 1_000_000_000                                           

  repeat 10                                                    
    if value => i
      byte[strptr] := value / i + "0" + x*(i == 1)             
      strptr++
      value //= i                                              
      result~~                                                 
    elseif result or i == 1
      byte[strptr] :="0"                                       
      strptr++
    i /= 10                                                    

byte[strptr] := 0
                                                           
   
PRI StrToBase(stringptr, base) : value | chr, index
{Converts a zero terminated string representation of a number to a value in the designated base.
Ignores all non-digit characters (except negative (-) when base is decimal (10)).}

  value := index := 0
  repeat until ((chr := byte[stringptr][index++]) == 0)
    chr := -15 + --chr & %11011111 + 39*(chr > 56)                              'Make "0"-"9","A"-"F","a"-"f" be 0 - 15, others out of range     
    if (chr > -1) and (chr < base)                                              'Accumulate valid values into result; ignore others
      value := value * base + chr                                                  
  if (base == 10) and (byte[stringptr] == "-")                                  'If decimal, address negative sign; ignore otherwise
    value := - value


                                                        

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

        FogLightsON  BYTE $3f, $0b, $bf, $0c, $00, $00, $00, $00, $00, $00, $01, $06
        FogLightsOFF BYTE $3f, $0b, $bf, $0c, $00, $00, $00, $00, $00, $00, $00, $06


        HazzAndInt   BYTE $3F, $05, $00, $0C, $70, $01 

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

'Config Mode Commands
get           BYTE "get",0
set           BYTE "set",0
sermon        BYTE "sermonitor",0
seroff        BYTE "seroff",0 
ComboBox      BYTE "ComboBox",0
CheckBox      BYTE "CheckBox",0  
testcmd       BYTE "TestCmd",0
sersend       Byte "sersend",0
serdone       Byte "serdone",0

'datalog mode   
logfilesuffix BYTE ".txt",0



sndBcast     Byte "Broadcast",0
sndcdw       Byte "cdw",0
sndnav       Byte "nav",0
sndmenu      Byte "Menu",0
sndmfl       Byte "MFL",0
sndpdc       Byte "PDC",0
sndrad       Byte "RAD",0
snddsp       Byte "DSP",0
sndike       Byte "KMB",0
sndtv        Byte "TV",0
sndlcm       Byte "Lights",0
sndMID       Byte "MID",0
sndtel       Byte "Phone",0
sndnavbar    Byte "Navbar",0
sndobctxt    Byte "OBC Text",0
sndseats     Byte "Stored",0
sndNA        Byte " ",0   


'Config remap for buttons
maplist       BYTE 102,105,107,114,116,118
xmitlist      BYTE 103,104,106,113,115,117

'Config remap for bluetooth
btmaplist     BYTE 121,123,125,127,133,131,129
btxmitlist    BYTE 120,122,124,126,132,130,128






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