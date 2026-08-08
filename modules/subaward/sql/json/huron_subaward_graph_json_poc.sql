SELECT JSON_OBJECT(
         'subawardId'      VALUE s.subaward_id,
         'subawardCode'    VALUE s.subaward_code,
         'sequenceNumber'  VALUE s.sequence_number,
         'sequenceStatus'  VALUE s.subaward_sequence_status,
         'title'           VALUE s.title,
         'statusCode'      VALUE s.status_code,
         'statusDescription' VALUE st.description,
         'subawardType'    VALUE at.description,
         'organization'    VALUE JSON_OBJECT(
                                   'organizationId'   VALUE s.organization_id,
                                   'organizationName' VALUE o.organization_name
                                 ),
         'buDateReceived'  VALUE TO_CHAR(ex.date_received,'YYYY-MM-DD'),
         'fundingSources'  VALUE (SELECT JSON_ARRAYAGG(
                                          JSON_OBJECT(
                                            'awardId'          VALUE f.award_id,
                                            'awardNumber'      VALUE a.award_number,
                                            'awardSequence'    VALUE a.sequence_number,
                                            'awardVersionStatus' VALUE a.award_sequence_status
                                          ) RETURNING CLOB)
                                   FROM subaward_funding_source f
                                   LEFT JOIN award a ON a.award_id = f.award_id
                                  WHERE f.subaward_id = s.subaward_id),
         'amounts'         VALUE (SELECT JSON_ARRAYAGG(
                                          JSON_OBJECT(
                                            'modificationNumber' VALUE ai.modification_number,
                                            'obligatedAmount'    VALUE ai.obligated_amount,
                                            'anticipatedAmount'  VALUE ai.anticipated_amount,
                                            'effectiveDate'      VALUE TO_CHAR(ai.effective_date,'YYYY-MM-DD')
                                          ) RETURNING CLOB)
                                   FROM subaward_amount_info ai
                                  WHERE ai.subaward_id = s.subaward_id),
         'contacts'        VALUE (SELECT JSON_ARRAYAGG(
                                          JSON_OBJECT(
                                            'contactTypeCode'  VALUE c.contact_type_code,
                                            'contactType'      VALUE ct.description,
                                            'requisitionerId'  VALUE c.requisitioner_id
                                          ) RETURNING CLOB)
                                   FROM subaward_contact c
                                   LEFT JOIN contact_type ct ON ct.contact_type_code = c.contact_type_code
                                  WHERE c.subaward_id = s.subaward_id),
         'ffata'           VALUE (SELECT JSON_ARRAYAGG(
                                          JSON_OBJECT(
                                            'dateSubmitted' VALUE TO_CHAR(ff.date_submitted,'YYYY-MM-DD'),
                                            'submitterId'   VALUE ff.submitter_id
                                          ) RETURNING CLOB)
                                   FROM subaward_ffata_reporting ff
                                  WHERE ff.subaward_id = s.subaward_id),
         'customFields'    VALUE (SELECT JSON_ARRAYAGG(
                                          JSON_OBJECT(
                                            'customAttributeId' VALUE cd.custom_attribute_id,
                                            'name'              VALUE ca.name,
                                            'label'             VALUE ca.label,
                                            'value'             VALUE cd.value
                                          ) RETURNING CLOB)
                                   FROM subaward_custom_data cd
                                   LEFT JOIN custom_attribute ca ON ca.id = cd.custom_attribute_id
                                  WHERE cd.subaward_id = s.subaward_id)
         RETURNING CLOB
       ) AS subaward_graph_json
FROM       kcoeus.subaward s
LEFT JOIN  kcoeus.subaward_extension ex ON ex.subaward_id = s.subaward_id
LEFT JOIN  kcoeus.subaward_status    st ON st.subaward_status_code = s.status_code
LEFT JOIN  kcoeus.award_type         at ON at.award_type_code = s.subaward_type_code
LEFT JOIN  kcoeus.organization       o  ON o.organization_id = s.organization_id
WHERE      s.subaward_id = 76775

-- One subaward only, pinned by id. This is a feasibility check, not the interface.
-- Each collection is a correlated JSON_ARRAYAGG subquery, so 40 funding sources,
-- 21 amounts, 2 contacts and 15 custom fields stay in their own arrays instead of
-- multiplying into 25,200 rows. RETURNING CLOB is needed -- the default
-- VARCHAR2(4000) overflows on a subaward this size.
