-- 1. Как распределены метрики качества секвенирования?
-- Распределение метрик (средние, мин, макс, процентили)
SELECT 
    -- Средняя глубина покрытия
    AVG(mean_coverage) AS avg_mean_coverage,
    MIN(mean_coverage) AS min_mean_coverage,
    MAX(mean_coverage) AS max_mean_coverage,
    -- Процент покрытия
    AVG(coverage_percent) AS avg_coverage_percent,
    MIN(coverage_percent) AS min_coverage_percent,
    MAX(coverage_percent) AS max_coverage_percent,
    -- Униформность
    AVG(uniformity) AS avg_uniformity,
    MIN(uniformity) AS min_uniformity,
    MAX(uniformity) AS max_uniformity,
    -- Количество прочтений
    AVG(reads_count) AS avg_reads_count,
    MIN(reads_count) AS min_reads_count,
    MAX(reads_count) AS max_reads_count
FROM Analysis;

-- Группировка по типу секвенирования
SELECT 
    sr.sequencing_type,
    COUNT(*) AS n_analyses,
    ROUND(AVG(a.mean_coverage), 2) AS avg_coverage,
    ROUND(AVG(a.coverage_percent), 2) AS avg_coverage_pct,
    ROUND(AVG(a.uniformity), 2) AS avg_uniformity,
    ROUND(AVG(a.reads_count), 0) AS avg_reads
FROM Analysis a
JOIN SequencingRun sr ON a.run_id = sr.run_id
GROUP BY sr.sequencing_type;

-- 2. Сколько результатов было выдано партнерам?
-- Общее количество выданных результатов
SELECT 
    COUNT(*) AS total_analyses,
    SUM(CASE WHEN results_shared = TRUE THEN 1 ELSE 0 END) AS shared_count,
    SUM(CASE WHEN results_shared = FALSE THEN 1 ELSE 0 END) AS not_shared_count,
    ROUND(100.0 * SUM(CASE WHEN results_shared = TRUE THEN 1 ELSE 0 END) / COUNT(*), 2) AS shared_percent
FROM Analysis;

-- По партнерам
SELECT 
    p.partner_name,
    COUNT(a.analysis_id) AS total_analyses,
    SUM(CASE WHEN a.results_shared = TRUE THEN 1 ELSE 0 END) AS shared_count,
    ROUND(100.0 * SUM(CASE WHEN a.results_shared = TRUE THEN 1 ELSE 0 END) / COUNT(a.analysis_id), 2) AS shared_percent
FROM Analysis a
JOIN Patient pt ON a.patient_uuid = pt.patient_uuid
JOIN Partner p ON pt.partner_id = p.partner_id
GROUP BY p.partner_name
ORDER BY shared_percent DESC


-- Общее количество семей и близкородственные
-- 3. Сколько семей участвовало в исследовании? Какова доля близкородственных браков?
SELECT 
    COUNT(*) AS total_families,
    SUM(CASE WHEN is_consanguineous = TRUE THEN 1 ELSE 0 END) AS consanguineous_count,
    ROUND(100.0 * SUM(CASE WHEN is_consanguineous = TRUE THEN 1 ELSE 0 END) / COUNT(*), 2) AS consanguineous_percent
FROM Family;

-- Семьи с пробандами (имеющие хотя бы одного пациента со степенью родства 'пробанд')
SELECT 
    COUNT(DISTINCT f.family_id) AS families_with_probands
FROM Family f
JOIN Patient p ON f.family_id = p.family_id
WHERE p.relationship = 'пробанд';


-- 4. Каково соотношение типов исследований? Каков вклад партнеров, и что они чаще заказывали?
-- Соотношение типов секвенирования
SELECT 
    sequencing_type,
    COUNT(*) AS count,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM SequencingRun), 2) AS percent
FROM SequencingRun
GROUP BY sequencing_type
ORDER BY count DESC;

-- Вклад партнеров (количество анализов)
SELECT 
    p.partner_name,
    COUNT(a.analysis_id) AS total_analyses,
    ROUND(100.0 * COUNT(a.analysis_id) / (SELECT COUNT(*) FROM Analysis), 2) AS percent
FROM Partner p
LEFT JOIN Patient pt ON p.partner_id = pt.partner_id
LEFT JOIN Analysis a ON pt.patient_uuid = a.patient_uuid
GROUP BY p.partner_name
ORDER BY total_analyses DESC;

-- Что чаще заказывал каждый партнер (тип секвенирования)
SELECT 
    p.partner_name,
    sr.sequencing_type,
    COUNT(*) AS count
FROM Partner p
JOIN Patient pt ON p.partner_id = pt.partner_id
JOIN Analysis a ON pt.patient_uuid = a.patient_uuid
JOIN SequencingRun sr ON a.run_id = sr.run_id
GROUP BY p.partner_name, sr.sequencing_type
ORDER BY p.partner_name, count DESC;


-- 5. Какова доля просроченных анализов?
-- Сравнение даты анализа с дедлайном
SELECT 
    COUNT(*) AS total_analyses,
    SUM(CASE WHEN date_analysis > deadline THEN 1 ELSE 0 END) AS overdue_count,
    ROUND(100.0 * SUM(CASE WHEN date_analysis > deadline THEN 1 ELSE 0 END) / COUNT(*), 2) AS overdue_percent
FROM Analysis
WHERE deadline IS NOT NULL AND date_analysis IS NOT NULL;

-- Среднее опоздание (в днях) для просроченных
SELECT 
    ROUND(AVG(DATEDIFF(date_analysis, deadline)), 1) AS avg_days_overdue
FROM Analysis
WHERE deadline IS NOT NULL 
  AND date_analysis IS NOT NULL 
  AND date_analysis > deadline;

-- По партнерам
SELECT 
    p.partner_name,
    COUNT(*) AS total,
    SUM(CASE WHEN a.date_analysis > a.deadline THEN 1 ELSE 0 END) AS overdue,
    ROUND(100.0 * SUM(CASE WHEN a.date_analysis > a.deadline THEN 1 ELSE 0 END) / COUNT(*), 2) AS overdue_pct
FROM Analysis a
JOIN Patient pt ON a.patient_uuid = pt.patient_uuid
JOIN Partner p ON pt.partner_id = p.partner_id
WHERE a.deadline IS NOT NULL AND a.date_analysis IS NOT NULL
GROUP BY p.partner_name;

-- 6. Сколько анализов было сделано в рамках каких проектов?
-- По проектам
SELECT 
    pr.project_name,
    COUNT(a.analysis_id) AS analyses_count,
    ROUND(100.0 * COUNT(a.analysis_id) / (SELECT COUNT(*) FROM Analysis), 2) AS percent
FROM Project pr
LEFT JOIN Analysis a ON pr.project_id = a.project_id
GROUP BY pr.project_name
ORDER BY analyses_count DESC;

-- Проекты без назначенного проекта (NULL)
SELECT 
    'Без проекта' AS project_name,
    COUNT(*) AS analyses_count
FROM Analysis
WHERE project_id IS NULL;

-- 7. Каково соотношение полов, распределение возраста в исследовании среди пробандов?
-- Соотношение полов среди пробандов
SELECT 
    sex,
    COUNT(*) AS count,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM Patient WHERE relationship = 'пробанд'), 2) AS percent
FROM Patient
WHERE relationship = 'пробанд'
GROUP BY sex;

-- Распределение возраста пробандов (на момент анализа или текущий)
SELECT 
    CASE 
        WHEN TIMESTAMPDIFF(YEAR, birth_date, CURDATE()) < 1 THEN '0-1'
        WHEN TIMESTAMPDIFF(YEAR, birth_date, CURDATE()) < 3 THEN '1-3'
        WHEN TIMESTAMPDIFF(YEAR, birth_date, CURDATE()) < 6 THEN '3-6'
        WHEN TIMESTAMPDIFF(YEAR, birth_date, CURDATE()) < 12 THEN '6-12'
        WHEN TIMESTAMPDIFF(YEAR, birth_date, CURDATE()) < 18 THEN '12-18'
        ELSE '18+'
    END AS age_group,
    COUNT(*) AS count,
    ROUND(AVG(TIMESTAMPDIFF(YEAR, birth_date, CURDATE())), 1) AS avg_age
FROM Patient
WHERE relationship = 'пробанд'
GROUP BY age_group
ORDER BY MIN(TIMESTAMPDIFF(YEAR, birth_date, CURDATE()));



-- 8. Грубая оценка размера вставки (insert size)
-- Оценка insert size: (reads_count * read_length) / coverage / genome_size
-- Для ONT (длина чтения ~ 5000-10000 п.н.), для WGBS (~150 п.н.)
-- Размер генома человека ~ 3.1e9 п.н.

SELECT 
    p.patient_uuid,
    p.full_name,
    sr.sequencing_type,
    a.reads_count,
    a.mean_coverage,
    a.coverage_percent,
    -- Оценка insert size (грубо)
    CASE 
        WHEN sr.sequencing_type = 'ONT' THEN ROUND(a.reads_count * 8000 / a.mean_coverage / 3.1e9, 0)
        WHEN sr.sequencing_type = 'WGBS' THEN ROUND(a.reads_count * 150 / a.mean_coverage / 3.1e9, 0)
        ELSE NULL
    END AS estimated_insert_size_gb,
    -- Технические возможности метода
    CASE 
        WHEN sr.sequencing_type = 'ONT' THEN 'Long reads (5-100kb), insert size не применим'
        WHEN sr.sequencing_type = 'WGBS' THEN 'Short reads (150bp), insert size ~300-500bp'
        ELSE NULL
    END AS technical_note
FROM Analysis a
JOIN Patient p ON a.patient_uuid = p.patient_uuid
JOIN SequencingRun sr ON a.run_id = sr.run_id
WHERE p.relationship = 'пробанд'
LIMIT 20;


-- 9. Оцените нагрузку приборов
-- Количество запусков по приборам (по run_number)
SELECT 
    sequencing_type,
    COUNT(DISTINCT run_id) AS total_runs,
    SUM(reads_count) AS total_reads,
    ROUND(AVG(reads_count), 0) AS avg_reads_per_run,
    COUNT(DISTINCT DATE(date_sequencing)) AS distinct_days,
    ROUND(COUNT(DISTINCT run_id) / COUNT(DISTINCT DATE(date_sequencing)), 1) AS runs_per_day
FROM SequencingRun sr
JOIN Analysis a ON sr.run_id = a.run_id
GROUP BY sequencing_type;

-- Нагрузка по месяцам
SELECT 
    DATE_FORMAT(date_sequencing, '%Y-%m') AS month,
    sequencing_type,
    COUNT(DISTINCT run_id) AS runs,
    COUNT(a.analysis_id) AS analyses
FROM SequencingRun sr
JOIN Analysis a ON sr.run_id = a.run_id
GROUP BY month, sequencing_type
ORDER BY month DESC;


-- 10. Сколько пробандов, каким заболеванием болеет? Что это за заболевания?
-- Количество пробандов по диагнозам
SELECT 
    d.diagnosis_code,
    COUNT(DISTINCT p.patient_uuid) AS proband_count
FROM Diagnosis d
JOIN Analysis a ON d.diagnosis_id = a.diagnosis_id
JOIN Patient p ON a.patient_uuid = p.patient_uuid
WHERE p.relationship = 'пробанд'
GROUP BY d.diagnosis_code
ORDER BY proband_count DESC;

-- Расширенная информация о заболеваниях
SELECT 
    d.diagnosis_code,
    COUNT(DISTINCT p.patient_uuid) AS proband_count,
    GROUP_CONCAT(DISTINCT p.full_name SEPARATOR ', ') AS proband_names,
    GROUP_CONCAT(DISTINCT a.phenotype SEPARATOR '; ') AS phenotypes
FROM Diagnosis d
JOIN Analysis a ON d.diagnosis_id = a.diagnosis_id
JOIN Patient p ON a.patient_uuid = p.patient_uuid
WHERE p.relationship = 'пробанд'
GROUP BY d.diagnosis_code
ORDER BY proband_count DESC;

-- Расшифровка кодов МКБ-10 (справочно)
SELECT 
    diagnosis_code,
    CASE diagnosis_code
        WHEN 'Q85.0' THEN 'Нейрофиброматоз (незлокачественные опухоли нервной системы)'
        WHEN 'E84.0' THEN 'Муковисцидоз (поражение лёгких и ЖКТ)'
        WHEN 'E70.0' THEN 'Нарушение обмена ароматических аминокислот (фенилкетонурия и др.)'
        WHEN 'G11.3' THEN 'Мозжечковая атаксия (нарушение координации движений)'
        WHEN 'Q87.2' THEN 'Врождённые пороки развития'
        ELSE 'Другой диагноз'
    END AS disease_description
FROM Diagnosis;

