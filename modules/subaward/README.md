# Subaward

**Status: NOT STARTED**

Expected root: `org.kuali.kra.subaward.bo.SubAward` → `KCOEUS.SUBAWARD`
(93,061 rows; `SUBAWARD_EXTENSION` is 1:1 on `SUBAWARD_ID`).

Work will follow the same method as Award: root object from the Kuali source →
complete relationship graph → current-version rule validated against production →
front-end field-to-database mapping → BU extensions and custom attributes (15 `SAWD`
attributes configured) → SQL interface last.

Known open item: `SUBAWARD.SUBAWARD_TYPE_CODE` has no lookup table in KCOEUS — flagged
during Award work, not yet resolved.
