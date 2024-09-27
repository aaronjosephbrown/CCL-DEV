drop   program kids_clin_doc_pt_cncus_rel_ltr:dba go
create program kids_clin_doc_pt_cncus_rel_ltr:dba

/*****************************************************************************
Author:            Shane Peterson
Date Written:      12/19/2019
PPM:               173547
Source file name:  kids_clin_doc_pt_concussion_release_ltr.prg
Object name:       kids_clin_doc_pt_cncus_rel_ltr
Program purpose:
Executing from:    PowerChart, Communicate -> Patient Letter -> Subject: Concussion Clearance Letter
Special Notes:     calls kids_rpt_generator
*******************************************************************************
Mod Date     By              PPM    Comment
--- -------- --------------- ------ -------------------------------------------
000 12/19/19 Shane Peterson  169178 Initial Release
001 06/02/21 Mary Mattson    181657 Updated Heart Clinic location
002 05/12/22 Zach Meyer    186549 MTKA updates
******************************************************************************/

declare    err_check(idx) = i2
subroutine err_check(idx)

  declare err = i4
  declare msg = vc
  declare body = vc

  set err = error(body,0)
  set zzz = 0

  while (err > 0 and zzz < 10)
    ;execute oencpm_msglog(build2(idx, ": ", msg, char(0)))
    set err = error(msg,0)
    set body = concat(body,char(10),char(10),msg)
    set zzz = zzz + 1
  endwhile

  execute kids_send_email "greg.zarambo@childrensmn.org",build(idx),body,0
end ; subroutine err_check

declare    fix_loc_name(loc_in = vc) = vc
subroutine fix_loc_name(loc_in)
  set temp1 = loc_in

  if (temp1 = "*-M")
    set temp1 = replace(temp1,"-M","- Minneapolis",2)
  elseif (temp1 = "*-S")
    set temp1 = replace(temp1,"-S","- St. Paul",2)
  elseif (temp1 = "*-WB")
    set temp1 = replace(temp1,"-WB","- Woodbury",2)
  elseif (temp1 = "*-Mtka")
    set temp1 = replace(temp1,"-Mtka","- Minnetonka",2)
  endif

  set temp1 = replace(temp1,"Cl-","Clinic",2)
  return (temp1)
end ; subroutine fix_loc_name


record data
(
  1 person_id = f8
  1 encntr_id = f8
  1 name_first = vc
  1 name_last = vc
  1 dob = vc
  1 he_she = vc
  1 his_her = vc
  1 loc_cd = f8
  1 loc_name = vc
  1 loc_name_addr = vc
  1 loc_addr1 = vc
  1 loc_addr2 = vc
  1 loc_phone = vc
  1 enc_type = vc
  1 user = vc
  1 reg_dt_tm = vc
  1 reg_to_discharge = vc
  1 logo
    2 str = vc
    2 scale = vc
    2 top = vc
    2 left = vc
    2 img = vc
  1 form_event_id = f8
  1 app_ctx_id = f8
  1 ce2_event_id = f8
  1 ce2_verified_dt = vc
  1 clrd_cntct_sports = vc
  1 clrd_cntct_sports_cr = vc
  1 clrd_cntct_sports_dt = vc
  1 clrd_acdmc_actvty = vc
  1 clrd_acdmc_actvty_cr = vc
  1 clrd_acdmc_actvty_dt = vc
  1 concus_accom_cmmnts = vc
  1 concus_clear_cmmnts = vc
  1 signature = vc
  1 cosignature = vc
)


declare temp1 = vc

set data->encntr_id = request->visit[1].encntr_id ; 34003009.00
set data->person_id = request->person[1].person_id ; 13945114.00

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;
declare INERROR_CD = f8 with constant(uar_get_code_by("MEANING",8,"INERROR")),protect

; ph.phone_type_cd
declare BUS_PHONE_CD = f8 with constant(uar_get_code_by("MEANING",43,"BUSINESS")),protect

; p.sex_cd
declare MALE_CD = f8 with constant(uar_get_code_by("MEANING",57,"MALE")),protect

; e.encntr_type_cd
declare CLINIC_CD        = f8 with constant(uar_get_code_by("DISPLAYKEY",71,"CLINIC")),protect
declare DAYSURGERY_CD    = f8 with constant(uar_get_code_by("DISPLAYKEY",71,"DAYSURGERY")),protect
declare EMERGENCYDEPT_CD = f8 with constant(uar_get_code_by("DISPLAYKEY",71,"EMERGENCYDEPT")),protect
declare INPATIENT_CD     = f8 with constant(uar_get_code_by("MEANING",71,"INPATIENT")),protect
declare OBSERVATION_CD   = f8 with constant(uar_get_code_by("MEANING",71,"OBSERVATION")),protect
declare OPINABED_CD      = f8 with constant(uar_get_code_by("MEANING",71,"OUTPATIENT")),protect

; ce2.event_cd
declare CLRDFULLCNTCTSPORTS_CD = f8 with constant(uar_get_code_by("DISPLAYKEY",72,"CLEAREDFORFULLCONTACTSPORTS")),protect
declare CLRDFULLACDMCACTVTY_CD = f8 with constant(uar_get_code_by("DISPLAYKEY",72,"CLEAREDFORFULLACADEMICACTIVITY")),protect
declare CONCUSACCOMCMMNTS_CD = f8 with constant(uar_get_code_by("DISPLAYKEY",72,"CONCUSSIONACCOMMODATIONSCOMMENTS")),protect
declare CONCUSCLEARCMMNTS_CD = f8 with constant(uar_get_code_by("DISPLAYKEY",72,"CONCUSSIONCLEARANCECOMMENTS")),protect
declare DTCLRDFULLCNTCTSPORTS_CD = f8 with constant(uar_get_code_by("DISPLAYKEY",72,"DATECLEAREDFORFULLCONTACTSPORTS")),protect
declare DTCLRDFULLACDMCACTVTY_CD = f8 with constant(uar_get_code_by("DISPLAYKEY",72,"DATECLEAREDFORFULLACADEMICACTIVITY")),protect
declare SIGNATURE_CD   = f8 with constant(uar_get_code_by("DISPLAYKEY",72,"SIGNATURE")),protect
declare COSIGNATURE_CD = f8 with constant(uar_get_code_by("DISPLAYKEY",72,"COSIGNATURE")),protect

; a.address_type_cd
declare BUS_ADDR_CD  = f8 with constant(uar_get_code_by("MEANING",212,"BUSINESS")),protect
declare MAIL_ADDR_CD = f8 with constant(uar_get_code_by("MEANING",212,"MAILING")),protect

; dfc.component_cd
declare CLINCALEVENT_CD = f8 with constant(uar_get_code_by("MEANING",18189,"CLINCALEVENT")),protect

; Get person/encntr info
declare ADDR_CD = f8

set ENV = cnvtlower(currdbname)

set HC_BUILDING_CD =  uar_get_code_by_cki("CHC.LOC!Heart Clinic")
select into "nl:"
from encounter e
    ,person p
plan e
  where e.encntr_id = data->encntr_id
join p
  where p.person_id = e.person_id
detail
  data->name_first = p.name_first
  data->name_last  = p.name_last
  data->dob = format(p.birth_dt_tm,"mm/dd/yyyy;;q")
  data->loc_cd = e.loc_facility_cd
  data->loc_name_addr = uar_get_code_description(e.loc_facility_cd)
  data->reg_dt_tm = format(e.reg_dt_tm,"mm/dd/yyyy;;q")

  data->reg_to_discharge =
      if (e.disch_dt_tm = null)

        if (format(e.reg_dt_tm,"yyyymmdd;;q") != format(cnvtdatetime(curdate,curtime),"yyyymmdd;;q"))
          build2(format(e.reg_dt_tm,"mm/dd/yyyy;;q")," - ",format(curdate,"mm/dd/yyyy;;q"))
        else
          format(e.reg_dt_tm,"mm/dd/yyyy;;q")
        endif

      elseif (format(e.reg_dt_tm,"yyyymmdd;;q") != format(e.disch_dt_tm,"yyyymmdd;;q"))
        build2(format(e.reg_dt_tm,"mm/dd/yyyy;;q")," - ",format(e.disch_dt_tm,"mm/dd/yyyy;;q"))
      else
        format(e.reg_dt_tm,"mm/dd/yyyy;;q")
      endif

  ADDR_CD = BUS_ADDR_CD

  if (p.sex_cd = MALE_CD)
    data->he_she  = "He"
    data->his_her = "His"
  else
    data->he_she  = "She"
    data->his_her = "Her"
  endif

  case (cnvtupper(uar_get_code_display(e.loc_facility_cd)))
    of "WEST":
      data->loc_name = replace(data->loc_name,"West","Minnetonka",2)
  else
      data->loc_name = trim(uar_get_code_display(e.loc_facility_cd))
  endcase

  if (e.encntr_type_cd = CLINIC_CD)
    data->enc_type = "seen in our clinic today"
  elseif (e.encntr_type_cd = EMERGENCYDEPT_CD)
    data->enc_type = build2("seen at our ",data->loc_name," Emergency Department today")
  elseif (e.encntr_type_cd = DAYSURGERY_CD)
    data->enc_type = build2("seen at our ",data->loc_name," Surgical Center today")
  elseif (e.encntr_type_cd in (INPATIENT_CD,OBSERVATION_CD,OPINABED_CD))
    data->enc_type = build2("admitted to our ",data->loc_name," Campus on ",data->reg_dt_tm)
  else
    data->enc_type = "seen in our facility today"
  endif

  if (e.loc_building_cd = HC_BUILDING_CD )
     data->logo->img = "Childrens_MN_and_Heart_Clinic_logos_2020.jpg"
  else
     data->logo->img = "ChildrensMN_2019_logo_2c_445_143.jpg"
  endif

  data->logo->str = concat("{IMAGE/~/nfs~/middle_fs~/custom_warehouses~/",trim(env),
                           "~/code~/script~/",trim(data->logo->img),
                           "/TOP;",trim(data->logo->top),
                           "/LEFT;",trim(data->logo->left),
                           "/SCALE;",trim(data->logo->scale),"}")
with nocounter

/*** Get provider/clinic info ***/
select into "nl:"
from sch_appt a
plan a
  where a.encntr_id  = data->encntr_id
    and a.active_ind = 1
    and a.role_meaning = "PATIENT"
    and a.state_meaning IN ("CHECKED IN","CHECKED OUT","CONFIRMED","SCHEDULED")
head report
  if (fix_loc_name(uar_get_code_display(a.appt_location_cd)) != "Surgery*")
    data->loc_cd = a.appt_location_cd
;    data->loc_name_addr = fix_loc_name(uar_get_code_display(a.appt_location_cd))

    ADDR_CD = MAIL_ADDR_CD
  endif
with nocounter


/*** Get clinic address ***/
select into "nl:"
from address a
plan a
  where a.parent_entity_id = data->loc_cd
    and a.parent_entity_name = "LOCATION"
    and a.active_ind = 1
    and a.address_type_cd = ADDR_CD
    and a.beg_effective_dt_tm <= cnvtdatetime(curdate,curtime)
    and a.end_effective_dt_tm >  cnvtdatetime(curdate,curtime)
detail
  if (trim(a.street_addr2) > " ")
    data->loc_addr1 = a.street_addr2
  else
    data->loc_addr1 = a.street_addr
  endif

  data->loc_addr2 = concat(trim(a.city),", ",trim(uar_get_code_display(a.state_cd))," ",a.zipcode)
with nocounter


/*** Get clinic phone ***/
select into "nl:"
from phone ph
plan ph
  where ph.parent_entity_id = data->loc_cd
    and ph.parent_entity_name = "LOCATION"
    and ph.active_ind = 1
    and ph.phone_type_cd = BUS_PHONE_CD
    and ph.beg_effective_dt_tm <= cnvtdatetime(curdate,curtime)
    and ph.end_effective_dt_tm >  cnvtdatetime(curdate,curtime)
detail
  data->loc_phone = cnvtphone(cnvtalphanum(ph.phone_num,1),0)
with nocounter


select into "nl:"
from prsnl p
    ,credential c
plan p
  where p.person_id = reqinfo->updt_id
join c
  where c.prsnl_id = outerjoin(p.person_id)
    and c.active_ind = outerjoin(1)
    and c.end_effective_dt_tm > outerjoin(cnvtdatetime(curdate,curtime3))
head report
  data->user = concat(trim(p.name_first)," ",p.name_last)

  if (c.credential_cd > 0)
    data->user = concat(data->user,", ",uar_get_code_display(c.credential_cd))
  endif
with nocounter


declare DCP_FORMS_REF_ID = f8

select into "nl:"
from dcp_forms_ref dfr
plan dfr
  where dfr.definition = "Concussion Clinic Clearance"
    and dfr.active_ind = 1
detail
  DCP_FORMS_REF_ID = dfr.dcp_forms_ref_id
with nocounter


select into "nl:"
  form_dt_tm = format(dfa.form_dt_tm,"yyyymmddhhmm;;dq8")
from dcp_forms_activity dfa
    ,dcp_forms_activity_comp dfc
plan dfa
  where dfa.person_id  = data->person_id
    and dfa.active_ind = 1
    and dfa.form_status_cd != INERROR_CD
    and dfa.dcp_forms_ref_id = DCP_FORMS_REF_ID
    and dfa.form_dt_tm > cnvtdatetime(curdate - 365,0)
join dfc
  where dfc.dcp_forms_activity_id = dfa.dcp_forms_activity_id
    and dfc.parent_entity_name = "CLINICAL_EVENT"
    and dfc.component_cd = CLINCALEVENT_CD
order by form_dt_tm desc
;head report
head dfa.dcp_forms_ref_id
  data->form_event_id = dfc.parent_entity_id
  data->app_ctx_id    = dfa.updt_applctx
with nocounter


select into "nl:"
from clinical_event ce1
    ,clinical_event ce2
    ,ce_date_result dr
    ,ce_string_result cs
plan ce1
  where ce1.parent_event_id = data->form_event_id
    and ce1.event_id != ce1.parent_event_id  ;section rows only
    and ce1.valid_until_dt_tm > cnvtdatetime(curdate,curtime)
join ce2
  where ce2.parent_event_id = ce1.event_id
    and ce2.view_level = 1
    and ce2.valid_from_dt_tm  <= cnvtdatetime(curdate,curtime + 1)
    and ce2.valid_until_dt_tm >  cnvtdatetime(curdate,curtime)
    and ce2.result_status_cd in (REQDATA->AUTH_AUTH_CD,REQDATA->AUTH_MODIFIED_CD,REQDATA->AUTH_ALTERED_CD)
join cs
  where cs.event_id = outerjoin(ce2.event_id)
    and cs.valid_from_dt_tm  <= outerjoin(cnvtdatetime(curdate,curtime3))
    and cs.valid_until_dt_tm >  outerjoin(cnvtdatetime(curdate,curtime3))
join dr
  where dr.event_id = outerjoin(ce2.event_id)
    and dr.valid_from_dt_tm  <= outerjoin(cnvtdatetime(curdate,curtime3))
    and dr.valid_until_dt_tm >  outerjoin(cnvtdatetime(curdate,curtime3))
order by ce2.event_cd,ce2.valid_from_dt_tm desc

head ce2.event_id
  data->ce2_event_id = ce2.event_id
  data->ce2_verified_dt = format(ce2.verified_dt_tm,"mm/dd/yyyy;;d")
head ce2.event_cd
  case (ce2.event_cd)
    of CLRDFULLCNTCTSPORTS_CD:
;        data->clrd_cntct_sports = trim(cr.descriptor)
      data->clrd_cntct_sports = trim(cs.string_result_text)
    of CLRDFULLACDMCACTVTY_CD:
;        data->clrd_acdmc_actvty = trim(cr.descriptor)
      data->clrd_acdmc_actvty = trim(cs.string_result_text)
    of CONCUSACCOMCMMNTS_CD:
;      data->concus_accom_cmmnts = trim(cs.string_result_text)
      data->concus_accom_cmmnts = replace(cs.string_result_text,concat(char(13),char(10)),"{NL}")
    of CONCUSCLEARCMMNTS_CD:
;      data->concus_clear_cmmnts = trim(cs.string_result_text)
      data->concus_clear_cmmnts = replace(cs.string_result_text,concat(char(13),char(10)),"{NL}")
    of DTCLRDFULLACDMCACTVTY_CD:
      data->clrd_acdmc_actvty_dt = concat("As of: ",format(dr.result_dt_tm,"mm/dd/yyyy;;d"))
    of DTCLRDFULLCNTCTSPORTS_CD:
      data->clrd_cntct_sports_dt = concat("As of: ",format(dr.result_dt_tm,"mm/dd/yyyy;;d"))
    of SIGNATURE_CD:
      data->signature = trim(cs.string_result_text)
    of COSIGNATURE_CD:
      data->cosignature = trim(cs.string_result_text)
  endcase
with nocounter


select into "nl:"
from clinical_event ce1
    ,clinical_event ce2
    ,ce_coded_result cr
plan ce1
  where ce1.parent_event_id = data->form_event_id
    and ce1.event_id != ce1.parent_event_id  ;section rows only
    and ce1.valid_until_dt_tm > cnvtdatetime(curdate,curtime)
join ce2
  where ce2.parent_event_id = ce1.event_id
    and ce2.view_level = 1
    and ce2.valid_from_dt_tm  <= cnvtdatetime(curdate,curtime + 1)
    and ce2.valid_until_dt_tm >  cnvtdatetime(curdate,curtime)
    and ce2.result_status_cd in (REQDATA->AUTH_AUTH_CD,REQDATA->AUTH_MODIFIED_CD,REQDATA->AUTH_ALTERED_CD)
join cr
  where cr.event_id = outerjoin(ce2.event_id)
    and cr.valid_from_dt_tm  <= outerjoin(cnvtdatetime(curdate,curtime3))
    and cr.valid_until_dt_tm >  outerjoin(cnvtdatetime(curdate,curtime3))
order by ce2.event_cd
        ,ce2.valid_from_dt_tm desc
        ,cr.sequence_nbr
detail
  case (ce2.event_cd)
    of CLRDFULLCNTCTSPORTS_CD:
;        data->clrd_cntct_sports = trim(cr.descriptor)
      if (data->clrd_cntct_sports_cr = " ")
        data->clrd_cntct_sports_cr = trim(cr.descriptor)
      else
        data->clrd_cntct_sports_cr = concat(data->clrd_cntct_sports_cr,"{NL}",trim(cr.descriptor))
      endif
    of CLRDFULLACDMCACTVTY_CD:
;        data->clrd_acdmc_actvty = trim(cr.descriptor)
      if (data->clrd_acdmc_actvty_cr = " ")
        data->clrd_acdmc_actvty_cr = trim(cr.descriptor)
      else
        data->clrd_acdmc_actvty_cr = concat(data->clrd_acdmc_actvty_cr,"{NL}",trim(cr.descriptor))
      endif
  endcase
with nocounter


if (data->clrd_cntct_sports > " ")

  if (data->clrd_cntct_sports_cr = " ")
    set data->clrd_cntct_sports_cr = data->clrd_cntct_sports
  else
    set data->clrd_cntct_sports_cr = concat(data->clrd_cntct_sports_cr,"{NL}",data->clrd_cntct_sports)
  endif

endif

if (data->clrd_acdmc_actvty > " ")

  if (data->clrd_acdmc_actvty_cr = " ")
    set data->clrd_acdmc_actvty_cr = data->clrd_acdmc_actvty
  else
    set data->clrd_acdmc_actvty_cr = concat(data->clrd_acdmc_actvty_cr,"{NL}",data->clrd_acdmc_actvty)
  endif

endif



call echorecord(data)

record rpt
(
  1 text = vc            ;source text
  1 text_formatted = vc  ;formatted return text
  1 msg = vc             ;message string returned to calling script with various informational messages
  1 status = c1          ;returns "S" if succcessful or "F" if failed.
)
/*
set rpt->text = concat("{RTF}{FONT/ARIAL/10}",
                        data->logo->str,"{NL/3}",
                        data->loc_name_addr,"{NL}",
                        data->loc_addr1,"{NL}",
                        data->loc_addr2,"{NL}",
                        data->loc_phone,"{NL/2}",
                        "Name: ",data->name_first," ",data->name_last,"{TAB/2}",
                        "Birth Date: ",data->dob,"{TAB/2}",
                        "Date(s) of Visit: ",data->reg_to_discharge,"{NL/3}",
                        data->name_first," was ",data->enc_type,". Please excuse from school/daycare/work. ",
                        data->he_she," may return on _{NL/2}Restrictions:{NL}{TAB}",
                        "___ Excuse from Physical Education until further notice{NL}{TAB}",
                        "___ Excuse from Physical Education for 3 weeks{NL}{TAB}",
                        "___ May participate in Physical Education without restrictions{NL}{TAB}",
                        "___ May participate in Physical Education with the following restrictions:{NL}{TAB/2}",
                        "___ No contact sports{TAB/2}",
                        "___ No push-ups or pull-ups{TAB}",
                        "___ No weight on arm{NL}{TAB/2}",
                        "___ No endurance running{TAB}",
                        "___ No running or jumping{TAB}",
                        "___ Stay indoors for recess{NL}{TAB/2}",
                        "___ No climbing/playground equipment{TAB/2}",
                        "___ Allow extra time between classes{NL}{TAB/2}",
                        "___ If in pain, allow alternate activity{NL}{TAB}",
                        "___ Please provide elevator pass for _{NL}{TAB}",
                        "___ Please allow for a book buddy or rolling backpack{NL}{TAB}",
                        "___ Other: _{NL/3}",
                        "Comments: _{NL/3}Signature: ",data->user,"{END}")
*/

set rpt->text =
        concat("{RTF}{FONT/ARIAL/10}",
               data->logo->str,"{NL/3}",
               data->loc_name_addr,"{NL}",
               data->loc_addr1,"{NL}",
               data->loc_addr2,"{NL}",
               data->loc_phone,"{NL/2}",
               "Name: ",data->name_first," ",data->name_last,"{TAB/2}",
               "Birth Date: ",data->dob,"{TAB/2}",
               "Date(s) of Visit: ",data->reg_to_discharge,"{NL/3}",

               data->name_first," is cleared for a complete return to full contact sport participation:{NL/2}",

;               "As of: ",data->ce2_verified_dt,"{NL/2}",
               data->clrd_cntct_sports_dt,"{NL/2}",

               data->clrd_cntct_sports_cr,"{NL/2}",

               "The student is instructed to stop play immediately and notify the coach or athletic trainer{NL}",
               "should the symptoms return or if they should become symptomatic with any additional{NL}",
               "activities.{NL/2}",

               "Concussion Clearance Comments: ",data->concus_clear_cmmnts,"{NL/2}",

               data->name_first," is cleared for a complete return to full academic activity without accommodations:","{NL/2}",

;               "As of: ",data->ce2_verified_dt,"{NL/2}",
               data->clrd_acdmc_actvty_dt,"{NL/2}",

               data->clrd_acdmc_actvty_cr,"{NL/2}",

               "Concussion Accommodations Comments: ",data->concus_accom_cmmnts,"{NL/2}",

               "Electronically Signed by: ",data->signature,"{NL}",
               "Electronically Co-Signed by: ",data->cosignature,"{NL/3}",

               "{TAB/2}Children's Concussion, Neurosurgery & Rehabilitation Clinics{NL}",
               "{TAB/3}A division of the Neuroscience Center{NL}",
               "{TAB/3}651-220-5230{END}")


execute kids_rpt_generator

set reply->text = rpt->text_formatted
set reply->status_data->status = rpt->status

;call echorecord(rpt)
;call err_check(1)
;call echo(rpt->text_formatted)

end
go
 
