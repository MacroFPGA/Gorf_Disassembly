; FRENCH_X11.asm
; French language expansion ROM for Gorf program 2
; This source targets program 2 only; it does not build a program-1 variant.
;
; ROM map:  $C000-$CFFF (X11 socket, 4 KB)
;
; Historical source:
;    Program-1 French X11: french_gorf.x11
;   CRC-32: 759D7F66
;   SHA-1:  339B719FC1FFE3C2BE49FBD5CF562D06134ABADC
;
; The historical filename is intentionally unusual.  This repository normalizes
; the project artifact to FRENCH_X11.asm -> roms/french.x11.  For stock MAME
; compatibility, build.sh/build.bat temporarily alias that image to
; french_gorf.x11 only while creating gorfpgm1f.zip.
;
; MAME-tested Program-2 image produced by this source lineage:
;   CRC-32: C6F7E746
;   SHA-1:  627346AB5BE396F54B55B90E2AF59FFBB75B121F
;
; The Program-1 French and German sets use byte-identical X1-X8 CPU ROMs.
; Their language behavior is therefore isolated to X11.  The  French
; image is an executable/data hybrid with this verified layout:
;
;   $C000-$C002  JP $C737
;   $C003-$C2FF  54 length-prefixed Program-1 display/control records
;   $C300-$C6A6  34 local French SC-01 records
;   $C6A7-$C6EE  36 translation targets
;   $C6EF-$C736  36 sorted Program-1 English speech keys
;   $C737-$C76E  36-entry predecessor-search translator
;   $C76F-$CFF2  Erased $FF padding
;   $CFF3-$CFFF  Shared GORF/DNA identification record
;
; The French translator independently confirms the same 36-entry predecessor
; search architecture found in the  German Program-1 X11.  Its final
; dispatcher is Program 1's speech queue entry at $10CA.
;
; This Program-2 adaptation preserves the  French SC-01 payloads and
; the original 36-entry search behavior while replacing the resident addresses,
; message ordering, speech queue destination, and foreign-mode return path that
; changed between Gorf Program 1 and Program 2.
;
; Interface used by Gorf program 2:
;
;   $C000  JP TranslateSpeechPrimitive
;   $C003  Length-prefixed French message table
;   $CC00  JP PROGRAM2_FOREIGN_RESUME
;
; The resident program jumps to $C000 with DE holding the address of an English
; speech primitive.  TranslateSpeechPrimitive searches the 36 Program-2 keys,
; selects the parallel French record, waits for one free resident queue slot,
; then dispatches through Program 2's speech queue routine at $10B8.  A null
; translation suppresses that primitive.
;
; Message and speech records both use a one-byte payload length followed by
; that many data bytes.  SC-01 phoneme bytes are copied byte-for-byte from the
;  Program-1 French ROM, including the inflection bits in bits 7 and 6.
;
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

; Program-2 speech primitive addresses.  The first 26 are in the resident
; speech block.  The next three form the upper-ROM flagship sequence.  $B3BE is
; the coin/start prompt; $B3D4-$B465 are the randomized game-start records.
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
PGM2_SPK_FLAGSHIP_INTRO           EQU     $A985        ; "Next time will be harder, but for now"
PGM2_SPK_GORFIAN_CHRONICLES           EQU     $A9A8        ; "In the Gorfian chronicles"
PGM2_SPK_FLAGSHIP_HIT           EQU     $A9C1        ; "For hitting my flagship"
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
; French message table
;
; Program 2 indexes 52 length-prefixed records beginning at $C003.  Most French
; wording comes directly from the  Program-1 ROM.  Where Program 2
; changed its English record boundaries or introduced new records, the French
; text is recomposed from the historical wording or translated specifically for
; the Program-2 screen.
;
; Notable adaptations:
;   - indexes 3 and 4 drop the Program-1 "NO " prefix because Program 2 supplies
;     the player-number context separately;
;   - indexes 9 through 15 are recomposed for Program 2's player/credit prompts;
;   - indexes 42 through 47 are Program-2 structural records and must remain
;     byte-for-byte identical to the resident English table;
;   - indexes 49 through 51 are Program-2-only credit/copyright records.
;
; The  Program-1 French table contains 54 records, not 52.  Its
; structural/control records also occupy different indexes from Program 2.
; After Program-1 record 48 ("LE MEME JOUEUR"), five additional records appear
; before the $C300 speech block:
;
;   49  "PARTICIPANTS"
;   50  "POUR UN JEU A 2"
;   51  "OU"
;   52  "AVEC DES VAISSEAUX"
;   53  "SUPPLEMENTAIRES"
;
; Those records are provenance for the recomposed Program-2 prompts; they are
; not appended here because Program 2 indexes exactly 52 positions.
; -----------------------------------------------------------------------------

FrenchMessageTable:
Message_00_Mission:
        DB      Message_00_Mission_End - $ - 1
        DB      "MISSION["
Message_00_Mission_End:

Message_01_FinDuJeu:
        DB      Message_01_FinDuJeu_End - $ - 1
        DB      "FIN DU JEU"
Message_01_FinDuJeu_End:

Message_02_Joueur:
        DB      Message_02_Joueur_End - $ - 1
        DB      "JOUEUR"
Message_02_Joueur_End:

Message_03_Two:
        DB      Message_03_Two_End - $ - 1
        DB      "2"
Message_03_Two_End:

Message_04_One:
        DB      Message_04_One_End - $ - 1
        DB      "1"
Message_04_One_End:

Message_05_Fin:
        DB      Message_05_Fin_End - $ - 1
        DB      "FIN"
Message_05_Fin_End:

Message_06_DuJeu:
        DB      Message_06_DuJeu_End - $ - 1
        DB      "DU JEU"
Message_06_DuJeu_End:

Message_07_TenezVous:
        DB      Message_07_TenezVous_End - $ - 1
        DB      "TENEZ VOUS"
Message_07_TenezVous_End:

Message_08_Pret:
        DB      Message_08_Pret_End - $ - 1
        DB      "PRET"
Message_08_Pret_End:

Message_09_JetonSupplementaire:
        DB      Message_09_JetonSupplementaire_End - $ - 1
        DB      "DEPOSER JETON SUPPLEMENTAIRE"
Message_09_JetonSupplementaire_End:

Message_10_SelectionnerUnJoueur:
        DB      Message_10_SelectionnerUnJoueur_End - $ - 1
        DB      "SELECTIONNER 1 JOUEUR"
Message_10_SelectionnerUnJoueur_End:

Message_11_Ou:
        DB      Message_11_Ou_End - $ - 1
        DB      "OU"
Message_11_Ou_End:

Message_12_UnOuDeuxParticipants:
        DB      Message_12_UnOuDeuxParticipants_End - $ - 1
        DB      "A 1 OU 2 PARTICIPANTS"
Message_12_UnOuDeuxParticipants_End:

Message_13_PourUnJeuADeux:
        DB      Message_13_PourUnJeuADeux_End - $ - 1
        DB      "POUR UN JEU A 2"
Message_13_PourUnJeuADeux_End:

Message_14_OuPourVaisseauxEnPlus:
        DB      Message_14_OuPourVaisseauxEnPlus_End - $ - 1
        DB      "OU POUR VAISSEAUX EN PLUS"
Message_14_OuPourVaisseauxEnPlus_End:

Message_15_AvecVaisseauxEnPlus:
        DB      Message_15_AvecVaisseauxEnPlus_End - $ - 1
        DB      "AVEC VAISSEAUX EN PLUS"
Message_15_AvecVaisseauxEnPlus_End:

Message_16_LEmpire:
        DB      Message_16_LEmpire_End - $ - 1
        DB      "L EMPIRE"
Message_16_LEmpire_End:

Message_17_DemonsRobotsGorfiens:
        DB      Message_17_DemonsRobotsGorfiens_End - $ - 1
        DB      "DES DEMONS ROBOTS GORFIENS"
Message_17_DemonsRobotsGorfiens_End:

Message_18_AAttaque:
        DB      Message_18_AAttaque_End - $ - 1
        DB      "A ATTAQUE"
Message_18_AAttaque_End:

Message_19_VotreDevoirEstDe:
        DB      Message_19_VotreDevoirEstDe_End - $ - 1
        DB      "VOTRE DEVOIR EST DE"
Message_19_VotreDevoirEstDe_End:

Message_20_RepousserInvasion:
        DB      Message_20_RepousserInvasion_End - $ - 1
        DB      "REPOUSSER L INVASION ET DE"
Message_20_RepousserInvasion_End:

Message_21_LancerContreAttaque:
        DB      Message_21_LancerContreAttaque_End - $ - 1
        DB      "LANCER UNE CONTRE ATTAQUE"
Message_21_LancerContreAttaque_End:

Message_22_VousDevrez:
        DB      Message_22_VousDevrez_End - $ - 1
        DB      "VOUS DEVREZ"
Message_22_VousDevrez_End:

Message_23_MesurerDifferents:
        DB      Message_23_MesurerDifferents_End - $ - 1
        DB      "VOUS MESURER A DIFFERENTS"
Message_23_MesurerDifferents_End:

Message_24_VaisseauxEnnemis:
        DB      Message_24_VaisseauxEnnemis_End - $ - 1
        DB      "VAISSEAUX ENNEMIS SUR VOTRE"
Message_24_VaisseauxEnnemis_End:

Message_25_RouteVersSupreme:
        DB      Message_25_RouteVersSupreme_End - $ - 1
        DB      "ROUTE VERS LA SUPREME"
Message_25_RouteVersSupreme_End:

Message_26_ConfrontationAvec:
        DB      Message_26_ConfrontationAvec_End - $ - 1
        DB      "CONFRONTATION AVEC"
Message_26_ConfrontationAvec_End:

Message_27_VaisseauAmiralEnnemi:
        DB      Message_27_VaisseauAmiralEnnemi_End - $ - 1
        DB      "LE VAISSEAU AMIRAL ENNEMI"
Message_27_VaisseauAmiralEnnemi_End:

Message_28_HautsResultats:
        DB      Message_28_HautsResultats_End - $ - 1
        DB      "LES HAUTS RESULTATS"
Message_28_HautsResultats_End:

Message_29_Sont:
        DB      Message_29_Sont_End - $ - 1
        DB      "SONT["
Message_29_Sont_End:

Message_30_DeuxVaisseaux:
        DB      Message_30_DeuxVaisseaux_End - $ - 1
        DB      "2 VAISSEAUX"
Message_30_DeuxVaisseaux_End:

Message_31_TroisVaisseaux:
        DB      Message_31_TroisVaisseaux_End - $ - 1
        DB      "3 VAISSEAUX"
Message_31_TroisVaisseaux_End:

Message_32_QuatreVaisseaux:
        DB      Message_32_QuatreVaisseaux_End - $ - 1
        DB      "4 VAISSEAUX"
Message_32_QuatreVaisseaux_End:

Message_33_SixVaisseaux:
        DB      Message_33_SixVaisseaux_End - $ - 1
        DB      "6 VAISSEAUX"
Message_33_SixVaisseaux_End:

Message_34_BataillesAstrales:
        DB      Message_34_BataillesAstrales_End - $ - 1
        DB      "BATAILLES ASTRALES"
Message_34_BataillesAstrales_End:

Message_35_Galaxiens:
        DB      Message_35_Galaxiens_End - $ - 1
        DB      "GALAXIENS"
Message_35_Galaxiens_End:

Message_36_AttaqueLaser:
        DB      Message_36_AttaqueLaser_End - $ - 1
        DB      "ATTAQUE LASER"
Message_36_AttaqueLaser_End:

Message_37_CreatureSpatiale:
        DB      Message_37_CreatureSpatiale_End - $ - 1
        DB      "CREATURE SPATIALE"
Message_37_CreatureSpatiale_End:

Message_38_VaisseauAmiral:
        DB      Message_38_VaisseauAmiral_End - $ - 1
        DB      "VAISSEAU AMIRAL"
Message_38_VaisseauAmiral_End:

Message_39_UnJoueur:
        DB      Message_39_UnJoueur_End - $ - 1
        DB      "1 JOUEUR"
Message_39_UnJoueur_End:

Message_40_DeuxJoueurs:
        DB      Message_40_DeuxJoueurs_End - $ - 1
        DB      "2 JOUEURS"
Message_40_DeuxJoueurs_End:

Message_41_DeposerJeton:
        DB      Message_41_DeposerJeton_End - $ - 1
        DB      "DEPOSER JETON"
Message_41_DeposerJeton_End:

Message_42_Blank:
        DB      Message_42_Blank_End - $ - 1
        DB      " "
Message_42_Blank_End:

Message_43_Blank:
        DB      Message_43_Blank_End - $ - 1
        DB      " "
Message_43_Blank_End:

Message_44_Control:
        DB      Message_44_Control_End - $ - 1
        DB      $09
Message_44_Control_End:

Message_45_Control:
        DB      Message_45_Control_End - $ - 1
        DB      $0A,$0B,$09,$0D,$0E
Message_45_Control_End:

Message_46_Control:
        DB      Message_46_Control_End - $ - 1
        DB      $0C,$0B,$09,$0D,$0F
Message_46_Control_End:

Message_47_Control:
        DB      Message_47_Control_End - $ - 1
        DB      $0C
Message_47_Control_End:

Message_48_LeMemeJoueur:
        DB      Message_48_LeMemeJoueur_End - $ - 1
        DB      "LE MEME JOUEUR"
Message_48_LeMemeJoueur_End:

Message_49_CreditVaisseaux:
        DB      Message_49_CreditVaisseaux_End - $ - 1
        DB      "CREDIT VAISSEAUX["
Message_49_CreditVaisseaux_End:

Message_50_Copyright:
        DB      Message_50_Copyright_End - $ - 1
        DB      $5C,"1981 MIDWAY MFG CO"
Message_50_Copyright_End:

Message_51_TousDroitsReserves:
        DB      Message_51_TousDroitsReserves_End - $ - 1
        DB      "TOUS DROITS RESERVES"
Message_51_TousDroitsReserves_End:

; -----------------------------------------------------------------------------
;  French SC-01 speech primitives
;
; The 34 local records below are copied byte-for-byte from french_gorf.x11.
; Their physical order follows the original French ROM, which differs from the
; German ROM: French stores Insert Coin at $C32B and Push a Player Button at
; $C52C.  Across these records, all 901 encoded payload bytes are preserved.
;
; "Working French transcription" comments are documentary reconstructions from
; the SC-01 data and known selector semantics.  They are not bytes stored in the
; ROM and should not override the encoded record if later listening suggests a
; wording correction.
; -----------------------------------------------------------------------------

; Program-1 source $C300, PGM1 key $1180, PGM2 key $116D
; English selector meaning: I am the Gorfian Empire
; Working French transcription: Je suis l'empire gorfien.
FrenchSpeech_Gorf:
        DB      FrenchSpeech_Gorf_End - $ - 1
        DB      $3E,$1A,$1A,$36,$36,$03,$1F,$37,$3C,$18,$30,$30
        DB      $25,$62,$49,$6B,$5C,$04,$34,$2B,$1D,$29,$2F,$3E
        DB      $3E
FrenchSpeech_Gorf_End:

; Program-1 source $C31A, PGM1 key $11DA, PGM2 key $11C7
; English selector meaning: Long live Gorf
; Working French transcription: Longue vie, Gorf.
FrenchSpeech_Long:
        DB      FrenchSpeech_Long_End - $ - 1
        DB      $3E,$18,$26,$1C,$0F,$4F,$7C,$43,$5C,$44,$74,$34
        DB      $2B,$1D,$1D,$3E
FrenchSpeech_Long_End:

; Program-1 source $C32B, PGM1 key $1170, PGM2 key $115D
; English selector meaning: Insert coin
; Working French transcription: Déposez jeton.
FrenchSpeech_InsertCoin:
        DB      FrenchSpeech_InsertCoin_End - $ - 1
        DB      $3E,$1E,$00,$0A,$03,$25,$26,$12,$00,$3E,$3E,$3B
        DB      $3E,$3E,$1A,$1A,$3B,$2A,$26,$3E
FrenchSpeech_InsertCoin_End:

; Program-1 source $C340, PGM1 key $11EA, PGM2 key $11D7
; English selector meaning: Gorfian robots, attack! Attack!
; Working French transcription: Robots gorfiens, attaque ! Attaque !
FrenchSpeech_Robots:
        DB      FrenchSpeech_Robots_End - $ - 1
        DB      $3E,$3A,$35,$0E,$74,$1C,$04,$34,$2B,$1D,$29,$2F
        DB      $3E,$2F,$2A,$2F,$19,$05,$3E,$3E,$2F,$2A,$2F,$19
        DB      $05,$3E
FrenchSpeech_Robots_End:

; Program-1 source $C35B, PGM1 key $B342, PGM2 key $B3D4
; English selector meaning: You will meet a Gorfian doom
; Working French transcription: Vous connaîtrez une fin gorfienne.
FrenchSpeech_Doom:
        DB      FrenchSpeech_Doom_End - $ - 1
        DB      $3E,$0F,$37,$03,$19,$34,$0D,$0D,$0A,$2A,$2B,$0A
        DB      $03,$22,$0D,$03,$1D,$6F,$03,$1C,$04,$31,$34,$34
        DB      $2B,$1D,$22,$2F,$0D,$0D,$3E,$3E
FrenchSpeech_Doom_End:

; Program-1 source $C37C, PGM1 key $B35D, PGM2 key $B3EF
; English selector meaning: Survival is impossible
; Working French transcription: Toute survie est hors de question.
FrenchSpeech_Survival:
        DB      FrenchSpeech_Survival_End - $ - 1
        DB      $3E,$2A,$37,$2A,$03,$1F,$22,$2B,$0F,$69,$69,$03
        DB      $0A,$03,$1B,$35,$6B,$6B,$03,$1E,$00,$03,$19,$0A
        DB      $1F,$2A,$62,$75,$03,$3E
FrenchSpeech_Survival_End:

; Program-1 source $C39B, PGM1 key $B394, PGM2 key $B426
; English selector meaning: My Gorfian robots are unbeatable
; Working French transcription: Mes robots gorfiens sont imbattables.
FrenchSpeech_Gorfian:
        DB      FrenchSpeech_Gorfian_End - $ - 1
        DB      $3E,$0C,$0A,$03,$0F,$2B,$34,$0E,$34,$03,$1C,$04
        DB      $34,$34,$2B,$1D,$22,$2F,$03,$1F,$26,$03,$6F,$4E
        DB      $48,$6A,$15,$0E,$18,$00,$3E,$3E
FrenchSpeech_Gorfian_End:

; Program-1 source $C3BC, PGM1 key $B3B7, PGM2 key $B449
; English selector meaning: I am a Gorfian consciousness
; Working French transcription: Je suis la conscience gorfienne.
FrenchSpeech_IAm:
        DB      FrenchSpeech_IAm_End - $ - 1
        DB      $3E,$1A,$00,$03,$1F,$37,$3C,$03,$18,$08,$03,$03
        DB      $19,$35,$1F,$22,$15,$13,$1F,$03,$1C,$04,$34,$34
        DB      $2B,$1D,$22,$2F,$0D,$0D,$3E
FrenchSpeech_IAm_End:

; Program-1 source $C3DC, PGM1 key $125E, PGM2 key $124B
; English selector meaning: Gorfians take no prisoners
; Working French transcription: Les Gorfiens ne font pas de prisonniers.
FrenchSpeech_Prisoner:
        DB      FrenchSpeech_Prisoner_End - $ - 1
        DB      $3E,$1C,$04,$34,$34,$2B,$1D,$62,$6F,$3E,$3E,$0D
        DB      $00,$03,$1D,$0A,$2A,$2A,$03,$65,$55,$03,$1E,$00
        DB      $03,$25,$2B,$22,$12,$34,$0D,$22,$0A,$3E
FrenchSpeech_Prisoner_End:

; Program-1 source $C3FF, PGM1 key $1209, PGM2 key $11F6
; English selector meaning: Bad move
; Working French transcription: Mauvais mouvement.
FrenchSpeech_BadMove:
        DB      FrenchSpeech_BadMove_End - $ - 1
        DB      $3E,$0C,$35,$0F,$2F,$03,$0C,$37,$0F,$0C,$15,$3E
FrenchSpeech_BadMove_End:

; Program-1 source $C40C, PGM1 key $1241, PGM2 key $122E
; English selector meaning: Got you
; Working French transcription: Je vous ai eu.
FrenchSpeech_GotYou:
        DB      FrenchSpeech_GotYou_End - $ - 1
        DB      $3E,$1A,$00,$03,$03,$0F,$37,$03,$03,$12,$0A,$03
        DB      $03,$62,$3E,$3E
FrenchSpeech_GotYou_End:

; Program-1 source $C41D, PGM1 key $130F, PGM2 key $12FC
; English selector meaning: Another enemy ship destroyed
; Working French transcription: Un autre vaisseau ennemi détruit.
FrenchSpeech_Enemy:
        DB      FrenchSpeech_Enemy_End - $ - 1
        DB      $3E,$3B,$03,$75,$2A,$2B,$00,$03,$0F,$0A,$1F,$34
        DB      $34,$03,$0A,$0D,$0C,$22,$03,$5E,$0A,$2A,$6B,$77
        DB      $62,$3E
FrenchSpeech_Enemy_End:

; Program-1 source $C438, PGM1 key $121D, PGM2 key $120A
; English selector meaning: You cannot escape the Gorfian robots
; Working French transcription: Vous ne pouvez échapper aux robots de Gorf.
FrenchSpeech_Escape:
        DB      FrenchSpeech_Escape_End - $ - 1
        DB      $3E,$0F,$37,$03,$0D,$00,$03,$65,$37,$4F,$4A,$03
        DB      $0A,$10,$08,$25,$0A,$0A,$03,$03,$35,$03,$0F,$2B
        DB      $34,$0E,$35,$03,$1E,$31,$34,$34,$2B,$1D,$22,$2F
        DB      $3E
FrenchSpeech_Escape_End:

; Program-1 source $C45E, PGM1 key $1256, PGM2 key $1243
; English selector meaning: Too bad
; Working French transcription: Bien essayé.
FrenchSpeech_TooBad:
        DB      FrenchSpeech_TooBad_End - $ - 1
        DB      $3E,$0E,$22,$2F,$03,$0A,$1F,$1F,$0A,$22,$0A,$3E
FrenchSpeech_TooBad_End:

; Program-1 source $C46B, PGM1 key $11BB, PGM2 key $11A8
; English selector meaning: Try again; I devour your coins
; Working French transcription: Essayez encore ; je dévore la monnaie.
FrenchSpeech_Try:
        DB      FrenchSpeech_Try_End - $ - 1
        DB      $3E,$0A,$1F,$0A,$22,$0A,$03,$30,$30,$59,$75,$6B
        DB      $3E,$3E,$1A,$00,$03,$1E,$0A,$0F,$34,$2B,$03,$18
        DB      $08,$0C,$34,$0D,$0A,$29,$3E,$3E
FrenchSpeech_Try_End:

; Program-1 source $C48C, PGM1 key $12E1, PGM2 key $12CE
; English selector meaning: Bite the dust
; Working French transcription: Allez mordre la poussière.
FrenchSpeech_Bite:
        DB      FrenchSpeech_Bite_End - $ - 1
        DB      $3E,$08,$58,$49,$03,$03,$0C,$34,$2B,$1E,$0A,$03
        DB      $18,$08,$03,$25,$37,$1F,$22,$2F,$2B,$3E,$3E
FrenchSpeech_Bite_End:

; Program-1 source $C4A4, PGM1 key $119F, PGM2 key $118C
; English selector meaning: Gorfians conquer another galaxy
; Working French transcription: Les Gorfiens ont conquis une autre galaxie.
FrenchSpeech_Conquer:
        DB      FrenchSpeech_Conquer_End - $ - 1
        DB      $3E,$18,$2F,$1C,$04,$34,$34,$2B,$1D,$22,$2F,$03
        DB      $35,$03,$19,$35,$19,$22,$03,$22,$0D,$03,$75,$2A
        DB      $2B,$00,$03,$1C,$08,$18,$08,$19,$1F,$22,$3E
FrenchSpeech_Conquer_End:

; Program-1 source $C4C8, PGM1 key $12EE, PGM2 key $12DB
; English selector meaning: All hail the supreme Gorfian Empire
; Working French transcription: Vive le suprême empire gorfien.
FrenchSpeech_Hail:
        DB      FrenchSpeech_Hail_End - $ - 1
        DB      $3E,$0F,$62,$4F,$03,$18,$00,$03,$1F,$22,$25,$6B
        DB      $4A,$4C,$03,$30,$30,$65,$62,$6B,$03,$1C,$04,$34
        DB      $34,$2B,$1D,$22,$2F,$3E,$3E
FrenchSpeech_Hail_End:

; Program-1 source $C4E8, PGM1 key $A8DA, PGM2 key $A985
; English selector meaning: Next time will be harder, but for now
; Working French transcription: La prochaine fois, ce sera plus difficile, mais dans l'entretemps...
FrenchSpeech_NextTimeHarder:
        DB      FrenchSpeech_NextTimeHarder_End - $ - 1
        DB      $3E,$3E,$18,$08,$03,$25,$2B,$34,$10,$1B,$0A,$0D
        DB      $03,$1D,$37,$08,$03,$1F,$00,$03,$1F,$00,$2B,$08
        DB      $03,$65,$58,$62,$03,$1E,$22,$1D,$22,$5F,$62,$18
        DB      $3E,$3E,$0C,$06,$03,$1E,$30,$30,$03,$18,$30,$2A
        DB      $2B,$00,$2A,$30,$30,$3E
FrenchSpeech_NextTimeHarder_End:

; Program-1 source $C51F, PGM1 key $124A, PGM2 key $1237
; English selector meaning: Nice shot
; Working French transcription: Bien visé.
FrenchSpeech_Nice:
        DB      FrenchSpeech_Nice_End - $ - 1
        DB      $3E,$3E,$0E,$22,$2F,$03,$0F,$22,$12,$0A,$3E,$3E
FrenchSpeech_Nice_End:

; Program-1 source $C52C, PGM1 key $B32C, PGM2 key $B3BE
; English selector meaning: Push a player button
; Working French transcription: Pressez le bouton joueur.
FrenchSpeech_Push:
        DB      FrenchSpeech_Push_End - $ - 1
        DB      $3E,$25,$2B,$0A,$1F,$1F,$0B,$3E,$3E,$3B,$3E,$3E
        DB      $0E,$0E,$37,$2A,$2A,$35,$3E,$3E,$1A,$37,$16,$2B
        DB      $2B,$3E
FrenchSpeech_Push_End:

; Program-1 source $C547, PGM1 key $B373, PGM2 key $B405
; English selector meaning: Robot warriors, seek and destroy the
; Working French transcription: Guerriers robots, poursuivez et détruisez le...
FrenchSpeech_RoboWarrior:
        DB      FrenchSpeech_RoboWarrior_End - $ - 1
        DB      $3E,$1C,$1C,$0A,$2B,$6B,$62,$4A,$03,$0F,$2B,$34
        DB      $0E,$34,$03,$25,$37,$2B,$1F,$0F,$22,$4F,$4A,$03
        DB      $0A,$03,$1E,$0A,$2A,$2B,$0F,$22,$52,$4A,$03,$18
        DB      $02,$03
FrenchSpeech_RoboWarrior_End:

; Program-1 source $C56E, PGM1 key $12C5, PGM2 key $12B2
; English selector meaning: Some galactic defender you are
; Working French transcription: Quelle sorte de protecteur de la galaxie êtes-vous ?
FrenchSpeech_Some:
        DB      FrenchSpeech_Some_End - $ - 1
        DB      $3E,$59,$4A,$58,$03,$1F,$74,$6B,$6A,$03,$1E,$00
        DB      $03,$25,$2B,$34,$2A,$00,$19,$2A,$3B,$2B,$03,$1E
        DB      $00,$03,$18,$08,$03,$1C,$08,$18,$08,$19,$1F,$29
        DB      $00,$03,$4A,$6A,$00,$03,$0F,$37,$3E,$3E
FrenchSpeech_Some_End:

; Program-1 source $C59D, PGM1 key $132A, PGM2 key $1317
; English selector meaning: Your end draws near
; Working French transcription: Votre fin est proche.
FrenchSpeech_Betcha:
        DB      FrenchSpeech_Betcha_End - $ - 1
        DB      $3E,$0F,$34,$2A,$2B,$03,$1D,$2F,$03,$0A,$03,$65
        DB      $6B,$74,$50,$1B,$3E
FrenchSpeech_Betcha_End:

; Program-1 source $C5AF, PGM1 key $A8FD, PGM2 key $A9A8
; English selector meaning: In the Gorfian chronicles
; Working French transcription: Votre nom sera dans le journal gorfien.
FrenchSpeech_GorfianChronicles:
        DB      FrenchSpeech_GorfianChronicles_End - $ - 1
        DB      $3E,$3E,$0F,$34,$2A,$2B,$03,$4D,$75,$03,$1F,$00
        DB      $2B,$08,$03,$1E,$30,$30,$03,$18,$02,$03,$1A,$37
        DB      $2B,$4D,$48,$58,$03,$1C,$04,$34,$34,$2B,$1D,$29
        DB      $2F,$3E,$3E
FrenchSpeech_GorfianChronicles_End:

; Program-1 source $C5D7, PGM1 key $B3D3, PGM2 key $B465
; English selector meaning: Prepare yourself for annihilation
; Working French transcription: Votre destruction est proche.
FrenchSpeech_Prepare:
        DB      FrenchSpeech_Prepare_End - $ - 1
        DB      $3E,$0F,$34,$2A,$2B,$00,$03,$1E,$0A,$1F,$2A,$2B
        DB      $76,$19,$1F,$22,$34,$03,$01,$03,$65,$6B,$74,$50
        DB      $1B,$3E,$3E
FrenchSpeech_Prepare_End:

; Program-1 source $C5F3, PGM1 key $A916, PGM2 key $A9C1
; English selector meaning: For hitting my flagship
; Working French transcription: Pour avoir descendu mon vaisseau amiral.
FrenchSpeech_FlagshipHit:
        DB      FrenchSpeech_FlagshipHit_End - $ - 1
        DB      $3E,$3E,$25,$37,$2B,$03,$08,$0F,$37,$15,$2B,$03
        DB      $1E,$0A,$1F,$30,$30,$5E,$62,$03,$0C,$35,$03,$0F
        DB      $0A,$1F,$06,$37,$03,$08,$0C,$22,$2B,$08,$18,$3E
FrenchSpeech_FlagshipHit_End:

; Program-1 source $C618, PGM1 key $12AB, PGM2 key $1298
; English selector meaning: You have been promoted to
; Working French transcription: Vous avez été promu
FrenchSpeech_Promote:
        DB      FrenchSpeech_Promote_End - $ - 1
        DB      $3E,$0F,$37,$03,$12,$08,$0F,$0A,$03,$12,$0A,$2A
        DB      $0A,$03,$25,$2B,$34,$0C,$22,$03
FrenchSpeech_Promote_End:

; Program-1 source $C62D, PGM1 key $1277, PGM2 key $1264
; English selector meaning: Cadet
; Working French transcription: Cadet de l'espace
FrenchSpeech_Cadet:
        DB      FrenchSpeech_Cadet_End - $ - 1
        DB      $19,$19,$08,$5E,$6F,$03,$1E,$00,$03,$18,$0A,$1F
        DB      $25,$08,$1F,$3E
FrenchSpeech_Cadet_End:

; Program-1 source $C63E, PGM1 key $127E, PGM2 key $126B
; English selector meaning: Captain
; Working French transcription: Capitaine de l'espace
FrenchSpeech_Captain:
        DB      FrenchSpeech_Captain_End - $ - 1
        DB      $19,$08,$25,$22,$6A,$4A,$4D,$03,$1E,$00,$03,$18
        DB      $0A,$1F,$25,$08,$1F,$3E
FrenchSpeech_Captain_End:

; Program-1 source $C651, PGM1 key $1287, PGM2 key $1274
; English selector meaning: Colonel
; Working French transcription: Colonel de l'espace
FrenchSpeech_Colonel:
        DB      FrenchSpeech_Colonel_End - $ - 1
        DB      $19,$34,$18,$34,$4D,$4A,$58,$03,$1E,$00,$03,$18
        DB      $0A,$1F,$25,$08,$1F,$3E
FrenchSpeech_Colonel_End:

; Program-1 source $C664, PGM1 key $128E, PGM2 key $127B
; English selector meaning: General
; Working French transcription: Général de l'espace
FrenchSpeech_General:
        DB      FrenchSpeech_General_End - $ - 1
        DB      $1A,$1A,$0A,$0D,$0A,$6B,$48,$58,$03,$1E,$00,$03
        DB      $18,$0A,$1F,$25,$08,$1F,$3E
FrenchSpeech_General_End:

; Program-1 source $C678, PGM1 key $1297, PGM2 key $1284
; English selector meaning: Warrior
; Working French transcription: Guerrier de l'espace
FrenchSpeech_Warrior:
        DB      FrenchSpeech_Warrior_End - $ - 1
        DB      $1C,$04,$2B,$30,$30,$03,$1C,$04,$0A,$6B,$62,$4A
        DB      $03,$1E,$00,$03,$18,$0A,$1F,$25,$08,$1F,$3E
FrenchSpeech_Warrior_End:

; Program-1 source $C690, PGM1 key $12A0, PGM2 key $128D
; English selector meaning: Avenger
; Working French transcription: Suprême héros de l'espace
FrenchSpeech_Avenger:
        DB      FrenchSpeech_Avenger_End - $ - 1
        DB      $1F,$22,$25,$2B,$0A,$0C,$03,$1B,$0A,$6B,$75,$03
        DB      $1E,$00,$03,$18,$0A,$1F,$25,$08,$1F,$3E
FrenchSpeech_Avenger_End:

; -----------------------------------------------------------------------------
; Parallel speech translation tables
;
; FrenchSpeechTable[n] is selected when Pgm2SpeechTable[n] matches the primitive
; address supplied in DE.  The order is semantic and corresponds directly to
; the 36-entry Program-1 French tables at $C6A7/$C6EF after substituting the
; Program-2 resident addresses.
;
; The Program-1 French ROM suppresses SPACE (target $0000) exactly as the German
; ROM does; the translated French rank records already contain the required
; spacing/rank phrasing.  The laugh remains the resident language-neutral record.
; -----------------------------------------------------------------------------

FrenchSpeechTable:
        DW      FrenchSpeech_InsertCoin
        DW      FrenchSpeech_Gorf
        DW      $0000                   ; Suppress PGM2_SPK_SPACE, matching Program-1 French
        DW      FrenchSpeech_Conquer
        DW      FrenchSpeech_Try
        DW      FrenchSpeech_Long
        DW      FrenchSpeech_Robots
        DW      FrenchSpeech_BadMove
        DW      PGM2_SPK_HAHA           ; Language-neutral resident laugh
        DW      FrenchSpeech_Escape
        DW      FrenchSpeech_GotYou
        DW      FrenchSpeech_Nice
        DW      FrenchSpeech_TooBad
        DW      FrenchSpeech_Prisoner
        DW      FrenchSpeech_Cadet
        DW      FrenchSpeech_Captain
        DW      FrenchSpeech_Colonel
        DW      FrenchSpeech_General
        DW      FrenchSpeech_Warrior
        DW      FrenchSpeech_Avenger
        DW      FrenchSpeech_Promote
        DW      FrenchSpeech_Some
        DW      FrenchSpeech_Bite
        DW      FrenchSpeech_Hail
        DW      FrenchSpeech_Enemy
        DW      FrenchSpeech_Betcha
        DW      FrenchSpeech_NextTimeHarder
        DW      FrenchSpeech_GorfianChronicles
        DW      FrenchSpeech_FlagshipHit
        DW      FrenchSpeech_Push
        DW      FrenchSpeech_Doom
        DW      FrenchSpeech_Survival
        DW      FrenchSpeech_RoboWarrior
        DW      FrenchSpeech_Gorfian
        DW      FrenchSpeech_IAm
        DW      FrenchSpeech_Prepare
FrenchSpeechTableEnd:

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
        DW      PGM2_SPK_FLAGSHIP_INTRO
        DW      PGM2_SPK_GORFIAN_CHRONICLES
        DW      PGM2_SPK_FLAGSHIP_HIT
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
; IN:    DE = Program-2 English speech primitive address
; OUT:   DE = translated primitive address when dispatched
;        BC preserved
; USES:  AF, DE, HL
;
; This retains the  Gorf X11 36-entry predecessor-search algorithm.
; The translation keys, resident targets, message ordering, data placement,
; queue handling, and $CC00 entry are adapted specifically for Program 2.
; Every speech primitive used by Program 2 has an exact, sorted key in
; Pgm2SpeechTable.
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
        LD      HL,FrenchSpeechTable
        NEG
        ADD     A,TRANSLATION_COUNT
        RLCA                            ; Two bytes per address
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
; whether its eight-entry ring buffer is full.  Several  French
; primitives are substantially longer than the corresponding English records,
; and compound announcements can enqueue multiple records in quick succession.
; Reserve one slot so equal read/write pointers continue to mean "empty," as the
; interrupt-driven consumer expects.  Interrupts remain enabled while waiting.
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
; of $FF so the source can pad to fixed addresses without relying on a modern
; assembler extension.
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

; Pad to Program 2's third foreign-ROM entry point.  The resident input routine
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

; The physical X11 device is a 4 KB ROM.  Unused bytes read as $FF.
;
; French and German Program-1 X11 images share the 13-byte identification
; record at $CFF3-$CFFF.  The preceding byte at $CFF2 is not part of that
; common record:  German stores $00 there, while  French
; leaves it erased ($FF).  This French derivative preserves the French value
; by padding through $CFF2 and starting the identification record at $CFF3.
        IF      $CFF3 - $ >= 2048
        FillFF2048
        ENDIF
        IF      $CFF3 - $ >= 1024
        FillFF1024
        ENDIF
        IF      $CFF3 - $ >= 512
        FillFF512
        ENDIF
        IF      $CFF3 - $ >= 256
        FillFF256
        ENDIF
        IF      $CFF3 - $ >= 128
        FillFF128
        ENDIF
        IF      $CFF3 - $ >= 64
        FillFF64
        ENDIF
        IF      $CFF3 - $ >= 32
        FillFF32
        ENDIF
        IF      $CFF3 - $ >= 16
        FillFF16
        ENDIF
        IF      $CFF3 - $ >= 8
        FillFF8
        ENDIF
        IF      $CFF3 - $ >= 4
        FillFF4
        ENDIF
        IF      $CFF3 - $ >= 2
        FillFF2
        ENDIF
        IF      $CFF3 - $ >= 1
        FillFF1
        ENDIF

RomIdentificationTrailer:
        DB      $00,"GORF",$00,"DNA",$00,$12,$15,$80

        END
