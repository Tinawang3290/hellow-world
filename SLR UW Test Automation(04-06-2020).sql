WITH F0 AS (
SELECT * FROM(
  SELECT  
  s.application_uuid.value AS Application_UUID_Value,
  CASE WHEN DATE(app_start_date) = '2020-03-26' THEN sla.kafka_timestamp_ts ELSE app_start_date END AS App_Created_Dt,
  sla.event_completed AS App_Status,   
  s.decision AS UW_Decision,
  d.code AS Decline_Code, 
  d.reason AS Decline_Reason,
  sla.hard_fico_score AS FICO,
  sla.citizenship AS Citizenship,
  (CAST(s.uw_packet.credit_score AS FLOAT64)<680 OR s.uw_packet.credit_score IS NULL OR CAST(s.uw_packet.credit_score AS FLOAT64) = 0) OR s.uw_packet.credit_score IN (9000,9001,9002,9003) AS CREDIT_SCORE_Rejection,
  CAST(s.selected_offer.post_loan_dti.value AS FLOAT64) AS Post_Loan_DTI,
  CAST(IFNULL(s.selected_offer.post_loan_dti.value,o.pre_loan_dti.value) AS FLOAT64) > 0.65 AS MAXIMUM_DTI_Rejection,
  (loan_amount > 250000 or loan_amount < 5000)  AS LOAN_SIZE_Rejection,
  citizenship NOT IN ('CITIZEN', 'PERMANENT_RESIDENT') AS CITIZENSHIP_Rejection,
  IQT9416 > 3 AS INQ3MONTHS_Rejection,
  (ALS8220 < 12 OR ALX8220 < 12) AS THIN_FILE_Rejection,
  STU8151 < 13 OR (STU6200 >30 AND STU6200 <= 400) AS STUDENT_LOANS_Rejection,
  ALL0400 > 15 AND ((ALL0337/ALL0400) > 0.3) AS NEW_CREDIT_TRADES_RATIO_Rejection,
  (REV2326 + ILN2326 + MTA2326) > 0 AS INSTALLMENT_AND_REVOLVING_PAYMENTS_Rejection,
  (ALL9221 <= 84 OR ALL9120 > (ALL9121 + ALL9122)) AS BANKRUPTCY_Rejection,
  ((COL5064 + COL5067 + COL5068 + COL5069) > 500) AS COLLECTIONS_Rejection,
  ALL5361 > 1500 AS MAJOR_DEROGATORY_Rejection, 
  
  CAST(uw_packet.revolving_credit_card_debt.amount AS FLOAT64) AS Revolving_Credit_Card_Debt,  
 (((((BCC5830 - BCC5838)/0.04)*0.025) + BCC5838) - (BCC5830 - BCX5830)) AS Z,
  ROUND(CAST(uw_packet.total_revolving_debt.amount AS FLOAT64),4) AS Total_Revolving_Debt, 
  CASE 
  WHEN  BCC5830 <= BCX5830 AND uw_packet.credit_score BETWEEN 680 AND 739 THEN  ROUND(( (((((BCC5830 - BCC5838)/0.04)*0.025) + BCC5838) - (BCC5830 - BCX5830)) + (BAX5030 - BCX5030)*0.025 + RTR5030 * 0.025), 4)
  WHEN BCC5830 <= BCX5830 AND uw_packet.credit_score >= 740 THEN ROUND( (((((BCC5830 - BCC5838)/0.04)*0.025) + BCC5838) - (BCC5830 - BCX5830)) + RTR5030 * 0.025, 4)
  END AS T_Monthly_Revolving_Debt,
  
  CAST(uw_packet.total_installment_debt.amount AS FLOAT64) AS Total_Installment_Debt,
  
  CASE 
  WHEN BCC5830 <= BCX5830 AND uw_packet.credit_score BETWEEN 680 AND 739 THEN ROUND(ILN5820 -ILN5824, 4)
  WHEN BCC5830 <= BCX5830 AND uw_packet.credit_score >= 740 THEN ROUND( AUA5820 + STU5020*0.0035 + (ILN5820 - (STU5820 + AUA5820)) - ILN5824,4)
  END AS T_Monthly_Installment_Debt,
  
  CAST(uw_packet.total_mortgage_debt.amount AS FLOAT64) AS Total_Mortgage_Debt,  
  CASE 
  WHEN BCC5830 <= BCX5830 AND uw_packet.credit_score BETWEEN 680 AND 739 THEN ROUND(MTF5820 + MTS5820 + HLC5820, 4)
  WHEN BCC5830 <= BCX5830 AND uw_packet.credit_score >= 740 THEN ROUND(MTF5820 + MTS5820 + HLC5820, 4)
  END AS T_Monthly_Mortgage_Debt,  
  
  CAST(uw_packet.msa_housing_expense.amount AS FLOAT64) AS MSA_Housing_Expense, 
  CAST(uw_packet.housing_expense.amount AS FLOAT64) AS Housing_Expense, 
 
  CASE 
  WHEN MTX5839 > 0 AND ((DATE(App_start_Date) >= '2020-01-17' AND DATE(app_start_date) != '2020-03-26')  OR  (DATE(app_start_date) = '2020-03-26' AND DATE(sla.kafka_timestamp_ts) >= '2020-01-17')) THEN MTX5839
  WHEN MTX5839 > 0 AND MTJ0416 > 0 AND (DATE(App_start_Date) < '2020-01-17' OR (DATE(app_start_date) = '2020-03-26' AND DATE(sla.kafka_timestamp_ts) < '2020-01-17')) THEN MTX5839* 0.5
  WHEN MTX5839 > 0 AND MTJ0416 <= 0 AND (DATE(App_start_Date) < '2020-01-17'  OR  (DATE(app_start_date) = '2020-03-26' AND DATE(sla.kafka_timestamp_ts) < '2020-01-17')) THEN MTX5839
  ELSE CAST(uw_packet.msa_housing_expense.amount AS FLOAT64)
  END AS T_Housing_Expense,

  CAST(uw_packet.stated_monthly_income.amount AS FLOAT64) AS Stated_Monthly_Income,
  CAST( sla.stated_monthly_income AS FLOAT64) AS Offer_Stated_Monthly_Income, 
 
  CAST(uw_packet.tax_reduction_factor.value AS FLOAT64) AS Tax_Reduction_Factor,
  CAST(uw_packet.verified_monthly_income.amount AS FLOAT64) AS Verified_Monthly_Income,
  CAST( sla.verified_monthly_income_amount AS FLOAT64) AS Offer_Verified_Monthly_Income, 
  
  CASE 
  WHEN( CAST(uw_packet.verified_monthly_income.amount AS FLOAT64) > CAST(uw_packet.stated_monthly_income.amount AS FLOAT64) 
  OR  CAST(uw_packet.verified_monthly_income.amount AS FLOAT64) = 0)
  THEN CAST(uw_packet.stated_monthly_income.amount AS FLOAT64) 
  ELSE CAST(uw_packet.verified_monthly_income.amount AS FLOAT64)
  END AS Calc_Income, 

  CAST( loan_term AS FLOAT64) AS Offer_Term,
  CAST( app_rate_with_auto AS FLOAT64) AS Offer_Autopay_Rate,
  CAST( app_rate_wo_auto AS FLOAT64) AS Offer_Non_Autopay_Rate,
  CAST( pre_loan_free_cash_flow AS FLOAT64) AS Offer_Pre_Loan_Cashflow,
  CAST( sla.post_loan_dti AS FLOAT64) AS Offer_Post_Loan_DTI,
  CAST( post_loan_free_cash_flow AS FLOAT64) AS Offer_Post_Loan_Cashflow,
  CAST(uw_packet.transportation_expense.amount AS FLOAT64) AS Transportation_Expense,
  CASE
  WHEN AUT5820 > 0 THEN AUT5820 + 200
  ELSE 350
  END AS T_Transportation_Expense,
  
  CAST(uw_packet.bureau_debt.amount AS FLOAT64) AS Bureau_Debt,
  
  CASE 
  WHEN DATE(App_start_Date) >= '2020-01-24' AND DATE(App_start_Date) != '2020-03-26' OR  (DATE(app_start_date) = '2020-03-26' AND sla.kafka_timestamp_ts >= '2020-01-24') THEN (ALL5830  - MTA5830_new  - STU5820)
  WHEN DATE(App_start_Date) >= '2020-01-17' AND  DATE(App_start_Date) < '2020-01-24' OR (DATE(app_start_date) = '2020-03-26' AND sla.kafka_timestamp_ts >= '2020-01-17' AND sla.kafka_timestamp_ts < '2020-01-24') THEN (ALL5830 - MTA5830_new - AUT5820 - STU5820)
  ELSE (ALL5830 - MTX5839 - AUT5820)
  END AS T_Additional_Bureau_Debt,
  
  CAST(uw_packet.amt_to_refi.amount AS FLOAT64) AS Amt_To_Refi,
  CAST(amount_to_borrow.amount AS FLOAT64) AS Amt_To_Borrow,
  loan_amount_requested AS Amt_Requested,
  CAST(uw_packet.total_bureau_reported_sl_balance.amount AS FLOAT64) AS Total_Bureau_Reported_SL_Balance,
  uw_packet.origination_state AS Origination_State,
  uw_packet.zip_code AS Zip_Code,
  CAST(sla.pre_loan_dti AS FLOAT64) AS Pre_Loan_DTI,
  ROUND(CAST(uw_packet.current_student_loan_payment.amount AS FLOAT64),3) AS Current_Student_Loan_Payment,
  ROUND(CAST(uw_packet.monthly_debt.amount AS FLOAT64),4) AS Monthly_Debt,
  IQT9416, ALS8220, ALX8220, STU8151, STU6200, ALL0400, ALL0337, REV2326, ILN2326, MTA2326, ALL9221, ALL9120, ALL9121, ALL9122, COL5068, COL5069,ALL5830,BCX5030,MTA5830,
  MTX5839, BCC5830, BCX5830, ALX5830, MTA5830_new, ILN5824, BAX5030, RTR5030, BCC5838, AUA5820, STU5020, ILN5820, STU5820, MTF5820, MTS5820, HLC5820, COL5064, ALL5361, AUT5820, MTJ0416,
  ROW_NUMBER() OVER (PARTITION BY application_uuid.value ORDER BY s.kafka_timestamp_ts DESC) AS R 
FROM `figure-production.staging_evolved.uw_data_proto_external_decision_slr_r1` s
JOIN `figure-production.reporting.lkup_slr_application` sla ON sla.application_uuid_value = s.application_uuid.value
JOIN (SELECT *, CASE WHEN MTA5830 in(999999998, 999999996) THEN 0 ELSE MTA5830 END AS MTA5830_new FROM `reporting.lkup_credit_attr` WHERE credit_type = 'Hard Credit') lca ON lca.application_uuid_value = s.application_uuid.value
LEFT JOIN UNNEST(offers) AS O
LEFT JOIN UNNEST(decline_reasons) AS D
ORDER BY s.kafka_timestamp_ts DESC) 
WHERE R = 1),

F1 AS (
SELECT 
  *,
  ROUND((STU5020 * 0.0638/12)/ (1 - POW((1 + 0.0638/12), -120)),3) AS T_Pre_Refi_Student_Loan_Payment_Bureau,
  ROUND((Amt_To_Refi * 0.0638/12)/ (1 - POW((1 + 0.0638/12), -120)),3) AS T_Pre_Refi_Student_Loan_Payment_Req,

  CASE WHEN Offer_Non_Autopay_Rate != 0 AND offer_term != 0
  THEN ROUND((STU5020 * Offer_Non_Autopay_Rate/12)/ (1 - POW((1 +  Offer_Non_Autopay_Rate/12), -(Offer_Term*12))),3) 
  ELSE NULL 
  END AS T_Offer_Post_Refi_Student_Loan_Payment_Bureau,
  
  CASE WHEN Offer_Non_Autopay_Rate != 0 AND offer_term != 0
  THEN ROUND((Amt_To_Refi * Offer_Non_Autopay_Rate/12)/ (1 - POW((1 + Offer_Non_Autopay_Rate/12), -(Offer_Term*12))),3) 
  ELSE NULL 
  END AS T_Offer_Post_Refi_Student_Loan_Payment_Req,  

  CASE 
  WHEN Amt_To_Refi >= STU5020 AND Offer_Non_Autopay_Rate != 0 AND offer_term != 0 THEN ROUND((Amt_To_Refi * Offer_Non_Autopay_Rate/12)/ (1 - POW((1 + Offer_Non_Autopay_Rate/12), -(Offer_Term*12))),3)
  WHEN Amt_To_Refi < STU5020 AND Offer_Non_Autopay_Rate != 0 AND offer_term != 0  THEN ROUND((STU5020 * Offer_Non_Autopay_Rate/12)/ (1 - POW((1 +  Offer_Non_Autopay_Rate/12), -(Offer_Term*12))),3) + ROUND((STU5020 * 0.0638/12)/ (1 - POW((1 + 0.0638/12), -120)),3)*(1-Amt_To_Refi/STU5020)
  ELSE NULL
  END AS T_Offer_Post_Refi_Student_Loan_Payment,
  CASE
  WHEN BCC5830 > BCX5830 THEN ROUND((ALX5830 - ILN5824),4)
  ELSE ROUND((T_Monthly_Revolving_Debt + T_Monthly_Installment_Debt + T_Monthly_Mortgage_Debt +  T_Housing_Expense),4)
  END AS T_Monthly_Debt,
  
  CASE
  WHEN (CREDIT_SCORE_Rejection IS TRUE OR LOAN_SIZE_Rejection IS TRUE OR Citizenship_Rejection IS TRUE OR MAXIMUM_DTI_Rejection IS TRUE OR INQ3MONTHS_Rejection IS TRUE OR THIN_FILE_Rejection IS TRUE OR STUDENT_LOANS_Rejection IS TRUE OR NEW_CREDIT_TRADES_RATIO_Rejection IS TRUE 
  OR INSTALLMENT_AND_REVOLVING_PAYMENTS_Rejection IS TRUE OR BANKRUPTCY_Rejection IS TRUE OR COLLECTIONS_Rejection IS TRUE OR MAJOR_DEROGATORY_Rejection IS TRUE) THEN  'True'
  ELSE 'False'
  END AS T_Credit_Hard_Knock_Outs,
  CASE 
  WHEN LOAN_SIZE_Rejection IS TRUE AND UW_Decision != 'DECLINE' AND App_Status NOT IN ('Cancelled', 'Declined') THEN 'Loan_Size_Rejection_Failure'
  WHEN Citizenship_Rejection IS TRUE AND UW_Decision != 'DECLINE' AND App_Status NOT IN ('Cancelled', 'Declined') THEN 'Citizenship_Rejection_Failure'
  WHEN CREDIT_SCORE_Rejection IS TRUE AND UW_Decision != 'DECLINE' AND App_Status NOT IN ('Cancelled', 'Declined') THEN 'CREDIT_SCORE_Rejection_Failure'
  WHEN MAXIMUM_DTI_Rejection IS TRUE AND UW_Decision != 'DECLINE' AND App_Status NOT IN ('Cancelled', 'Declined') THEN 'MAXIMUM_DTI_Rejection_Failure'
  WHEN INQ3MONTHS_Rejection IS TRUE AND UW_Decision != 'DECLINE' AND App_Status NOT IN ('Cancelled', 'Declined') THEN 'INQ3MONTHS_Rejection_Failure'
  WHEN THIN_FILE_Rejection IS TRUE AND UW_Decision != 'DECLINE' AND App_Status NOT IN ('Cancelled', 'Declined') THEN 'THIN_FILE_Rejection_Failure'
  WHEN STUDENT_LOANS_Rejection IS TRUE AND UW_Decision != 'DECLINE' AND App_Status NOT IN ('Cancelled', 'Declined') THEN 'STUDENT_LOANS_Rejection_Failure'
  WHEN NEW_CREDIT_TRADES_RATIO_Rejection IS TRUE AND UW_Decision != 'DECLINE' AND App_Status NOT IN ('Cancelled', 'Declined') THEN 'NEW_CREDIT_TRADES_RATIO_Rejection_Failure'
  WHEN INSTALLMENT_AND_REVOLVING_PAYMENTS_Rejection IS TRUE AND UW_Decision != 'DECLINE' AND App_Status NOT IN ('Cancelled', 'Declined') THEN 'INSTALLMENT_AND_REVOLVING_PAYMENTS_Rejection_Failure'
  WHEN BANKRUPTCY_Rejection IS TRUE AND UW_Decision != 'DECLINE' AND App_Status NOT IN ('Cancelled', 'Declined') THEN 'BANKRUPTCY_Rejection_Failure'
  WHEN COLLECTIONS_Rejection IS TRUE AND UW_Decision != 'DECLINE' AND App_Status NOT IN ('Cancelled', 'Declined') THEN 'COLLECTIONS_Rejection_Failure'
  WHEN MAJOR_DEROGATORY_Rejection IS TRUE AND UW_Decision != 'DECLINE' AND App_Status NOT IN ('Cancelled', 'Declined') THEN 'MAJOR_DEROGATORY_Rejection_Failure'
  ELSE 'Pass'
  END AS T_Credit_Hard_Knock_Outs_Failure,

  CASE 
  WHEN Amt_To_Refi >= Total_Bureau_Reported_SL_Balance AND DATE(App_Created_Dt) >= '2020-01-24' THEN ROUND((Calc_Income * Tax_Reduction_Factor - T_Housing_Expense - T_Additional_Bureau_Debt - ROUND((Amt_To_Refi * 0.0638/12)/ (1 - POW((1 + 0.0638/12), -120)),3)),3)
  WHEN Amt_To_Refi < Total_Bureau_Reported_SL_Balance AND DATE(App_Created_Dt) >= '2020-01-24' THEN ROUND((Calc_Income * Tax_Reduction_Factor - T_Housing_Expense - T_Additional_Bureau_Debt - ROUND((Total_Bureau_Reported_SL_Balance * 0.0638/12)/ (1 - POW((1 + 0.0638/12), -120)),3)),3)
  WHEN DATE(App_Created_Dt) < '2020-01-24' THEN ROUND((Calc_Income * Tax_Reduction_Factor - T_Housing_Expense- T_Transportation_Expense - T_Additional_Bureau_Debt - ROUND((Amt_To_Refi * 0.0638/12)/ (1 - POW((1 + 0.0638/12), -120)),3)),3)
  END AS T_Pre_Loan_FCF,
  
  CASE 
  WHEN Amt_To_Refi >= Total_Bureau_Reported_SL_Balance AND DATE(App_Created_Dt) >= '2020-01-24' AND Offer_Non_Autopay_Rate != 0 AND offer_term != 0 THEN ROUND((Calc_Income * Tax_Reduction_Factor - T_Housing_Expense - T_Additional_Bureau_Debt - ROUND((Amt_To_Refi * Offer_Non_Autopay_Rate/12)/ (1 - POW((1 + Offer_Non_Autopay_Rate/12), -(offer_Term*12))),3)),3)
  WHEN Amt_To_Refi < Total_Bureau_Reported_SL_Balance AND DATE(App_Created_Dt) >= '2020-01-24' AND Total_Bureau_Reported_SL_Balance != 0 AND Offer_Non_Autopay_Rate != 0 AND offer_term != 0  THEN ROUND((Calc_Income * Tax_Reduction_Factor - T_Housing_Expense - T_Additional_Bureau_Debt - ROUND((Amt_To_Refi * Offer_Non_Autopay_Rate/12)/ (1 - POW((1 + Offer_Non_Autopay_Rate/12), -(offer_Term*12))),3) - 
  ROUND((Total_Bureau_Reported_SL_Balance * 0.0638/12)/ (1 - POW((1 + 0.0638/12), -120)),3) * (1 - Amt_To_Refi/Total_Bureau_Reported_SL_Balance) ),3)
  WHEN DATE(App_Created_Dt) < '2020-01-24' AND Offer_Non_Autopay_Rate != 0 AND offer_term != 0 THEN  ROUND((Calc_Income * Tax_Reduction_Factor - T_Housing_Expense - T_Transportation_Expense - T_Additional_Bureau_Debt - ROUND((Amt_To_Refi * Offer_Non_Autopay_Rate/12)/ (1 - POW((1 + Offer_Non_Autopay_Rate/12), -(Offer_Term*12))),3)),3)
  END AS T_Offer_Post_Loan_FCF
  FROM F0),

F2 AS(
SELECT 
  Application_UUID_Value,
  App_Created_Dt,
  App_Status,
  UW_Decision,
  Decline_Code, 
  Decline_Reason,
  FICO, BCC5838, BCC5830,BCX5830, RTR5030, BAX5030, BCX5030, ILN5820, ILN5824, ALX5830, AUA5820, STU5020, STU5820, MTF5820, MTS5820,
  HLC5820, ALL5830, MTA5830, MTX5839, AUT5820, MTJ0416,IQT9416, MTA5830_new,
  
  T_Credit_Hard_Knock_Outs,
  T_Credit_Hard_Knock_Outs_Failure,
  Revolving_Credit_Card_Debt,
  Z,
  CASE 
  WHEN ROUND(Z,0) = ROUND(Revolving_Credit_Card_Debt,0) THEN 'Match'
  WHEN ROUND(Z,0) != ROUND(Revolving_Credit_Card_Debt,0) THEN 'Unmatch'
  ELSE 'Unavailable'
  END AS Credit_Card_Debt_Match,
  
  Total_Revolving_Debt,
  T_Monthly_Revolving_Debt,
  
  CASE 
  WHEN ROUND(Total_Revolving_Debt,0) = ROUND(T_Monthly_Revolving_Debt,0) THEN 'Match' 
  WHEN ROUND(Total_Revolving_Debt,0) != ROUND(T_Monthly_Revolving_Debt,0) THEN 'Unmatch' 
  ELSE 'Unavailable'
  END AS Total_Revolving_Debt_Match,
  
  Total_Installment_Debt,
  T_Monthly_Installment_Debt,
  CASE 
  WHEN ROUND(Total_Installment_Debt, 0) = ROUND(T_Monthly_Installment_Debt,0) THEN 'Match'
  WHEN ROUND(Total_Installment_Debt,0) != ROUND(T_Monthly_Installment_Debt,0) THEN 'Unmatch'
  ELSE 'Unavailable'
  END AS Total_Installment_Debt_Match,
  
  Total_Mortgage_Debt,
  T_Monthly_Mortgage_Debt, 
  
  CASE 
  WHEN ROUND(Total_Mortgage_Debt,0) = ROUND(T_Monthly_Mortgage_Debt,0) THEN 'Match'
  WHEN ROUND(Total_Mortgage_Debt,0) != ROUND(T_Monthly_Mortgage_Debt,0) THEN 'Unmatch'
  ELSE 'Unavailable'
  END AS Total_Mortgage_Debt_Match,
  
  Transportation_Expense,
  T_Transportation_Expense,
  CASE
  WHEN ROUND(Transportation_Expense,0) = ROUND(T_Transportation_Expense,0) THEN 'Match'
  WHEN ROUND(Transportation_Expense,0) != ROUND(T_Transportation_Expense,0) THEN 'Unmatch'
  ELSE 'Unavailable'
  END AS Transportation_Expense_Match,
  
  Bureau_Debt,
  T_Additional_Bureau_Debt,
  
  CASE 
  WHEN ROUND(Bureau_Debt,0) = ROUND(T_Additional_Bureau_Debt,0) THEN 'Match'
  WHEN ROUND(Bureau_Debt,0) != ROUND(T_Additional_Bureau_Debt,0) THEN 'Unmatch'
  ELSE 'Unavailable'
  END AS Bureau_Debt_Match,
  
  MSA_Housing_Expense,
  Housing_Expense,
  T_Housing_Expense,
  
  CASE 
  WHEN Housing_Expense = T_Housing_Expense THEN 'Match'
  WHEN Housing_Expense != T_Housing_Expense THEN 'Unmatch'
  ELSE 'Unavailable'
  END AS Housing_Expense_Match,
  
  Stated_Monthly_Income,
  Offer_Verified_Monthly_Income,
  Calc_Income,
  Monthly_Debt,
  T_Monthly_Debt,  
  
  CASE 
  WHEN ROUND(Monthly_Debt,0) = ROUND(T_Monthly_Debt,0) THEN 'Match'
  WHEN ROUND(Monthly_Debt,0) != ROUND(T_Monthly_Debt,0) THEN 'Unmatch'
  ELSE 'Unavailable'
  END AS Monthly_Debt_Match,
  
  Total_Bureau_Reported_SL_Balance,
  CASE WHEN Amt_To_Refi>= Amt_To_Borrow THEN Amt_To_Refi
  ELSE Amt_To_Borrow
  END AS Amt_To_Borrow,
  Amt_Requested,
  Current_Student_Loan_Payment,
  T_Pre_Refi_Student_Loan_Payment_Req,
  CASE 
  WHEN ROUND(Current_Student_Loan_Payment,0) =  ROUND(T_Pre_Refi_Student_Loan_Payment_Req,0) THEN 'Match'
  WHEN ROUND(Current_Student_Loan_Payment,0) !=  ROUND(T_Pre_Refi_Student_Loan_Payment_Req,0) THEN 'Unmatch'
  ELSE 'Unavailable'
  END AS Pre_Refi_Student_Loan_Payment_Req_Match,  
  
  T_Offer_Post_Refi_Student_Loan_Payment_Bureau,
  T_Offer_Post_Refi_Student_Loan_Payment_Req,
  T_Offer_Post_Refi_Student_Loan_Payment, 

  Pre_Loan_DTI,  
  
  CASE 
  WHEN (Offer_Verified_Monthly_Income = 0 OR Offer_Verified_Monthly_Income > Stated_Monthly_Income) AND Stated_Monthly_Income != 0 THEN ROUND(T_Monthly_Debt / Stated_Monthly_Income, 4) 
  ELSE ROUND(T_Monthly_Debt / Offer_Verified_Monthly_Income, 4)
  END AS T_Pre_Loan_DTI,
 
  CASE 
  WHEN Calc_Income != 0 AND Pre_Loan_DTI = ROUND(T_Monthly_Debt/Calc_Income, 4) THEN 'Match'
  WHEN Calc_Income != 0 AND Pre_Loan_DTI != ROUND(T_Monthly_Debt/Calc_Income, 4) THEN 'Unmatch'
  ELSE 'Unavailble'
  END AS Pre_Loan_DTI_Match,
  
  CASE 
  WHEN (T_Credit_Hard_Knock_Outs != 'True') AND (T_Monthly_Debt/Stated_Monthly_Income) > 0.65 AND UW_Decision != 'DECLINE' AND App_status NOT IN ('Cancelled','Declined')  THEN 'Pre_Loan_DTI_Decline_Failure' 
  WHEN (T_Monthly_Debt/Stated_Monthly_Income) IS NULL THEN 'Unavailable'
  ELSE 'Pass'
  END AS T_Pre_Loan_DTI_Decline_Failure,
  
  Offer_Term,
  Offer_Autopay_Rate,
  Offer_Non_Autopay_Rate,
  Offer_Pre_Loan_Cashflow,
  T_Pre_Loan_FCF,
  
  CASE 
  WHEN ROUND(Offer_Pre_Loan_Cashflow, 0) = ROUND(T_Pre_Loan_FCF,0) THEN 'Match'
  WHEN ROUND(Offer_Pre_Loan_Cashflow, 0) != ROUND(T_Pre_Loan_FCF,0) THEN 'Unmatch'
  ELSE 'Unavailable'
  END AS Pre_Loan_FCF_Match,
  
  Offer_Post_Loan_DTI,
  Offer_Post_Loan_Cashflow,
  T_Offer_Post_Loan_FCF,
  
  CASE 
  WHEN ROUND(Offer_Post_Loan_Cashflow,0) = ROUND(T_Offer_Post_Loan_FCF,0) THEN 'Match'
  WHEN ROUND(Offer_Post_Loan_Cashflow,0) != ROUND(T_Offer_Post_Loan_FCF,0) THEN 'Unmatch'
  ELSE 'Unavailable'
  END AS Post_Loan_FCF_Match,
  
  CASE 
  WHEN (T_Credit_Hard_Knock_Outs_Failure = 'Pass') AND ((T_Monthly_Debt/Calc_Income) <= 0.65 OR (T_Monthly_Debt/Calc_Income) IS NULL) AND T_Offer_Post_Loan_FCF < 1500 AND UW_Decision != 'DECLINE' AND App_status NOT IN ('Cancelled','Declined')  THEN 'Post_Loan_FCF_Decline_Failure'
  WHEN T_Offer_Post_Loan_FCF IS NULL THEN 'Unavailable'
  ELSE 'Pass'
  END AS T_FCF_Decline_Failure
FROM F1
ORDER BY 	App_Created_Dt DESC 
), 

F3 AS (
SELECT 
  *,
  CASE 
  WHEN (T_Credit_Hard_Knock_Outs_Failure != 'Pass' OR  T_Pre_Loan_DTI_Decline_Failure != 'Pass' OR T_FCF_Decline_Failure != 'Pass') AND App_Status NOT IN ('Declined', 'Cancelled') THEN 'App should have been declined, while were not declined'
  WHEN (T_Credit_Hard_Knock_Outs != 'True' AND T_Pre_Loan_DTI_Decline_Failure = 'Pass' AND T_FCF_Decline_Failure = 'Pass') AND UW_Decision = 'DECLINE' AND  App_Status = 'Declined' THEN 'App should have not been declined, while were declined'
  ELSE 'Pass'
  END AS T_UW_False_Decline
FROM F2)

SELECT * FROM F3
WHERE T_UW_False_Decline != 'Pass'

