SELECT
       a.negotiation_activity_id           AS negotiation_activity_id,
       a.negotiation_id                    AS negotiation_id,
       a.activity_type_id                  AS activity_type_id,
       ty.description                      AS activity_type,
       a.location_id                       AS location_id,
       lo.description                      AS location,
       a.start_date                        AS start_date,
       a.end_date                          AS end_date,
       a.followup_date                     AS followup_date,
       a.create_date                       AS create_date,
       a.restricted                        AS restricted_flag,
       DBMS_LOB.SUBSTR(a.description, 4000, 1) AS description,
       a.last_modified_user                AS last_modified_user,
       a.last_modified_date                AS last_modified_date,
       a.ver_nbr                           AS version_number,
       a.update_timestamp                  AS update_timestamp,
       a.update_user                       AS update_user
FROM       kcoeus.negotiation_activity a
LEFT JOIN  kcoeus.negotiation_activity_type ty ON ty.negotiation_activity_type_id = a.activity_type_id
LEFT JOIN  kcoeus.negotiation_location      lo ON lo.negotiation_location_id      = a.location_id

-- The activity log: what happened on a negotiation and when. 30,475 rows. This is
-- where the actual negotiation history lives, so it stays a separate dataset.
