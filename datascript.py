import csv
from datetime import datetime

# Читаем CSV (с разделителем TAB)
with open('data_fpb.tsv', 'r', encoding='utf-8') as f:
    reader = csv.DictReader(f, delimiter='\t')
    rows = list(reader)

# Генерация SQL
print("-- 1. Family")
family_codes = set()
for row in rows:
    family_codes.add((row['Семья'], row['Близкородственный брак'] or 'FALSE'))
for code, cons in family_codes:
    print(f"INSERT IGNORE INTO Family (family_code, is_consanguineous) VALUES ('{code}', {cons});")

print("\n-- 2. Project")
projects = set()
for row in rows:
    if row['Проект']:
        projects.add(row['Проект'])
for p in projects:
    print(f"INSERT IGNORE INTO Project (project_name) VALUES ('{p}');")

print("\n-- 3. Diagnosis")
diagnoses = set()
for row in rows:
    if row['Предполагаемый диагноз']:
        diagnoses.add(row['Предполагаемый диагноз'])
for d in diagnoses:
    print(f"INSERT IGNORE INTO Diagnosis (diagnosis_code) VALUES ('{d}');")

print("\n-- 4. SequencingRun")
runs = set()
for row in rows:
    runs.add((row['Номер запуска'], row['Тип секвенирования'], row['Дата секвенирования'][:10], row['Путь к файлам']))
for run, seq_type, date_seq, path in runs:
    print(f"INSERT IGNORE INTO SequencingRun (run_number, sequencing_type, date_sequencing, file_path) VALUES ('{run}', '{seq_type}', '{date_seq}', '{path}');")

print("\n-- 5. Patient")
for row in rows:
    family_id = f"(SELECT family_id FROM Family WHERE family_code = '{row['Семья']}')"
    print(f"INSERT IGNORE INTO Patient (patient_uuid, uin1, sex, full_name, birth_date, relationship, family_id, card_number, partner_info, admission_date) VALUES ('{row['УИН2']}', '{row['УИН1']}', '{row['Пол']}', '{row['ФИО']}', STR_TO_DATE('{row['Дата рождения']}', '%d.%m.%Y'), '{row['Степень родства']}', {family_id}, '{row['Номер карты']}', '{row['Партнер']}', '{row['Дата поступления'][:10]}');")

print("\n-- 6. ParentChild (автоматически)")
# Для каждой семьи собираем proband, мать, отец
# Здесь логика зависит от ваших данных — можно добавить вручную или через скрипт

print("\n-- 7. Analysis")
for row in rows:
    project_id = f"(SELECT project_id FROM Project WHERE project_name = '{row['Проект']}')" if row['Проект'] else "NULL"
    diagnosis_code = f"'{row['Предполагаемый диагноз']}'" if row['Предполагаемый диагноз'] else "NULL"
    print(f"""
INSERT INTO Analysis (
    patient_uuid, run_number, project_id, diagnosis_code,
    phenotype, pipeline, reference_genome,
    mean_coverage, coverage_percent, reads_count, uniformity,
    date_analysis, deadline, results_shared
) VALUES (
    '{row['УИН2']}', '{row['Номер запуска']}', {project_id}, {diagnosis_code},
    '{row['Фенотип']}', '{row['Пайплайн анализа']}', '{row['Референсный геном']}',
    {float(row['Средняя глубина покрытия']):.2f}, {float(row['Покрытие']):.5f}, {int(row['Количество прочтений'])}, {float(row['Униформность']):.5f},
    '{row['Дата анализа'][:10]}', '{row['Дедлайн'][:10]}', {row['Выданы результаты партнерам']}
);
""")