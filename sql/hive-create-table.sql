-- Create external table for patient data
CREATE EXTERNAL TABLE IF NOT EXISTS patients (
  payload STRUCT<
    patient_id: INT,
    gender: STRING,
    birthdate: STRING,
    creator: INT,
    date_created: STRING
  >
)
ROW FORMAT SERDE 'org.apache.hive.serde2.json.JsonSerDe'
LOCATION '/kafka/openmrs.patient/';

-- Create external table for person names
CREATE EXTERNAL TABLE IF NOT EXISTS person_names (
  payload STRUCT<
    person_name_id: INT,
    person_id: INT,
    given_name: STRING,
    family_name: STRING,
    creator: INT,
    date_created: STRING
  >
)
ROW FORMAT SERDE 'org.apache.hive.serde2.json.JsonSerDe'
LOCATION '/kafka/openmrs.person_name/';
