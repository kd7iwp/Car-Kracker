''********************************************
''*  Car Kracker Main, V0.66                 *
''*  Author: Nick McClanahan (c) 2012        *
''*  See end of file for terms of use.       *
''********************************************

{-----------------REVISION HISTORY-----------------
  For complete usage and version history, see Release_Notes.txt
0.66     Temp removed Time sync
         Changed timing to 9700bps - improves compatability
         - Major revisions to KbusCore - see Object file for full notes

New:     Basic DBUS support

0.65     Fixed USB bug - USB now shuts down after entering a non-config or non USB necessary mode.
           To run music, repeater, or other modes with USB serial support, enter Debug mode on bootup
         Added support for '-' separator in audio filenames

New:     Time sync
           Kracker now syncs with the car clock.      

0.60     Strings moved back to program memory.  Added differential audio

0.59     Strings are now stored in upper EEPROM.  Kustomizer .59 will populate the strings, or use string_updater
         Bugfixes on KbusCore, Padding now works
         New Time engine 

0.58     Added WAV Riff tag support
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
DAT
Version  BYTE "V",13,"0.66",13,0 
version2 BYTE 16,"Kracker V 0.66",0

CON
  _clkmode = xtal1 + pll16x                             ' Crystal and PLL settings.
  _xinfreq = 5_000_000                                  ' 5 MHz crystal (5 MHz x 16 = 80 MHz).

  Menudelay = 3
  EEPROM_Addr   = %1010_0000   
  EEPROM_base   = $8000
  stack_base    = $7500

  RADsize       = 11 
  maincog =  4, LEDcog = 2

'MCP3204 pinout; P8 = Clk p9 = Dio, P10 = ChipS
'adc.start(9,8,10,0) ch 0 = lchan, ch 1 = rchan

    
'Cogs are custom mapped to reduce jitter - COG 0 goes with audio.  Definitions:
'COG7: Touch / SD __COG6: Kbus RX  __Cog 5: Debug Console  __Cog 4: Main Thread  __Cog 3: Audio Buffer __Cog 2: LED notifier __Cog 0: Audio

OBJ
  Kbus         : "kbusCore.spin"
  debug        : "DebugTerminal.spin" 
  Buttons      : "Touch Buttons"
  music        : "music_manager"
  i2cObject    : "i2cObject.spin"
  SD           : "FSRW"
  time         : "time.spin"
' adc: "MCP3208_fast.spin"  
  
VAR
'LED Notifier
BYTE ledctrl
LONG stack[25]
LONG stack2[20]

'Variables for Config Mode
BYTE configbuffer[64]
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
WORD LEDtext          'Address for the text to be displayed
BYTE displayrefresh

'filter values for buffer display
byte activedebugfilters
byte bufferdebugcmds[5]
byte debugfilterIDs[5]
byte debugfilterType[5]
byte hexstyle

byte KMBreturn[16] 'For parsing KMB strings 
byte KMBreturn2[16]
 

PUB Initialize
'We use this method to dump running the main process in Cog 0
ActiveDebugFilters := 0
debug.StartRxTx(31, 30, %0000, 115_200, 0)  'added final value; 0 = enable debug term, anthing else = disable debug term                          
coginit(maincog, main, stack_base)
cogstop(0)


PUB main | i, c, delay
i2cObject.Init(29, 28, false)
coginit(LEDcog, LEDnotifier, @stack)  
'           RX  TX 
kbus.Start(27, 26, %0010, 9700)


'Make sure debug filters are clear

delay := 0
debug.str(string("Hit d key for debug",13))

repeat until time.oneshot(@delay, 5)
  setled(1)
  c := debug.rxcheck
  if c == "C" 
    configmode
  if (c == "d") OR (c == "D")
    debugmode


setLED(-1)          

IF EEPROM_read(112) == 0
  setLED(-1)
  Buttons.start(clkfreq / 25000)                  
  i := cnt + (menudelay)
  repeat while  cnt < i 
    case Buttons.State
      %1000_0000 : COGSTOP(7)
                   setLED(23)
                   SerialRepeatMODE     'Sniffs bus and repeats over USB

      %0100_0000 : COGSTOP(7)  
                   setLED(22)
                   debug.stop    
                   DiagnosticMODE       'Diagnostic Mode for connecting PC

      %0010_0000 : COGSTOP(7)
                   setLED(21)
                   debug.stop         
                   MusicMode            'Music Mode, start with a button

      %0001_0000 : COGSTOP(7)
                   setLED(20)
                   debug.stop    
                   ConnectionTestMODE   'Test connection by blinking Clown Nose

  COGSTOP(7)
  setLED(20)
  Musicmode

case EEPROM_read(101)

  0 : debug.stop    
      DiagnosticMode

  1 : debug.stop    
      MusicMode

  2 : debug.stop    
      SerialRepeatMode

  3 : debug.stop    
      RemapperMode

  4 : debug.stop    
      DataLogMode

  OTHER : debug.stop    
          Musicmode



PUB configmode  | controlSelected, eepromoffset
setLED(-1)
setLED(2)
waitcnt(clkfreq  / 800 + cnt)
repeat until debug.rxcheck   == -1
debug.str(@version)

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

  IF strcomp(@configbuffer, @dmon)
    dbusmonitormode

  IF strcomp(@configbuffer, @loadstrings)
    loadtextstrings
    
  IF strcomp(@configbuffer, @combobox) 
    eepromoffset := 100 + debug.decin
    getseteeprom(eepromoffset) 

  IF strcomp(@configbuffer, @checkbox) 
    eepromoffset := 200 + debug.decin
    getseteeprom(eepromoffset)

DAT  'Config Mode text strings
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
loadstrings   BYTE "loadstrings",0   
dmon          BYTE "dmonitor",0



PUB dbusmonitormode | i, stopflag, len

i := 0
stopflag := 0

 

repeat
  IF kbus.nextDcode(50)
    setLED (199)
    len := BYTE[kbus.codeptr + 1] -1
    repeat i from 0 to len
      debug.hex(BYTE[kbus.codeptr + i], 2)
      debug.char(32)
    next
    
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
          bussendvalue[1] := i
          codetostring(@bussendvalue)
          kbus.sendKcode(@bussendvalue)
          stopflag := 1    
        ELSE
          bussendvalue[i] := debug.hexin
          i++



PUB loadtextstrings | i, x, y, strstart, offset, strlen, strcnt

strstart := 600    
offset := 400
strcnt := 0

repeat
  debug.dec(strcnt)
  debug.newline
  debug.strin(@configbuffer)
  if configbuffer == "e"
    debug.str(string("Loaded "))
    debug.dec((offset - 400) / 2)
    debug.str(string(" Strings",13))
    return
  EEPROM_set(offset,strstart.byte[0])   'Store the start address to the string
  EEPROM_set(offset+1,strstart.byte[1])
  strlen := strsize(@configbuffer) 
  repeat i from 0 to strlen
    IF configbuffer[i] == "~"
      configbuffer[i] := 13        
    EEPROM_set(strstart,configbuffer[i])
    strstart++
  strstart++
  strcnt++     
  offset += 2

PUB gettexteeprom(offset)| i, x, y, returnptr
y~
i~
returnptr := @configbuffer


Offset := offset * 2 + 400

i.byte[0] := EEPROM_Read(offset)
i.byte[1] := EEPROM_Read(offset + 1)

BYTE[returnptr] := EEPROM_Read(i)

repeat while BYTE[returnptr] > 0
   BYTE[++returnptr] :=  EEPROM_read(++i)
 
BYTE[returnptr] := 0
return @configbuffer


PUB gettextstring(offset)| strptr, strlen, i
  strptr := @@strings[offset]
  return strptr 




DAT
strings WORD @str00, @str01, @str02, @str03, @str04, @str05, @str06, @str07, @str08, @str09, @str10, @str11, @str12
        WORD @str13, @str14, @str15, @str16, @str17, @str18, @str19, @str20, @str21, @str22, @str23, @str24, @str25
        WORD @str26, @str27, @str28, @str29, @str30, @str31, @str32, @str33, @str34, @str35, @str36, @str37, @str38
        WORD @str39, @str40, @str41, @str42, @str43, @str44, @str45, @str46, @str47, @str48, @str49, @str50, @str51
        WORD @str52, @str53, @str54, @str55, @str56, @str57, @str58, @str59, @str60 


str00 BYTE "Hit d key for debug",0
str01 BYTE 13,"DEBUG MENU",13,"Main Modes:",13," 0: Diagnostic",13,0
str02 BYTE " 1: Music",13," 2: SerialRepeat",13," 3: Remapper",13," 4: DataLog",13,"Test",0
str03 BYTE "Modes: (e to escape test)",13," 5: Hex Bus Sniffer",13," 6: CMD B",0
str04 BYTE "last Bus Watch",13," 7: CMD Blast Single",13," 8: Audio Player",13," 9",0
str05 BYTE ": Write text to Radio/NAV",13," 10: Read EEPROM",13," 11: Read EEPROM Strin",0
str06 BYTE "gs",13," 12: Read KMB",13," 13: Dbus Xmit",13," 14: Dbus sniffer",13,0
str07 BYTE "Read KMB",13," 0: Return to Main Debug",13," 1: Read Time Parsed",0
str08 BYTE 13," 2: Read Date Parsed",13," 3: Read Fuel Parsed",13," 4: Read Ra",0
str09 BYTE "nge Parsed",13," 5: Check sync'ed time",13,0
str10 BYTE "(r)ead, (w)rite, or (e)xit?",13,0
str11 BYTE "Enter Address(0-500)",0
str12 BYTE "Has Value: ",0
str13 BYTE "Enter new value: ",0
str14 BYTE "Done",13,0
str15 BYTE "w=CD Up, s=CD Down d=Track+, a=Track- 1=vol-, 2=vol+",0
str16 BYTE " q=stop Track",13,"r=Aux Mode, 3=Artist, 4= Album, ",0
str17 BYTE "5=Track, 6=Genre",13,0
str18 BYTE "Couldn't Mount SD Card!!",13,0
str19 BYTE "Enter String and press enter to write text to ",0
str20 BYTE "radio display",13,"Or hit enter to go back",0
str21 BYTE "Entering:Data Log Mode",13,0
str22 BYTE "Writing logfile Header",13,0
str23 BYTE "Writing logfile Entry",13,0
str24 BYTE "Entering: Connection Test Mode",13,0
str25 BYTE "Not Found - Nothing",0
str26 BYTE "Prev Track",0
str27 BYTE "Next Track",0
str28 BYTE "Prev CD",0
str29 BYTE "Next CD",0
str30 BYTE "Change CD to #",0
str31 BYTE "Change Aux",0
str32 BYTE "Time Text",0
str33 BYTE "Fuel Text",0
str34 BYTE "Range Text",0
str35 BYTE "Date Text",0
str36 BYTE "(Kracker Vol+)",0
str37 BYTE "(Kracker Vol-)",0
str38 BYTE "Artist Name",0
str39 BYTE "Album Name",0
str40 BYTE "Track Name",0
str41 BYTE "Genre",0
str42 BYTE "NA",0
str43 BYTE "NA",0
str44 BYTE "NA",0
str45 BYTE "NA",0
str46 BYTE "Entered AuxIn Only Mode",13,0
str47 BYTE "Volume Set: ",0
str48 BYTE "Running with Remapper",13,0
str49 BYTE "Remaper disabled",13,0
str50 BYTE "Nothing, CD Announce",13,0
str51 BYTE "(CD Polled,Responded)",0
str52 BYTE "(PowerDown,Stopped)",0
str53 BYTE "(PowerUp,Stopped)",0
str54 BYTE "Entering:Repeat Mode",13,0
str55 BYTE "Entering:Remapper Mode",13,0
str56 BYTE "Entering Music Mode",13,0
str57 BYTE "s + addr to view messages sent BY addr",13,0
str58 BYTE "d + addr to view messages sent TO addr",13,0
str59 BYTE "'r' to remove most recently set filter.  Up to five",0
str60 BYTE "active filters",13,0

  


pri eepromreset | i
repeat i from 0 to 400
  eeprom_set(i, 255)
  
Pri getseteeprom(eepromoffset)
setLED(99) 
debug.strin(@getorset)
  IF strcomp(@getorset, @set)
    EEPROM_set(eepromoffset,debug.decin)
  ELSE 
    sendsetting(eepromoffset,1)

Pri EEPROM_set(addr,byteval)
setLED(99)
waitcnt(cnt + 300000)
i2cObject.writeLocation(EEPROM_ADDR, addr+EEPROM_base, byteval, 16, 8)
waitcnt(cnt + 300000)

Pri EEPROM_Read(addr) | eepromdata
setLED(199)

eepromdata := 0
eepromdata := i2cObject.readLocation(EEPROM_ADDR, addr+EEPROM_base, 16, 8)
'waitcnt(cnt + 20000) 
return eepromdata

Pri sendsetting(addr,len) |  i

i := EEPROM_Read(addr) 
IF i == 255
  debug.str(string("-1"))  
ELSE
  debug.dec(i)
debug.newline   


PUB datalogmode     | i,repeattimer, repeatlimit, nextupdate, lastupdate

debug.clear
debug.str(gettextstring(21))
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
  IF kbus.nextKcode(50)
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
debug.str(gettextstring(22))
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
debug.str(gettextstring(23))
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
  IF kbus.nextKcode(50)
    setLED (199)
    repeat i from 0 to BYTE[kbus.codeptr + 1]
      debug.hex(BYTE[kbus.codeptr + i],2)
      debug.char(32)
    debug.newline
    debug.str(lookupmember(0))
    debug.newline             
    debug.str(lookupmember(2))
    debug.newline    
    next
    
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
          kbus.sendKcode(@bussendvalue)
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
kbus.sendKcode(@@CMDLIST[cmd])

'Some commands need a second message
 case cmd
   2       :  kbus.sendKcode(@whlplusup)                    
   3       :  kbus.sendKcode(@whlminup)
SetLED(100)  

DAT 'List of Commands to Blast
'Command List      0x10           1x10          2x10         3x10           4x10         5x10       6x10           7x10          8x10          9x10
CMDLIST  WORD   @volup,      @voldown,     @whlplus,     @whlmin,      @RTButton,    @Dial,     @DRwindOpen,  @DRwindClose, @PRwindClose,  @PRwindOpen
         WORD   @DFwindOpen, @DFwindClose, @PFwindOpen,  @PFwindClose, @SRoofClose, @SRoofOpen, @DMirrorFold, @DMirrorOut,  @PMirrorFold,  @PMirrorOut
         WORD   @ClownNose,  @Wrnblnk,     @Wrnblnk3sec, @ParkLeft,    @ParkRight,  @StopLeft,  @StopRight,   @FogLightsON, @FogLightsOFF, @HazzAndInt
         WORD   @Lock3,      @LockDriver,  @TrunkOpen,   @Wiper,       @WiperFluid



PUB connectionTestMode
debug.clear
debug.str(gettextstring(24))

repeat
  SetLED(100)
  kbus.sendKcode(@clownnose)
  waitcnt(clkfreq * 5 + cnt)


DAT 'Music and Radio messages

'RADIO BUTTONS
         CDCHG       BYTE $68, $05, $00, $38, $06
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
        CDrespond     BYTE $18, $04, $FF, $02, $00

'radio button remap fields
radbutlist    BYTE 134,135,136,137,138,139,140,141, 142, 143, 111, 144
'                  CD1                 CD6 T-  T+   vol  Aux, RND, dsp
'                   0                   5   6   7    8    9    10   11



PUB MUSICMODE     | i, d, volset , len, cdtype, delay, randctr, remap
debug.str(@version2) 
debug.str(gettextstring(56))
debug.str(gettextstring(57))
debug.str(gettextstring(58))
debug.str(gettextstring(59))    
debug.str(gettextstring(60))
updatestat~
randctr~
delay~
displayrefresh := 15
          
volset :=  EEPROM_read(byte[@radbutlist][8])                 ''Load Stored Preferences - dropdowns and Volume
debug.str(gettextstring(47))
debug.dec(volset)
debug.newline
remapTel := 3 

repeat i from 0 to 7
  radioremaps[i] := EEPROM_read(byte[@radbutlist][i])

''Check Stored Preference for AuxIn Only 
IF EEPROM_read(byte[@radbutlist][9]) == 1
  music.AuxIn
  debug.str(gettextstring(46))
ELSE
  if \music.start(volset, EEPROM_read(144))
    debug.str(gettextstring(18))
    
    repeat 
      setLED(201)   
      waitcnt(clkfreq + cnt)
      debug.str(gettextstring(18))


IF EEPROM_read(109) == 1
  remap := TRUE
  remappersetup  
  debug.str(gettextstring(48))
ELSE
  remap := FALSE
  debug.str(gettextstring(49))

kbus.sendKcode(@CDAnnounce)
debug.str(gettextstring(50))


repeat
     kbus.clearcode
     i := kbus.nextKcode(50)
     displaybuffer
  IF i 
    IF kbus.KCodeCompare(@pollCD)
       kbus.sendKcode(@CDRespond)
       repeat until NOT kbus.txcheck
       displaybuffercode(@CDrespond)
       debug.str(gettextstring(51))  
       next

    IF kbus.KCodeCompare(@IKEoff)
       debug.str(gettextstring(52)) 
       remapTel := 0    
       music.stopplaying  
       next

    If kbus.KCodeCompare(@IKEon)
       debug.str(gettextstring(53)) 
       next
     
    IF kbus.KCodeCompare(@cdstatusreq)
       debug.str(string("(Status Request,"))
       IF music.inPlaymode
         kbus.sendKcode(music.PlayingCode)
         displaybuffercode(music.playingcode)
         debug.str(string(",Status Playing)"))
       ELSE
         kbus.sendKcode(music.notplaycode)
         displaybuffercode(music.notplaycode)
         debug.str(string(",Status Not Playing)"))        
       next

    IF kbus.KCodeCompare(@playtrack)
       kbus.sendKcode(music.StartPlayCode)
       displaybuffercode(music.StartPlayCode)
       debug.str(string("(Play Start,Begin Playing)"))                                    
       music.playtrack("c","c") 
       next
     
    IF kbus.KCodeCompare(@stoptrack)
       kbus.sendKcode(music.TrackEndCode)
       displaybuffercode(music.TrackEndCode)
       music.stopplaying
       debug.str(string("Stop Track,Nothing"))
       updatestat := FALSE
       next

    IF kbus.partialmatch(@CDCHG, 5)
       i := BYTE[kbus.codeptr+5] - 1
       IF i < 6
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

    IF kbus.KCodeCompare(@nobuttons)
       debug.str(string("exit text disp,Nothing"))
       updatestat := false
       next
    IF remap
      remapcheck

  IF NOT music.nexttrack
    music.playtrack("c","n")
    kbus.sendKcode(music.startplaycode)
    debug.str(string(13,"(endtrack),Next Track"))
{
  IF time.oneshot(@delay, displayrefresh)
    IF updatestat == TRUE 
      debug.str(string(13,"(Text Update),"))
      musiccmd(textfield)
}


Pri musiccmd(selectedaction)    | i , x

Case selectedaction
   0..4  :   debug.str(gettextstring(selectedaction + 25)) 
   5..10 :   debug.str(gettextstring(30))
  10..25 :   debug.str(gettextstring(selectedaction + 20)) 

case selectedaction
  1 : music.playtrack("c", "p")
  2 : music.playtrack("c", "n")

  3 : music.playtrack("p", 1)
      kbus.sendKcode(music.StartPlayCode) 
      displaybuffercode(music.StartPlayCode)

  4 : music.playtrack("n", 1)
      kbus.sendKcode(music.StartPlayCode)
      displaybuffercode(music.StartPlayCode)     

  5..10 :  music.playtrack(selectedaction -4, 1)
           debug.dec(selectedaction - 4)
           kbus.sendKcode(music.StartPlayCode)
           displaybuffercode(music.StartPlayCode)     

  11 :                 
    IF music.AuxIn                                    'str 36
       settext(string("Aux On"))
    ELSE
      settext(string("Aux Off"))

  12 : IF NOT time.carissynced
         kbus.localtime(@configbuffer)
         settext(@configbuffer)
       ELSE
        case EEPROM_read(111)
         1 :     settext(time.gettimetext(0, 0))  ' 24hr, no sec          
                 setupdate(selectedaction)      
         2     : settext(time.gettimetext(1, 1))  ' 12hr, with sec 
                 setupdate(selectedaction)
                 displayrefresh := 2
         3     : settext(time.gettimetext(1, 0))    ' 24hr with sec
                 setupdate(selectedaction)
                 displayrefresh := 2       
         OTHER : settext(time.gettimetext(0, 1))    ' 12hr, no sec
                 setupdate(selectedaction)                

  13 : kbus.fuelaverage(@configbuffer)                  'AVG fuel str 38
       i := strsize(@configbuffer) 
       Bytemove(@configbuffer + i, @mpgsuffix, 5)
       settext(@configbuffer)
       setupdate(selectedaction)      
 
  14 : kbus.estrange(@configbuffer)                     'Estimated Range        
       i := strsize(@configbuffer)                                                                               
       Bytemove(@configbuffer + i , @milessuffix, 7)
       settext(@configbuffer)                       
       setupdate(selectedaction)                                            

        
  15 : kbus.date(@configbuffer)                         'date
       settext(@configbuffer)
       setupdate(selectedaction)
      
  16 : settext(string("K vol+"))
       music.changevol("p")

  17 : settext(string("K vol-"))
       music.changevol("m")      

  18 : settext(music.artist)
       setupdate(selectedaction)

  19 : settext(music.Album)
       setupdate(selectedaction)

  20 : settext(music.song)
       setupdate(selectedaction)

  21 : settext(music.genre)
       setupdate(selectedaction)



PRI setupdate(field)
updatestat := TRUE
textfield := field
displayrefresh := 15

PUB DIAGNOSTICMODE 
kbus.stop

dira[30] := 1 'FTDI settings (tx = 30, rx = 31)
dira[31] := 0
dira[26] := 1 'Bus settings (tx = 26 rx = 27)
dira[27] := 0
repeat
  outa[26] := !ina[31]
  outa[30] := ina[27]
    

PUB SERIALREPEATMODE  | i
debug.str(@version2)
debug.str(gettextstring(54))
setLED(205) 

repeat
    kbus.clearcode     
    kbus.nextKcode(100)
    displaybuffer


PUB REMAPPERMODE   | i,x,y, xmit 
setLED(-1)
debug.str(@version2)
debug.str(gettextstring(55))
remappersetup


repeat
    kbus.clearcode
    kbus.nextKcode(0)
    If kbus.KCodeCompare(@IKEon)
      remaptel := 0
    setLED(199)  
    remapcheck


Pri remappersetup | i, x, y, xmit

repeat i from 0 to 5
  triggeritems[i] := EEPROM_read(mapfieldlist[i])
  xmititems[i] :=    EEPROM_read(xmitfieldlist[i])
  IF (triggeritems[i] == 0) OR (xmititems[i] == 0)
    triggeritems[i] := 255



pri remapcheck | y, delay


IF kbus.KCodeCompare(@RTButton)  
 IF remaptel < 3
  remaptel++
  return
    
repeat y from 0 to 5                              
  IF triggeritems[y] < 250  
    IF kbus.KCodeCompare(@@maptrg[triggeritems[y]-1]) 'triggeritems[y] is the dropdown value. First dropdown field value is 'none' = 0
       kbus.sendKcode(@@mapxmit[xmititems[y]-1])      
       displaybuffercode(@@mapxmit[xmititems[y]-1])
       debug.str(string(" REMAP,"))  
       debug.char(triggeritems[y] + $30)
       debug.str(string(","))
       debug.char(xmititems[y] + $30)


  
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

      
PUB LEDnotifier  | switcher, i, delay, timeupdate


{{Notification Options:
23..20: Each LED    | 0:   All Off  |   1: Middle two |   2: Outer two
   199: Towards USB | 200: and back |  99: USB Away   | 100: And Back}}
delay~
timeupdate := 0
time.start
dira[23..16] := %1111_1111



repeat
  time.wait(50)
{
  IF time.oneshot(@delay, 7)
    IF timeupdate == 0
     IF kbus.localtime(@kmbreturn)
       timeupdate := 1
    ELSEif timeupdate == 1
     If kbus.localtime(@kmbreturn2)
        If not strcomp(@kmbreturn, @kmbreturn2)
         time.synctime(@kmbreturn2)        
         delay~~
         timeupdate := 3
}

  IF LEDtext
     textscroll(LEDtext)
     LEDtext := 0

  case LEDctrl
     -1: outa[23..16] := %0000_0000
     1 : outa[23..16] := %0110_0000
     2 : outa[23..16] := %1001_0000
    99,100  :
         outa[23..16]:=  %1000_0000     
         time.wait(30)     
         repeat 7                       
           time.wait(30)   
           outa[23..16] ->= 1           
         IF ledctrl   == 100            
           time.wait(30)   
           repeat 7                     
             time.wait(30) 
             outa[23..16] <-= 1         
         outa[23..16] := %0000_0000
         LEDctrl~ 
    201 :
           outa[23..16] := %1010_1010
           repeat 4
              time.wait(166)
              outa[23..16] ->= 1
              time.wait(166)
              outa[23..16] <-= 1
           outa[23..16] := %0000_0000
           LEDctrl~

    199,200 :
      outa[23..16] := %0000_0001  
              time.wait(30)                       
              repeat 7                                         
                time.wait(30)                    
                outa[23..16] <-= 1                             

              IF ledctrl == 200                                                            
                time.wait(30)                                                   
                repeat 7                     
                  time.wait(30) 
                  outa[23..16] ->= 1         
              outa[23..16] := %0000_0000
              LEDCTRL~

    23..20 :  outa[23..20]~
              outa[ledctrl]~~  

PUB textscroll(strptr) | strlen      
strlen := strsize(strptr)

IF strlen =< Radsize
  kbus.sendtext(strptr)
ELSE
  kbus.sendtext(strptr)
  time.wait(2500)
  repeat strlen - radsize
    kbus.sendtext(++strptr)
    time.wait(300)
    IF kbus.KCodeCompare(@nobuttons)
      return
return



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

return strptr
                                                           
Pri StrToBase(stringptr, base)
return debug.strtobase(stringptr, base)

Pri displaybuffer | i, x    

If debug.rxcount > 2         
  x := debug.rxcount
  repeat i from 1 to x 
    bufferdebugcmds[i - 1] := debug.rxcheck
  bufferdebugcmds[x] := 0
  IF (bufferdebugcmds[0] > $40) AND (bufferdebugcmds[0] < $5B)
    bufferdebugcmds[0] += $20    
  
  CASE bufferdebugcmds[0] 
    "h": 
       !hexstyle
       debug.str(string(13,"Hex display changed",13)) 
    "s","d":                    
       If activedebugfilters > 4                                      'activedebufilters stores the count of active filters
         debug.str(string(13,"No available filters",13))                
       ELSE 
         debugfilterIDs[activedebugfilters] := strtobase(@bufferdebugcmds+1, 16)
         debugfiltertype[activedebugfilters++] := bufferdebugcmds[0] 
         debug.str(string(13,"OK: Filter type "))                
         debug.char(bufferdebugcmds[0])
         debug.str(string(" set on address "))       
         debug.str(@bufferdebugcmds+1)
         debug.newline
    "r"    :
         If activedebugfilters == 0
            debug.str(string(13,"No filters to remove",13))
         ELSE
           debug.str(string(13,"OK: Removed Filter on address "))
           debug.hex(debugfilterIDs[activedebugfilters--],2)
           debug.newline
    "e"    : debug.clear
             reboot


    OTHER  : debug.str(string(13,"Command not recognized",13))


IF BYTE[kbus.codeptr + 1] <> 0  
  IF activedebugfilters == 0     ' if no filters, just display every code
    displaybuffercode(kbus.codeptr)
    return
  repeat i from 1 to activedebugfilters 
    IF (debugfiltertype[i-1] == "s") AND (BYTE[kbus.codeptr]  == debugfilterIDs[i-1])
      displaybuffercode(kbus.codeptr)
      return
    IF (debugfiltertype[i-1] == "d") AND (BYTE[kbus.codeptr+2]  == debugfilterIDs[i-1])         
      displaybuffercode(kbus.codeptr)
      return  



PRI displaybuffercode(code) | i, x

debug.newline   
debug.str(time.gettimestamp)  
debug.char(32)
repeat i from 0 to BYTE[code + 1]  + 1
  If hexstyle
    debug.str(string("$"))
  debug.hex(BYTE[code + i],2)
  IF hexstyle 
    debug.str(string(","))
  debug.char(32)         

  
debug.str(string(","))
debug.str(lookupmember(0))
debug.str(string(","))
debug.str(lookupmember(2))
 
PUB debugmode
waitcnt(clkfreq  / 800 + cnt)
repeat until debug.rxcheck  == -1

repeat
  debug.str(gettextstring(1))
  debug.str(gettextstring(2))
  debug.str(gettextstring(3))
  debug.str(gettextstring(4))
  debug.str(gettextstring(5))
  debug.str(gettextstring(6))          
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
    11 :loopdebugstrings  
    12 : debugkmb
    13 : readdbus
    14 : Loopdbussniff
  waitcnt(clkfreq / 2 + cnt)




PUB loopdebugstrings | i, x, y, strstart, offset, strcnt, strlen
strstart := 600    
offset := 400
strcnt := 0

repeat
  debug.str(string(16,"(e)nter Strings, (r)ead String, or (q)uit: "))
  y := debug.charin 
  IF y == "q"
    return
  ELSEIF y == "e"
    repeat
      debug.str(string(13,"Enter String: "))  
      debug.strin(@configbuffer)
      if configbuffer == 0
        return
      EEPROM_set(offset,strstart.byte[0])   'Store the start address to the string
      EEPROM_set(offset+1,strstart.byte[1])
      strlen := strsize(@configbuffer) 
      repeat i from 0 to strlen
        EEPROM_set(strstart,configbuffer[i]) 
        strstart++
      strstart++      
      offset += 2
  ELSEIF y == "r"
    debug.str(string(13,"Read String offset: "))
    y := debug.decin
    Offset += y * 2
    i~
    i.byte[0] := EEPROM_Read(offset)
    i.byte[1] := EEPROM_Read(offset + 1)
    x := EEPROM_Read(i)
    repeat while x > 0
      debug.char(x)
      x := EEPROM_read(++i)
    waitcnt(clkfreq * 2 + cnt)
    return
      
    


PUB loopeeprom | i, x
debug.clear
debug.str(gettextstring(10))  
repeat
  debug.newline
  case debug.charin
    "e": return
    "r":   debug.str(gettextstring(11))
           i := debug.decin
           debug.positionx(0)
           debug.clearend
           debug.dec(i)
           debug.str(gettextstring(12))            
           debug.dec(EEPROM_read(i))
           next
    "w":   debug.str(gettextstring(11))
           i := debug.decin
           debug.dec(i)
           debug.str(gettextstring(13))
           x := debug.decin            
           EEPROM_set(i, x)
           debug.dec(x)
           debug.str(gettextstring(14))
           next                                             


PUB debugkmb  
repeat
  debug.clear
  debug.str(gettextstring(7))
  debug.str(gettextstring(8))
  debug.str(gettextstring(9))     

  case debug.decin
    0 : return
    1 : kbus.localtime(@configbuffer)
        debug.str(@configbuffer)
    2 : kbus.date(@configbuffer)                                     
        debug.str(@configbuffer)                                      
    3 : kbus.fuelaverage(@configbuffer)
        debug.str(@configbuffer)
    4 : kbus.estrange(@configbuffer)
        debug.str(@configbuffer)
    5 : If time.carissynced
          debug.str(time.gettimetext(1, 1))
          debug.newline                    
        Else
          debug.str(string("Time not synced",13))               
    6 : readdbus
  waitcnt(clkfreq + cnt)


PUB readdbus  | i,x, y, end

x~                 ' each byte in send code
y := 3             ' return line for response code              

debug.clear                       
debug.str(string("Enter CMD, e to exit, s to send, n to enter next byte",13))
                                                                                         '
repeat
  end := 0
  debug.position(0,2)
  debug.clearend
  debug.position(0,2)           
  x~ 
  repeat until end == 1
    i := debug.hexin
    configbuffer[x++] := i
    debug.hex(i,2)
    debug.char(32)
    case debug.charin
     "e" : Return
     "s" : debug.newline
           kbus.sendDcode(@configbuffer)
           kbus.NextDcode(200)
           displaydbus
           waitcnt(clkfreq * 3 + cnt)
           return


PUB Loopdbussniff
debug.clear

repeat
    kbus.clearcode     
    If kbus.nextDcode(100)
      displaydbus

PUB displaydbus | len, i

len := BYTE[kbus.codeptr + 1] -1 


repeat i from 0 to len
  debug.str(string("$"))
  debug.hex(BYTE[kbus.codeptr + i], 2)
  debug.str(string(","))
  debug.char(32)  
debug.newline

   


 


'                  4 faults                3 faults
'Read Fault:       3F 04 D0 04 00 EF    3F 04 00 04 00 3F                                                                                         '
'Response          D0 04 3F A0 04 4F    00 0C 3F A0 03 00 00 3D 03 29 02 30 09 BC                                                                                       '
'Request Block1    3F 04 D0 04 01 EE    3F 04 00 04 01 3E                                                                                       '
'Response          D0 22 3F A0 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 6D '


' Service Information
'80 03 D0 53 00 request
'D0 10 80 54 46 50 66 98 90 07 F2 40 EC 00 00 00 11 24 ' Response
'VIN FP66989; Total dist 203,400 kms [126,387 mls]; SI-L 2360 litres since last service; ; SI-T 17 days since last service




DAT
'                       rec 
FaultReq BYTE $3F, $04, $00, $04, $00




PUB loopaudio | i
debug.clear
debug.str(gettextstring(15))
debug.str(gettextstring(16))
debug.str(gettextstring(17))
if \music.start(1, 0)                                                         
  debug.str(gettextstring(18))
  repeat 
    setLED(201)   
    waitcnt(clkfreq / 3 + cnt)




repeat
  case debug.rxcheck
    "e" : music.stop
          return
    "r" : music.auxin
          debug.str(string("Set Aux In "))
    "1" : music.changevol("m")
    "2" : music.changevol("p")
    "3" : debug.str(music.artist)
    "4" : debug.str(music.album)
    "5" : debug.str(music.song)
    "6" : debug.str(music.genre)
    "q" : music.stopplaying

    "w" : showvalue(music.playtrack("n", 1 ))
          debug.str(music.fileptr)          

    "s" : showvalue(music.playtrack("p", 1 ))
          debug.str(music.fileptr)
    
    "d" : showvalue(music.playtrack("c","n"))
          debug.str(music.fileptr)

    "a" : showvalue(music.playtrack("c","p"))
          debug.str(music.fileptr)                  
  IF NOT music.nexttrack
    music.playtrack("c","n")


    

PRI showvalue(val)
debug.str(string("Return"))    
debug.dec(val)
debug.newline
  
      
PUB loopradiotxt
repeat
  debug.clear
  debug.str(gettextstring(19))
  debug.str(gettextstring(20))
  debug.StrIn(@configbuffer)
  if configbuffer == 0
    return
  settext(@configbuffer)


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


                                         

DAT


'DBUS cmds
        dvolup       BYTE   $68, $05, $0C, $05 
        dvoldn       BYTE   $68, $05, $0C, $06
        dgalup       BYTE   $68, $05, $0C, $40
        dgaldn       BYTE   $68, $05, $0C, $20
        

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