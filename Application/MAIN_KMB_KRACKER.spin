''********************************************
''*  Car Kracker Main, V0.58                 *
''*  Author: Nick McClanahan (c) 2012        *
''*  See end of file for terms of use.       *
''********************************************

{-----------------REVISION HISTORY-----------------
  For complete usage and version history, see Release_Notes.txt

0.58  Added WAV Riff tag support
      Added DSP support (set in Kustomizer)
      Added Remapping within music mode
      Added Textscroll
      Added Prev / Next Support

0.57: Added Text Display to RAD/NAV
      Improved EEPROM reading reliability
 
0.56: Fixed Wav Playback bug
                                                                                                
0.55: Major Release                                                                             
-----                                                                                           
New:     Debug mode                                                                             
           Run main modes and tests from the serial terminal by hitting 'd' during bootup
           Loop tests are available, along with cmd fire tests and bus sniffers                 
           Main modes are much more verbose.  Can be read with 'Kracker Status' tab             
                                                                                                
New:     LED Notifier                                                                           
            LED's are updated to note status                                                    
            1: LED's run towards USB jack = EEPROM Read                                         
            2: Towards jack and return = Kbus In                                                
            3: LED's run Away from USB jack = EEPROM Write                                   
            4: Away jack and return = Kbus Out                                               
            5: Continous xoxox = no or bad SD                                                       
                                                                                                    
New:     Stateless TX/RX engine                                                                     
            more reliable transfers, with a larger buffer and less memory                           
                                                                                                    
New:     Radio button Remaps                                                                        
            Remap radio buttons to other functions using the Kustomizer                             
            Display car data on the radio display                                                   
            Remap CD buttons to CD+ and CD- to support more albums        
    
New:     Firmware version reported to Kustomizer on bootup                             
New:     Set the audio vol level in the kustomizer to change Kracker Audio level       
New:     Default config TX/RX speed is now 115_200                                     
New:     Cogs are hardmapped to reduce jitter
                                                                                       
Fixed:   A few new bus commands, and better, more compatible commands for unlock / lock
Fixed:   Faster sample speed for touch buttons to eliminate audio interference         
Fixed:   Possible buffer overflow on SD card player object                             
                                                                                       
Removed: Nothing
     
For Previous Releases, see Release_Notes.txt
}


CON
  _clkmode = xtal1 + pll16x                             ' Crystal and PLL settings.
  _xinfreq = 5_000_000                                  ' 5 MHz crystal (5 MHz x 16 = 80 MHz).
  Menudelay = 80_000_000 * 5

  EEPROM_Addr   = %1010_0000   
  EEPROM_base   = $8000
  stack_base    = $7500
  maincog =  4, LEDcog = 2  
'Cogs are custom mapped to reduce jitter - COG 0 goes with audio.  Definitions:
'COG7: Touch / SD __COG6: Kbus RX  __Cog 5: Debug Console  __Cog 4: Main Thread  __Cog 3: Audio Buffer __Cog 2: LED notifier __Cog 0: Audio

OBJ
  Kbus         : "kbusCore.spin"
  debug        : "DebugTerminal.spin" 
  Buttons      : "Touch Buttons"
  music        : "music_manager"
  i2cObject    : "i2cObject.spin"
  SD           : "FSRW"  
  
VAR
'LED Notifier
BYTE ledctrl
LONG stack[10]
LONG stack2[20]

'Variables for Config Mode
BYTE configbuffer[20]
BYTE controltype[20]
BYTE getorset[5]
BYTE bussendvalue[20]

'Variables for log mode
BYTE senderlookup[3]
BYTE logfilename[10]      
LONG speed, rpm, intemp, outtemp, ignitionStat
BYTE loggeditems[15]  

'Variables for remap mode
BYTE triggeritems[6]
BYTE    xmititems[6]
BYTE    remapTel



'Variables for Music Mode
BYTE radioremaps[8]
BYTE playerstatus
BYTE textfield
LONG updatestat       ' 
BYTE textrepeats      'How many times to repeat text
WORD LEDtext          'Address for the text to be displayed



PUB Initialize
'We use this method to dump running the main process in Cog 0
coginit(maincog, main, stack_base)
coginit(LEDcog, LEDnotifier, @stack)
debug.StartRxTx(31, 30, %0000, 115200)
cogstop(0)


PUB main | i, c, nextupdate, lastupdate
i2cObject.Init(29, 28, false)
kbus.Start(27, 26, %0010, 9600)

setled(1)
IF EEPROM_read(101) <> 0
  debug.str(string(16,"Hit d key for debug",13))

lastupdate := cnt
nextupdate := 0

repeat
  nextupdate += ||(cnt - lastupdate)
  lastupdate := cnt
  c := debug.rxcheck
  if c == "C" 
    configmode
  if (c == "d") OR (c == "D")
    debugmode
  if nextupdate > menudelay
    quit



setLED(0)          

IF EEPROM_read(112) == 0
  setLED(0)
  Buttons.start(clkfreq / 25000)                  
  i := cnt + (menudelay)
  repeat while  cnt < i 
    case Buttons.State
      %1000_0000 : COGSTOP(7)
                   setLED(23)
                   SerialRepeatMODE     'Sniffs bus and repeats over USB

      %0100_0000 : COGSTOP(7)  
                   setLED(22)
                   DiagnosticMODE       'Diagnostic Mode for connecting PC

      %0010_0000 : COGSTOP(7)
                   setLED(21)     
                   MusicMode            'Music Mode, start with a button

      %0001_0000 : COGSTOP(7)
                   setLED(20)
                   ConnectionTestMODE   'Test connection by blinking Clown Nose

  COGSTOP(7)
  setLED(20)
  Musicmode

case EEPROM_read(101)
  0 : DiagnosticMode
  1 : MusicMode
  2 : SerialRepeatMode
  3 : RemapperMode
  4 : DataLogMode
  OTHER : Musicmode

PUB debugmode
waitcnt(clkfreq  / 800 + cnt)
repeat until debug.rxcheck  == -1

repeat
  debug.str(@debugmenu)
   case debug.decin
    0 : DiagnosticMode
    1 : MusicMode
    2 : SerialRepeatMode
    3 : RemapperMode
    4 : DataLogMode
    5 : loophex
    6 : loopcmd(1)
    7 : loopcmd(0)
    8 : loopAudio
    9 : loopRadiotxt
    10 :loopeeprom
    11 : debugkmb
  waitcnt(clkfreq / 2 + cnt)

DAT 'Debug Menu Text
debugmenu     BYTE      16,"DEBUG MENU",13
              BYTE      "Main Modes:",13
              BYTE      "  0: Diagnostic",13
              BYTE      "  1: Music",13
              BYTE      "  2: SerialRepeat",13
              BYTE      "  3: Remapper",13
              BYTE      "  4: DataLog",13
              BYTE      "Test Modes: (e to escape test)",13
              BYTE      "  5: Hex Bus Sniffer",13
              BYTE      "  6: CMD Blast, Bus Watch",13
              BYTE      "  7: CMD Blast, Single",13
              BYTE      "  8: Audio Player",13
              BYTE      "  9: Write text to Radio/NAV",13
              BYTE      " 10: Read EEPROM",13 
              BYTE      " 11: Read KMB values",13,0

kmbmenu       BYTE      16,"Read KMB",13
              BYTE      "  0: Return to Main Debug",13
              BYTE      "  1: Read Time, Parsed",13
              BYTE      "  2: Read Date, Parsed",13
              BYTE      "  3: Read Fuel, Parsed",13
              BYTE      "  4: Read Range, Parsed",13,0                            

eeprom1       BYTE      16,"(r)ead, (w)rite, or (e)xit?",13,0
eeprom2       BYTE      "Enter Address(0-500)",0
eeprom3       BYTE      " Has Value: ",0
eeprom4       BYTE      " Enter new value: ",0
eeprom5       BYTE      " Done",13,0

PUB loopeeprom | i, x
debug.str(@eeprom1) 
repeat
  debug.newline
  case debug.charin
    "e": return
    "r":   debug.str(@eeprom2)
           i := debug.decin
           debug.positionx(0)
           debug.clearend
           debug.dec(i)
           debug.str(@eeprom3)            
           debug.dec(EEPROM_read(i))
           next
    "w":   debug.str(@eeprom2)
           i := debug.decin
           debug.dec(i)
           debug.str(@eeprom4)
           x := debug.decin            
           EEPROM_set(i, x)
           debug.dec(x)
           debug.str(@eeprom5)
           next                                             


PUB debugkmb  | i
repeat
  debug.str(@kmbmenu)
  i := debug.decin 
   case i
        0 : return
        1 : kbus.localtime(@configbuffer)
            debug.str(@configbuffer)
        2 : kbus.date(@configbuffer)
            debug.str(@configbuffer)
        3 : kbus.fuelaverage(@configbuffer)
            debug.str(@configbuffer)
        4 : kbus.estrange(@configbuffer)
            debug.str(@configbuffer)
  waitcnt(clkfreq / 2 + cnt)


PUB loopaudio
  debug.clear
  debug.str(string("Playing 01_01.wav",13,"Hit e to stop and exit",13))
  debug.str(string("w=CD Up, s=CD Down d=Track+, a=Track- 1=vol-, 2=vol+, q=stop Track",13))
  debug.str(string("3=Artist, 4= Album, 5=Track, 6=Genre",13))
if \music.start(1, 0)                                                         
  debug.str(string("Couldn't mount SD card!!!",13))
  repeat 
    setLED(201)   
    waitcnt(clkfreq / 3 + cnt)

    
music.playtrack(1,1)

 
repeat
  case debug.rxcheck
    "e" : music.stop
          return
    "1" : music.changevol("m")
    "2" : music.changevol("p")
    "3" : debug.str(music.artist)
    "4" : debug.str(music.album)
    "5" : debug.str(music.song)
    "6" : debug.str(music.genre)
    "q" : music.stopplaying
    
    "w" : IF music.playtrack("n", 1 )
             debug.str(string("Audio File Not Found: "))
          debug.str(music.fileptr)          
    
    "s" : IF music.playtrack("p", 1 )
             debug.str(string("Audio File Not Found: "))
          debug.str(music.fileptr)
    
    "d" : IF music.playtrack("c","n")
             debug.str(string("Audio File Not Found: "))
          debug.str(music.fileptr)

    "a" : IF music.playtrack("c","p")
             debug.str(string("Audio File Not Found: "))
          debug.str(music.fileptr)                  
  IF music.nexttrack
    music.playtrack("c","n")

  
      
PUB loopradiotxt
repeat
  debug.str(string(16,"Enter String and press enter to write text to radio display",13))
  debug.str(string("Or hit enter to go back",13))
  debug.StrInMax(@configbuffer, 11)
  if configbuffer == 0
    return
  kbus.sendtext(@configbuffer)
  kbus.sendnav(@configbuffer, 2)   



PUB loophex  | i, x
'debug.clear      
debug.str(string(16,"Byte Bus Monitor",13))
debug.newline
debug.dec(cnt / 80000)
debug.char(":")
debug.char(" ")

repeat
    i := kbus.rxcheck
    IF i > -1
      debug.hex(i,2)
      debug.char(32)
      IF ++x == 15
        debug.newline
        debug.dec(cnt / 80000)
        debug.char(":")
        debug.char(" ")
        x~
    IF debug.rxcheck == "e"
      return  

PUB loopcmd(option) | i
'debug.clear          
debug.str(string(16,"Command Blast",13))   
configblast(22)
debug.str(string("Sent Cmd 22",13))

IF option == 1
  serialrepeatmode
ELSEIF option == 2
  repeat
    waitcnt(clkfreq * 10 + cnt)
    configblast(22)
    debug.str(string("Sent Cmd 22",13))    
    IF debug.rxcheck == "e"
      return  


PUB configmode  | controlSelected, eepromoffset
setLED(0)
setLED(2)
waitcnt(clkfreq  / 800 + cnt)
repeat until debug.rxcheck   == -1
debug.str(string("Version",13, "0.58", 13))

repeat
  debug.strin(@configbuffer)

  IF strcomp(@configbuffer, @testcmd)
    configblast(debug.decin)
    debug.strin(@getorset)
    debug.strin(@configbuffer)


  IF strcomp(@configbuffer, @default)
    debug.strin(@getorset)
    debug.strin(@configbuffer)
    eepromreset                                                     

  IF strcomp(@configbuffer, @sermon)
    serialmonitormode

    
  IF strcomp(@configbuffer, @combobox) 
    eepromoffset := 100 + debug.decin
    getseteeprom(eepromoffset) 

  IF strcomp(@configbuffer, @checkbox) 
    eepromoffset := 200 + debug.decin
    getseteeprom(eepromoffset)

DAT
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
default       Byte "default",0
modesel       BYTE "m",0    


pri eepromreset | i
repeat i from 0 to 400
  eeprom_set(i, 255)
  
Pri getseteeprom(eepromoffset)

debug.strin(@getorset)
  IF strcomp(@getorset, @set)
    EEPROM_set(eepromoffset,debug.decin)
  ELSE 
    sendsetting(eepromoffset,1)

Pri EEPROM_set(addr,byteval)
setLED(99)
waitcnt(cnt + 100_000)
i2cObject.writeLocation(EEPROM_ADDR, addr+EEPROM_base, byteval, 16, 8)
waitcnt(cnt + 200_000) 

Pri EEPROM_Read(addr) | eepromdata
setLED(199)
eepromdata := 0

eepromdata := i2cObject.readLocation(EEPROM_ADDR, addr+EEPROM_base, 16, 8)
return eepromdata

Pri sendsetting(addr,len) |  i

i := EEPROM_Read(addr) 
IF i == 255
  debug.str(string("-1"))  
ELSE
  debug.dec(i)
debug.newline   


PUB datalogmode     | i,repeattimer, repeatlimit, nextupdate, lastupdate
debug.str(string(16,"Entering:Data Log Mode",13)) 
BYTEfill(@configbuffer,0,20)
i := EEPROM_read(199)
repeattimer := 0
EEPROM_set(199, i + 1)
bytefill(@logfilename, 0, 10)


i:= \sd.mount_explicit(0, 1, 2, 3)
If i < 0
  repeat 
    setLED(201)  


decimaltostring(EEPROM_read(199), @logfilename)
bytemove(@logfilename+strsize(@logfilename), @logfilesuffix, 5)
csvheader 


Case EEPROM_Read(119)
  0: repeatlimit := 1
  1: repeatlimit := 2
  2: repeatlimit := 4
  3: repeatlimit := 20
  4: repeatlimit := 240      



lastupdate := cnt
nextupdate := 0



repeat
  IF kbus.nextcode(50)
    setLED (200)
    If loggeditems[1] == 1
      passiveupdate(kbus.speed, @speed)
    If loggeditems[3] == 1
      passiveupdate(kbus.Ignitionstatus, @ignitionstat)
    If loggeditems[4] == 1
      passiveupdate(kbus.rpms, @rpm)
    If loggeditems[9] == 1
      passiveupdate(kbus.cooltemp, @intemp)
    If loggeditems[7] == 1  
      passiveupdate(kbus.outtemp, @outtemp)

  nextupdate += ||(cnt - lastupdate)
  lastupdate := cnt
  IF nextupdate > 1_200_000_000
    nextupdate := 0
    repeattimer++
    If  repeattimer == repeatlimit
      writetolog
      repeattimer := 0


pri passiveupdate(newval, valptr)
IF newval > -1
  long[valptr] := newval
  debug.str(string("Updated_Value: "))
  debug.dec(newval)
  debug.newline

PRI csvheader
debug.str(string("Writing logfile Header",13))
sd.popen(@logfilename, "a")    

IF EEPROM_Read(201) <> 0   ' speed
  sd.pputs(string("speed,"))
  loggeditems[1] := 1

IF EEPROM_Read(202) <> 0   ' time
  sd.pputs(string("time,"))
  loggeditems[2] := 1

IF EEPROM_Read(203) <> 0   ' Ignition
  sd.pputs(string("Ignition Status,"))
  loggeditems[3] := 1

IF EEPROM_Read(204) <> 0   ' RPM
  sd.pputs(string("rpm,"))
  loggeditems[4] := 1

IF EEPROM_Read(205) <> 0   ' date
  sd.pputs(string("Date,"))
  loggeditems[5] := 1

'IF EEPROM_Read(206) <> 0   ' GPS
'   sd.pputc("x")
'   sd.pputc(",")
'  loggeditems[6] := 1
   
IF EEPROM_Read(207) <> 0   ' outside temp
  sd.pputs(string("outsidetemp,"))
  loggeditems[7] := 1

IF EEPROM_Read(208) <> 0   ' inside temp
  sd.pputs(string("coolanttemp,"))
  loggeditems[8] := 1

IF EEPROM_Read(209) <> 0   ' fuelconsum
  sd.pputs(string("Avg Fuel consumption,"))
  loggeditems[9] := 1

IF EEPROM_Read(210) <> 0   ' range
  sd.pputs(string("Estimated Range,"))
  loggeditems[10] := 1

IF EEPROM_Read(211) <> 0   ' Odometer
  sd.pputs(string("Odometer,"))
  loggeditems[11] := 1

  
sd.pputc("0")
sd.pputc(13)
sd.pputc(10)
sd.pclose


Pri writetolog  
debug.str(string("Writing logfile Entry",13))
setled(99)

BYTEfill(@configbuffer,0,20)

sd.popen(@logfilename, "a")

IF loggeditems[1] == 1   ' speed
  decimaltostring(speed, @configbuffer)  
  sd.pputs(@configbuffer) 
  sd.pputc(",")

IF loggeditems[2] == 1   ' time
  kbus.localtime(@configbuffer)
  sd.pputs(@configbuffer) 
  sd.pputc(",")
  
IF loggeditems[3] == 1   ' Ignition
  decimaltostring(Ignitionstat, @configbuffer)
  sd.pputs(@configbuffer) 
  sd.pputc(",")

IF loggeditems[4] == 1   ' RPM
  decimaltostring(rpm, @configbuffer)  
  sd.pputs(@configbuffer) 
  sd.pputc(",")

IF loggeditems[5] == 1   ' date
  kbus.date(@configbuffer)
  sd.pputs(@configbuffer) 
  sd.pputc(",")

'IF loggeditems[6] == 1   ' GPS
'   sd.pputc("x")
'   sd.pputc(",")
   
IF loggeditems[7] == 1   ' outside temp
  decimaltostring(outtemp, @configbuffer)  
  sd.pputs(@configbuffer) 
  sd.pputc(",")

IF loggeditems[8] == 1   ' inside temp
  decimaltostring(intemp, @configbuffer)  
  sd.pputs(@configbuffer) 
  sd.pputc(",")

IF loggeditems[9] == 1   ' fuelconsum
  kbus.fuelaverage(@configbuffer)  
  sd.pputs(@configbuffer) 
  sd.pputc(",")

IF loggeditems[10] == 1   ' estimated range
  kbus.EstRange(@configbuffer)  
  sd.pputs(@configbuffer) 
  sd.pputc(",")

IF loggeditems[11] == 1   ' fuel
  decimaltostring(kbus.odometer, @configbuffer)  
  sd.pputs(@configbuffer) 
  sd.pputc(",")

sd.pputc("0")
sd.pputc(13)
sd.pputc(10)
sd.pclose


PUB serialmonitormode | i, stopflag

i := 0
stopflag := 0

repeat
  IF kbus.nextcode(50)
    setLED (199)
    repeat i from 0 to BYTE[kbus.codeptr + 1]
      debug.hex(BYTE[kbus.codeptr + i],2)
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
      setLED (99)
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

pri lookupmember(selected) | code

code := lookdown(BYTE[kbus.codeptr + selected]: $00, $18, $76, $BF, $D0, $3f, $3B, $80, $ff, $44, $5B, $E0, $3F, $7F, $50, $60, $08, $72, $C8, $C0, $6A, $68, $F0)

if code == 0
  return @@senderlist[23]

return @@senderlist[code]


DAT 'List of Sender ID's
senderlist WORD  0,  @sndGM, @sndcdw, @sndCDdin, @sndBcast, @sndLCM, @sndDIA, @sndGT, @sndIKE, @sndLOC, @sndEWS, @sndIHKA, @sndIRIS, @sndLWS, @sndNAV, @sndMFL, @sndPDC, @sndSHD, @sndSM, @sndTel, @sndMID, @sndDSP, @sndRAD, @sndunk, @sndBMBT

sndGM        Byte "GM Module",0        '$00
sndcdw       Byte "CD Changer",0       '$18
sndCDdin     Byte "CD Din Chg",0       '$76
sndBcast     Byte "Broadcast",0        '$BF
sndLCM       BYTE "Light Control",0    '$D0
sndDIA       BYTE "Diagnostics",0      '$3f          
sndGT        BYTE "Graphics Drv",0     '$3B
sndIKE       BYTE "IKE Cluster",0      '$80
sndLOC       BYTE "Local",0            '$ff
sndEWS       BYTE "Immobilizer",0      '$44
sndIHKA      BYTE "Heating/AC",0       '$5B
sndIRIS      BYTE "Radio Info",0       '$E0
sndLWS       BYTE "Steering",0         '$3F                                      
sndNAV       BYTE "NAV sys",0          '$7F
sndMFL       BYTE "S Wheel Btns",0     '$50
sndPDC       BYTE "Park Distance",0    '$60
sndSHD       BYTE "Sunroof",0          '$08 
sndSM        BYTE "Seat Module",0      '$72 
sndTel       BYTE "Telephone",0        '$C8 
sndMID       BYTE "Multi Info Disp",0  '$C0 
sndDSP       BYTE "DSP",0              '$6A 
sndRAD       BYTE "Radio",0            '$68 
sndBMBT      BYTE "Mon. Ctrl Panel",0  'F0  
sndunk       BYTE " ",0                'unidentified




    
PUB configblast(cmd) | selected
kbus.sendcode(@@CMDLIST[cmd])

'Some commands need a second message
 case cmd
   2       :  kbus.sendcode(@whlplusup)                     
   3       :  kbus.sendcode(@whlminup)
SetLED(100)  

DAT 'List of Commands to Blast
'Command List      0x10           1x10          2x10         3x10           4x10         5x10       6x10           7x10          8x10          9x10
CMDLIST  WORD   @volup,      @voldown,     @whlplus,     @whlmin,      @RTButton,    @Dial,     @DRwindOpen,  @DRwindClose, @PRwindClose,  @PRwindOpen
         WORD   @DFwindOpen, @DFwindClose, @PFwindOpen,  @PFwindClose, @SRoofClose, @SRoofOpen, @DMirrorFold, @DMirrorOut,  @PMirrorFold,  @PMirrorOut
         WORD   @ClownNose,  @Wrnblnk,     @Wrnblnk3sec, @ParkLeft,    @ParkRight,  @StopLeft,  @StopRight,   @FogLightsON, @FogLightsOFF, @HazzAndInt
         WORD   @Lock3,      @LockDriver,  @TrunkOpen,   @Wiper,       @WiperFluid



PUB connectionTestMode
debug.str(string(16,"Entering: Connection Test Mode",13))

repeat
  SetLED(100)
  kbus.sendcode(@clownnose)
  waitcnt(clkfreq * 5 + cnt)


DAT 'Music and Radio messages
'RADIO BUTTONS
        CDCHG        BYTE $68, $05, $00, $38, $06
        TRKCHG       BYTE $68, $05, $00, $38, $05
        RNDCHG       BYTE $68, $05, $00, $38, $08 
     Nobuttons       BYTE $68, $04, $FF, $3B, $00, $A8   

'CD CHANGER
        playtrack     BYTE $68, $05, $18, $38, $03, $00
        stoptrack     BYTE $68, $05, $18, $38, $01, $00
        pollCD        BYTE $68, $03, $18, $01
        pollDIN       BYTE $68, $03, $76, $01
        CDstatusreq   BYTE $68, $05, $18, $38, $00, $00 
        CDannounce    BYTE $18, $04, $FF, $02, $01
        CDrespond     BYTE $18, $04, $68, $02, $00

'radio button remap fields
radbutlist    BYTE 134,135,136,137,138,139,140,141, 142, 143, 111, 144
'                  CD1                 CD6 T-  T+   vol  Aux, RND, dsp
'                   0                   5   6   7    8    9    10   11

PUB MUSICMODE     | i, d, volset , len, cdtype, lastupdate, nextupdate, randctr, remap
debug.str(string(16,"Entering: Music Mode",13))
updatestat := FALSE
randctr := FALSE
          
volset :=  EEPROM_read(byte[@radbutlist][8])                 ''Load Stored Preferences - dropdowns and Volume
debug.str(string("Volume Set: "))
debug.dec(volset)
debug.newline
remapTel := 3 

repeat i from 0 to 7
  radioremaps[i] := EEPROM_read(byte[@radbutlist][i])

''Check Stored Preference for AuxIn Only 
IF EEPROM_read(byte[@radbutlist][9]) == 1
  music.AuxIn
  debug.str(string("Entered AuxIn Only Mode",13))
ELSE
  if \music.start(volset, EEPROM_read(144))
    debug.str(string("Couldn't mount SD card!!!",13))
    repeat 
      setLED(201)   
      waitcnt(clkfreq + cnt)
      debug.str(string("Couldn't mount SD card!!!",13))


IF EEPROM_read(109) == 1
  remap := TRUE
  remappersetup  
ELSE
  remap := FALSE


kbus.sendcode(@CDAnnounce)
debug.str(string("Nothing, CD Announce",13))

lastupdate := cnt
nextupdate := 0

repeat
  i := kbus.nextcode(50)
  IF i
    displaybuffer
    debug.str(string(","))
    debug.str(lookupmember(0))
    debug.str(string(","))
    debug.str(lookupmember(2))
    debug.newline

    IF kbus.codecompare(@pollCD)
       kbus.sendcode(@CDRespond)  
       debug.str(string("CD Polled,Responded",13))
      next
    IF kbus.codecompare(@pollDIN)
       setdin
       kbus.sendcode(@CDRespond)  
       debug.str(string("CD Polled,Responded",13))


    IF kbus.codecompare(@IKEoff)
       debug.str(string("PowerDown,Stopped",13))
       remapTel := 0    
       music.stopplaying  

    If kbus.codecompare(@IKEon)
       debug.str(string("PowerUp,Stopped",13))
       kbus.sendcode(@CDAnnounce)
       debug.str(string("Nothing, CD Announce",13))
       randctr := FALSE
     
    IF kbus.codecompare(@cdstatusreq)
       debug.str(string("Status Request,"))
       IF music.inPlaymode
         kbus.sendcode(music.PlayingCode)
         debug.str(string(",Status Playing",13))
       ELSE
         kbus.sendcode(music.notplaycode)
         debug.str(string(",Status Not Playing",13))        
       next

    IF kbus.codecompare(@playtrack)
       kbus.sendcode(music.StartPlayCode)
       debug.str(string("Play Start,Begin Playing",13))                                    
       music.playtrack("c","c") 
       next
     
    IF kbus.codecompare(@stoptrack)
       kbus.sendcode(music.TrackEndCode)
       music.stopplaying
       debug.str(string("Stop Track,Nothing",13))
       updatestat := FALSE
       next
     
{{    IF kbus.partialmatch(@RNDCHG, 5)
       IF RANDctr
         debug.str(string("Random,"))      
         musiccmd(EEPROM_read(111))
       ELSE
        randctr := TRUE 
       next
}}     
    IF kbus.partialmatch(@CDCHG, 5)
       i := BYTE[kbus.codeptr+5] - 1
       IF i < 6
         debug.str(string("CD CHG"))
         debug.dec(i + 1)
         debug.str(string(","))
         musiccmd(radioremaps[i])
       next
     
    IF kbus.partialmatch(@TRKCHG, 5)
       i := BYTE[kbus.codeptr+5]
       If i == 1
         debug.str(string("Prev Track,"))
         musiccmd(radioremaps[6])    
       ELSE
         debug.str(string("REC: Next Track,"))
         musiccmd(radioremaps[7])
       next

    IF kbus.codecompare(@nobuttons)
       debug.str(string("exit text disp,Nothing",13))
       updatestat := false
       next

    IF remap
      remapcheck
      
  IF NOT music.nexttrack
    music.playtrack("c","n")
    kbus.sendcode(music.startplaycode)
    debug.str(string("(endtrack),Next Track",13))

  nextupdate += ||(cnt - lastupdate)
  lastupdate := cnt
  IF nextupdate > 480_000_000
    IF updatestat == TRUE 
      debug.str(string("(Text Update),"))
      musiccmd(textfield)
    nextupdate := 0


PRI setdin

  IF byte[@playtrack][2] == $18
     debug.str(string("(Set to CDDIN),Nothing",13))
     byte[@playtrack][2]   := $76
     byte[@stoptrack][2]   := $76
     byte[@pollCD][2]      := $76
     byte[@CDStatusreq][2] := $76
     byte[@CDannounce]     := $76
     byte[@CDrespond]      := $76
     music.buscodeupdate(0, $76)



      
Pri musiccmd(selectedaction)    | i , x

case selectedaction
  0 : debug.str(string("Not Found - Nothing",13)) 

  1 :        'Previous Track       
      debug.str(string("Prev Track",13))
      music.playtrack("c", "p")
      playerstatus := FALSE

  2 :        'Next Track           
      debug.str(string("Next Track",13))
      music.playtrack("c", "n")

  3 :        'Previous CD          
      music.playtrack("p", 1)
      debug.str(string("Prev CD",13)) 
      kbus.sendcode(music.StartPlayCode)  

  4 :        'Next CD
      music.playtrack("n", 1)
      debug.str(string("Next CD",13))
      kbus.sendcode(music.StartPlayCode)
                   
  5..10 :        'CD 1-6
      music.playtrack(selectedaction -4, 1)
      debug.str(string("Change CD to #"))
      debug.dec(selectedaction - 4)
      debug.newline 
      settext(music.StartPlayCode)

  11 :       'Aux In               
    IF music.AuxIn
      debug.str(string("(Aux On)",13)) 
      settext(string("Aux On"))
    ELSE
      debug.str(string("(Aux Off)",13))
      settext(string("Aux Off"))

  12 :       'Time normally 12                 
      debug.str(string("Time Text",13))
      kbus.localtime(@configbuffer)
      settext(@configbuffer)
      setupdate(selectedaction)

  13 :       'Avg Fuel Consumption 
      debug.str(string("Fuel Text",13))
      kbus.fuelaverage(@configbuffer)
      i := strsize(@configbuffer) 
      Bytemove(@configbuffer + i, @mpgsuffix, 5)
      settext(@configbuffer)
      setupdate(selectedaction)      
 
  14 :       'Estimated Range      
      debug.str(string("Range Text",13))
      kbus.estrange(@configbuffer)
      i := strsize(@configbuffer)  
      Bytemove(@configbuffer + i , @milessuffix, 7)
      settext(@configbuffer)
      setupdate(selectedaction)

      
  15 :       'Date 
      debug.str(string("Date Text",13))
      kbus.date(@configbuffer)
      settext(@configbuffer)
      setupdate(selectedaction)
      
  16 :       'Kracker Vol + 
      debug.str(string("(Kracker Vol+)",13))
      settext(string("K vol+"))
      music.changevol(-1)

  17 :       'Kracker Vol - 
      debug.str(string("(Kracker Vol-)",13))
      settext(string("K vol-"))
      music.changevol(+1)      

  18 :       'Artist Name
      debug.str(string("Artist Name",13))
      settext(music.artist)
      setupdate(selectedaction)

  19 :       'Album Name
      debug.str(string("Album Name",13))
      settext(music.Album)
      setupdate(selectedaction)

  20 :       'Track Name
      debug.str(string("Track Name",13))
      settext(music.song)
      setupdate(selectedaction)

  21 :       'Genre Name
      debug.str(string("Genre",13))
      settext(music.genre)
      setupdate(selectedaction)

  Other :  debug.str(string("Command Not Found",13))


PRI setupdate(field)
updatestat := TRUE
textfield := field



PUB DIAGNOSTICMODE 
debug.stop
kbus.stop

dira[30] := 1 'FTDI settings (tx = 30, rx = 31)
dira[31] := 0
dira[26] := 1 'Bus settings (tx = 26 rx = 27)
dira[27] := 0
repeat
  outa[26] := !ina[31]
  outa[30] := ina[27]
    

PUB SERIALREPEATMODE  | i
debug.str(string(16,"Entering:Repeat Mode",13)) 
setLED(205) 

repeat
  IF kbus.nextcode(100)
    displaybuffer
  IF debug.charin == "e"
      return  


PUB REMAPPERMODE   | i,x,y, xmit 
setLED(0)
debug.str(string(16,"Entering:Remapper Mode"))  
remappersetup


repeat
    kbus.nextcode(0)
    setLED(199)  
    repeat y from 0 to 5                                'check every map
      IF triggeritems[y] < 250  
        IF kbus.codecompare(@@maptrg[triggeritems[y]-1])
           debug.str(string(13,"REC code: "))  
           debug.char(triggeritems[y] + $30)
           debug.str(string(" - XMIT: Code"))
           kbus.sendcode(@@mapxmit[xmititems[y]-1])  
           debug.char(xmititems[y] + $30)


Pri remappersetup | i, x, y, xmit

repeat i from 0 to 5
  triggeritems[i] := EEPROM_read(mapfieldlist[i])
  xmititems[i] :=    EEPROM_read(xmitfieldlist[i])
  IF (triggeritems[i] == 0) OR (xmititems[i] == 0)
    triggeritems[i] := 255



pri remapcheck | y


IF kbus.codecompare(@RTButton)   
 IF remaptel < 3
  remaptel++
  return
    
repeat y from 0 to 5                              
  IF triggeritems[y] < 250  
    IF kbus.codecompare(@@maptrg[triggeritems[y]-1])
       debug.str(string("REMAP,"))  
       debug.char(triggeritems[y] + $30)
       debug.str(string(","))
       kbus.sendcode(@@mapxmit[xmititems[y]-1])  
       debug.char(xmititems[y] + $30)
       debug.newline
  
DAT ' Remaps 
'                 0x10           1x10          2x10         3x10           4x10         5x10         6x10           7x10          8x10          9x10
MAPTrg   word   @RTButton,    @dial,        @volup,       @voldown,     @whlplus,     @whlmin,     @Remotelock,   @remotehome,   @IKEon,      @IKEoff
         word   @keyinsert,   @keyremove      

'                 0x10           1x10           2x10         3x10           4x10         5x10         6x10            7x10          8x10          9x10
MAPXmit  word   @TrunkOpen,   @lock3,        @lockdriver,  @clownnose,   @Wrnblnk3sec, @ParkLeft,    @ParkRight,   @StopLeft,   @StopRight 
         word   @FogLightsON, @FogLightsOFF, @HazzAndInt,  @sroofclose,  @sroofOpen,   @DRwindOpen,  @DRwindClose, @PRwindClose, @PRwindOpen, @DFwindOpen         
         word   @DFwindClose, @PFwindClose,  @PFwindOpen,  @Wiper,       @WiperFluid  

'How long is the xmit list
MAPxmitLn BYTE   30
MAPTrgLn BYTE   10


'Field values in Kustomizer
mapfieldlist       BYTE 102,105,107,114,116,118
xmitfieldlist      BYTE 103,104,106,113,115,117


pri setLED(mode)
ledctrl := mode

Pri settext(strptr)
ledtext := strptr

      
PUB LEDnotifier  | switcher, i
{{Notification Options:
23..20: Each LED    | 0:   All Off  |   1: Middle two |   2: Outer two
   199: Towards USB | 200: and back |  99: USB Away   | 100: And Back}}

repeat
  switcher := LEDctrl
  dira[23..16] := %1111_1111
  IF LEDtext
    i := LEDtext
    LEDtext := 0  
    IF strsize(i) > 10
      kbus.textscroll(i)
    ELSE
      kbus.sendtext(i)


  case switcher
    0: outa[23..16] := %0000_0000
    1: outa[23..16] := %0110_0000
    2: outa[23..16] := %1001_0000
    99,100  :
      outa[23..16]:=  %1000_0000     
      waitcnt(clkfreq /30 + cnt)     
              repeat 7                       
                waitcnt(clkfreq /30 + cnt)   
                outa[23..16] ->= 1           

              IF ledctrl   == 100            
                waitcnt(clkfreq /30 + cnt)   
                repeat 7                     
                  waitcnt(clkfreq /30 + cnt) 
                  outa[23..16] <-= 1         
       LEDctrl := 0

    201 :
           outa[23..16] := %1010_1010
           repeat 4
              waitcnt(clkfreq / 6 + cnt)
              outa[23..16] ->= 1
              waitcnt(clkfreq / 6 + cnt)
              outa[23..16] <-= 1

           LEDctrl := 0

    199,200 :
      outa[23..16]:=  %0000_0001  
              waitcnt(clkfreq /30 + cnt)                       
              repeat 7                                         
                waitcnt(clkfreq /30 + cnt)                     
                outa[23..16] <-= 1                             

              IF ledctrl == 200                                                            
                waitcnt(clkfreq /30 + cnt)                                                   
                repeat 7                     
                  waitcnt(clkfreq /30 + cnt) 
                  outa[23..16] ->= 1         
       LEDctrl := 0

    23..20 :  outa[23..20] := %0000
              outa[ledctrl]~~  
 

Pri codetostring(strptr) | i

      repeat i from 0 to BYTE[strptr+1] + 1
        debug.hex(BYTE[strptr + i],2)
        debug.char(32)
      debug.newline
      debug.str(@sndunk)
      debug.newline        
      debug.str(@sndunk)
      debug.newline    

Pri decimaltostring(value,strptr) | i,x

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
                                                           
Pri StrToBase(stringptr, base) : value | chr, index
{Converts a zero terminated string representation of a number to a value in the designated base.
Ignores all non-digit characters (except negative (-) when base is decimal (10)).}

  value := index := 0
  repeat until ((chr := byte[stringptr][index++]) == 0)
    chr := -15 + --chr & %11011111 + 39*(chr > 56)                              'Make "0"-"9","A"-"F","a"-"f" be 0 - 15, others out of range     
    if (chr > -1) and (chr < base)                                              'Accumulate valid values into result; ignore others
      value := value * base + chr                                                  
  if (base == 10) and (byte[stringptr] == "-")                                  'If decimal, address negative sign; ignore otherwise
    value := - value


Pri displaybuffer | i
    IF BYTE[kbus.codeptr + 1] <> 0 

      repeat i from 0 to BYTE[kbus.codeptr + 1]  + 1
'        debug.str(string("$"))
        debug.hex(BYTE[kbus.codeptr + i],2)
'        debug.str(string(", "))
        debug.str(string(" "))
                                                                           

DAT

'STEERING WHEEL
        volup        BYTE $50, $04, $68, $32, $11
        voldown      BYTE $50, $04, $68, $32, $10

        whlplus      BYTE $50, $04, $68, $3B, $01
        whlplusup    BYTE $50, $04, $68, $3B, $21       

        whlmin       BYTE $50, $04, $68, $3B, $08
        whlminup     BYTE $50, $04, $68, $3B, $28

        RTButton     BYTE $50, $03, $C8, $01, $9A
        Dial         BYTE $50, $04, $C8, $3B, $A0, $07  'Dial Up
        Dialdown     BYTE $50, $04, $C8, $3B, $80, $27  'Dial Down     
        dial3sec     BYTE $50, $04, $C8, $3B, $90, $37  'Dial 3sec 

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



'LOCKS
        OpenAll      BYTE $00, $05, $00, $0C, $96, $01
        LockAll      BYTE $3f, $05, $00, $0C, $97, $01
                           
   Remotebtnup       BYTE $00, $04, $BF, $72, $06
     remoteHome      BYTE $00, $04, $BF, $72, $26 
     remoteLock      BYTE $00, $04, $BF, $72, $16
        

        
        KeyInsert    BYTE $44, $05, $bf, $74, $04, $00
        KeyRemove    BYTE $44, $05, $bf, $74, $00, $00


        IKEoff       BYTE $80, $04, $BF, $11, $00, $2A
        IKEon        BYTE $80, $04, $BF, $11, $01, $2B


        Lock3        BYTE $3F, $05, $00, $0C, $4F, $01 'Lock all but driver
        LockDriver   BYTE $3F, $05, $00, $0C, $47, $01 'Lock Driver 
        TrunkOpen    BYTE $3f, $05, $00, $0c, $95, $01

'MOTORS
        Wiper        BYTE $3F, $05, $00, $0C, $49, $01
        WiperFluid   BYTE $3F, $05, $00, $0C, $62, $01


      timeReq         BYTE $3B, $05, $80, $41, $01, $01
      None            BYTE $00, $00, $00, $00, $00, $00         

 

'datalog mode   
logfilesuffix BYTE ".csv",0











mpgsuffix     BYTE " mpg",0
milessuffix   BYTE " Miles",0


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