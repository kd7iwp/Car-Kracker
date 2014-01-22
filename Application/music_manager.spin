''********************************************
''*  Music Manager 1.2                       *
''*  Author: Nick McClanahan (c) 2012        *
''*  See end of file for terms of use.       *
''********************************************
{-----------------REVISION HISTORY-----------------
1.2 - Fixed Next / Previous track bug

1.1 - RIFF support
Audio_Player now supports RIFF (Audio file metadata).  

1.0 - Initial Release
* Added Aux In - flip state with AuxIn Method
}


CON

  _clkmode = xtal1 + pll16x                             ' Crystal and PLL settings.
  _xinfreq = 5_000_000                                  ' 5 MHz crystal (5 MHz x 16 = 80 MHz).


  AudioBufferCog = 3

OBJ
  player : "audio_player.spin"
    
VAR
WORD CurrCD, CurrTrack
WORD CurrArtist, CurrSong, CurrAlbum, CurrGenre

LONG stack[90]

BYTE Aux
LONG filestate
LONG playerstate
LONG playermode
LONG volumeset
word filenameptr


PUB start(vol, mode) | i
currartist := player.getArtist
currsong   := player.getSong
curralbum  := player.getAlbum
currgenre  := player.getgenre


Aux := FALSE
playermode  := FALSE
playerstate := FALSE

volumeset := vol
return \player.start(volumeset, mode)

PUB stop
stopplaying
player.stop

PUB playtrack(CD,track) | tens, i, CDHex, TrackHex, newCD, newTrack
{{Stops the current track, if playing, and plays the requested track, if it can be found
  Call with "c", "n", or "p" for keeping the (c)urrent CD/Track value, (n)ext, or (p)revious 
  Return of TRUE means a problem was encountered}}
track #>= 1
CD    #>= 1



playermode := TRUE
player.endtrack

CASE track
    "c" : track := currTrack 
    "n" : track := currTrack + 1
    "p" : track := currTrack -1  #> 1

CASE CD
    "c" : CD := currCD
    "n" : CD := currCD + 1
    "p" : CD := currCD - 1  #> 1

IF AUX
  return TRUE



newfilename(CD,track)
IFNOT player.FileNotFound(@playfile)
  filenameptr := @playfile 
  startplaying
  return -2
IFNOT player.FileNotFound(@playfile2)
  filenameptr := @playfile2 
  startplaying
  return -2
IFNOT player.FileNotFound(@altfile)
  filenameptr := @altfile 
  startplaying
  return -3

ELSE
  repeat 2                      'First attempt the next 2 tracks
    newfilename(CD,++track)
    IFNOT player.filenotfound(@playfile)
      filenameptr := @playfile 
      startplaying
      return -3
    IFNOT player.filenotfound(@playfile2)
      filenameptr := @playfile2 
      startplaying
      return -3 
    IFnot player.filenotfound(@altfile)
      filenameptr := @altfile
      startplaying
      return -4 
   
  repeat 2                      'Then attempt the next 2 CD's 
    newfilename(++CD, 1)  
    IFNOT player.filenotfound(@playfile)
      filenameptr := @playfile 
      startplaying
      return -5
    IFNOT player.filenotfound(@playfile2)
      filenameptr := @playfile2 
      startplaying
      return -5 
    ifnot player.filenotfound(@altfile)
      filenameptr := @altfile
      startplaying
      return -6
   
  newfilename(1,1)              'Then attempt Track 1, CD 1
    IFNOT player.filenotfound(@playfile)
      filenameptr := @playfile 
      startplaying
      return -7
    IFNOT player.filenotfound(@playfile2)
      filenameptr := @playfile2 
      startplaying
      return -7
    ifnot player.filenotfound(@altfile)
      filenameptr := @altfile
      startplaying
      return -8
   
  playermode := FALSE     
  return 0
   

PUB changevol(newval)
CASE newval
 "p"   : --volumeset
 "m"   : ++volumeset 
 other : volumeset := newval

volumeset #>= 0
volumeset <#= 6

player.changevol(volumeset)

return TRUE

PUB stopplaying  
player.endtrack 
playermode := FALSE


PUB NextTrack
{{Find out if the current track has finished playing
TRUE = Done and ready for next file
}}
IF Aux == TRUE
  return FALSE

IF playermode == TRUE
  return playerstate
ELSE
  return TRUE
  

PUB InPlayMode
return playermode
  

PUB AuxIn
!AUX
stopplaying
RETURN AUX

PUB fileptr
return  filenameptr

PUB notplayCode
return @CDnotplay

PUB playingCode
return @Cdplaying

PUB startplayCode
return @CDstartplay

PUB TrackENDCode
return @CDTrackEnd

PUB SeekingCode
return @CDSeek

PUB Artist
return currartist

PUB Song
return currsong

PUB album
return curralbum

PUB genre
return currgenre

PRI startplaying
                
IF Aux == FALSE
  waitcnt(clkfreq / 30 + cnt)  
  coginit(AudioBufferCog, bgplay, @stack)        
  waitcnt(clkfreq / 30 + cnt)
  Return TRUE
ELSE
  return TRUE
   
  
PRI bgplay
playerstate := TRUE
playerstate := player.play(filenameptr)

PRI newfilename(CD, Track) | tens, cdBCD, trackBCD, z
{{Set new filename for Audio track.  Computes a Binary Coded Decimal version for updating kbus codes, too}}
z := 0

    currCD := CD
    tens := 0
    repeat while CD > 9
      tens++
      CD -= 10
    byte[@playfile]   := $30 + tens
    byte[@playfile2]   := $30 + tens   
    byte[@playfile+1] := $30 + cd
    byte[@playfile2+1] := $30 + cd      
    if tens >0 
      byte[@altfile][z++] := byte[@playfile]
    byte[@altfile][z++] :=   byte[@playfile+1]  

    cdBCD := cd

byte[@altfile][z++] := "_"

  currTrack := Track
  tens := 0
  repeat while track > 9
    tens++
    track -= 10
  byte[@playfile+3]   := $30 + tens 
  byte[@playfile+4]   := $30 + track
  byte[@playfile2+3]   := $30 + tens 
  byte[@playfile2+4]   := $30 + track

  if tens >0 
      byte[@altfile][z++] := byte[@playfile+3]
  byte[@altfile][z++] :=   byte[@playfile+4] 

  trackBCD := ((tens << 4) + track) & $FF

byte[@altfile][z++] := "."
byte[@altfile][z++] := "w"
byte[@altfile][z++] := "a"
byte[@altfile][z++] := "v"
byte[@altfile][z++] := 0

BusCodeUpdate(9, cdBCD)
BusCodeUpdate(10, trackBCD)

PUB BusCodeUpdate(idx, newval)
{{Update Buss codes with new track numbers.  index 9 = CD and index 10 = track}}

IF newval
  byte[@CDnotplay+idx]   := newval
  byte[@CDplaying+idx]   := newval
  byte[@CDstartplay+idx] := newval
  byte[@CDtrackend+idx]  := newval
  byte[@CDseek+idx]      := newval

DAT

playfile      BYTE "00_00.wav",0
playfile2     BYTE "00-00.wav",0  
altfile       BYTE  0,0,0,0,0,0,0,0,0,0,0
 

'CD Status                                                        dd   tt  Disc (01-06 / track)

CDnotplay     BYTE $18, $0A, $68,  $39, $00, $02, $00, $3F, $00, $01, $01 
CDplaying     BYTE $18, $0A, $68,  $39, $00, $09, $00, $3F, $00, $01, $01
CDtrackend    BYTE $18, $0A, $68,  $39, $07, $09, $00, $3F, $00, $01, $01

CDseek        BYTE $18, $0A, $68,  $39, $08, $09, $00, $3F, $00, $01, $01        
CDstartplay   BYTE $18, $0A, $68,  $39, $02, $09, $00, $3F, $00, $01, $01