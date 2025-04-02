-- This is a placeholder for the OpenMRS sample database dump
-- In a real implementation, this would contain the actual SQL dump of the OpenMRS database

-- Create basic tables for demonstration
CREATE TABLE IF NOT EXISTS patient (
  patient_id INT PRIMARY KEY,
  gender CHAR(1),
  birthdate DATE,
  creator INT,
  date_created DATETIME
);

CREATE TABLE IF NOT EXISTS person_name (
  person_name_id INT PRIMARY KEY,
  person_id INT,
  given_name VARCHAR(50),
  family_name VARCHAR(50),
  creator INT,
  date_created DATETIME,
  FOREIGN KEY (person_id) REFERENCES patient(patient_id)
);

-- Insert sample data
INSERT INTO patient (patient_id, gender, birthdate, creator, date_created)
VALUES 
  (1, 'M', '1980-07-15', 1, NOW()),
  (2, 'F', '1992-03-22', 1, NOW()),
  (3, 'M', '1975-11-30', 1, NOW());

INSERT INTO person_name (person_name_id, person_id, given_name, family_name, creator, date_created)
VALUES
  (1, 1, 'John', 'Smith', 1, NOW()),
  (2, 2, 'Sarah', 'Johnson', 1, NOW()),
  (3, 3, 'Michael', 'Williams', 1, NOW());
