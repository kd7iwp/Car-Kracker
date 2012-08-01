CON

  _clkmode = xtal1 + pll16x                             ' Crystal and PLL settings.
  _xinfreq = 5_000_000                                  ' 5 MHz crystal (5 MHz x 16 = 80 MHz).

OBJ
  player : "Audio_Player.spin"
    
VAR
BYTE playerstatus
WORD CurrCD
WORD CurrTrack
BYTE RADString[32]
LONG stack[50]
BYTE Auxmode
      

PUB start
Auxmode := player.start
return Auxmode


PUB settrack(CD,track) | tens, i 
tens := 0


IF CD > 0
    currCD := CD
    repeat while CD > 9
      tens++
      CD -= 10
    byte[@playfile]   := $30 + tens 
    byte[@playfile+1] := $30 + cd      

    byte[@CDnotplay+9]   := cd + (tens * 16)
    byte[@CDplaying+9]   := cd + (tens * 16)
    byte[@CDstartplay+9] := cd + (tens * 16)
    byte[@CDtrackend+9]  := cd + (tens * 16)
    byte[@CDseek+9]      := cd + (tens * 16)



tens := 0                        

IF track > 0
  currtrack := track
  repeat while track > 9
    tens++
    track -= 10
  byte[@playfile+3]   := $30 + tens 
  byte[@playfile+4]   := $30 + track
  byte[@CDnotplay+10]   := track + (tens * 16)
  byte[@CDplaying+10]   := track + (tens * 16)
  byte[@CDstartplay+10] := track + (tens * 16)
  byte[@CDtrackend+10]  := track + (tens * 16)
  byte[@CDseek+10]      := track + (tens * 16)



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

PUB startsong
IF Auxmode > -1
  player.stopplaying
  waitcnt(clkfreq / 50 + cnt)
  cognew(bgplay,@stack)

PUB bgplay
IF Auxmode > -1   
  player.play(@playfile)

DAT

playfile      BYTE "00_00.wav",0

'Steering Wheel
volup         BYTE $50, $04, $68, $32, $11
voldown       BYTE $50, $04, $68, $32, $10
whlplus       BYTE $50, $04, $68, $3B, $01
whlmin        BYTE $50, $04, $68, $3B, $08





'From Radio  $68
playtrack     BYTE $68, $05, $18, $38, $03, $00
stoptrack     BYTE $68, $05, $18, $38, $01, $00
'Switch CD# (01-06)                         CD#                                       
changecd      BYTE $68, $05, $18, $38, $06, $00        
'Switch tracks                              0= previous, 1=next
changetrack   BYTE $68, $05, $18, $38, $05, $00
'changetrack   BYTE $68, $05, $18, $38, $0A, $00

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
