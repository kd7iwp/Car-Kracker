''********************************************
''*  Car Kracker Main, V0.56                 *
''*  Author: Nick McClanahan (c) 2012        *
''*  See end of file for terms of use.       *
''********************************************

{-----------------REVISION HISTORY-----------------
  For complete usage and version history, see Release_Notes.txt

0.57: Added Text Display to RAD/NAV 
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
  Menudelay = 80_000_000 * 4

  EEPROM_Addr   = %1010_0000   
  EEPROM_base   = $8000
  stack_base    = $7500

  maincog =  4, LEDcog = 2  
'Cogs are custom mapped to reduce jitter - COG 0 goes with audio.  Definitions:
'COG 7: Touch / SD
'COG 6: Kbus RX
'Cog 5: Debug Console
'Cog 4: Main Thread
'Cog 3: Audio Buffer '
'Cog 2: LED notifier
'Cog 0: Audio

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

'Variables for Music Mode
BYTE radioremaps[8]
BYTE playerstatus
BYTE textfield   
BYTE CurrCD, CurrTrack

PUB Initialize
'We use this method to dump running the main process in Cog 0
coginit(maincog, main, stack_base)
coginit(LEDcog, LEDnotifier, @stack)
cogstop(0)


PUB main | i, c

i2cObject.Init(29, 28, false)
'kbus.Start(27, 26, %0110, 9600)
kbus.Start(27, 26, %0010, 9600)
debug.StartRxTx(31, 30, %0000, 115200)

setled(1)

debug.str(string("Hit d key for debug",13))

i := cnt
i  += menudelay
repeat while cnt < i
   CASE debug.rxcheck
     "C":
        configmode
     "d": 
        debugmode

  
setLED(0)          

IF EEPROM_read(112) <> 1
  Buttons.start(clkfreq / 25000)                  
  i := cnt + (menudelay)
  repeat while  cnt < i 
    case Buttons.State
      %1000_0000 : COGSTOP(7)
                   SerialRepeatMODE     'Sniffs bus and repeats over USB
                   
      %0001_0000 : COGSTOP(7)
                   ConnectionTestMODE   'Test connection by blinking Clown Nose

      %0100_0000 : COGSTOP(7)  
                   DiagnosticMODE       'Diagnostic Mode for connecting PC

      %0010_0000 : COGSTOP(7)
                   MusicMode            'Music Mode, start with a button

  Musicmode

case EEPROM_read(101)
  0 : DiagnosticMode
  1 : MusicMode
  2 : SerialRepeatMode
  3 : RemapperMode
  4 : DataLogMode
  OTHER : DiagnosticMode

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
    8 : loopcmd(2)            
    9 : loopAudio
    10 : looptimeparse
    11 : loopRadiotxt
  waitcnt(clkfreq / 2 + cnt)

DAT
debugmenu     BYTE      "Select Function",13
              BYTE      "Main Modes:",13
              BYTE      "0:Diagnostic",13
              BYTE      "1:Music",13
              BYTE      "2:SerialRepeat",13
              BYTE      "3:Remapper",13
              BYTE      "4:DataLog",13
              BYTE      "Test Modes: (e to escape test)",13
              BYTE      "5:Hex Bus Sniffer",13
              BYTE      "6:CMD Blast, Bus Watch",13
              BYTE      "7:CMD Blast, Single",13
              BYTE      "8:CMD Blast, Repeat",13                            
              BYTE      "9:Audio Player",13
              BYTE      "10:Read Time, Parsed",13
              BYTE      "11:Write text to Radio/NAV",13,0

PUB loopaudio
  debug.str(string("Playing 01_01.wav",13,"Hit e to stop and exit",13))
  debug.str(string("w=CD Up, s=CD Down",13,"d=Track+, a=Track-",13))

if music.start(0) < 0
  debug.str(string("Couldn't mount SD card!!!",13))
  debug.str(string("Rebooting",13))
  repeat 10
    setLED(201)   
    waitcnt(clkfreq / 3 + cnt)

settrack(1,1)  
music.startsong 
repeat
  case debug.rxcheck
    "e" : music.stop
          return
    "w" : music.stop
          return
    "a" : music.stop
          return
    "d" : music.stop
          return
    "s" : music.stop
          return                                
      
PUB loopradiotxt
repeat
' debug.clear       
  debug.str(string("Enter String and press enter to write text to radio display",13))
  debug.str(string("Or hit enter to go back",13))
  debug.StrInMax(@configbuffer, 11)
  if configbuffer == 0
    return
  kbus.sendtext(@configbuffer)
  kbus.sendnav(@configbuffer, 2)   



PUB loophex  | i, x
'debug.clear      
debug.str(string("Byte Bus Monitor",13))
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
debug.str(string("Command Blast",13))   
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

PUB looptimeparse | i
'debug.clear          
debug.str(string("Read Time, Parsed",13))
repeat
  kbus.localtime(@configbuffer)
  displaybuffer
  debug.str(string("New time",13))
  debug.str(@configbuffer)
  kbus.sendtext(@configbuffer)
  debug.newline  
  waitcnt(clkfreq + cnt)
   IF debug.rxcheck == "e"
     return  


PUB loopfuelparse | i
'debug.clear          
debug.str(string("Read Fuel, Parsed",13))
repeat
  kbus.fuelaverage(@configbuffer)
  debug.str(string("Fuel",13))
  debug.str(@configbuffer)
  debug.newline
  waitcnt(clkfreq * 2 + cnt)
   IF debug.rxcheck == "e"
     return  



PUB configmode  | controlSelected, eepromoffset
setLED(0)
setLED(2)
waitcnt(clkfreq  / 800 + cnt)
repeat until debug.rxcheck  == -1
debug.str(string("Version",13, "0.57", 13))

repeat
  debug.strin(@configbuffer)

  IF strcomp(@configbuffer, @testcmd)
    configblast(debug.decin)
    debug.strin(@getorset)
    debug.strin(@configbuffer)
                                                     

  IF strcomp(@configbuffer, @sermon)
    serialmonitormode

    
  IF strcomp(@configbuffer, @combobox) 
    eepromoffset := 100 + debug.decin
    getseteeprom(eepromoffset) 

  IF strcomp(@configbuffer, @checkbox) 
    eepromoffset := 200 + debug.decin
    getseteeprom(eepromoffset)
  
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

Pri EEPROM_Read(addr) | eepromdata
setLED(199)
eepromdata := 0
waitcnt(cnt + 100_000)
eepromdata := i2cObject.readLocation(EEPROM_ADDR, addr+EEPROM_base, 16, 8)
return eepromdata

Pri sendsetting(addr,len) |  i

i := EEPROM_Read(addr) 
IF i == 255
  debug.str(string("-1"))  
ELSE
  debug.dec(i)
debug.newline   


PUB datalogmode     | i,repeattimer, interval, repeatlimit
debug.str(string("Entering:Data Log Mode",13)) 

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
  2: repeatlimit := 20
  3: repeatlimit := 240



BYTEfill(@configbuffer,0,20)


interval := cnt
interval += 1_200_000_000

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

      
  IF cnt > interval
    repeattimer++
    If  repeattimer == repeatlimit
      writetolog
      repeattimer := 0
    interval := cnt
    interval += 1_200_000_000 '15 sec


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

pri lookupmember(selected) : value   | lookupval

lookupval := BYTE[kbus.codeptr + selected]

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


    
PUB configblast(cmd) | selected
 case cmd
   0 :  kbus.sendcode(@volup)                         
   1 :  kbus.sendcode(@voldown)                       

   2 :  kbus.sendcode(@whlplus)                       
        kbus.sendcode(@whlplusup)

   3 :  kbus.sendcode(@whlmin)                        
        kbus.sendcode(@whlminup)

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
   31 : kbus.sendcode(@OpenAll)                   
   32 : kbus.sendcode(@LockAll)                   
   33 : kbus.sendcode(@KeyInsert)                    
   34 : kbus.sendcode(@KeyRemove)  
   35 : kbus.sendcode(@Lock3)      
   36 : kbus.sendcode(@LockDriver) 
   37 : kbus.sendcode(@TrunkOpen)  
   38 : kbus.sendcode(@Wiper)      
   39 : kbus.sendcode(@WiperFluid)

SetLED(100)  



PUB connectionTestMode
debug.str(string("Entering: Connection Test Mode",13))

repeat
  SetLED(100)
  kbus.sendcode(@clownnose)
  waitcnt(clkfreq * 5 + cnt)


PUB MUSICMODE     | i, d, volset , len
debug.str(string("Entering: Music Mode",13))

playerstatus := FALSE
 
repeat i from 0 to 7
  radioremaps[i] := EEPROM_read(byte[@radbutlist][i])

volset :=  EEPROM_read(byte[@radbutlist][8])
debug.str(string("Vol set at:"))
debug.dec(volset)
debug.newline

IF EEPROM_read(byte[@radbutlist][9]) == 1
  music.AuxIn
  debug.str(string("Entered AuxIn Only Mode",13))
ELSE
  if music.start(volset) < 0
    debug.str(string("Couldn't mount SD card!!!",13))
    debug.str(string("Rebooting",13))
    repeat 10
      setLED(201)   
      waitcnt(clkfreq / 3 + cnt)
    reboot

settrack(2,1)  


kbus.sendcode(@CDAnnounce)
debug.str(string("XMIT: CD Announce",13))

repeat
  IF kbus.rx == $68
    len := kbus.rx
    IF kbus.rx == $18
      kbus.rx
      case kbus.rx 
        $72 :
              kbus.sendcode(@CDRespond)           
              debug.str(string(13,"REC: CD Polled"))
              debug.str(string(" - XMIT: Responded",13))

        $06 : i := kbus.rx
              IF i > 6
                kbus.rx
              ELSE 
               debug.str(string(13,"REC: CD CHG:"))
               debug.dec(i)
               kbus.rx
               musiccmd(radioremaps[--i])
                 
        $08 :  debug.str(string(13,"REC: Random:"))  
               repeat len -3 
                kbus.rx
               musiccmd(radioremaps[5])             

        $05 :
              If kbus.rx == 1
               debug.str(string(13,"REC: Prev Track"))
               kbus.rx
               musiccmd(radioremaps[6])
              ELSE
               debug.str(string(13,"REC: Next Track"))
               kbus.rx
               musiccmd(radioremaps[7])

        $01 : debug.str(string(13,"REC: Track Stop")) 
               kbus.rx
               kbus.sendcode(music.TrackEndCode)
               music.stopplaying
               debug.str(string(" - XMIT: Nothing",13))
               playerstatus := FALSE                  

        $00 : debug.str(string("REC: Status Request"))
              kbus.rx
              kbus.rx                      
              IF playerstatus == 255                                           
                kbus.sendcode(music.PlayingCode)
                debug.str(string(" - XMIT: Status Playing",13))
              ELSE                                                
                kbus.sendcode(music.notplaycode)                  
                debug.str(string(" - XMIT: Status Not Playing",13))
                     
        $03 :If kbus.rx == 0
               kbus.rx
               kbus.sendcode(music.startPlayCode)
               debug.str(string("REC: Play Start"))
               debug.str(string(" - XMIT: Begin Playing",13))
               music.startsong
               playerstatus := TRUE                                 

                                

'  IF (music.trackcompleted == TRUE) AND (playerstatus == 255)    
'    musiccmd(2)



Pri musiccmd(selectedaction)    | i , x

case selectedaction
  0 : debug.str(string(" - XMIT: Nothing",13)) 

  1 :        'Previous Track       
      debug.str(string(" - XMIT: Prev Track",13))
      settrack(CurrCD, CurrTrack -1)
      playerstatus := FALSE

  2 :        'Next Track           
      debug.str(string(" - XMIT: Next Track",13))
      settrack(CurrCD, CurrTrack +1)
      playerstatus := FALSE

  3 :        'Previous CD          
      settrack(CurrCD -1, 1)
      music.startsong
      debug.str(string(" - XMIT: Prev CD",13)) 
      kbus.sendcode(music.StartPlayCode)  
      playerstatus := TRUE

  4 :        'Next CD
      settrack(CurrCD + 1, 1)
      music.startsong
      debug.str(string(" - XMIT: Next CD",13))
      kbus.sendcode(music.StartPlayCode)
      playerstatus := TRUE
                   
  5..9 :        'CD 1-5
      settrack(selectedaction -4, 1)
      music.startsong
      debug.str(string(" - XMIT: CD"))
      debug.dec(selectedaction - 4)
      debug.newline 
      kbus.sendcode(music.StartPlayCode)
      playerstatus := TRUE

  10 :       'Aux In               
      debug.str(string("sent: AuxIn",13))
      IF music.AuxIn
        kbus.sendtext(string("Aux On"))
      ELSE
        kbus.sendtext(string("Aux Off"))         

  11 :       'Time normally 11                 
      debug.str(string(" - XMIT: Time Text",13))
      kbus.localtime(@configbuffer)
      kbus.sendtext(@configbuffer) 

  12 :       'Avg Fuel Consumption 
      debug.str(string(" - XMIT: Fuel Text",13))
      kbus.fuelaverage(@configbuffer)
 
  13 :       'Estimated Range      
      debug.str(string(" - XMIT: Range Text",13))
      kbus.estrange(@configbuffer)
      kbus.sendtext(@configbuffer)

  14 :       'Date 
      debug.str(string(" - XMIT: Date Text",13))
      kbus.date(@configbuffer)
      kbus.sendtext(@configbuffer)
      
  15 :       'Kracker Vol + 
      debug.str(string("Kracker Vol+",13))
      kbus.sendtext(string("k vol+"))
      music.changevol(-1)

  16 :       'Kracker Vol - 
      debug.str(string("Kracker Vol-",13))
      kbus.sendtext(string("k vol-"))
      music.changevol(+1)      

  Other :  debug.str(string("Command Not Found",13)) 

Pri settrack(CD,Track)
CurrCD := CD  #> 1
CurrTrack := Track #> 1
music.settrack(CurrCD, CurrTrack)

PUB DIAGNOSTICMODE 
debug.str(string("Entering Diagnostics",13))
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
debug.str(string("Entering:Repeater Mode",13)) 
setLED(205) 


repeat
  IF kbus.nextcode(100)
    repeat i from 0 to byte[kbus.codeptr+1] + 1 
      debug.hex(BYTE[kbus.codeptr + i],2)
      debug.char(32)
    debug.newline
  IF debug.rxcount > 0
    IF debug.charin == "e"
      return  


PUB REMAPPERMODE   | codetosend, i,y, xmit 
setLED(0)

debug.str(string("Entering:Remapper Mode",13))  

repeat i from 0 to 5
  loggeditems[i] := EEPROM_read(byte[@maplist][i])

repeat
  kbus.nextcode(0)
    setLED(199)  
    repeat y from 0 to 5
      codetosend := 0     
      xmit := byte[@xmitlist][y]      

      case loggeditems[y]
        1 :IF kbus.codecompare(@RTButton)
              codetosend :=  EEPROM_read(xmit)
              debug.str(string("Received:R/T",13))                                   

        2 :IF kbus.codecompare(@dial)
              codetosend :=  EEPROM_read(xmit)
              debug.str(string("Received:Dial",13))

        3 :IF kbus.codecompare(@Volup)        
              codetosend :=  EEPROM_read(xmit)
              debug.str(string("Received:Volup",13))
               
        4 :IF kbus.codecompare(@VolDown)      
              codetosend :=  EEPROM_read(xmit)
              debug.str(string("Received:Voldown",13))
                
        5 :IF kbus.codecompare(@whlPlus)      
              codetosend :=  EEPROM_read(xmit)
              debug.str(string("Received:WhlPlus",13))
                
        6 :IF kbus.codecompare(@Whlmin)       
              codetosend :=  EEPROM_read(xmit)
              debug.str(string("Received:WhlMin",13))
                
        7 :IF kbus.codecompare(@CDbutton1)    
              codetosend :=  EEPROM_read(xmit)
              debug.str(string("Received:CD1",13))
                
        8 :IF kbus.codecompare(@CDbutton2)    
              codetosend :=  EEPROM_read(xmit)
              debug.str(string("Received:CD2",13))
                
        9 :IF kbus.codecompare(@CDbutton3)    
              codetosend :=  EEPROM_read(xmit)
              debug.str(string("Received:CD3",13))
                
        10:IF kbus.codecompare(@CDbutton4)    
              codetosend :=  EEPROM_read(xmit)
              debug.str(string("Received:CD4",13))
                
        11:IF kbus.codecompare(@CDbutton5)    
              codetosend :=  EEPROM_read(xmit)
              debug.str(string("Received:CD5",13))
                
        12:IF kbus.codecompare(@Remotelock)   
              codetosend :=  EEPROM_read(xmit)
              debug.str(string("Received:RemoteLock",13))
              
        13:IF kbus.codecompare(@remotehome)   
              codetosend :=  EEPROM_read(xmit)  
              debug.str(string("Received:RemoteOpen",13))

      IF (codetosend > 0) AND (codetosend < 24)
        setled(100)        

      
      case codetosend                                                                          
         1: kbus.sendcode(@TrunkOpen)
              debug.str(string("Sent:TrunkOpen",13))

         2: kbus.sendcode(@OpenAll)                                
              debug.str(string("Sent:UnlockAll",13))

         3: kbus.sendcode(@LockAll)
              debug.str(string("Sent:LockAll",13))

         4: kbus.sendcode(@lock3)
              debug.str(string("Sent:Lock3",13))

         5: kbus.sendcode(@lockdriver)                        
              debug.str(string("Sent:LockDriver",13))

         6: kbus.sendcode(@clownnose)                         
              debug.str(string("Sent:Clown",13))

         7: kbus.sendcode(@Wrnblnk3sec)                       
              debug.str(string("Sent:Wrn3Sec",13))

         8: kbus.sendcode(@ParkLeft)                          
              debug.str(string("Sent:ParkLeft",13))

         9: kbus.sendcode(@ParkRight)                         
              debug.str(string("Sent:Parkright",13))

         10: kbus.sendcode(@InteriorOut)                                             
              debug.str(string("Sent:IntOut",13))

         11: kbus.sendcode(@FogLightsON)                      
              debug.str(string("Sent:FoglightOn",13))

         12: kbus.sendcode(@FogLightsOFF)                     
              debug.str(string("Sent:FoglightOff",13))

         13: kbus.sendcode(@HazzAndInt)                                                  
              debug.str(string("Sent:HazzandInt",13))

         14: kbus.sendcode(@sroofclose)                                                  
              debug.str(string("Sent:sroofclose",13))

         15: kbus.sendcode(@sroofOpen)                                                   
              debug.str(string("Sent:sroofOpen",13))

         16: kbus.sendcode(@DRwindOpen)                                                  
              debug.str(string("Sent:DRWinOpen",13))

         17: kbus.sendcode(@DRwindClose)             
              debug.str(string("Sent:DRWinClose",13))

         18: kbus.sendcode(@PRwindClose)
              debug.str(string("Sent:PRWinClose",13))

         19: kbus.sendcode(@PRwindOpen) 
              debug.str(string("Sent:PRWinOpen",13))

         20: kbus.sendcode(@DFwindOpen) 
              debug.str(string("Sent:DFWinOpen",13))

         21: kbus.sendcode(@DFwindClose)             
              debug.str(string("Sent:DFWinClose",13))

         22: kbus.sendcode(@PFwindClose)
              debug.str(string("Sent:PFWinClose",13))

         23: kbus.sendcode(@Wiper)      
              debug.str(string("Sent:Wiper",13))

         24: kbus.sendcode(@WiperFluid)  
              debug.str(string("Sent:WiperFluid",13))


pri setLED(mode)
ledctrl := mode
      
PUB LEDnotifier  | switcher
'setLED(0) = off
'setLED(1) = middle
'setLED(2) = outer
'setLED 23..20 = each LED
'setLED (199) = towards computer
'setLED (200) = and come back

'setLED (99) = away from computer
'setLED (100) - and come back 

repeat
  switcher := LEDctrl
  dira[23..16] := %1111_1111
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
      debug.str(@sndNA)
      debug.newline        
      debug.str(@sndNA)
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
        debug.hex(BYTE[kbus.codeptr + i],2)
        debug.char(32)
      debug.newline                                                        

DAT

'STEERING WHEEL
        volup        BYTE $50, $04, $68, $32, $11
        voldown      BYTE $50, $04, $68, $32, $10

        whlplus      BYTE $50, $04, $68, $3B, $01
        whlplusup    BYTE $50, $04, $68, $3B, $21       

        whlmin       BYTE $50, $04, $68, $3B, $08
        whlminup     BYTE $50, $04, $68, $3B, $28

        RTButton     BYTE $50, $03, $C8, $01, $9A
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
        OpenAll      BYTE $00, $05, $00, $0C, $96, $01
        LockAll      BYTE $3f, $05, $00, $0C, $97, $01
                           
        remoteHome   BYTE $00, $04, $BF, $72, $26
        remoteLock   BYTE $00, $04, $BF, $72, $16

        
        KeyInsert    BYTE $44, $05, $bf, $74, $04, $01
        KeyRemove    BYTE $44, $05, $bf, $74, $00, $FF

        Lock3        BYTE $3F, $05, $00, $0C, $4F, $01 'Lock all but driver
        LockDriver   BYTE $3F, $05, $00, $0C, $47, $01 'Lock Driver 
        TrunkOpen    BYTE $3f, $05, $00, $0c, $95, $01

'MOTORS
        Wiper        BYTE $3F, $05, $00, $0C, $49, $01
        WiperFluid   BYTE $3F, $05, $00, $0C, $62, $01


'CD CHANGER
        'From Radio  $68
        playtrack     BYTE $68, $05, $18, $38, $03, $00
        stoptrack     BYTE $68, $05, $18, $38, $01, $00
        pollCD        BYTE $68, $03, $18, $01 
        CDstatusreq   BYTE $68, $05, $18, $38, $00, $00 
         
        'From CD changer ($18h)
        CDannounce    BYTE $18, $04, $FF, $02, $01
        CDrespond     BYTE $18, $04, $68, $02, $00

      timeReq         BYTE $3B, $05, $80, $41, $01, $01



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
modesel       BYTE "m",0
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


'radio button remap fields
radbutlist    BYTE 134,135,136,137,138,139,140,141, 142, 143
'                  CD1             CD5 Ran T-  T+   vol  Aux

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