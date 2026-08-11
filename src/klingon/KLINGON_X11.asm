; KLINGON_X11.asm
; Klingon language expansion ROM for Gorf Program 2
; This source targets Gorf Program 2 only; it is not compatible with the
; Wizard of Wor X11 layout or the Gorf Program-1 CPU ROMs.
;
; ROM map:  $C000-$CFFF (X11 socket, 4 KB)
;
; Interface used by Gorf program 2:
;
;   $C000  JP TranslateSpeechPrimitive
;   $C003  Length-prefixed Klingon message table
;   $CC00  JP PROGRAM2_FOREIGN_RESUME
;
; The executable structure is derived from the working program-2 German X11
; conversion.  Canonical tlhIngan Hol appears in comments and documentation.
; Display payloads use uppercase, apostrophe-free arcade transliteration.
;
; The resident program jumps to $C000 with DE holding the address of an
; English speech primitive.  The routine searches a table of 36 program-2
; primitive addresses, obtains the parallel Klingon primitive address, and
; transfers control to the program-2 speech queue routine at $10B8.  A null
; translation suppresses that primitive.
;
; Message and speech records both use a one-byte payload length followed by
; that many data bytes.  Klingon speech uses direct low-six-bit SC-01 phoneme
; values; bits 7 and 6 are zero.

        ORG     $C000

PGM2_SPEECH_QUEUE       EQU     $10B8
PROGRAM2_FOREIGN_RESUME EQU     $1769
TRANSLATION_COUNT       EQU     36
SC01_SETTINGS_PORT      EQU     $10
SC01_ENABLED_MASK       EQU     $80
SPEECH_QUEUE_FIRST      EQU     $D112
SPEECH_QUEUE_AFTER_LAST EQU     $D122
SPEECH_QUEUE_WRITE_PTR  EQU     $D125
SPEECH_QUEUE_READ_PTR   EQU     $D127

PGM2_SPK_INSERT_COIN   EQU     $115D
PGM2_SPK_GORF          EQU     $116D
PGM2_SPK_SPACE         EQU     $1185
PGM2_SPK_CONQUER       EQU     $118C
PGM2_SPK_TRY           EQU     $11A8
PGM2_SPK_LONG          EQU     $11C7
PGM2_SPK_ROBOTS        EQU     $11D7
PGM2_SPK_BAD_MOVE      EQU     $11F6
PGM2_SPK_HAHA          EQU     $1200
PGM2_SPK_ESCAPE        EQU     $120A
PGM2_SPK_GOT_YOU       EQU     $122E
PGM2_SPK_NICE          EQU     $1237
PGM2_SPK_TOO_BAD       EQU     $1243
PGM2_SPK_PRISONER      EQU     $124B
PGM2_SPK_CADET         EQU     $1264
PGM2_SPK_CAPTAIN       EQU     $126B
PGM2_SPK_COLONEL       EQU     $1274
PGM2_SPK_GENERAL       EQU     $127B
PGM2_SPK_WARRIOR       EQU     $1284
PGM2_SPK_AVENGER       EQU     $128D
PGM2_SPK_PROMOTE       EQU     $1298
PGM2_SPK_SOME          EQU     $12B2
PGM2_SPK_BITE          EQU     $12CE
PGM2_SPK_HAIL          EQU     $12DB
PGM2_SPK_ENEMY         EQU     $12FC
PGM2_SPK_BETCHA        EQU     $1317
PGM2_SPK_A985          EQU     $A985
PGM2_SPK_A9A8          EQU     $A9A8
PGM2_SPK_A9C1          EQU     $A9C1
PGM2_SPK_PUSH          EQU     $B3BE
PGM2_SPK_DOOM          EQU     $B3D4
PGM2_SPK_SURVIVAL      EQU     $B3EF
PGM2_SPK_ROBOWARRIOR   EQU     $B405
PGM2_SPK_GORFIAN       EQU     $B426
PGM2_SPK_I_AM          EQU     $B449
PGM2_SPK_PREPARE       EQU     $B465

; -----------------------------------------------------------------------------
; X11 entry point
; -----------------------------------------------------------------------------

X11Entry:
        JP      TranslateSpeechPrimitive

; -----------------------------------------------------------------------------
; Klingon message table
;
; The table contains all 52 program-2 indexes in the exact order expected by
; the resident program.  Each record is a payload length followed by payload
; bytes.  Indexes 42 through 47 remain byte-for-byte compatible with program 2.
; -----------------------------------------------------------------------------

KlingonMessageTable:
; Message 00: Program-2 "MISSION["
; tlhIngan Hol: Qu'
Message_00_Mission:
        DB      Message_00_Mission_End - $ - 1
        DB      "QU["
Message_00_Mission_End:

; Message 01: Program-2 "GAME OVER"
; tlhIngan Hol: rIn Quj
Message_01_GameOver:
        DB      Message_01_GameOver_End - $ - 1
        DB      "RIN QUJ"
Message_01_GameOver_End:

; Message 02: Program-2 "PLAYER"
; tlhIngan Hol: QujwI'
Message_02_Player:
        DB      Message_02_Player_End - $ - 1
        DB      "QUJWI"
Message_02_Player_End:

; Message 03: Program-2 "2"
; tlhIngan Hol: 2
Message_03_Two:
        DB      Message_03_Two_End - $ - 1
        DB      "2"
Message_03_Two_End:

; Message 04: Program-2 "1"
; tlhIngan Hol: 1
Message_04_One:
        DB      Message_04_One_End - $ - 1
        DB      "1"
Message_04_One_End:

; Message 05: Program-2 "GAME"
; tlhIngan Hol: rIn
Message_05_Game:
        DB      Message_05_Game_End - $ - 1
        DB      "RIN"
Message_05_Game_End:

; Message 06: Program-2 "OVER"
; tlhIngan Hol: Quj
Message_06_Over:
        DB      Message_06_Over_End - $ - 1
        DB      "QUJ"
Message_06_Over_End:

; Message 07: Program-2 "GET"
; tlhIngan Hol: SuvmeH
Message_07_ForBattle:
        DB      Message_07_ForBattle_End - $ - 1
        DB      "SUVMEH"
Message_07_ForBattle_End:

; Message 08: Program-2 "READY"
; tlhIngan Hol: yIghuH
Message_08_Prepare:
        DB      Message_08_Prepare_End - $ - 1
        DB      "YIGHUH"
Message_08_Prepare_End:

; Message 09: Program-2 "INSERT ADDITIONAL COIN"
; tlhIngan Hol: latlh Huch yIlan
Message_09_AdditionalCoin:
        DB      Message_09_AdditionalCoin_End - $ - 1
        DB      "LATLH HUCH YILAN"
Message_09_AdditionalCoin_End:

; Message 10: Program-2 "SELECT 1 PLAYER GAME"
; tlhIngan Hol: wa' QujwI' Quj yIwIv
Message_10_SelectOnePlayer:
        DB      Message_10_SelectOnePlayer_End - $ - 1
        DB      "WA QUJWI QUJ YIWIV"
Message_10_SelectOnePlayer_End:

; Message 11: Program-2 "OR"
; tlhIngan Hol: ghap
Message_11_Or:
        DB      Message_11_Or_End - $ - 1
        DB      "GHAP"
Message_11_Or_End:

; Message 12: Program-2 "SELECT 1 OR 2 PLAYER GAME"
; tlhIngan Hol: wa' QujwI' cha' QujwI' ghap yIwIv
Message_12_SelectOneOrTwo:
        DB      Message_12_SelectOneOrTwo_End - $ - 1
        DB      "WA CHA GHAP QUJWI YIWIV"
Message_12_SelectOneOrTwo_End:

; Message 13: Program-2 "FOR 2 PLAYER GAME"
; tlhIngan Hol: cha' QujwI' QujmeH
Message_13_ForTwoPlayers:
        DB      Message_13_ForTwoPlayers_End - $ - 1
        DB      "CHA QUJWI QUJMEH"
Message_13_ForTwoPlayers_End:

; Message 14: Program-2 "OR FOR EXTRA SHIPS"
; tlhIngan Hol: qoj latlh Dujmey
Message_14_OrExtraShips:
        DB      Message_14_OrExtraShips_End - $ - 1
        DB      "QOJ LATLH DUJMEY"
Message_14_OrExtraShips_End:

; Message 15: Program-2 "WITH EXTRA SHIPS"
; tlhIngan Hol: latlh Dujmey ghaj
Message_15_WithExtraShips:
        DB      Message_15_WithExtraShips_End - $ - 1
        DB      "LATLH DUJMEY GHAJ"
Message_15_WithExtraShips_End:

; Message 16: Program-2 "THE EVIL"
; tlhIngan Hol: nuHIvpu'
Message_16_HasAttacked:
        DB      Message_16_HasAttacked_End - $ - 1
        DB      "NUHIVPU"
Message_16_HasAttacked_End:

; Message 17: Program-2 "GORFIAN ROBOT"
; tlhIngan Hol: Gorf wo'
Message_17_GorfEmpire:
        DB      Message_17_GorfEmpire_End - $ - 1
        DB      "GORF WO"
Message_17_GorfEmpire_End:

; Message 18: Program-2 "EMPIRE HAS ATTACKED"
; tlhIngan Hol: qoqmey mIgh
Message_18_EvilGorfRobots:
        DB      Message_18_EvilGorfRobots_End - $ - 1
        DB      "QOQMEY MIGH"
Message_18_EvilGorfRobots_End:

; Message 19: Program-2 "YOUR ASSIGNMENT IS TO"
; tlhIngan Hol: Qu'lIj 'oH
Message_19_YourMission:
        DB      Message_19_YourMission_End - $ - 1
        DB      "QULIJ OH"
Message_19_YourMission_End:

; Message 20: Program-2 "REPEL THE INVASION AND"
; tlhIngan Hol: yot yIbot 'ej
Message_20_RepelInvasion:
        DB      Message_20_RepelInvasion_End - $ - 1
        DB      "YOT YIBOT EJ"
Message_20_RepelInvasion_End:

; Message 21: Program-2 "LAUNCH A COUNTERATTACK"
; tlhIngan Hol: yIHIvqa'
Message_21_Counterattack:
        DB      Message_21_Counterattack_End - $ - 1
        DB      "YIHIVQA"
Message_21_Counterattack_End:

; Message 22: Program-2 "YOU WILL"
; tlhIngan Hol: tugh
Message_22_Soon:
        DB      Message_22_Soon_End - $ - 1
        DB      "TUGH"
Message_22_Soon_End:

; Message 23: Program-2 "ENGAGE VARIOUS"
; tlhIngan Hol: jagh
Message_23_Enemies:
        DB      Message_23_Enemies_End - $ - 1
        DB      "JAGH"
Message_23_Enemies_End:

; Message 24: Program-2 "HOSTILE SPACECRAFT"
; tlhIngan Hol: Dujmey DaSuv
Message_24_FightShips:
        DB      Message_24_FightShips_End - $ - 1
        DB      "DUJMEY DASUV"
Message_24_FightShips_End:

; Message 25: Program-2 "AS YOU JOURNEY TOWARD"
; tlhIngan Hol: bIghoStaHDI'
Message_25_AsYouTravel:
        DB      Message_25_AsYouTravel_End - $ - 1
        DB      "BIGHOSTAHDI"
Message_25_AsYouTravel_End:

; Message 26: Program-2 "A DRAMATIC CONFRONTATION"
; tlhIngan Hol: may' Qatlh DaSuv
Message_26_DramaticBattle:
        DB      Message_26_DramaticBattle_End - $ - 1
        DB      "MAY QATLH DASUV"
Message_26_DramaticBattle_End:

; Message 27: Program-2 "WITH THE ENEMY FLAG SHIP"
; tlhIngan Hol: jagh ra'wI' Duj DaSuv
Message_27_EnemyFlagship:
        DB      Message_27_EnemyFlagship_End - $ - 1
        DB      "JAGH RAWI DUJ DASUV"
Message_27_EnemyFlagship_End:

; Message 28: Program-2 "THE HIGH"
; tlhIngan Hol: mIvwa'mey nIv
Message_28_HighScores:
        DB      Message_28_HighScores_End - $ - 1
        DB      "MIVWAMEY NIV"
Message_28_HighScores_End:

; Message 29: Program-2 "SCORES ARE["
; tlhIngan Hol: bIH:
Message_29_ScoresAre:
        DB      Message_29_ScoresAre_End - $ - 1
        DB      "BIH["
Message_29_ScoresAre_End:

; Message 30: Program-2 "2 SHIPS"
; tlhIngan Hol: cha' Dujmey
Message_30_TwoShips:
        DB      Message_30_TwoShips_End - $ - 1
        DB      "CHA DUJMEY"
Message_30_TwoShips_End:

; Message 31: Program-2 "3 SHIPS"
; tlhIngan Hol: wej Dujmey
Message_31_ThreeShips:
        DB      Message_31_ThreeShips_End - $ - 1
        DB      "WEJ DUJMEY"
Message_31_ThreeShips_End:

; Message 32: Program-2 "4 SHIPS"
; tlhIngan Hol: loS Dujmey
Message_32_FourShips:
        DB      Message_32_FourShips_End - $ - 1
        DB      "LOS DUJMEY"
Message_32_FourShips_End:

; Message 33: Program-2 "6 SHIPS"
; tlhIngan Hol: jav Dujmey
Message_33_SixShips:
        DB      Message_33_SixShips_End - $ - 1
        DB      "JAV DUJMEY"
Message_33_SixShips_End:

; Message 34: Program-2 "ASTRO BATTLES"
; tlhIngan Hol: Hov may'mey
Message_34_StarBattles:
        DB      Message_34_StarBattles_End - $ - 1
        DB      "HOV MAYMEY"
Message_34_StarBattles_End:

; Message 35: Program-2 "GALAXIANS"
; tlhIngan Hol: qIbnganpu'
Message_35_Galaxians:
        DB      Message_35_Galaxians_End - $ - 1
        DB      "QIBNGANPU"
Message_35_Galaxians_End:

; Message 36: Program-2 "LASER ATTACK"
; tlhIngan Hol: nISwI' HIv
Message_36_DisruptorAttack:
        DB      Message_36_DisruptorAttack_End - $ - 1
        DB      "NISWI HIV"
Message_36_DisruptorAttack_End:

; Message 37: Program-2 "SPACE WARP"
; tlhIngan Hol: pIvghor
Message_37_WarpDrive:
        DB      Message_37_WarpDrive_End - $ - 1
        DB      "PIVGHOR"
Message_37_WarpDrive_End:

; Message 38: Program-2 "FLAG SHIP"
; tlhIngan Hol: ra'wI' Duj
Message_38_Flagship:
        DB      Message_38_Flagship_End - $ - 1
        DB      "RAWI DUJ"
Message_38_Flagship_End:

; Message 39: Program-2 "1 PLAYER"
; tlhIngan Hol: wa' QujwI'
Message_39_OnePlayer:
        DB      Message_39_OnePlayer_End - $ - 1
        DB      "WA QUJWI"
Message_39_OnePlayer_End:

; Message 40: Program-2 "2 PLAYERS"
; tlhIngan Hol: cha' QujwI'
Message_40_TwoPlayers:
        DB      Message_40_TwoPlayers_End - $ - 1
        DB      "CHA QUJWI"
Message_40_TwoPlayers_End:

; Message 41: Program-2 "INSERT COIN"
; tlhIngan Hol: Huch yIlan
Message_41_InsertCoin:
        DB      Message_41_InsertCoin_End - $ - 1
        DB      "HUCH YILAN"
Message_41_InsertCoin_End:

; Message 42: Program-2 "one space"
; tlhIngan Hol: one space
Message_42_BlankA:
        DB      Message_42_BlankA_End - $ - 1
        DB      $20
Message_42_BlankA_End:

; Message 43: Program-2 "one space"
; tlhIngan Hol: one space
Message_43_BlankB:
        DB      Message_43_BlankB_End - $ - 1
        DB      $20
Message_43_BlankB_End:

; Message 44: Program-2 "$09"
; tlhIngan Hol: unchanged control record
Message_44_ControlA:
        DB      Message_44_ControlA_End - $ - 1
        DB      $09
Message_44_ControlA_End:

; Message 45: Program-2 "$0A,$0B,$09,$0D,$0E"
; tlhIngan Hol: unchanged control record
Message_45_ControlB:
        DB      Message_45_ControlB_End - $ - 1
        DB      $0A,$0B,$09,$0D,$0E
Message_45_ControlB_End:

; Message 46: Program-2 "$0C,$0B,$09,$0D,$0F"
; tlhIngan Hol: unchanged control record
Message_46_ControlC:
        DB      Message_46_ControlC_End - $ - 1
        DB      $0C,$0B,$09,$0D,$0F
Message_46_ControlC_End:

; Message 47: Program-2 "$0C"
; tlhIngan Hol: unchanged control record
Message_47_ControlD:
        DB      Message_47_ControlD_End - $ - 1
        DB      $0C
Message_47_ControlD_End:

; Message 48: Program-2 "SAME PLAYER UP"
; tlhIngan Hol: QujwI' rap
Message_48_SamePlayer:
        DB      Message_48_SamePlayer_End - $ - 1
        DB      "QUJWI RAP"
Message_48_SamePlayer_End:

; Message 49: Program-2 "CREDIT SHIPS["
; tlhIngan Hol: Huch Dujmey:
Message_49_CreditShips:
        DB      Message_49_CreditShips_End - $ - 1
        DB      "HUCH DUJMEY["
Message_49_CreditShips_End:

; Message 50: Program-2 "$5C,\"1981 MIDWAY MFG CO\""
; tlhIngan Hol: unchanged copyright record
Message_50_Copyright:
        DB      Message_50_Copyright_End - $ - 1
        DB      $5C,$31,$39,$38,$31,$20,$4D,$49,$44,$57,$41,$59
        DB      $20,$4D,$46,$47,$20,$43,$4F
Message_50_Copyright_End:

; Message 51: Program-2 "ALL RIGHTS RESERVED"
; tlhIngan Hol: Hoch DIbmey pollu'
Message_51_RightsReserved:
        DB      Message_51_RightsReserved_End - $ - 1
        DB      "HOCH DIBMEY POLLU"
Message_51_RightsReserved_End:

; -----------------------------------------------------------------------------
; Klingon SC-01 speech primitives
;
; Pronunciations follow the direct approximation scheme used by the Wizard of
; Wor Klingon X11.  PA0 separates words and PA1 normally terminates a record.
; Every local record begins directly with its first spoken allophone and ends
; with PA1.  This matches the Wizard of Wor Klingon record convention and
; avoids PA1-to-PA1 boundaries when Program 2 chains speech records.
; -----------------------------------------------------------------------------

; Insert coin
; tlhIngan Hol: Huch yIlan.
; SC-01: H U CH PA0 Y I L AH1 N PA1
KlingonSpeech_InsertCoin:
        DB      KlingonSpeech_InsertCoin_End - $ - 1
        DB      $1B,$28,$10,$03,$29,$27,$18,$15,$0D,$3E
KlingonSpeech_InsertCoin_End:
        DB      $FF                     ; Preserve following record addresses

; I am the Gorfian Empire
; tlhIngan Hol: Gorf wo' jIH.
; SC-01: G DT O1 R F PA0 W O PA0 D J I H PA1
KlingonSpeech_Gorf:
        DB      KlingonSpeech_Gorf_End - $ - 1
        DB      $1C,$04,$35,$2B,$1D,$03,$2D,$26,$03,$1E,$1A
        DB      $27,$1B,$3E
KlingonSpeech_Gorf_End:
        DB      $FF                     ; Preserve following record addresses

; Gorfians conquer another galaxy
; tlhIngan Hol: latlh qIb luchargh Gorfnganpu'.
; SC-01: L AH1 T L H PA0 K I B PA0 L U CH AH1 R G H PA0 G DT O1 R F NG AH1 N P U PA1
KlingonSpeech_Conquer:
        DB      KlingonSpeech_Conquer_End - $ - 1
        DB      $18,$15,$2A,$18,$1B,$03,$19,$27,$0E,$03,$18
        DB      $28,$10,$15,$2B,$1C,$1B,$03,$1C,$04,$35,$2B,$1D
        DB      $14,$15,$0D,$25,$28,$3E
KlingonSpeech_Conquer_End:
        DB      $FF                     ; Preserve following record addresses

; Try again; I devour your coins
; tlhIngan Hol: yInIDqa'; HuchlIj vISop.
; SC-01: Y I N I D K AH1 PA0 H U CH L I D J PA0 V I SH O P PA1
KlingonSpeech_Try:
        DB      KlingonSpeech_Try_End - $ - 1
        DB      $29,$27,$0D,$27,$1E,$19,$15,$03,$1B,$28,$10
        DB      $18,$27,$1E,$1A,$03,$0F,$27,$11,$26,$25,$3E
KlingonSpeech_Try_End:
        DB      $FF                     ; Preserve following record addresses

; Long live Gorf
; tlhIngan Hol: taHjaj Gorf.
; SC-01: T AH1 H D J AH1 D J PA0 G DT O1 R F PA1
KlingonSpeech_Long:
        DB      KlingonSpeech_Long_End - $ - 1
        DB      $2A,$15,$1B,$1E,$1A,$15,$1E,$1A,$03,$1C,$04
        DB      $35,$2B,$1D,$3E
KlingonSpeech_Long_End:
        DB      $FF                     ; Preserve following record addresses

; Gorf, attack! Attack!
; tlhIngan Hol: Gorf, peHIv! peHIv!
; SC-01: G DT O1 R F PA0 P EH H I V PA0 P EH H I V PA1
KlingonSpeech_Robots:
        DB      KlingonSpeech_Robots_End - $ - 1
        DB      $1C,$04,$35,$2B,$1D,$03,$25,$3B,$1B,$27,$0F
        DB      $03,$25,$3B,$1B,$27,$0F,$3E
KlingonSpeech_Robots_End:
        ; Preserve all following ROM addresses from the original 26-phoneme record.
        DB      $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF

; Bad move
; tlhIngan Hol: vIHHa'.
; SC-01: V I H H AH1 PA1
KlingonSpeech_BadMove:
        DB      KlingonSpeech_BadMove_End - $ - 1
        DB      $0F,$27,$1B,$1B,$15,$3E
KlingonSpeech_BadMove_End:
        DB      $FF                     ; Preserve following record addresses

; You cannot escape the Gorfian robots
; tlhIngan Hol: Gorf qoqmeyvo' bInarghlaHbe'.
; SC-01: G DT O1 R F PA0 K O K M EH Y V O PA0 B I N AH1 R G H L AH1 H B EH PA1
KlingonSpeech_Escape:
        DB      KlingonSpeech_Escape_End - $ - 1
        DB      $1C,$04,$35,$2B,$1D,$03,$19,$26,$19,$0C,$3B
        DB      $29,$0F,$26,$03,$0E,$27,$0D,$15,$2B,$1C,$1B,$18
        DB      $15,$1B,$0E,$3B,$3E
KlingonSpeech_Escape_End:
        DB      $FF                     ; Preserve following record addresses

; Got you
; tlhIngan Hol: qajon.
; SC-01: K AH1 D J O N PA1
KlingonSpeech_GotYou:
        DB      KlingonSpeech_GotYou_End - $ - 1
        DB      $19,$15,$1E,$1A,$26,$0D,$3E
KlingonSpeech_GotYou_End:
        DB      $FF                     ; Preserve following record addresses

; Nice shot
; tlhIngan Hol: bach QaQ.
; SC-01: B AH1 CH PA0 K H AH1 K H PA1
KlingonSpeech_Nice:
        DB      KlingonSpeech_Nice_End - $ - 1
        DB      $0E,$15,$10,$03,$19,$1B,$15,$19,$1B,$3E
KlingonSpeech_Nice_End:
        DB      $FF                     ; Preserve following record addresses

; Too bad
; tlhIngan Hol: Do'Ha'.
; SC-01: D O PA0 H AH1 PA1
KlingonSpeech_TooBad:
        DB      KlingonSpeech_TooBad_End - $ - 1
        DB      $1E,$26,$03,$1B,$15,$3E
KlingonSpeech_TooBad_End:
        DB      $FF                     ; Preserve following record addresses

; Gorfians take no prisoners
; tlhIngan Hol: qama'pu' jonbe' Gorfnganpu'.
; SC-01: K AH1 M AH1 PA0 P U PA0 D J O N B EH PA0 G DT O1 R F NG AH1 N P U PA1
KlingonSpeech_Prisoner:
        DB      KlingonSpeech_Prisoner_End - $ - 1
        DB      $19,$15,$0C,$15,$03,$25,$28,$03,$1E,$1A,$26
        DB      $0D,$0E,$3B,$03,$1C,$04,$35,$2B,$1D,$14,$15,$0D
        DB      $25,$28,$3E
KlingonSpeech_Prisoner_End:
        DB      $FF                     ; Preserve following record addresses

; Cadet
; tlhIngan Hol: ghojwI'.
; SC-01: G H O D J W I PA1
KlingonSpeech_Cadet:
        DB      KlingonSpeech_Cadet_End - $ - 1
        DB      $1C,$1B,$26,$1E,$1A,$2D,$27,$3E
KlingonSpeech_Cadet_End:
        DB      $FF                     ; Preserve following record addresses

; Captain
; tlhIngan Hol: HoD.
; SC-01: H O D PA1
KlingonSpeech_Captain:
        DB      KlingonSpeech_Captain_End - $ - 1
        DB      $1B,$26,$1E,$3E
KlingonSpeech_Captain_End:
        DB      $FF                     ; Preserve following record addresses

; Colonel
; tlhIngan Hol: la'.
; SC-01: L AH1 PA1
KlingonSpeech_Colonel:
        DB      KlingonSpeech_Colonel_End - $ - 1
        DB      $18,$15,$3E
KlingonSpeech_Colonel_End:
        DB      $FF                     ; Preserve following record addresses

; General
; tlhIngan Hol: Sa'.
; SC-01: SH AH1 PA1
KlingonSpeech_General:
        DB      KlingonSpeech_General_End - $ - 1
        DB      $11,$15,$3E
KlingonSpeech_General_End:
        DB      $FF                     ; Preserve following record addresses

; Warrior
; tlhIngan Hol: SuvwI'.
; SC-01: SH U V W I PA1
KlingonSpeech_Warrior:
        DB      KlingonSpeech_Warrior_End - $ - 1
        DB      $11,$28,$0F,$2D,$27,$3E
KlingonSpeech_Warrior_End:
        DB      $FF                     ; Preserve following record addresses

; Avenger
; tlhIngan Hol: bortaSwI'.
; SC-01: B O R T AH1 SH W I PA1
KlingonSpeech_Avenger:
        DB      KlingonSpeech_Avenger_End - $ - 1
        DB      $0E,$26,$2B,$2A,$15,$11,$2D,$27,$3E
KlingonSpeech_Avenger_End:
        DB      $FF                     ; Preserve following record addresses

; You have been promoted to
; tlhIngan Hol: patlh chu' Dachav:
; SC-01: P AH1 T L H PA0 CH U PA0 D AH1 CH AH1 V PA1
KlingonSpeech_Promote:
        DB      KlingonSpeech_Promote_End - $ - 1
        DB      $25,$15,$2A,$18,$1B,$03,$10,$28,$03,$1E,$15
        DB      $10,$15,$0F,$3E
KlingonSpeech_Promote_End:
        DB      $FF                     ; Preserve following record addresses

; Some galactic defender you are
; tlhIngan Hol: qIb HubwI' qab SoH.
; SC-01: K I B PA0 H U B W I PA0 K AH1 B PA0 SH O H PA1
KlingonSpeech_Some:
        DB      KlingonSpeech_Some_End - $ - 1
        DB      $19,$27,$0E,$03,$1B,$28,$0E,$2D,$27,$03,$19
        DB      $15,$0E,$03,$11,$26,$1B,$3E
KlingonSpeech_Some_End:
        DB      $FF                     ; Preserve following record addresses

; Bite the dust
; tlhIngan Hol: lam yIchop.
; SC-01: L AH1 M PA0 Y I CH O P PA1
KlingonSpeech_Bite:
        DB      KlingonSpeech_Bite_End - $ - 1
        DB      $18,$15,$0C,$03,$29,$27,$10,$26,$25,$3E
KlingonSpeech_Bite_End:
        DB      $FF                     ; Preserve following record addresses

; All hail the supreme Gorfian Empire
; tlhIngan Hol: Gorf wo' quv yIvan.
; SC-01: G DT O1 R F PA0 W O PA0 K U V PA0 Y I V AH1 N PA1
KlingonSpeech_Hail:
        DB      KlingonSpeech_Hail_End - $ - 1
        DB      $1C,$04,$35,$2B,$1D,$03,$2D,$26,$03,$19,$28
        DB      $0F,$03,$29,$27,$0F,$15,$0D,$3E
KlingonSpeech_Hail_End:
        DB      $FF                     ; Preserve following record addresses

; Another enemy ship destroyed
; tlhIngan Hol: latlh jagh Duj Qaw'lu'.
; SC-01: L AH1 T L H PA0 D J AH1 G H PA0 D U D J PA0 K H AH1 W PA0 L U PA1
KlingonSpeech_Enemy:
        DB      KlingonSpeech_Enemy_End - $ - 1
        DB      $18,$15,$2A,$18,$1B,$03,$1E,$1A,$15,$1C,$1B
        DB      $03,$1E,$28,$1E,$1A,$03,$19,$1B,$15,$2D,$03,$18
        DB      $28,$3E
KlingonSpeech_Enemy_End:
        DB      $FF                     ; Preserve following record addresses

; Your end draws near
; tlhIngan Hol: tugh bIHegh.
; SC-01: T U G H PA0 B I H EH G H PA1
KlingonSpeech_Betcha:
        DB      KlingonSpeech_Betcha_End - $ - 1
        DB      $2A,$28,$1C,$1B,$03,$0E,$27,$1B,$3B,$1C,$1B
        DB      $3E
KlingonSpeech_Betcha_End:
        DB      $FF                     ; Preserve following record addresses

; Next time will be harder, but for now
; tlhIngan Hol: Qatlhqu' poH veb, 'ach DaH:
; SC-01: K H AH1 T L H K U PA0 P O H PA0 V EH B PA0 AH1 CH PA0 D AH1 H PA1
KlingonSpeech_For_A985:
        DB      KlingonSpeech_For_A985_End - $ - 1
        DB      $19,$1B,$15,$2A,$18,$1B,$19,$28,$03,$25,$26
        DB      $1B,$03,$0F,$3B,$0E,$03,$15,$10,$03,$1E,$15,$1B
        DB      $3E
KlingonSpeech_For_A985_End:
        DB      $FF                     ; Preserve following record addresses

; In the Gorfian chronicles
; tlhIngan Hol: Gorf QonoSDaq.
; SC-01: G DT O1 R F PA0 K H O N O SH D AH1 K PA1
KlingonSpeech_For_A9A8:
        DB      KlingonSpeech_For_A9A8_End - $ - 1
        DB      $1C,$04,$35,$2B,$1D,$03,$19,$1B,$26,$0D,$26
        DB      $11,$1E,$15,$19,$3E
KlingonSpeech_For_A9A8_End:
        DB      $FF                     ; Preserve following record addresses

; You have hit my flagship
; tlhIngan Hol: ra'wI' DujwIj DaqIpta'.
; SC-01: R AH1 PA0 W I PA0 D U D J W I D J PA0 D AH1 K I P T AH1 PA1
; This wording avoids the SC-01 P-to-M transition that destabilizes MAME audio.
KlingonSpeech_For_A9C1:
        DB      KlingonSpeech_For_A9C1_End - $ - 1
        DB      $2B,$15,$03,$2D,$27,$03,$1E,$28,$1E,$1A,$2D
        DB      $27,$1E,$1A,$03,$1E,$15,$19,$27,$25,$2A,$15,$3E
KlingonSpeech_For_A9C1_End:
        DB      $FF                     ; Preserve following record addresses

; Push a player button
; tlhIngan Hol: QujwI' DuQwI' yIyuv.
; SC-01: K H U D J W I PA0 D U K H W I PA0 Y I Y U V PA1
KlingonSpeech_Push:
        DB      KlingonSpeech_Push_End - $ - 1
        DB      $19,$1B,$28,$1E,$1A,$2D,$27,$03,$1E,$28,$19
        DB      $1B,$2D,$27,$03,$29,$27,$29,$28,$0F,$3E
KlingonSpeech_Push_End:
        DB      $FF                     ; Preserve following record addresses

; You will meet a Gorfian doom
; tlhIngan Hol: Gorf Hegh Daghom,
; SC-01: G DT O1 R F PA0 H EH G H PA0 D AH1 G H O M PA1
KlingonSpeech_Doom:
        DB      KlingonSpeech_Doom_End - $ - 1
        DB      $1C,$04,$35,$2B,$1D,$03,$1B,$3B,$1C,$1B,$03
        DB      $1E,$15,$1C,$1B,$26,$0C,$3E
KlingonSpeech_Doom_End:
        DB      $FF                     ; Preserve following record addresses

; Survival is impossible
; tlhIngan Hol: bIyInlaHbe',
; SC-01: B I Y I N L AH1 H B EH PA1
KlingonSpeech_Survival:
        DB      KlingonSpeech_Survival_End - $ - 1
        DB      $0E,$27,$29,$27,$0D,$18,$15,$1B,$0E,$3B,$3E
KlingonSpeech_Survival_End:
        DB      $FF                     ; Preserve following record addresses

; Robot warriors, seek and destroy the
; tlhIngan Hol: qoq SuvwI'pu' DuSam 'ej DuQaw',
; SC-01: K O K PA0 SH U V W I PA0 P U PA0 D U SH AH1 M PA0 EH D J PA0 D U K H AH1 W PA1
KlingonSpeech_RoboWarrior:
        DB      KlingonSpeech_RoboWarrior_End - $ - 1
        DB      $19,$26,$19,$03,$11,$28,$0F,$2D,$27,$03,$25
        DB      $28,$03,$1E,$28,$11,$15,$0C,$03,$3B,$1E,$1A,$03
        DB      $1E,$28,$19,$1B,$15,$2D,$3E
KlingonSpeech_RoboWarrior_End:
        DB      $FF                     ; Preserve following record addresses

; You cannot kill my warriors
; tlhIngan Hol: SuvwI'pu'wIj DaHoHlaHbe'.
; SC-01: SH U V W I P U W I D J PA0 D AH1 H O H L AH1 H B EH PA1
KlingonSpeech_Gorfian:
        DB      KlingonSpeech_Gorfian_End - $ - 1
        DB      $11,$28,$0F,$2D,$27,$25,$28,$2D,$27,$1E,$1A,$03
        DB      $1E,$15,$1B,$26,$1B,$18,$15,$1B,$0E,$3B,$3E
KlingonSpeech_Gorfian_End:
        ; Preserve the following record and table addresses.
        DB      $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF

; I am a Gorfian consciousness
; tlhIngan Hol: Gorf yab jIH.
; SC-01: G DT O1 R F PA0 Y AH1 B PA0 D J I H PA1
KlingonSpeech_IAm:
        DB      KlingonSpeech_IAm_End - $ - 1
        DB      $1C,$04,$35,$2B,$1D,$03,$29,$15,$0E,$03,$1E
        DB      $1A,$27,$1B,$3E
KlingonSpeech_IAm_End:
        DB      $FF                     ; Preserve following record addresses

; Prepare yourself for annihilation
; tlhIngan Hol: DaQaw'lu'meH yIghuH,
; SC-01: D AH1 K H AH1 W PA0 L U PA0 M EH H PA0 Y I G H U H PA1
KlingonSpeech_Prepare:
        DB      KlingonSpeech_Prepare_End - $ - 1
        DB      $1E,$15,$19,$1B,$15,$2D,$03,$18,$28,$03,$0C
        DB      $3B,$1B,$03,$29,$27,$1C,$1B,$28,$1B,$3E
KlingonSpeech_Prepare_End:
        DB      $FF                     ; Preserve translation-table address

; -----------------------------------------------------------------------------
; Parallel speech translation tables
;
; KlingonSpeechTable[n] is selected when Pgm2SpeechTable[n] matches the
; primitive address supplied in DE.  Both tables contain 36 little-endian
; addresses and must remain in the same order.
; -----------------------------------------------------------------------------

KlingonSpeechTable:
        DW      KlingonSpeech_InsertCoin
        DW      KlingonSpeech_Gorf
        DW      $0000                   ; Suppress the English SPACE token
        DW      KlingonSpeech_Conquer
        DW      KlingonSpeech_Try
        DW      KlingonSpeech_Long
        DW      KlingonSpeech_Robots
        DW      KlingonSpeech_BadMove
        DW      PGM2_SPK_HAHA           ; The laugh is language-neutral
        DW      KlingonSpeech_Escape
        DW      KlingonSpeech_GotYou
        DW      KlingonSpeech_Nice
        DW      KlingonSpeech_TooBad
        DW      KlingonSpeech_Prisoner
        DW      KlingonSpeech_Cadet
        DW      KlingonSpeech_Captain
        DW      KlingonSpeech_Colonel
        DW      KlingonSpeech_General
        DW      KlingonSpeech_Warrior
        DW      KlingonSpeech_Avenger
        DW      KlingonSpeech_Promote
        DW      KlingonSpeech_Some
        DW      KlingonSpeech_Bite
        DW      KlingonSpeech_Hail
        DW      KlingonSpeech_Enemy
        DW      KlingonSpeech_Betcha
        DW      KlingonSpeech_For_A985
        DW      KlingonSpeech_For_A9A8
        DW      KlingonSpeech_For_A9C1
        DW      KlingonSpeech_Push
        DW      KlingonSpeech_Doom
        DW      KlingonSpeech_Survival
        DW      KlingonSpeech_RoboWarrior
        DW      KlingonSpeech_Gorfian
        DW      KlingonSpeech_IAm
        DW      KlingonSpeech_Prepare
KlingonSpeechTableEnd:

Pgm2SpeechTable:
        DW      PGM2_SPK_INSERT_COIN
        DW      PGM2_SPK_GORF
        DW      PGM2_SPK_SPACE
        DW      PGM2_SPK_CONQUER
        DW      PGM2_SPK_TRY
        DW      PGM2_SPK_LONG
        DW      PGM2_SPK_ROBOTS
        DW      PGM2_SPK_BAD_MOVE
        DW      PGM2_SPK_HAHA
        DW      PGM2_SPK_ESCAPE
        DW      PGM2_SPK_GOT_YOU
        DW      PGM2_SPK_NICE
        DW      PGM2_SPK_TOO_BAD
        DW      PGM2_SPK_PRISONER
        DW      PGM2_SPK_CADET
        DW      PGM2_SPK_CAPTAIN
        DW      PGM2_SPK_COLONEL
        DW      PGM2_SPK_GENERAL
        DW      PGM2_SPK_WARRIOR
        DW      PGM2_SPK_AVENGER
        DW      PGM2_SPK_PROMOTE
        DW      PGM2_SPK_SOME
        DW      PGM2_SPK_BITE
        DW      PGM2_SPK_HAIL
        DW      PGM2_SPK_ENEMY
        DW      PGM2_SPK_BETCHA
        DW      PGM2_SPK_A985
        DW      PGM2_SPK_A9A8
        DW      PGM2_SPK_A9C1
        DW      PGM2_SPK_PUSH
        DW      PGM2_SPK_DOOM
        DW      PGM2_SPK_SURVIVAL
        DW      PGM2_SPK_ROBOWARRIOR
        DW      PGM2_SPK_GORFIAN
        DW      PGM2_SPK_I_AM
        DW      PGM2_SPK_PREPARE
Pgm2SpeechTableEnd:

; -----------------------------------------------------------------------------
; TranslateSpeechPrimitive
;
; IN:    DE = program-2 English speech primitive address
; OUT:   DE = translated primitive address when dispatched
;        BC preserved
; USES:  AF, DE, HL
;
; This retains the original X11 search algorithm and ROM layout.  Every speech
; primitive used by program 2 has an exact, sorted key in Pgm2SpeechTable.
; -----------------------------------------------------------------------------

TranslateSpeechPrimitive:
        PUSH    BC
        PUSH    DE
        POP     BC                      ; BC = requested primitive
        LD      A,TRANSLATION_COUNT
        LD      HL,Pgm2SpeechTable

TranslationSearchLoop:
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        INC     HL
        EX      DE,HL                   ; HL = table key, DE = next entry
        OR      A                       ; Clear carry before subtraction
        SBC     HL,BC
        EX      DE,HL                   ; Restore table cursor to HL
        JP      C,TranslationNext       ; Table key is below request
        JP      Z,SelectTranslation     ; Exact match
        INC     A                       ; Preserve original predecessor fallback

SelectTranslation:
        JP      ResolveTranslationIndex

TranslationNext:
        DEC     A
        JP      NZ,TranslationSearchLoop

ResolveTranslationIndex:
        LD      HL,KlingonSpeechTable
        NEG
        ADD     A,TRANSLATION_COUNT
        RLCA                              ; Two bytes per address
        LD      E,A
        LD      D,$00
        ADD     HL,DE
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        POP     BC
        LD      A,D
        OR      E
        JP      Z,TranslationSuppressed
        CALL    WaitForSpeechQueueSlot
        JP      PGM2_SPEECH_QUEUE

TranslationSuppressed:
        RET

; Program 2's resident queue routine writes the next primitive without testing
; whether its eight-entry ring buffer is full.  Translated Klingon primitives keep the
; consumer occupied substantially longer than the English originals, allowing
; a burst of queued speech to lap the consumer.  Reserve one slot so equal
; read/write pointers continue to mean "empty," as the interrupt handler
; expects.  Interrupts remain enabled while waiting and advance the reader.
WaitForSpeechQueueSlot:
        IN      A,(SC01_SETTINGS_PORT)
        AND     SC01_ENABLED_MASK
        RET     Z                       ; Resident routine will also ignore it

SpeechQueueWait:
        PUSH    DE                      ; Preserve translated primitive address
        LD      HL,(SPEECH_QUEUE_WRITE_PTR)
        INC     HL
        INC     HL
        LD      A,L
        CP      SPEECH_QUEUE_AFTER_LAST & $FF
        JR      C,SpeechQueueNextReady
        LD      HL,SPEECH_QUEUE_FIRST

SpeechQueueNextReady:
        LD      DE,(SPEECH_QUEUE_READ_PTR)
        OR      A                       ; Clear carry before pointer comparison
        SBC     HL,DE
        POP     DE
        JR      Z,SpeechQueueWait
        RET

; zmac v1.3 does not support REPT.  These nested macros emit power-of-two runs
; of $FF so the source can pad to the fixed trailer address without relying on
; a modern assembler extension.  The descending conditions select the binary
; decomposition of the remaining byte count.
FillFF1 MACRO
        DB      $FF
        ENDM

FillFF2 MACRO
        FillFF1
        FillFF1
        ENDM

FillFF4 MACRO
        FillFF2
        FillFF2
        ENDM

FillFF8 MACRO
        FillFF4
        FillFF4
        ENDM

FillFF16 MACRO
        FillFF8
        FillFF8
        ENDM

FillFF32 MACRO
        FillFF16
        FillFF16
        ENDM

FillFF64 MACRO
        FillFF32
        FillFF32
        ENDM

FillFF128 MACRO
        FillFF64
        FillFF64
        ENDM

FillFF256 MACRO
        FillFF128
        FillFF128
        ENDM

FillFF512 MACRO
        FillFF256
        FillFF256
        ENDM

FillFF1024 MACRO
        FillFF512
        FillFF512
        ENDM

FillFF2048 MACRO
        FillFF1024
        FillFF1024
        ENDM

; Pad to program 2's third foreign-ROM entry point.  The resident input routine
; branches here when the Language DIP selects the X11 ROM.
        IF      $CC00 - $ >= 2048
        FillFF2048
        ENDIF
        IF      $CC00 - $ >= 1024
        FillFF1024
        ENDIF
        IF      $CC00 - $ >= 512
        FillFF512
        ENDIF
        IF      $CC00 - $ >= 256
        FillFF256
        ENDIF
        IF      $CC00 - $ >= 128
        FillFF128
        ENDIF
        IF      $CC00 - $ >= 64
        FillFF64
        ENDIF
        IF      $CC00 - $ >= 32
        FillFF32
        ENDIF
        IF      $CC00 - $ >= 16
        FillFF16
        ENDIF
        IF      $CC00 - $ >= 8
        FillFF8
        ENDIF
        IF      $CC00 - $ >= 4
        FillFF4
        ENDIF
        IF      $CC00 - $ >= 2
        FillFF2
        ENDIF
        IF      $CC00 - $ >= 1
        FillFF1
        ENDIF

ForeignCoinInputEntry:
        JP      PROGRAM2_FOREIGN_RESUME

; The physical X11 device is a 4 KB ROM.  Unused bytes read as $FF.  Its final
; 14 bytes contain the original DNA identification trailer.  The final three
; bytes encode the date 12/15/1980.
        IF      $CFF2 - $ >= 2048
        FillFF2048
        ENDIF
        IF      $CFF2 - $ >= 1024
        FillFF1024
        ENDIF
        IF      $CFF2 - $ >= 512
        FillFF512
        ENDIF
        IF      $CFF2 - $ >= 256
        FillFF256
        ENDIF
        IF      $CFF2 - $ >= 128
        FillFF128
        ENDIF
        IF      $CFF2 - $ >= 64
        FillFF64
        ENDIF
        IF      $CFF2 - $ >= 32
        FillFF32
        ENDIF
        IF      $CFF2 - $ >= 16
        FillFF16
        ENDIF
        IF      $CFF2 - $ >= 8
        FillFF8
        ENDIF
        IF      $CFF2 - $ >= 4
        FillFF4
        ENDIF
        IF      $CFF2 - $ >= 2
        FillFF2
        ENDIF
        IF      $CFF2 - $ >= 1
        FillFF1
        ENDIF

RomIdentificationTrailer:
        DB      $00,$00,"GORF",$00,"DNA",$00,$12,$15,$80

        END
