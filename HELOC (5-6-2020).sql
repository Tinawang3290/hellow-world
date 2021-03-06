WITH Credit AS (
SELECT  
  * 
FROM(
SELECT 
  ROW_NUMBER() OVER (PARTITION BY lca.application_uuid_value ORDER BY application_start_date DESC) AS r,
  CAST(create_timestamp AS DATE) AS App_Start_Date,
  lca.application_uuid_value AS App_UUID,
  la.app_amount AS App_Amount,
  la.status AS App_Status,
  la.uw_decision_decision AS UW_Decision,
  la.adverse_action_declineReasons AS Decline_Reasons,
  CAST(la.credit_soft_fico AS FLOAT64) AS FICO,
  sud.age AS Age,
  la.app_term AS App_Term,
  la.stated_monthly_income AS Stated_Monthly_Income,
  CAST(MTA2126 AS FLOAT64) AS MTA2126,
  CAST(COL3211 AS FLOAT64) AS COL3211,
  CAST(ALM6270 AS FLOAT64) AS ALM6270,
  CAST(IQT9425 AS FLOAT64) AS IQT9425,
  CAST(IQM9415 AS FLOAT64) AS IQM9415,
  CAST(IQA9415 AS FLOAT64) AS IQA9415,
  CAST(IQF9415 AS FLOAT64) AS IQF9415,
  CAST(ALL9220 AS FLOAT64) AS ALL9220,
  CAST(ALL9120 AS FLOAT64) AS ALL9120, 
  CAST(ALL9121 AS FLOAT64) AS ALL9121,
  CAST(ALL9122 AS FLOAT64) AS ALL9122,
  CAST(MTF8169 AS FLOAT64) AS MTF8169,
  CAST(BCC5830 AS FLOAT64) AS BCC5830,
  CAST(BCX5830 AS FLOAT64) AS BCX5830,
  CAST(ALX5830 AS FLOAT64) AS ALX5830,
  CAST(ILN5824 AS FLOAT64) AS ILN5824,
  CAST(subcode AS FLOAT64) AS FACTA_Subcode, 
  d.description AS Experian_Message,
  
  CASE 
  WHEN (App_Amount < 15000 
  OR 
  (CAST(la.credit_soft_fico AS FLOAT64) BETWEEN 620 AND 679 AND App_Amount > 50000) 
  OR 
  (CAST(la.credit_soft_fico AS FLOAT64) BETWEEN 680 AND 759 AND App_Amount > 100000)
  OR 
  (CAST(la.credit_soft_fico AS FLOAT64) >=760 AND App_Amount > 150000)) AND la.uw_decision_decision != 'DECLINE' AND la.status NOT IN ('DECLINED', 'CANCELLED') THEN 'Loan_Size_Knockout_Failure' 
  WHEN (((CAST(la.credit_soft_fico AS FLOAT64) < 620 AND DATE(application_start_date) <= '2020-04-28') OR (CAST(la.credit_soft_fico AS FLOAT64) < 680 AND la.profile_state != 'OK' AND DATE(application_start_date) > '2020-04-28') OR (CAST(la.credit_soft_fico AS FLOAT64) < 720 AND la.profile_state = 'OK' AND DATE(application_start_date) > '2020-04-28')) 
  OR CAST(la.credit_soft_fico AS FLOAT64) > 850) OR CAST(la.credit_soft_fico AS FLOAT64) IN (9000,9001,9002,9003)
  AND la.uw_decision_decision != 'DECLINE' AND la.status NOT IN ('DECLINED', 'CANCELLED') THEN 'FICO_Knockout_Failure'
  WHEN MTA2126 > 0 AND la.uw_decision_decision != 'DECLINE' AND la.status NOT IN ('DECLINED', 'CANCELLED') THEN 'Delinquent_30mdy_6mo_Knockout_Failure' 
  WHEN COL3211 > 0 AND la.uw_decision_decision != 'DECLINE' AND la.status NOT IN ('DECLINED', 'CANCELLED') THEN 'Non_Medical_Collections_Knockout_Failure'
  WHEN ALM6270 >= 60 AND la.uw_decision_decision != 'DECLINE' AND la.status NOT IN ('DECLINED', 'CANCELLED') THEN 'Worst_Trade_Status_12mo_non_medical_Knockout_Failure'
  WHEN IQT9425 - ( IQM9415 + IQA9415 ) >= 6 AND la.uw_decision_decision != 'DECLINE' AND la.status NOT IN ('DECLINED', 'CANCELLED') THEN 'Inquiries_Num_6mo_Knockout_Failure'
  WHEN IQF9415 > 2 AND la.uw_decision_decision != 'DECLINE' AND la.status NOT IN ('DECLINED', 'CANCELLED') THEN 'Finance_Inquiries_Num_No_Exceed_2_Knockout_Failure'
  WHEN ((ALL9220 <= 60 AND DATE(application_start_date) >= '2020-04-02') OR (ALL9220 <= 24 AND DATE(application_start_date) < '2020-04-02')) AND la.uw_decision_decision != 'DECLINE' AND la.status NOT IN ('DECLINED', 'CANCELLED') THEN 'No_Bankruptcy_24mo_Knockout_Failure'
  WHEN ((ALL9120 >= 1 AND ALL9120 > (ALL9121 + ALL9122) AND DATE(application_start_date) >= '2020-04-02')) AND la.uw_decision_decision != 'DECLINE' AND la.status NOT IN ('DECLINED', 'CANCELLED') THEN 'Non_Discharged/Dismissed Bankruptcy Filings_Knockout_Failure'
  WHEN MTF8169 <= 60 AND la.uw_decision_decision != 'DECLINE' AND la.status NOT IN ('DECLINED', 'CANCELLED') THEN 'No_Foreclosure_60mo_Knockout_Failure'
  WHEN CAST(subcode AS FLOAT64) IN (16,23,26,28,31,33) AND la.uw_decision_decision != 'DECLINE' AND la.status NOT IN ('DECLINED', 'CANCELLED') THEN 'FACTA_Auto_Knockout_Failure' 
  WHEN (d.description LIKE '%subcode 5%' OR d.description LIKE '%subcode 25%' OR d.description LIKE '%subcode 13%' OR d.description LIKE '%subcode 14%' OR d.description LIKE '%subcode 27%') AND la.uw_decision_decision != 'DECLINE' AND la.status NOT IN ('DECLINED', 'CANCELLED') THEN 'Experian_Fraud_Shield_Knockouts_Failure'
  ELSE 'PASS'
  END AS Credit_Hard_Knockout_Failure_Check,
 
  (((((BCC5830 - BCC5838)/0.04)*0.025) + BCC5838) - (BCC5830 - BCX5830)) AS Z,
    
  CASE 
  WHEN  BCC5830 <= BCX5830 AND  CAST(la.credit_soft_fico AS FLOAT64) BETWEEN 620 AND 739 THEN  ROUND(( (((((BCC5830 - BCC5838)/0.04)*0.025) + BCC5838) - (BCC5830 - BCX5830)) + (BAX5030 - BCX5030)*0.025 + RTR5030 * 0.025), 4)
  WHEN BCC5830 <= BCX5830 AND  CAST(la.credit_soft_fico AS FLOAT64) >= 740 THEN ROUND( (((((BCC5830 - BCC5838)/0.04)*0.025) + BCC5838) - (BCC5830 - BCX5830)) + RTR5030 * 0.025, 4)
  END AS T_Monthly_Revolving_Debt,
  
  CASE 
  WHEN BCC5830 <= BCX5830 AND CAST(la.credit_soft_fico AS FLOAT64) BETWEEN 620 AND 739 THEN ROUND(ILN5820 -ILN5824, 4)
  WHEN BCC5830 <= BCX5830 AND CAST(la.credit_soft_fico AS FLOAT64) >= 740 THEN ROUND(AUA5820 + STU5020*0.0035 + (ILN5820 - (STU5820 + AUA5820)) - ILN5824,4)
  END AS T_Monthly_Installment_Debt,
  CASE 
  WHEN BCC5830 <= BCX5830 AND CAST(la.credit_soft_fico AS FLOAT64) BETWEEN 620 AND 739 THEN ROUND(MTF5820 + MTS5820 + HLC5820, 4)
  WHEN BCC5830 <= BCX5830 AND CAST(la.credit_soft_fico AS FLOAT64) >= 740 THEN ROUND(MTF5820 + MTS5820 + HLC5820, 4)
  END AS T_Monthly_Mortgage_Debt 
FROM reporting.lkup_application la  
JOIN rpt_staging.stg_uw_decision sud ON sud.application_uuid_value = la.application_uuid_value
JOIN staging_evolved.fraud f ON f.application_uuid.value = la.application_uuid_value
JOIN reporting.lkup_credit_attr lca ON lca.application_uuid_value = la.application_uuid_value
LEFT JOIN UNNEST(decisions) AS d
LEFT JOIN (SELECT * FROM rpt_staging.stg_credit_soft_elig_factors WHERE lower(type) LIKE '%facta%') s ON s.application_uuid_value = la.application_uuid_value
WHERE product_type ='HELOC')
WHERE R = 1
ORDER BY App_Start_Date DESC),

F0 AS (
SELECT
  c.*,
  ad.calc_monthly_debt,
  ad.calc_monthly_debt_v2,
  CASE 
  WHEN BCC5830 > BCX5830 THEN ALX5830 - ILN5824
  ELSE (COALESCE(T_Monthly_Revolving_Debt,0) + COALESCE(T_Monthly_Installment_Debt,0) + COALESCE(T_Monthly_Mortgage_Debt,0))
  END AS T_Monthly_Debt,

  sud.uw_packet_home_amount AS UW_Packet_Home_Amount, 
  CASE 
  WHEN lp.avm_value_amount IS NULL OR (lp.avm_value_amount >= sud.uw_packet_home_amount) THEN  ROUND(sud.uw_packet_home_amount,4) ELSE ROUND(lp.avm_value_amount,4) END AS T_AVM_Value,
  sud.avm_fsd AS AVM_FSD,
  IFNULL(lp.avm_fsd, lp.prequal_avm_fsd) AS T_FSD,
  verified_income_amount AS Verified_Income_Amount, 
  
  CASE 
  WHEN c.age <= 59.5 THEN (verified_asset_depletion_retirement_amount*0.7) + verified_asset_depletion_investment_amount + verified_asset_depletion_savings_amount
  ELSE verified_asset_depletion_retirement_amount + verified_asset_depletion_investment_amount + verified_asset_depletion_savings_amount
  END AS T_Total_Assets,
  
  verified_asset_depletion_retirement_amount AS Verified_Asset_Depletion_Retirement_Amount, 
  verified_asset_depletion_savings_amount AS Verified_Asset_Depletion_Savings_Amount,
  verified_asset_depletion_investment_amount AS Verified_Asset_Depletion_Investment_Amount,
  la.uw_packet_amt_owed AS Amount_Owed,
  la.adjusted_home_amount AS Adjusted_Home_Amount, 
  CAST(ad.avm_value_amount AS FLOAT64) AS AVM_Value_Amount,
  CAST(ad.prequal_avm_amount AS FLOAT64) AS Prequal_AVM_Amount,
  lp.land_use_code AS Land_Use_Code,
  lp.acres AS Acres,
  h.mortgage_status_indicator AS Mortgage_Status_Indicator,
  h.mortgage_payoff_date AS Mortgage_Payoff_Date,
  h.mortgage_origination_date AS Mortgage_Origination_Date,
  h.mortgage_recording_date AS Mortgage_Recording_Date,
  lp.avm_last_sale_date AS AVM_Last_Sale_Date,
  lp.current_transfer_sale_date AS Current_Transfer_Sale_Date,
  lp.last_market_sale_date AS Last_Market_Sale_Date,
 
  CASE WHEN (CAST(ad.prequal_avm_amount AS FLOAT64) IS NULL AND CAST(ad.avm_value_amount AS FLOAT64) IS NULL) AND la.uw_decision_decision != 'DECLINE' AND la.status NOT IN ('DECLINED', 'CANCELLED') THEN 'AVM_Knockout_Failure'
  WHEN ((CAST(lp.land_use_code AS FLOAT64) NOT IN(102,112,148,163) AND c.App_Start_Date <= '2020-03-21') OR (CAST(lp.land_use_code AS FLOAT64) NOT IN(102,112,163) AND c.App_Start_Date >'2020-03-21'))  AND la.uw_decision_decision != 'DECLINE' AND la.status NOT IN ('DECLINED', 'CANCELLED') THEN 'Land_Use_Code_Knockout_Failure'
  WHEN CAST(uw_packet_acres AS FLOAT64) > 20 AND la.uw_decision_decision != 'DECLINE' AND la.status NOT IN ('DECLINED', 'CANCELLED') THEN 'Acres_Knockout_Failure'
  WHEN (SAFE_CAST(h.mortgage_lien_position AS FLOAT64) > 2 AND c.App_Start_Date >= '2020-04-28')  AND la.uw_decision_decision != 'DECLINE' AND la.status NOT IN ('DECLINED', 'CANCELLED') THEN 'Lien_Position_Knockout_Failure'
  WHEN (DATE_DIFF(CURRENT_DATE(), SAFE_CAST(COALESCE(lp.avm_last_sale_date, lp.current_transfer_sale_date, lp.last_market_sale_date) AS DATE), day) <= 90)  AND la.uw_decision_decision != 'DECLINE' AND la.status NOT IN ('DECLINED', 'CANCELLED') THEN 'Last_Sale_Date_Knockout_Failure'
  WHEN (h.mortgage_status_indicator IN ('F','U') AND h.mortgage_payoff_date IS NULL 
  AND (h.mortgage_recording_date IS NOT NULL AND h.mortgage_origination_date IS NOT NULL) 
  AND  SAFE_CAST(h.mortgage_origination_date AS DATE) >= SAFE_CAST(COALESCE(lp.avm_last_sale_date, lp.current_transfer_sale_date, lp.last_market_sale_date) AS DATE)
  AND  SAFE_CAST(h.mortgage_recording_date AS DATE) >= SAFE_CAST(COALESCE(lp.avm_last_sale_date, lp.current_transfer_sale_date, lp.last_market_sale_date) AS DATE))
  AND la.uw_decision_decision != 'DECLINE' AND la.status NOT IN ('DECLINED', 'CANCELLED')
  THEN 'Foreclosure_Knockout_Failure'
  ELSE 'PASS'
  END AS Property_Eligibility_Knockout_Failure_Check,
  
  s.lien_summary.involuntary_lien.lien_on_property AS Involuntary_Lien_On_Property, 
  s.lien_summary.hoa_lien.lien_on_property AS HOA_Lien_On_Property,
  il.involuntary_lien_info.involuntary_lien_item.document_category AS Document_Category, 
  il.involuntary_lien_info.involuntary_lien_item.document_description AS Document_Description, 
  CAST(il.involuntary_lien_info.involuntary_lien_item.document_date.value AS DATE) AS Document_Date,
  il.involuntary_lien_info.state_code AS State_Code, 
  s.property_status_indicators.is_pace_lien AS Is_Pace_Lien,
  CASE WHEN s.lien_summary.involuntary_lien.lien_on_property IS TRUE OR s.lien_summary.hoa_lien.lien_on_property IS TRUE THEN 'YES' ELSE 'NO' END AS Involuntary_Lien_Exists, 
  CASE WHEN (
  FICO >= 680 AND 
 (il.involuntary_lien_info.involuntary_lien_item.document_category = 'NOTICE' AND il.involuntary_lien_info.involuntary_lien_item.document_description = 'NOTICE') 
  AND s.property_status_indicators.is_pace_lien IS FALSE) IS TRUE THEN 'YES' ELSE 'NO' END AS Exception1_Exists, 
  CASE WHEN 
  (il.involuntary_lien_info.involuntary_lien_item.document_category = 'FEDERAL TAX LIEN' AND DATE_DIFF( Current_Date, CAST(il.involuntary_lien_info.involuntary_lien_item.document_date.value AS DATE), MONTH) > 120) IS TRUE
  OR
  (il.involuntary_lien_info.involuntary_lien_item.document_category = 'MECHANICS LIEN' AND DATE_DIFF( Current_Date, CAST(il.involuntary_lien_info.involuntary_lien_item.document_date.value AS DATE), MONTH) > 24) IS TRUE
  OR
  (il.involuntary_lien_info.involuntary_lien_item.document_category = 'STATE TAX LIEN' AND il.involuntary_lien_info.state_code IN('NH', 'IL', 'CA', 'NJ', 'VA', 'WI', 'FL', 'HI', 'CT', 'OH', 'VT', 'IA', 'KY', 'LA', 'MD') AND DATE_DIFF( Current_Date, CAST(il.involuntary_lien_info.involuntary_lien_item.document_date.value AS DATE), MONTH) > 240) IS TRUE
  OR 
  (il.involuntary_lien_info.involuntary_lien_item.document_category = 'STATE TAX LIEN' AND il.involuntary_lien_info.state_code IN('AL', 'AZ', 'AR', 'DE', 'IN', 'ME', 'MA', 'MN', 'NM', 'TN', 'WA', 'WY', 'WV', 'KS', 'SC', 'GA', 'OK', 'NE') AND DATE_DIFF( Current_Date, CAST(il.involuntary_lien_info.involuntary_lien_item.document_date.value AS DATE), MONTH) > 120) IS TRUE
  OR  
  (il.involuntary_lien_info.involuntary_lien_item.document_category = 'STATE TAX LIEN' AND il.involuntary_lien_info.state_code IN('SD', 'UT', 'ID', 'CO', 'MI', 'MS') AND DATE_DIFF( Current_Date, CAST(il.involuntary_lien_info.involuntary_lien_item.document_date.value AS DATE), MONTH) > 84) IS TRUE
  OR  
  (il.involuntary_lien_info.involuntary_lien_item.document_category IN ('JUDGMENT', 'LIEN') AND il.involuntary_lien_info.state_code IN('MD', 'DC', 'NM', 'KY', 'ME', 'MA', 'CT', 'NJ', 'RI') AND DATE_DIFF( Current_Date, CAST(il.involuntary_lien_info.involuntary_lien_item.document_date.value AS DATE), MONTH) > 240) IS TRUE
  OR
  (il.involuntary_lien_info.involuntary_lien_item.document_category IN ('JUDGMENT', 'LIEN') AND il.involuntary_lien_info.state_code IN('AR', 'AL', 'IA','DE', 'IN', 'MN', 'TN', 'WA', 'WV', 'SC', 'CA', 'FL', 'VA', 'WI', 'SD', 'LA', 'TX', 'MT', 'NC', 'OR', 'MO', 'AZ', 'UT', 'VT', 'AK') AND 
  DATE_DIFF( Current_Date, CAST(il.involuntary_lien_info.involuntary_lien_item.document_date.value AS DATE), MONTH) > 120) IS TRUE
  OR 
  (il.involuntary_lien_info.involuntary_lien_item.document_category IN ('JUDGMENT', 'LIEN') AND il.involuntary_lien_info.state_code IN('WY', 'KS', 'OK', 'OH', 'ID', 'MI', 'PA', 'NE', 'NH', 'CO', 'NV', 'GA', 'IL', 'MI')
  AND 
  DATE_DIFF(Current_Date, CAST(il.involuntary_lien_info.involuntary_lien_item.document_date.value AS DATE), MONTH) > 84) IS TRUE THEN 'YES' ELSE 'NO' END AS Exception2_Exists, 
  
  CASE WHEN (il.involuntary_lien_info.involuntary_lien_item.document_category IN ('FEDERAL TAX LIEN', 'MECHANICS LIEN', 'STATE TAX LIEN','JUDGMENT', 'LIEN') AND  CAST(il.involuntary_lien_info.involuntary_lien_item.document_date.value AS DATE) IS NULL) THEN 'YES' ELSE 'NO' END AS Exception3_Exists,  
  DATE_DIFF( Current_Date, CAST(il.involuntary_lien_info.involuntary_lien_item.document_date.value AS DATE), MONTH) AS Date_Difference_By_Month,  
  la.pre_loan_cltv AS Pre_Loan_CLTV,
  la.Pre_Loan_Adj_CLTV,
  la.Pre_Loan_DTI
FROM reporting.application_details ad
JOIN reporting.lkup_datatree_summary s ON s.application_uuid.value = ad.application_uuid_value
JOIN reporting.lkup_datatree_involuntary_liens il ON il.application_uuid.value = ad.application_uuid_value
JOIN reporting.lkup_application la ON la.application_uuid_value = ad.application_uuid_value
JOIN reporting.lkup_property lp ON lp.property_uuid_value = ad.property_uuid_value
JOIN reporting.f_heloc_property_financial_history h ON h.application_uuid = ad.application_uuid_value
JOIN reporting.lkup_app_heloc_stg_uw_decision sud ON sud.application_uuid_value = ad.application_uuid_value
JOIN Credit c ON c.App_UUID = s.application_uuid.value
),

Property AS (
SELECT 
  *
FROM (
SELECT 
   *,
  CASE
  WHEN T_AVM_Value < 100000 THEN T_AVM_Value*0.5
  WHEN (T_AVM_Value >= 100000 AND AVM_FSD <= 13 AND App_Start_Date >= '2020-03-21' AND land_use_code != 112) OR (T_AVM_Value >= 100000 AND AVM_FSD <= 13 AND App_Start_Date < '2020-03-21') THEN T_AVM_Value
  WHEN (T_AVM_Value >= 100000 AND AVM_FSD > 13 AND AVM_FSD <= 20 AND App_Start_Date >= '2020-03-21' AND land_use_code != 112) OR (T_AVM_Value >= 100000 AND AVM_FSD > 13 AND App_Start_Date < '2020-03-21') 
  THEN T_AVM_Value*(1- AVM_FSD/200)
  WHEN ((T_AVM_Value >= 100000 AND AVM_FSD > 20) OR ( T_AVM_Value >= 100000 AND land_use_code = 112 )) AND App_Start_Date >= '2020-03-21' THEN T_AVM_Value *(1- AVM_FSD/100)
  END AS T_Adjusted_Collateral_Value,
  
  CASE 
  WHEN Stated_Monthly_Income IS NOT NULL AND Stated_Monthly_Income != 0 AND App_Term IS NOT NULL AND App_Term != 0 THEN ROUND(T_Monthly_Debt/(Stated_Monthly_Income + (T_Total_Assets*0.04/12)/(1-POWER((1+0.04/12),(- App_Term*12)))),4) 
  WHEN  Stated_Monthly_Income IS NOT NULL AND Stated_Monthly_Income != 0 AND (App_Term IS NULL OR App_Term = 0) THEN ROUND(T_Monthly_Debt/Stated_Monthly_Income,4)
  END AS T_DTI,
  
   CASE
   WHEN Involuntary_Lien_Exists = 'YES' AND Exception1_Exists = 'NO'  AND Exception2_Exists = 'NO' AND Exception3_Exists = 'NO' AND Document_Category IS NOT NULL AND Document_Description IS NOT NULL AND Document_Date IS NOT NULL AND Decline_Reasons NOT LIKE '%Involuntary lien%' AND (App_Status NOT IN('CANCELLED','DECLINED') AND UW_Decision != 'DECLINE')
   THEN 'Involuntary_Lien_Knockout_Failure(DT returns)'
   WHEN Involuntary_Lien_Exists = 'YES' AND Exception1_Exists = 'NO'  AND Exception2_Exists = 'NO' AND Exception3_Exists = 'NO' AND Document_Category IS NULL AND Document_Description IS  NULL AND Document_Date IS  NULL  AND Decline_Reasons NOT LIKE '%Involuntary lien%' AND (App_Status NOT IN('CANCELLED','DECLINED') AND UW_Decision != 'DECLINE')
   THEN 'Involuntary_Lien_Knockout_Failure(DT no returns)'
   ELSE 'PASS'
   END AS Involuntary_Lien_Decline_Check,  
   ROW_NUMBER() OVER(PARTITION BY App_UUID ORDER BY App_Start_Date DESC) AS rank
FROM F0
WHERE UW_Decision IS NOT NULL 
ORDER BY App_Start_Date DESC)),

C AS (SELECT 
  *,
  CASE WHEN T_AVM_Value IS NOT NULL AND T_AVM_Value != 0 THEN ROUND(Amount_Owed/T_AVM_Value,4) ELSE NULL END AS T_Pre_Loan_CLTV,
  CASE WHEN T_Adjusted_Collateral_Value IS NOT NULL AND T_Adjusted_Collateral_Value != 0 THEN ROUND(Amount_Owed/T_Adjusted_Collateral_Value,4) ELSE NULL END AS T_Pre_Loan_Adj_CLTV
FROM Property
WHERE rank = 1 AND (Involuntary_Lien_Decline_Check != 'PASS' OR Property_Eligibility_Knockout_Failure_Check != 'PASS' OR Credit_Hard_Knockout_Failure_Check != 'PASS')
ORDER BY App_Start_Date DESC, App_UUID),

CC AS (SELECT *,
  CASE
  WHEN ((Amount_Owed = 0 AND (T_Pre_Loan_CLTV > 0.5 OR T_Pre_Loan_Adj_CLTV > 0.5))
  OR
  (Amount_Owed > 0 AND FICO >=620 AND FICO <660 AND (T_Pre_Loan_CLTV > 0.65 OR T_Pre_Loan_Adj_CLTV > 0.65) AND App_Start_Date < '2020-04-30' AND App_Start_Date >= '2020-03-18') 
  OR 
  (Amount_Owed > 0 AND FICO >=660 AND FICO <680 AND (T_Pre_Loan_CLTV > 0.75 OR T_Pre_Loan_Adj_CLTV > 0.75) AND App_Start_Date < '2020-04-30' AND App_Start_Date >= '2020-03-18') 
  OR 
  (Amount_Owed > 0 AND FICO >=620 AND FICO <680 AND (((T_Pre_Loan_CLTV > 0.75 OR T_Pre_Loan_Adj_CLTV > 0.75) AND App_Start_Date < '2020-03-18' AND App_Start_Date >= '2020-03-05') OR ((T_Pre_Loan_CLTV > 0.8 OR T_Pre_Loan_Adj_CLTV > 0.8) AND App_Start_Date < '2020-03-05')))
  OR 
  (Amount_Owed > 0 AND FICO >=680 AND FICO <720 AND (((T_Pre_Loan_CLTV > 0.9 OR T_Pre_Loan_Adj_CLTV > 0.9) AND App_Start_Date < '2020-03-18' AND App_Start_Date >= '2020-03-05') OR ((T_Pre_Loan_CLTV > 0.95 OR T_Pre_Loan_Adj_CLTV > 0.95) AND App_Start_Date < '2020-03-05')))
  OR
  (Amount_Owed > 0 AND FICO >=680 AND FICO <720 AND (((T_Pre_Loan_CLTV > 0.85 OR T_Pre_Loan_Adj_CLTV > 0.85) AND App_Start_Date < '2020-04-30' AND App_Start_Date >= '2020-03-18') OR ((T_Pre_Loan_CLTV > 0.8 OR T_Pre_Loan_Adj_CLTV > 0.8) AND App_Start_Date >= '2020-04-30')))
  OR
  (Amount_Owed > 0 AND FICO >=720 AND FICO <760 AND (((T_Pre_Loan_CLTV > 0.9 OR T_Pre_Loan_Adj_CLTV > 0.9) AND App_Start_Date < '2020-04-30' AND App_Start_Date >= '2020-03-18') OR ((T_Pre_Loan_CLTV > 0.8 OR T_Pre_Loan_Adj_CLTV > 0.8) AND App_Start_Date >= '2020-04-30')))
  OR
  (Amount_Owed > 0 AND FICO >=760 AND FICO <850 AND (((T_Pre_Loan_CLTV > 0.95 OR T_Pre_Loan_Adj_CLTV > 0.95) AND App_Start_Date < '2020-04-30' AND App_Start_Date >= '2020-03-18') OR ((T_Pre_Loan_CLTV > 0.8 OR T_Pre_Loan_Adj_CLTV > 0.8) AND App_Start_Date >= '2020-04-30'))))
  AND 
  (App_Status NOT IN('CANCELLED','DECLINED') AND UW_Decision != 'DECLINE')
  THEN 'CLTV_Decline_Failure'
  ELSE 'PASS'
  END AS CLTV_Decline_Failure_Check,
  
  CASE 
  WHEN ROUND(Pre_Loan_CLTV,3) = ROUND(T_Pre_Loan_CLTV,3) THEN 'Match'
  WHEN ROUND(Pre_Loan_CLTV,3) != ROUND(T_Pre_Loan_CLTV,3) THEN 'Unmatch'
  ELSE 'Unavailable'
  END AS CLTV_Match,
  CASE 
  WHEN  ROUND(Pre_Loan_DTI,3) = ROUND(T_DTI,3) THEN 'Match'
  WHEN  ROUND(Pre_Loan_DTI,3) != ROUND(T_DTI,3) THEN 'Unmatch'
  ELSE 'Unavailable'
  END AS DTI_Match,
 
  CASE
  WHEN ((FICO BETWEEN 620 AND 739 AND T_DTI > 0.43) OR (FICO >= 740 AND T_DTI > 0.5)) AND (App_Status NOT IN('CANCELLED','DECLINED') AND UW_Decision != 'DECLINE')
  THEN 'DTI_Decline_Failure'
  ELSE 'PASS'
  END AS DTI_Decline_Failure_Check,

FROM C
WHERE App_Start_Date > '2020-02-27')

SELECT * FROM
(SELECT 
  *,
  CASE  
  WHEN (App_Status NOT IN('CANCELLED','DECLINED') AND UW_Decision != 'DECLINE') AND (Involuntary_Lien_Decline_Check != 'PASS' OR Property_Eligibility_Knockout_Failure_Check != 'PASS' OR Credit_Hard_Knockout_Failure_Check != 'PASS' OR CLTV_Decline_Failure_Check != 'PASS' OR DTI_Decline_Failure_Check != 'PASS') THEN 'Apps should have been declined, but were not declined'
  WHEN (App_Status IN('CANCELLED','DECLINED') AND UW_Decision = 'DECLINE') AND (Involuntary_Lien_Decline_Check = 'PASS' AND Property_Eligibility_Knockout_Failure_Check = 'PASS' AND Credit_Hard_Knockout_Failure_Check = 'PASS' AND CLTV_Decline_Failure_Check = 'PASS' AND DTI_Decline_Failure_Check ='PASS') THEN 'Apps should have NOT been declined, but were declined'
  ELSE 'Apps were declined correctly'
  END AS  UW_Decline_Failure_Check
FROM CC)
WHERE UW_Decline_Failure_Check != 'Apps were declined correctly'
ORDER BY App_Start_Date DESC
