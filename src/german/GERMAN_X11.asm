; GERMAN_X11.asm
; German language expansion ROM for Gorf program 2
; This source targets program 2 only; it does not build a program-1 variant.
;
; ROM map:  $C000-$CFFF (X11 socket, 4 KiB)
; CRC-32:   E3A07D3B
; SHA-1:    1C131EF85D898BDF70413AB6C7B386C6EA996BB1
;
; Interface used by Gorf program 2:
;
;   $C000  JP TranslateSpeechPrimitive
;   $C003  Length-prefixed German message table
;
; The resident program jumps to $C000 with DE holding the address of an
; English speech primitive.  The routine searches a table of 36 program-2
; primitive addresses, obtains the parallel German primitive address, and
; transfers control to the program-2 speech queue routine at $10B8.  A null
; translation suppresses that primitive.
;
; Message and speech records both use a one-byte payload length followed by
; that many data bytes.  SC-01 phoneme bytes retain their inflection bits in
; bits 7 and 6.

        ORG     $C000

PGM2_SPEECH_QUEUE       EQU     $10B8
TRANSLATION_COUNT       EQU     36

; Program-2 speech primitive addresses.  The first 26 are in the resident
; speech block.  The next three are upper-ROM records not yet named in the
; program-2 source, and the final seven are attract-mode speech records.
PGM2_SPK_INSERT_COIN    EQU     $115D
PGM2_SPK_GORF           EQU     $116D
PGM2_SPK_SPACE          EQU     $1185
PGM2_SPK_CONQUER        EQU     $118C
PGM2_SPK_TRY            EQU     $11A8
PGM2_SPK_LONG           EQU     $11C7
PGM2_SPK_ROBOTS         EQU     $11D7
PGM2_SPK_BAD_MOVE       EQU     $11F6
PGM2_SPK_HAHA           EQU     $1200
PGM2_SPK_ESCAPE         EQU     $120A
PGM2_SPK_GOT_YOU        EQU     $122E
PGM2_SPK_NICE           EQU     $1237
PGM2_SPK_TOO_BAD        EQU     $1243
PGM2_SPK_PRISONER       EQU     $124B
PGM2_SPK_CADET          EQU     $1264
PGM2_SPK_CAPTAIN        EQU     $126B
PGM2_SPK_COLONEL        EQU     $1274
PGM2_SPK_GENERAL        EQU     $127B
PGM2_SPK_WARRIOR        EQU     $1284
PGM2_SPK_AVENGER        EQU     $128D
PGM2_SPK_PROMOTE        EQU     $1298
PGM2_SPK_SOME           EQU     $12B2
PGM2_SPK_BITE           EQU     $12CE
PGM2_SPK_HAIL           EQU     $12DB
PGM2_SPK_ENEMY          EQU     $12FC
PGM2_SPK_BETCHA         EQU     $1317
PGM2_SPK_A985           EQU     $A985
PGM2_SPK_A9A8           EQU     $A9A8
PGM2_SPK_A9C1           EQU     $A9C1
PGM2_SPK_PUSH           EQU     $B3BE
PGM2_SPK_DOOM           EQU     $B3D4
PGM2_SPK_SURVIVAL       EQU     $B3EF
PGM2_SPK_ROBOWARRIOR    EQU     $B405
PGM2_SPK_GORFIAN        EQU     $B426
PGM2_SPK_I_AM           EQU     $B449
PGM2_SPK_PREPARE        EQU     $B465

; -----------------------------------------------------------------------------
; X11 entry point
; -----------------------------------------------------------------------------

X11Entry:
        JP      TranslateSpeechPrimitive

; -----------------------------------------------------------------------------
; German message table
;
; Gorf's resident index routine starts at $C003.  Each record is:
;
;       DB payload_length, payload...
;
; The table contains all 52 program-2 indexes.  Indexes 0 through 48 retain the
; authentic German payloads where the display composition remains compatible.
; Index 49 is program-2 credit text, and indexes 50 and 51 are the program-2
; copyright lines.
; -----------------------------------------------------------------------------

GermanMessageTable:
Message_00_Mission:
        DB      Message_00_Mission_End - $ - 1
        DB      "MISSION"
Message_00_Mission_End:

Message_01_SpielBeendet:
        DB      Message_01_SpielBeendet_End - $ - 1
        DB      "SPIEL BEENDET"
Message_01_SpielBeendet_End:

Message_02_Spieler:
        DB      Message_02_Spieler_End - $ - 1
        DB      "SPIELER"
Message_02_Spieler_End:

Message_03_Two:
        DB      Message_03_Two_End - $ - 1
        DB      "2"
Message_03_Two_End:

Message_04_One:
        DB      Message_04_One_End - $ - 1
        DB      "1"
Message_04_One_End:

Message_05_Spiel:
        DB      Message_05_Spiel_End - $ - 1
        DB      "SPIEL"
Message_05_Spiel_End:

Message_06_Beendet:
        DB      Message_06_Beendet_End - $ - 1
        DB      "BEENDET"
Message_06_Beendet_End:

Message_07_AufDie:
        DB      Message_07_AufDie_End - $ - 1
        DB      "AUF DIE"
Message_07_AufDie_End:

Message_08_Plaetze:
        DB      Message_08_Plaetze_End - $ - 1
        DB      "PLAETZE"
Message_08_Plaetze_End:

Message_09_ZusaetzlicheMuenzen:
        DB      Message_09_ZusaetzlicheMuenzen_End - $ - 1
        DB      "ZUSAETZLICHE MUENZEN"
Message_09_ZusaetzlicheMuenzen_End:

Message_10_ZusaetzlicheMuenzenEin:
        DB      Message_10_ZusaetzlicheMuenzenEin_End - $ - 1
        DB      "ZUSAETZLICHE MUENZEN EIN"
Message_10_ZusaetzlicheMuenzenEin_End:

Message_11_WaehlenSieEinenSpieler:
        DB      Message_11_WaehlenSieEinenSpieler_End - $ - 1
        DB      "WAEHLEN SIE EINEN SPIELER"
Message_11_WaehlenSieEinenSpieler_End:

Message_12_OderWerfenSie:
        DB      Message_12_OderWerfenSie_End - $ - 1
        DB      "ODER WERFEN SIE"
Message_12_OderWerfenSie_End:

Message_13_FuerZweiSpielerOder:
        DB      Message_13_FuerZweiSpielerOder_End - $ - 1
        DB      "FUER ZWEI SPIELER ODER"
Message_13_FuerZweiSpielerOder_End:

Message_14_FuerZusaetzlicheSchiffe:
        DB      Message_14_FuerZusaetzlicheSchiffe_End - $ - 1
        DB      "FUER ZUSAETZLICHE SCHIFFE"
Message_14_FuerZusaetzlicheSchiffe_End:

Message_15_WaehlenSie:
        DB      Message_15_WaehlenSie_End - $ - 1
        DB      "WAEHLEN SIE"
Message_15_WaehlenSie_End:

Message_16_DieGorfRoboter:
        DB      Message_16_DieGorfRoboter_End - $ - 1
        DB      "DIE GORF ROBOTER"
Message_16_DieGorfRoboter_End:

Message_17_GreifenAn:
        DB      Message_17_GreifenAn_End - $ - 1
        DB      "GREIFEN AN"
Message_17_GreifenAn_End:

Message_18_IhreAufgabeIst:
        DB      Message_18_IhreAufgabeIst_End - $ - 1
        DB      "IHRE AUFGABE IST"
Message_18_IhreAufgabeIst_End:

Message_19_DieInvasionAbzuschlagen:
        DB      Message_19_DieInvasionAbzuschlagen_End - $ - 1
        DB      "DIE INVASION ABZUSCHLAGEN"
Message_19_DieInvasionAbzuschlagen_End:

Message_20_UndEinenGegenangriff:
        DB      Message_20_UndEinenGegenangriff_End - $ - 1
        DB      "UND EINEN GEGENANGRIFF"
Message_20_UndEinenGegenangriff_End:

Message_21_Durchzufuehren:
        DB      Message_21_Durchzufuehren_End - $ - 1
        DB      "DURCHZUFUEHREN"
Message_21_Durchzufuehren_End:

Message_22_AufIhremWeg:
        DB      Message_22_AufIhremWeg_End - $ - 1
        DB      "AUF IHREM WEG"
Message_22_AufIhremWeg_End:

Message_23_ZumDramatischenKampfMit:
        DB      Message_23_ZumDramatischenKampfMit_End - $ - 1
        DB      "ZUM DRAMATISCHEN KAMPF MIT"
Message_23_ZumDramatischenKampfMit_End:

Message_24_DemFeindlichenFlagschiff:
        DB      Message_24_DemFeindlichenFlagschiff_End - $ - 1
        DB      "DEM FEINDLICHEN FLAGSCHIFF"
Message_24_DemFeindlichenFlagschiff_End:

Message_25_MuessenSie:
        DB      Message_25_MuessenSie_End - $ - 1
        DB      "MUESSEN SIE"
Message_25_MuessenSie_End:

Message_26_FeindlicheRaumschiffe:
        DB      Message_26_FeindlicheRaumschiffe_End - $ - 1
        DB      "FEINDLICHE RAUMSCHIFFE"
Message_26_FeindlicheRaumschiffe_End:

Message_27_Zerstoeren:
        DB      Message_27_Zerstoeren_End - $ - 1
        DB      "ZERSTOEREN"
Message_27_Zerstoeren_End:

Message_28_DieHoechstergebnisse:
        DB      Message_28_DieHoechstergebnisse_End - $ - 1
        DB      "DIE HOECHSTERGEBNISSE"
Message_28_DieHoechstergebnisse_End:

Message_29_Sind:
        DB      Message_29_Sind_End - $ - 1
        DB      "SIND"
Message_29_Sind_End:

Message_30_ZweiSchiffe:
        DB      Message_30_ZweiSchiffe_End - $ - 1
        DB      "ZWEI SCHIFFE"
Message_30_ZweiSchiffe_End:

Message_31_DreiSchiffe:
        DB      Message_31_DreiSchiffe_End - $ - 1
        DB      "DREI SCHIFFE"
Message_31_DreiSchiffe_End:

Message_32_VierSchiffe:
        DB      Message_32_VierSchiffe_End - $ - 1
        DB      "VIER SCHIFFE"
Message_32_VierSchiffe_End:

Message_33_SechsSchiffe:
        DB      Message_33_SechsSchiffe_End - $ - 1
        DB      "SECHS SCHIFFE"
Message_33_SechsSchiffe_End:

Message_34_AstroBattles:
        DB      Message_34_AstroBattles_End - $ - 1
        DB      "ASTRO BATTLES"
Message_34_AstroBattles_End:

Message_35_Galaxians:
        DB      Message_35_Galaxians_End - $ - 1
        DB      "GALAXIANS"
Message_35_Galaxians_End:

Message_36_AttackFighters:
        DB      Message_36_AttackFighters_End - $ - 1
        DB      "ATTACK FIGHTERS"
Message_36_AttackFighters_End:

Message_37_SpaceWarp:
        DB      Message_37_SpaceWarp_End - $ - 1
        DB      "SPACE WARP"
Message_37_SpaceWarp_End:

Message_38_FlagShip:
        DB      Message_38_FlagShip_End - $ - 1
        DB      "FLAG SHIP"
Message_38_FlagShip_End:

Message_39_EinSpieler:
        DB      Message_39_EinSpieler_End - $ - 1
        DB      "EIN SPIELER"
Message_39_EinSpieler_End:

Message_40_ZweiSpieler:
        DB      Message_40_ZweiSpieler_End - $ - 1
        DB      "ZWEI SPIELER"
Message_40_ZweiSpieler_End:

Message_41_GeldEinwerfen:
        DB      Message_41_GeldEinwerfen_End - $ - 1
        DB      "GELD EINWERFEN"
Message_41_GeldEinwerfen_End:

Message_42_EinOderZweiSpieler:
        DB      Message_42_EinOderZweiSpieler_End - $ - 1
        DB      "EIN ODER ZWEI SPIELER"
Message_42_EinOderZweiSpieler_End:

Message_43_FuerZweiSpieler:
        DB      Message_43_FuerZweiSpieler_End - $ - 1
        DB      "FUER ZWEI SPIELER"
Message_43_FuerZweiSpieler_End:

Message_44_Control:
        DB      Message_44_Control_End - $ - 1
        DB      $09,"1"
Message_44_Control_End:

Message_45_Control:
        DB      Message_45_Control_End - $ - 1
        DB      $0B,$0C,$0A,$0D,$0E
Message_45_Control_End:

Message_46_Control:
        DB      Message_46_Control_End - $ - 1
        DB      $0F,$2A,$0C,$0A,$0E,$2B
Message_46_Control_End:

Message_47_Control:
        DB      Message_47_Control_End - $ - 1
        DB      $0F,$2A
Message_47_Control_End:

Message_48_SameSpieler:
        DB      Message_48_SameSpieler_End - $ - 1
        DB      "SAME SPIELER"
Message_48_SameSpieler_End:

Message_49_KreditSchiffe:
        DB      Message_49_KreditSchiffe_End - $ - 1
        DB      "KREDIT SCHIFFE["
Message_49_KreditSchiffe_End:

Message_50_Copyright:
        DB      Message_50_Copyright_End - $ - 1
        DB      $5C,"1981 MIDWAY MFG CO"
Message_50_Copyright_End:

Message_51_AlleRechteVorbehalten:
        DB      Message_51_AlleRechteVorbehalten_End - $ - 1
        DB      "ALLE RECHTE VORBEHALTEN"
Message_51_AlleRechteVorbehalten_End:

; -----------------------------------------------------------------------------
; German SC-01 speech primitives
;
; Labels identify the program-2 English primitive whose address selects each
; translation.  The payload bytes are kept literal so inflection bits remain
; visible and the ROM can be reproduced exactly.
; -----------------------------------------------------------------------------

GermanSpeech_Gorf:
        DB      GermanSpeech_Gorf_End - $ - 1
        DB      $3E,$4B,$1B,$1B,$03,$0E,$0B,$0D,$03,$1E,$01,$2B
        DB      $03,$1C,$04,$75,$6B,$5D,$4A,$11,$31,$03,$5B,$41
        DB      $40,$6B,$11,$01,$2B,$3E
GermanSpeech_Gorf_End:

GermanSpeech_Long:
        DB      GermanSpeech_Long_End - $ - 1
        DB      $3E,$18,$55,$54,$03,$18,$7C,$4E,$08,$03,$1C,$04
        DB      $35,$2B,$1D,$3E
GermanSpeech_Long_End:

GermanSpeech_Push:
        DB      GermanSpeech_Push_End - $ - 1
        DB      $3E,$11,$65,$7C,$18,$2B,$19,$03,$0D,$30,$25,$1D
        DB      $03,$0E,$01,$2A,$45,$45,$2A,$0A,$1C,$01,$0D,$3E
GermanSpeech_Push_End:

GermanSpeech_Robots:
        DB      GermanSpeech_Robots_End - $ - 1
        DB      $3E,$1C,$04,$75,$6B,$1D,$0A,$11,$3A,$2B,$75,$4E
        DB      $08,$2A,$3A,$03,$55,$0D,$1C,$2B,$0B,$1D,$03,$55
        DB      $0D,$1C,$2B,$0B,$1D,$3E
GermanSpeech_Robots_End:

GermanSpeech_Doom:
        DB      GermanSpeech_Doom_End - $ - 1
        DB      $3E,$1E,$28,$03,$0F,$36,$2B,$1F,$2A,$03,$08,$00
        DB      $09,$0D,$03,$1C,$44,$75,$6B,$1D,$0A,$11,$01,$1F
        DB      $03,$11,$4A,$1B,$19,$12,$08,$23,$18,$03,$41,$6B
        DB      $18,$08,$0A,$22,$1E,$01,$0D,$3E,$3E
GermanSpeech_Doom_End:

GermanSpeech_Survival:
        DB      GermanSpeech_Survival_End - $ - 1
        DB      $3E,$37,$37,$36,$0D,$0C,$36,$76,$76,$1C,$18,$0B
        DB      $1B,$1B,$03,$03,$2A,$12,$28,$03,$03,$77,$0E,$2B
        DB      $18,$46,$0E,$01,$0D,$3E,$3E
GermanSpeech_Survival_End:

GermanSpeech_Gorfian:
        DB      GermanSpeech_Gorfian_End - $ - 1
        DB      $3E,$0C,$08,$40,$4D,$08,$03,$1C,$44,$75,$6B,$1D
        DB      $0A,$11,$00,$0D,$03,$6B,$75,$4E,$48,$2A,$2B,$03
        DB      $03,$52,$4B,$0D,$2A,$03,$37,$36,$0D,$11,$58,$48
        DB      $48,$5C,$0E,$08,$2B,$3E
GermanSpeech_Gorfian_End:

GermanSpeech_IAm:
        DB      GermanSpeech_IAm_End - $ - 1
        DB      $3E,$4B,$1B,$1B,$03,$0E,$0B,$0D,$03,$1E,$08,$08
        DB      $1F,$03,$1C,$44,$75,$6B,$1D,$0A,$11,$31,$03,$0E
        DB      $01,$4F,$77,$76,$1F,$2A,$12,$48,$41,$0D,$3E
GermanSpeech_IAm_End:

GermanSpeech_Prisoner:
        DB      GermanSpeech_Prisoner_End - $ - 1
        DB      $3E,$1C,$44,$75,$6B,$1F,$3E,$3E,$0C,$08,$08,$1B
        DB      $1B,$19,$2A,$03,$59,$48,$49,$0D,$08,$03,$1C,$01
        DB      $5D,$48,$14,$00,$0D,$00,$0D,$3E
GermanSpeech_Prisoner_End:

GermanSpeech_BadMove:
        DB      GermanSpeech_BadMove_End - $ - 1
        DB      $3E,$11,$58,$41,$1B,$1B,$2A,$2B,$03,$03,$2A,$12
        DB      $37,$37,$19,$3E
GermanSpeech_BadMove_End:

GermanSpeech_GotYou:
        DB      GermanSpeech_GotYou_End - $ - 1
        DB      $3E,$1C,$04,$35,$2B,$1D,$03,$1B,$15,$2A,$03,$6A
        DB      $52,$77,$5C,$41,$11,$18,$08,$1C,$02,$0D,$3E
GermanSpeech_GotYou_End:

GermanSpeech_Enemy:
        DB      GermanSpeech_Enemy_End - $ - 1
        DB      $3E,$4F,$7C,$1E,$2B,$03,$08,$09,$0D,$03,$5D,$48
        DB      $49,$0D,$1E,$18,$09,$1B,$1B,$00,$1F,$03,$51,$4B
        DB      $5D,$03,$03,$2A,$52,$40,$6B,$11,$0C,$01,$2A,$2B
        DB      $2A,$3E
GermanSpeech_Enemy_End:

GermanSpeech_Escape:
        DB      GermanSpeech_Escape_End - $ - 1
        DB      $3E,$5E,$68,$03,$19,$08,$08,$0D,$1F,$2A,$03,$4C
        DB      $48,$49,$0D,$00,$0D,$03,$1C,$44,$75,$6B,$1D,$0A
        DB      $11,$00,$0D,$03,$6B,$75,$4E,$48,$2A,$00,$0D,$03
        DB      $0D,$0B,$1B,$1B,$2A,$03,$01,$0D,$2A,$5D,$58,$7C
        DB      $00,$0D,$3E
GermanSpeech_Escape_End:

GermanSpeech_TooBad:
        DB      GermanSpeech_TooBad_End - $ - 1
        DB      $3E,$65,$42,$5B,$5B,$03,$5C,$71,$1B,$08,$08,$0E
        DB      $2A,$3E
GermanSpeech_TooBad_End:

GermanSpeech_Try:
        DB      GermanSpeech_Try_End - $ - 1
        DB      $3E,$1D,$00,$2B,$52,$77,$1B,$1B,$1F,$03,$4D,$70
        DB      $1B,$1B,$03,$0C,$08,$08,$18,$3E,$0B,$1B,$1B,$03
        DB      $1D,$00,$2B,$11,$58,$49,$54,$48,$03,$4C,$76,$76
        DB      $4D,$2A,$12,$00,$0D,$3E
GermanSpeech_Try_End:

GermanSpeech_Bite:
        DB      GermanSpeech_Bite_End - $ - 1
        DB      $3E,$4E,$48,$49,$22,$1F,$03,$49,$4D,$1F,$03,$1C
        DB      $04,$2B,$08,$08,$1F,$3E,$3E
GermanSpeech_Bite_End:

GermanSpeech_Conquer:
        DB      GermanSpeech_Conquer_End - $ - 1
        DB      $3E,$1E,$2C,$1C,$44,$75,$6B,$1F,$03,$1B,$08,$08
        DB      $0E,$00,$0D,$4F,$7C,$1E,$2B,$03,$08,$09,$0D,$08
        DB      $0D,$75,$22,$08,$03,$1C,$08,$58,$48,$48,$19,$1F
        DB      $3C,$03,$71,$6B,$66,$0E,$00,$2B,$2A,$3E
GermanSpeech_Conquer_End:

GermanSpeech_Hail:
        DB      GermanSpeech_Hail_End - $ - 1
        DB      $3E,$4F,$4A,$2B,$03,$03,$03,$2B,$28,$1D,$01,$0D
        DB      $03,$1E,$08,$08,$1F,$03,$03,$1C,$44,$75,$6B,$1D
        DB      $0A,$11,$31,$6B,$48,$62,$1B,$1B,$03,$03,$30,$36
        DB      $36,$1F,$3E
GermanSpeech_Hail_End:

GermanSpeech_For_A985:
        DB      GermanSpeech_For_A985_End - $ - 1
        DB      $3E,$3E,$4D,$45,$62,$1B,$1B,$1F,$2A,$02,$1F,$0C
        DB      $08,$08,$18,$03,$0F,$21,$2B,$1F,$2A,$03,$5E,$68
        DB      $1E,$0A,$09,$2B,$1E,$3C,$03,$2A,$52,$46,$45,$0D
        DB      $23,$03,$30,$36,$36,$1F,$0E,$08,$09,$1F,$01,$0D
        DB      $3E
GermanSpeech_For_A985_End:

GermanSpeech_Nice:
        DB      GermanSpeech_Nice_End - $ - 1
        DB      $3E,$3E,$5D,$56,$18,$18,$03,$2A,$2B,$01,$1D,$00
        DB      $2B,$3E
GermanSpeech_Nice_End:

GermanSpeech_InsertCoin:
        DB      GermanSpeech_InsertCoin_End - $ - 1
        DB      $3E,$1C,$45,$40,$18,$2A,$03,$48,$49,$0D,$0F,$00
        DB      $2B,$1D,$00,$0D,$3E
GermanSpeech_InsertCoin_End:

GermanSpeech_RoboWarrior:
        DB      GermanSpeech_RoboWarrior_End - $ - 1
        DB      $3E,$6B,$75,$4E,$48,$2A,$2B,$03,$48,$48,$0D,$1C
        DB      $2B,$08,$09,$1D,$00,$2B,$03,$03,$1D,$01,$2B,$1D
        DB      $75,$58,$44,$5B,$1C,$2A,$03,$76,$4D,$2A,$03,$5D
        DB      $41,$2B,$0D,$0B,$1B,$1B,$2A,$02,$2A,$03,$03,$1E
        DB      $06,$05,$0D,$03
GermanSpeech_RoboWarrior_End:

GermanSpeech_Some:
        DB      GermanSpeech_Some_End - $ - 1
        DB      $3E,$1E,$28,$03,$0E,$0A,$1F,$2A,$3E,$08,$09,$22
        DB      $0D,$31,$03,$5C,$48,$48,$58,$48,$63,$19,$2A,$09
        DB      $11,$00,$31,$03,$0D,$3C,$2A,$23,$3E
GermanSpeech_Some_End:

GermanSpeech_Betcha:
        DB      GermanSpeech_Betcha_End - $ - 1
        DB      $3E,$1E,$08,$0A,$0D,$03,$18,$41,$6A,$52,$6A,$41
        DB      $5F,$03,$51,$6A,$76,$76,$0D,$2A,$18,$08,$09,$0D
        DB      $03,$11,$18,$05,$05,$04,$1B,$1C,$2A,$3E
GermanSpeech_Betcha_End:

GermanSpeech_For_A9A8:
        DB      GermanSpeech_For_A9A8_End - $ - 1
        DB      $3E,$3E,$08,$08,$0E,$00,$2B,$03,$22,$41,$6A,$52
        DB      $2A,$03,$1C,$06,$21,$1F,$2A,$03,$1E,$28,$03,$0B
        DB      $0D,$03,$1E,$3C,$03,$1C,$01,$51,$4B,$5B,$5B,$2A
        DB      $31,$03,$1E,$01,$2B,$03,$1C,$04,$35,$2B,$1D,$1F
        DB      $03,$03,$08,$08,$09,$0D,$3E
GermanSpeech_For_A9A8_End:

GermanSpeech_Prepare:
        DB      GermanSpeech_Prepare_End - $ - 1
        DB      $3E,$0E,$01,$6B,$48,$62,$2A,$08,$03,$5E,$4B,$1B
        DB      $1B,$03,$30,$36,$1D,$03,$5E,$48,$49,$0D,$08,$03
        DB      $1D,$00,$2B,$4D,$4B,$1B,$1B,$2A,$37,$14,$03,$1D
        DB      $35,$2B,$3E,$3E
GermanSpeech_Prepare_End:

GermanSpeech_For_A9C1:
        DB      GermanSpeech_For_A9C1_End - $ - 1
        DB      $3E,$3E,$5D,$76,$76,$2B,$03,$1E,$08,$08,$1F,$03
        DB      $08,$08,$0E,$51,$7C,$1F,$00,$0D,$03,$0C,$48,$49
        DB      $0D,$00,$1F,$03,$1D,$18,$08,$1C,$51,$49,$4A,$1D
        DB      $00,$1F,$3E
GermanSpeech_For_A9C1_End:

GermanSpeech_Promote:
        DB      GermanSpeech_Promote_End - $ - 1
        DB      $3E,$12,$3C,$03,$0F,$40,$6B,$5E,$00,$0D,$03,$40
        DB      $6B,$0D,$08,$08,$0D,$2A,$03,$2A,$12,$28,$0C,$03
GermanSpeech_Promote_End:

GermanSpeech_Cadet:
        DB      GermanSpeech_Cadet_End - $ - 1
        DB      $6B,$48,$71,$37,$0C,$0C,$03,$59,$48,$48,$1E,$02
        DB      $2A,$3E
GermanSpeech_Cadet_End:

GermanSpeech_Captain:
        DB      GermanSpeech_Captain_End - $ - 1
        DB      $6B,$48,$71,$37,$0C,$0C,$03,$5B,$48,$56,$25,$03
        DB      $2A,$0C,$08,$08,$0D,$0D,$3E
GermanSpeech_Captain_End:

GermanSpeech_Colonel:
        DB      GermanSpeech_Colonel_End - $ - 1
        DB      $6B,$48,$71,$37,$0C,$0C,$03,$74,$74,$0E,$01,$2B
        DB      $1F,$2A,$3E
GermanSpeech_Colonel_End:

GermanSpeech_General:
        DB      GermanSpeech_General_End - $ - 1
        DB      $6B,$48,$71,$37,$0C,$0C,$03,$5C,$40,$4D,$40,$2B
        DB      $08,$08,$18,$3E
GermanSpeech_General_End:

GermanSpeech_Warrior:
        DB      GermanSpeech_Warrior_End - $ - 1
        DB      $6B,$48,$71,$37,$0C,$0C,$03,$4C,$48,$48,$2B,$11
        DB      $08,$18,$3E
GermanSpeech_Warrior_End:

GermanSpeech_Avenger:
        DB      GermanSpeech_Avenger_End - $ - 1
        DB      $2B,$6F,$1B,$1B,$2B,$03,$03,$1E,$02,$1F,$03,$0F
        DB      $41,$58,$6A,$6B,$08,$23,$37,$0C,$1F,$3E,$3E
GermanSpeech_Avenger_End:

; -----------------------------------------------------------------------------
; Parallel speech translation tables
;
; GermanSpeechTable[n] is selected when Pgm2SpeechTable[n] matches the
; primitive address supplied in DE.  Both tables contain 36 little-endian
; addresses and must remain in the same order.
; -----------------------------------------------------------------------------

GermanSpeechTable:
        DW      GermanSpeech_InsertCoin
        DW      GermanSpeech_Gorf
        DW      $0000                   ; Suppress PGM2_SPK_SPACE
        DW      GermanSpeech_Conquer
        DW      GermanSpeech_Try
        DW      GermanSpeech_Long
        DW      GermanSpeech_Robots
        DW      GermanSpeech_BadMove
        DW      PGM2_SPK_HAHA           ; The laugh is language-neutral
        DW      GermanSpeech_Escape
        DW      GermanSpeech_GotYou
        DW      GermanSpeech_Nice
        DW      GermanSpeech_TooBad
        DW      GermanSpeech_Prisoner
        DW      GermanSpeech_Cadet
        DW      GermanSpeech_Captain
        DW      GermanSpeech_Colonel
        DW      GermanSpeech_General
        DW      GermanSpeech_Warrior
        DW      GermanSpeech_Avenger
        DW      GermanSpeech_Promote
        DW      GermanSpeech_Some
        DW      GermanSpeech_Bite
        DW      GermanSpeech_Hail
        DW      GermanSpeech_Enemy
        DW      GermanSpeech_Betcha
        DW      GermanSpeech_For_A985
        DW      GermanSpeech_For_A9A8
        DW      GermanSpeech_For_A9C1
        DW      GermanSpeech_Push
        DW      GermanSpeech_Doom
        DW      GermanSpeech_Survival
        DW      GermanSpeech_RoboWarrior
        DW      GermanSpeech_Gorfian
        DW      GermanSpeech_IAm
        DW      GermanSpeech_Prepare
GermanSpeechTableEnd:

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
        LD      HL,GermanSpeechTable
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
        JP      PGM2_SPEECH_QUEUE

TranslationSuppressed:
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

; The physical X11 device is a 4 KiB ROM.  Unused bytes read as $FF.  Its final
; 14 bytes contain the original DNA identification trailer.
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
