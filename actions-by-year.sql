SELECT
  sa.record_description,
  sa.create_dt_tm,
  sra.action_name,
  update_time = FORMAT (saa.action_dt_tm, 'yyyy-MM-dd HH:mm'),
  srm.macro_name
FROM
  sa_anesthesia_record sa,
  sa_action saa,
  sa_ref_action sra,
  sa_macro sm,
  sa_ref_macro srm 
  PLAN sa
  JOIN saa
WHERE
  sa.sa_anesthesia_record_id = saa.sa_anesthesia_record_id
  AND sa.record_description NOT LIKE 'CE%'
  AND YEAR (sa.create_dt_tm) IN (2022, 2023)
  JOIN sra
WHERE
  saa.sa_ref_action_id = sra.sa_ref_action_id
  JOIN sm
WHERE
  saa.sa_macro_id = sm.sa_macro_id
  JOIN srm
WHERE
  sm.sa_ref_macro_id = srm.sa_ref_macro_id
WITH
  TIME = 180,
  MAXREC = 100000;