SELECT JSON_OBJECT(
         'negotiationId'    VALUE n.negotiation_id,
         'documentNumber'   VALUE n.document_number,
         'associationType'  VALUE at.description,
         'associatedDocumentId' VALUE n.associated_document_id,
         'status'           VALUE st.description,
         'agreementType'    VALUE ag.description,
         'negotiator'       VALUE n.negotiator_full_name,
         'startDate'        VALUE TO_CHAR(n.negotiation_start_date,'YYYY-MM-DD'),
         'endDate'          VALUE TO_CHAR(n.negotiation_end_date,'YYYY-MM-DD'),
         'unassociatedDetail' VALUE (SELECT JSON_OBJECT(
                                            'title'       VALUE ud.title,
                                            'piName'      VALUE ud.pi_name,
                                            'leadUnit'    VALUE ud.lead_unit,
                                            'sponsorCode' VALUE ud.sponsor_code)
                                      FROM negotiation_unassoc_detail ud
                                     WHERE ud.negotiation_id = n.negotiation_id),
         'activities'       VALUE (SELECT JSON_ARRAYAGG(
                                          JSON_OBJECT(
                                            'activityId'   VALUE a.negotiation_activity_id,
                                            'activityType' VALUE ty.description,
                                            'location'     VALUE lo.description,
                                            'startDate'    VALUE TO_CHAR(a.start_date,'YYYY-MM-DD'),
                                            'attachments'  VALUE (SELECT COUNT(*) FROM negotiation_attachment x
                                                                   WHERE x.activity_id = a.negotiation_activity_id)
                                          ) RETURNING CLOB)
                                    FROM negotiation_activity a
                                    LEFT JOIN negotiation_activity_type ty ON ty.negotiation_activity_type_id=a.activity_type_id
                                    LEFT JOIN negotiation_location lo ON lo.negotiation_location_id=a.location_id
                                   WHERE a.negotiation_id = n.negotiation_id),
         'customFields'     VALUE (SELECT JSON_ARRAYAGG(
                                          JSON_OBJECT(
                                            'customAttributeId' VALUE cd.custom_attribute_id,
                                            'name'  VALUE ca.name,
                                            'label' VALUE ca.label,
                                            'value' VALUE cd.value
                                          ) RETURNING CLOB)
                                    FROM negotiation_custom_data cd
                                    LEFT JOIN custom_attribute ca ON ca.id = cd.custom_attribute_id
                                   WHERE cd.negotiation_id = n.negotiation_id)
         RETURNING CLOB
       ) AS negotiation_graph_json
FROM       kcoeus.negotiation n
LEFT JOIN  kcoeus.negotiation_status           st ON st.negotiation_status_id = n.negotation_status_id
LEFT JOIN  kcoeus.negotiation_agreement_type   ag ON ag.negotiation_agrmnt_type_id = n.negotiation_agreement_type_id
LEFT JOIN  kcoeus.negotiation_association_type at ON at.negotiation_assc_type_id = n.negotiation_assc_type_id
WHERE      n.negotiation_id = 420

-- One negotiation, pinned by id. Feasibility check, not the interface. Activities and
-- custom fields stay in their own arrays instead of multiplying against each other.
-- Attachments are counted rather than expanded, since they hang off the activity.
