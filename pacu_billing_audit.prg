drop program pacu_billing_audit_ops go
create program pacu_billing_audit_ops
/*****************************************************************************



Author:           Aaron J. Brown



Date Written:     09/12/2024



PPM:              



Source file name: pacu_billing_audit_ops.prg



Object name:      pacu_billing_audit_ops



Program purpose:  Identify PACU Missing Billing Items



Executing from:   Ops Job



*******************************************************************************



Mod Date       By              PPM    Comment



--- ---------- -------------- ------ ------------------------------------------



001 09/20/2024 Aaron J. Brown XXXXXX Initial Release



******************************************************************************/



PROMPT 
  "Output to File/Printer/MINE" = "MINE"
  
WITH OUTDEV



/* Ops job reply */
RECORD reply( 
  1 ops_event = vc
  1 status_data
      2 status = c1
      2 subeventstatus[1]
          3 OperationName = c25
          3 OperationStatus = c1
          3 TargetObjectName = c25
          3 TargetObjectValue = vc
)
SET reply->status_data->status = "Z"



FREE RECORD DATA



RECORD DATA (
  1 CNT = i4
  1 QUAL[*]
    2 NAME = vc
    2 DOB = vc
    2 ENCNTR_ID = f8
    2 ENCNTR_A = vc
      2 PHASEI_CALC = i2
      2 PHASEII_CALC = i2
      2 PHASEII_CALC_RES = i4
        2 PHASEI_START = i2
    2 PHASEII_START = i2
    2 PHASEI_STOP = i2
    2 PHASEII_STOP = i2
    2 PATIENTBYPASSPACU = i2
    2 PHASEINURSE_ID = f8
    2 PHASEIINURSE_ID = f8
    2 PHASEINURSE = vc
    2 PHASEIINURSE = vc
    2 ACTIVE_IND = i2
)



/* Phase Times */
DECLARE PHASEI_CALC_CD = f8 with constant(UAR_GET_CODE_BY("DISPLAYKEY", 72, "PHASEICALCULATION")), protect
DECLARE PHASEII_CALC_CD = f8 with constant(UAR_GET_CODE_BY("DISPLAYKEY", 72, "PHASEIICALCULATION")), protect
DECLARE PHASEISTART_CD = f8 with constant(UAR_GET_CODE_BY("DISPLAYKEY", 72, "PHASEISTART")), protect
DECLARE PHASEIISTART_CD = f8 with constant(UAR_GET_CODE_BY("DISPLAYKEY", 72, "PHASEIISTART")), protect
DECLARE PHASEISTOP_CD =  f8 with constant(UAR_GET_CODE_BY("DISPLAYKEY", 72, "PHASEISTOP")), protect
DECLARE PHASEIISTOP_CD = f8 with constant(UAR_GET_CODE_BY("DISPLAYKEY", 72, "PHASEIISTOP")), protect
DECLARE PHASEISTOPPHASEIISTART_CD = f8 with constant(UAR_GET_CODE_BY("DISPLAYKEY", 72, "PHASEISTOPPHASEIISTART")), protect
/* Additional Events */
DECLARE PATIENTBYPASSPACU_CD = f8 with constant(UAR_GET_CODE_BY("DISPLAYKEY", 72, "PATIENTBYPASSPACU")), protect
DECLARE FACILITY_CD = f8 with constant(UAR_GET_CODE_BY("DISPLAYKEY", 220, "NASHVILLE")), protect
DECLARE FIN_TYPE_CD = f8 with constant(UAR_GET_CODE_BY("DISPLAYKEY",319,"FINNBR")), protect
/* Excluded Areas */
DECLARE CVOR_CD = f8 with constant(UAR_GET_CODE_BY("DISPLAYKEY",221,"CVOR")), protect
DECLARE CVNORA_CD = f8 with constant(UAR_GET_CODE_BY("DISPLAYKEY",221,"CVNORA")), protect
DECLARE CVHYBRID_CD = f8 with constant(UAR_GET_CODE_BY("DISPLAYKEY",221,"CVHYBRID")), protect
DECLARE CVLAB_CD = f8 with constant(UAR_GET_CODE_BY("DISPLAYKEY",221,"CVLAB")), protect
/* Excluded Encounter */
DECLARE INPATIENT_CD = f8 with constant(UAR_GET_CODE_BY("DISPLAYKEY",71,"INPATIENT")), protect
DECLARE OBSERVATION_CD = f8 with constant(UAR_GET_CODE_BY("DISPLAYKEY",71,"OBSERVATION")), protect
DECLARE OUTPATIENTINABED_CD = f8 with constant(UAR_GET_CODE_BY("DISPLAYKEY",71,"OUTPATIENTINABED")), protect



/**************************************************************************************************
Get all surgical cases completed within 7 days.
**************************************************************************************************/



SELECT DISTINCT INTO "NL:"



FROM 
  ENCNTR_ALIAS EA
  , PERSON P
  , SURGICAL_CASE SC
  , ENCOUNTER E



PLAN SC
  WHERE SC.SURG_STOP_DT_TM BETWEEN CNVTLOOKBEHIND("7, d") 
  AND CNVTDATETIME(CURDATE, CURTIME3)
  /* Removed CVORS */
  AND SC.SCHED_OP_LOC_CD NOT IN (CVOR_CD, CVHYBRID_CD, CVNORA_CD, CVLAB_CD) 
  
JOIN E
  WHERE E.ENCNTR_ID = SC.ENCNTR_ID
  AND E.LOC_FACILITY_CD = FACILITY_CD
  /* Removed encounter types */
  AND E.ENCNTR_TYPE_CD NOT IN (INPATIENT_CD, OBSERVATION_CD, OUTPATIENTINABED_CD)
  
JOIN EA
  WHERE EA.ENCNTR_ID = E.ENCNTR_ID
  AND EA.ENCNTR_ALIAS_TYPE_CD = VALUE(UAR_GET_CODE_BY("DISPLAYKEY",319,"FINNBR"))



JOIN P
  WHERE P.PERSON_ID = E.PERSON_ID
/*********** REPORTWRITER SECTION ***************/
HEAD REPORT
  X = 0
  
DETAIL
  X += 1
  CALL ALTERLIST(DATA->QUAL, X)
  DATA->QUAL[X].NAME = FORMAT(P.NAME_FULL_FORMATTED, "##################;L")
  DATA->QUAL[X].DOB = FORMAT(P.BIRTH_DT_TM,"MM/DD/YY ;;D")
  DATA->QUAL[X].ENCNTR_ID = EA.ENCNTR_ID
  DATA->QUAL[X].ENCNTR_A = EA.ALIAS
  
FOOT REPORT
  DATA->CNT = X
/*********** END REPORTWRITER SECTION ***************/
WITH NOCOUNTER



/**************************************************************************************************
Get x clinical events.
**************************************************************************************************/



SELECT INTO "NL:"



FROM CLINICAL_EVENT CE
    ,(DUMMYT D WITH SEQ = DATA->CNT)
PLAN D
  WHERE DATA->CNT > 0



JOIN CE
  WHERE CE.ENCNTR_ID = DATA->QUAL[D.SEQ].ENCNTR_ID
  AND CE.EVENT_CD IN (
   PHASEI_CALC_CD, PHASEII_CALC_CD,
   PHASEISTART_CD, PHASEIISTART_CD,
   PHASEISTOP_CD, PHASEIISTOP_CD,
   PHASEISTOPPHASEIISTART_CD,
   PATIENTBYPASSPACU_CD
  )
  AND CE.RESULT_STATUS_CD IN (REQDATA->AUTH_AUTH_CD, REQDATA->AUTH_MODIFIED_CD, REQDATA->AUTH_ALTERED_CD)
  AND CE.VALID_UNTIL_DT_TM > CNVTDATETIME(CURDATE,CURTIME3)

ORDER BY D.SEQ



DETAIL
  
  CASE(CE.EVENT_CD)
     /* Phase I Cal */
     OF PHASEI_CALC_CD: 
       DATA->QUAL[D.SEQ].PHASEI_CALC = 1
       DATA->QUAL[D.SEQ].PHASEINURSE_ID = CE.PERFORMED_PRSNL_ID
     /* Phase II Cal */
     OF PHASEII_CALC_CD: 
       DATA->QUAL[D.SEQ].PHASEII_CALC = 1
       /* Phase II Cal Result */
       DATA->QUAL[D.SEQ].PHASEII_CALC_RES = CNVTINT(CE.RESULT_VAL)
       DATA->QUAL[D.SEQ].PHASEIINURSE_ID = CE.PERFORMED_PRSNL_ID
     /* Phase I Start */
     OF PHASEISTART_CD: 
       DATA->QUAL[D.SEQ].PHASEI_START = 1
      DATA->QUAL[D.SEQ].PHASEINURSE_ID = CE.PERFORMED_PRSNL_ID
     /* Phase II Start */
     OF PHASEIISTART_CD: 
       DATA->QUAL[D.SEQ].PHASEII_START = 1
       DATA->QUAL[D.SEQ].PHASEIINURSE_ID = CE.PERFORMED_PRSNL_ID
     /* Phase I Stop */
     OF PHASEISTOP_CD: 
       DATA->QUAL[D.SEQ].PHASEI_STOP = 1
       DATA->QUAL[D.SEQ].PHASEINURSE_ID = CE.PERFORMED_PRSNL_ID
     /* Phase I Stop and Phase II Strat */
     OF PHASEISTOPPHASEIISTART_CD :
       DATA->QUAL[D.SEQ].PHASEI_STOP = 1
      DATA->QUAL[D.SEQ].PHASEII_START = 1
        DATA->QUAL[D.SEQ].PHASEINURSE_ID = CE.PERFORMED_PRSNL_ID 
     /* Phase II Stop */
       OF PHASEIISTOP_CD: 
         DATA->QUAL[D.SEQ].PHASEII_STOP = 1
         DATA->QUAL[D.SEQ].PHASEIINURSE_ID = CE.PERFORMED_PRSNL_ID
       /* Phase I By Pass */
       OF PATIENTBYPASSPACU_CD:
         IF (CE.RESULT_VAL = "Yes")
             DATA->QUAL[D.SEQ].PATIENTBYPASSPACU = 1
             DATA->QUAL[D.SEQ].PHASEI_START = 1
             DATA->QUAL[D.SEQ].PHASEI_STOP = 1
             DATA->QUAL[D.SEQ].PHASEI_CALC = 1
         ENDIF
  ENDCASE
/*********** REPORTWRITER SECTION ***************/
FOOT D.SEQ 
  /* Phase II Cal < 30 mins exclusion */
  IF(DATA->QUAL[D.SEQ].PHASEII_CALC AND DATA->QUAL[D.SEQ].PHASEII_CALC_RES < 30)
    DATA->QUAL[D.SEQ].PHASEII_START = 1
    DATA->QUAL[D.SEQ].PHASEII_STOP = 1
  ENDIF
  /* Bypass PACU exclusion */
  IF(DATA->QUAL[D.SEQ].PATIENTBYPASSPACU AND DATA->QUAL[D.SEQ].PHASEII_CALC = 0)
    DATA->QUAL[D.SEQ].ACTIVE_IND = 1
  ELSEIF(DATA->QUAL[D.SEQ].PATIENTBYPASSPACU = 0 
    AND (DATA->QUAL[D.SEQ].PHASEI_CALC = 0 OR DATA->QUAL[D.SEQ].PHASEII_CALC = 0))
    DATA->QUAL[D.SEQ].ACTIVE_IND = 1
  ENDIF



WITH NOCOUNTER
/*********** END REPORTWRITER SECTION ***************/
CALL ECHORECORD(DATA)



/**************************************************************************************************
Get nurse names.
**************************************************************************************************/



SELECT INTO "NL:"



FROM (DUMMYT D WITH SEQ = DATA->CNT)
  ,PRSNL PL



PLAN D
  WHERE DATA->CNT > 0



JOIN PL
  WHERE PL.PERSON_ID IN (DATA->QUAL[D.SEQ].PHASEINURSE_ID,
    DATA->QUAL[D.SEQ].PHASEIINURSE_ID)



ORDER BY D.SEQ



/*********** REPORTWRITER SECTION ***************/
DETAIL
  
  CASE (PL.PERSON_ID)
    OF DATA->QUAL[D.SEQ].PHASEINURSE_ID : 
      DATA->QUAL[D.SEQ].PHASEINURSE = PL.NAME_FULL_FORMATTED
    OF DATA->QUAL[D.SEQ].PHASEIINURSE_ID : 
      DATA->QUAL[D.SEQ].PHASEIINURSE = PL.NAME_FULL_FORMATTED 
  ENDCASE
/*********** END REPORTWRITER SECTION ***************/
WITH NOCOUNTER





/**************************************************************************************************
Print
**************************************************************************************************/
  
SELECT DISTINCT INTO $OUTDEV
  
FROM (DUMMYT D WITH SEQ = DATA->CNT)



PLAN D
  WHERE DATA->CNT > 0
  
ORDER BY D.SEQ
/*********** REPORTWRITER SECTION ***************/
HEAD REPORT
  P = 0
  PAGE_COUNT = 0
  Y_AXIS = 25
  X_AXIS = 35
  X = 0
  
HEAD PAGE
  LINE_D = FILLSTRING(83,"=")
    CALL PRINT(CALCPOS(35, 0))  "{CPI/10}{FONT/4}{b}", CURTIME "HH:MM;;M", "{endb}", ROW + 1
  CALL PRINT(CALCPOS(235, 0)) "{CPI/10}{FONT/4}{b}","*** Nashville PACU Billing Audit ***", "{endb}", ROW + 1
  CALL PRINT(CALCPOS(535, 0))  "{CPI/10}{FONT/4}{b}", CURDATE "MM/DD/YY;;D", "{endb}", ROW + 1
  CALL PRINT(CALCPOS(35, 27)) LINE_D, ROW + 2
  Y_AXIS += 15
  PAGE_COUNT += 1
  
HEAD D.SEQ
    X += 1
    IF(DATA->QUAL[D.SEQ].ACTIVE_IND)
      CALL PRINT(CALCPOS(X_AXIS, Y_AXIS)) 
        "{CPI/10}{FONT/4}{b}" "Patient's Name: " "{ENDB}" 
         DATA->QUAL[D.SEQ].NAME, ROW + 1
      CALL PRINT(CALCPOS(X_AXIS + 250, Y_AXIS))
         "DOB: " DATA->QUAL[D.SEQ].DOB, ROW + 1
      CALL PRINT(CALCPOS(X_AXIS + 450, Y_AXIS)) 
        "FIN: " DATA->QUAL[D.SEQ].ENCNTR_A, ROW + 1
    ENDIF



DETAIL
  IF(DATA->QUAL[D.SEQ].ACTIVE_IND)
    P += 1
    Y_AXIS += 15
    X_AXIS = 40
    CALL PRINT(CALCPOS(X_AXIS, Y_AXIS)) "Missing Information:"
    X_AXIS = 50
    /* Phase I */
    /* Missing Start */
    IF(DATA->QUAL[X].PHASEI_START = 0 AND DATA->QUAL[X].PHASEI_STOP AND DATA->QUAL[X].PHASEI_CALC)
      Y_AXIS += 15
      CALL PRINT(CALCPOS(X_AXIS, Y_AXIS)) "{CPI/10}{FONT/4}{b}" "Phase I Start", ROW + 1
      Y_AXIS += 15
      CALL PRINT(CALCPOS(X_AXIS, Y_AXIS)) "Nurse: " DATA->QUAL[X].PHASEINURSE, ROW + 1
    /* Missing Stop */
    ELSEIF(DATA->QUAL[X].PHASEI_START AND DATA->QUAL[X].PHASEI_STOP = 0 AND DATA->QUAL[X].PHASEI_CALC)
      Y_AXIS += 15
      CALL PRINT(CALCPOS(X_AXIS, Y_AXIS)) "{CPI/10}{FONT/4}{b}" "Phase I Stop", ROW + 1
      Y_AXIS += 15
      CALL PRINT(CALCPOS(X_AXIS, Y_AXIS)) "Nurse: " DATA->QUAL[X].PHASEINURSE, ROW + 1
    /* Missing Calculation */
    ELSEIF(DATA->QUAL[X].PHASEI_START AND DATA->QUAL[X].PHASEI_STOP AND DATA->QUAL[X].PHASEI_CALC = 0)
      Y_AXIS += 15
      CALL PRINT(CALCPOS(X_AXIS, Y_AXIS)) "{CPI/10}{FONT/4}{b}" "Phase I Calculation", ROW + 1
      Y_AXIS += 15
      CALL PRINT(CALCPOS(X_AXIS, Y_AXIS)) "Nurse: " DATA->QUAL[X].PHASEINURSE, ROW + 1
    /* Missing Start/Stop */
    ELSEIF(DATA->QUAL[X].PHASEI_START = 0 AND DATA->QUAL[X].PHASEI_STOP = 0 AND DATA->QUAL[X].PHASEI_CALC)
      Y_AXIS += 15
      CALL PRINT(CALCPOS(X_AXIS, Y_AXIS)) "{CPI/10}{FONT/4}{b}" "Phase I Start/Phase I Stop", ROW + 1
      Y_AXIS += 15
      CALL PRINT(CALCPOS(X_AXIS, Y_AXIS)) "Nurse: " DATA->QUAL[X].PHASEINURSE, ROW + 1
    /* Missing Start/Calculation */
    ELSEIF(DATA->QUAL[X].PHASEI_START = 0 AND DATA->QUAL[X].PHASEI_STOP AND DATA->QUAL[X].PHASEI_CALC = 0)
      Y_AXIS += 15
      CALL PRINT(CALCPOS(X_AXIS, Y_AXIS)) "{CPI/10}{FONT/4}{b}" "Phase I Start/Phase I Calculation", ROW + 1
      Y_AXIS += 15
      CALL PRINT(CALCPOS(X_AXIS, Y_AXIS)) "Nurse: " DATA->QUAL[X].PHASEINURSE, ROW + 1
    /* Missing Stop/Calculation */
    ELSEIF(DATA->QUAL[X].PHASEI_START AND DATA->QUAL[X].PHASEI_STOP = 0 AND DATA->QUAL[X].PHASEI_CALC = 0)
      Y_AXIS += 15
      CALL PRINT(CALCPOS(X_AXIS, Y_AXIS)) "{CPI/10}{FONT/4}{b}" "Phase I Stop/Phase I Calculation", ROW + 1
      Y_AXIS += 15
      CALL PRINT(CALCPOS(X_AXIS, Y_AXIS)) "Nurse: " DATA->QUAL[X].PHASEINURSE, ROW + 1
    /* Missing Start/Stop/Calculation */
    ELSEIF(DATA->QUAL[X].PHASEI_START = 0 AND DATA->QUAL[X].PHASEI_STOP = 0 AND DATA->QUAL[X].PHASEI_CALC = 0)
      Y_AXIS += 15
      CALL PRINT(CALCPOS(X_AXIS, Y_AXIS)) "{CPI/10}{FONT/4}{b}" "Phase I Start/Phase I Stop/Phase I Calculation", ROW + 1
      Y_AXIS += 15
      CALL PRINT(CALCPOS(X_AXIS, Y_AXIS)) "Nurse: " DATA->QUAL[X].PHASEINURSE, ROW + 1
    ENDIF
    /* Phase II */
      /* Missing Start */
    IF(DATA->QUAL[X].PHASEII_START = 0 AND DATA->QUAL[X].PHASEII_STOP AND DATA->QUAL[X].PHASEII_CALC)
      Y_AXIS += 15
      CALL PRINT(CALCPOS(X_AXIS, Y_AXIS)) "{CPI/10}{FONT/4}{b}" "Phase II Start", ROW + 1
      Y_AXIS += 15
      CALL PRINT(CALCPOS(X_AXIS, Y_AXIS)) "Nurse: " DATA->QUAL[X].PHASEINURSE, ROW + 1
    /* Missing Stop */
    ELSEIF(DATA->QUAL[X].PHASEII_START AND DATA->QUAL[X].PHASEII_STOP = 0 AND DATA->QUAL[X].PHASEII_CALC)
      Y_AXIS += 15
      CALL PRINT(CALCPOS(X_AXIS, Y_AXIS)) "{CPI/10}{FONT/4}{b}" "Phase II Stop/Phase II Calculation", ROW + 1
      Y_AXIS += 15
      CALL PRINT(CALCPOS(X_AXIS, Y_AXIS)) "Nurse: " DATA->QUAL[X].PHASEINURSE, ROW + 1
    /* Missing Calculation */
    ELSEIF(DATA->QUAL[X].PHASEII_START AND DATA->QUAL[X].PHASEII_STOP AND DATA->QUAL[X].PHASEII_CALC = 0)
      Y_AXIS += 15
      CALL PRINT(CALCPOS(X_AXIS, Y_AXIS)) "{CPI/10}{FONT/4}{b}" "Phase II Calculation", ROW + 1
      Y_AXIS += 15
      CALL PRINT(CALCPOS(X_AXIS, Y_AXIS)) "Nurse: " DATA->QUAL[X].PHASEINURSE, ROW + 1
    /* Missing Start/Stop */
    ELSEIF(DATA->QUAL[X].PHASEII_START = 0 AND DATA->QUAL[X].PHASEII_STOP = 0 AND DATA->QUAL[X].PHASEII_CALC)
      Y_AXIS += 15
      CALL PRINT(CALCPOS(X_AXIS, Y_AXIS)) "{CPI/10}{FONT/4}{b}" "Phase II Start/Phase II Stop", ROW + 1
      Y_AXIS += 15
      CALL PRINT(CALCPOS(X_AXIS, Y_AXIS)) "Nurse: " DATA->QUAL[X].PHASEINURSE, ROW + 1
    /* Missing Start/Calculation */
    ELSEIF(DATA->QUAL[X].PHASEII_START = 0 AND DATA->QUAL[X].PHASEII_STOP AND DATA->QUAL[X].PHASEII_CALC = 0)
      Y_AXIS += 15
      CALL PRINT(CALCPOS(X_AXIS, Y_AXIS)) "{CPI/10}{FONT/4}{b}" "Phase II Start/Phase II Calculation", ROW + 1
      Y_AXIS += 15
      CALL PRINT(CALCPOS(X_AXIS, Y_AXIS)) "Nurse: " DATA->QUAL[X].PHASEINURSE, ROW + 1
    /* Missing Stop/Calculation */
    ELSEIF(DATA->QUAL[X].PHASEII_START AND DATA->QUAL[X].PHASEII_STOP = 0 AND DATA->QUAL[X].PHASEII_CALC = 0)
      Y_AXIS += 15
      CALL PRINT(CALCPOS(X_AXIS, Y_AXIS)) "{CPI/10}{FONT/4}{b}" "Phase II Stop/Phase II Calculation", ROW + 1
      Y_AXIS += 15
      CALL PRINT(CALCPOS(X_AXIS, Y_AXIS)) "Nurse: " DATA->QUAL[X].PHASEINURSE, ROW + 1
    /* Missing Start/Stop/Calculation */
    ELSEIF(DATA->QUAL[X].PHASEII_START = 0 AND DATA->QUAL[X].PHASEII_STOP = 0 AND DATA->QUAL[X].PHASEII_CALC = 0)
      Y_AXIS += 15
      CALL PRINT(CALCPOS(X_AXIS, Y_AXIS)) "{CPI/10}{FONT/4}{b}" "Phase II Start/Phase II Stop/Phase II Calculation", ROW + 1
      Y_AXIS += 15
      CALL PRINT(CALCPOS(X_AXIS, Y_AXIS)) "Nurse: " DATA->QUAL[X].PHASEINURSE, ROW + 1
    ENDIF
    X_AXIS = 35
    Y_AXIS += 25
  ENDIF
  
  CALL PRINT(CALCPOS(550,700)) PAGE_COUNT, ROW + 1
  IF (Y_AXIS > 650 AND DATA->CNT > X)
    "{NP}", ROW + 1
    Y_AXIS = 25, ROW + 1
    P = 0
    BREAK
  ENDIF
/*********** END REPORTWRITER SECTION ***************/
WITH NOCOUNTER
  ,MAXROW = 1
  ,FORMFEED = NONE
  ,DIO = POSTSCRIPT
  ,FORMAT = variable



SET reply->status_data->status = "S"
END GO
