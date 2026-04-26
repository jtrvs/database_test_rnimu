-- 1. Семья
CREATE TABLE Family (
    family_id INT PRIMARY KEY AUTO_INCREMENT,
    family_code VARCHAR(50) NOT NULL,     -- ваша колонка "Семья" (0,1...)
    is_consanguineous BOOLEAN DEFAULT FALSE,
    UNIQUE KEY uk_family_code (family_code)
);

-- 2. Проекты (справочник)
CREATE TABLE Project (
    project_id INT PRIMARY KEY AUTO_INCREMENT,
    project_name VARCHAR(100) NOT NULL UNIQUE
);

-- 3. Диагнозы (справочник МКБ-10)
CREATE TABLE Diagnosis (
    diagnosis_id INT PRIMARY KEY AUTO_INCREMENT,  -- суррогатный PK
    diagnosis_code VARCHAR(10) NOT NULL UNIQUE   -- код МКБ-10 (Q85.0, E84.0...)
);

CREATE TABLE Partner (
    partner_id INT PRIMARY KEY AUTO_INCREMENT,
    partner_name VARCHAR(255) NOT NULL UNIQUE
);

-- 4. Пациент
CREATE TABLE Patient (
    patient_uuid CHAR(36) PRIMARY KEY,        -- УИН2
    uin1 VARCHAR(50) UNIQUE,                  -- УИН1 (может быть NULL)
    sex ENUM('XX', 'XY') NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    birth_date DATE NOT NULL,
    relationship VARCHAR(20),                 -- пробанд, мать, отец
    family_id INT NOT NULL,
    card_number VARCHAR(50),                  -- Номер карты
    partner_id INT,                           -- Партнер
    admission_date DATE,                      -- Дата поступления
    FOREIGN KEY (family_id) REFERENCES Family(family_id) ON DELETE CASCADE,
    FOREIGN KEY (partner_id) REFERENCES Partner(partner_id) ON DELETE SET NULL
);

-- 5. Связь "родитель-ребенок" (для родословной)
CREATE TABLE ParentChild (
    child_uuid CHAR(36) NOT NULL,
    parent_uuid CHAR(36) NOT NULL,
    PRIMARY KEY (child_uuid, parent_uuid),
    FOREIGN KEY (child_uuid) REFERENCES Patient(patient_uuid) ON DELETE CASCADE,
    FOREIGN KEY (parent_uuid) REFERENCES Patient(patient_uuid) ON DELETE CASCADE,
    CONSTRAINT check_not_self CHECK (child_uuid != parent_uuid)
);

-- 6. Запуск секвенирования

CREATE TABLE SequencingRun (
    run_id INT PRIMARY KEY AUTO_INCREMENT,   -- суррогатный целочисленный ключ
    run_number VARCHAR(100) NOT NULL UNIQUE, -- исходный номер запуска (для отображения)
    sequencing_type VARCHAR(50) NOT NULL,
    date_sequencing DATE NOT NULL,
    file_path TEXT NOT NULL
);

-- 7. Анализ (главная фактовая таблица)
CREATE TABLE Analysis (
   analysis_id INT PRIMARY KEY AUTO_INCREMENT,
   patient_uuid CHAR(36) NOT NULL,
   run_id INT NOT NULL,
   project_id INT,
   diagnosis_id INT,
   phenotype TEXT,                           -- Фенотип
   pipeline VARCHAR(100),                    -- dorado+modkit
   reference_genome VARCHAR(50),             -- T2T
   mean_coverage DECIMAL(10,2),              -- 36.38
   coverage_percent DECIMAL(10,5),           -- 93.14%
   reads_count BIGINT,                       -- 569415231
   uniformity DECIMAL(10,5),                 -- 86.88%
   date_analysis DATE,
   deadline DATE,
   results_shared BOOLEAN DEFAULT FALSE,
   FOREIGN KEY (patient_uuid) REFERENCES Patient(patient_uuid),
   FOREIGN KEY (run_id) REFERENCES SequencingRun(run_id),
   FOREIGN KEY (project_id) REFERENCES Project(project_id),
   FOREIGN KEY (diagnosis_id) REFERENCES Diagnosis(diagnosis_id)
);

CREATE INDEX idx_analysis_patient ON Analysis(patient_uuid);
CREATE INDEX idx_analysis_run ON Analysis(run_id);
CREATE INDEX idx_analysis_project ON Analysis(project_id);
CREATE INDEX idx_analysis_diagnosis ON Analysis(diagnosis_id);
