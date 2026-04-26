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
    
print("\n-- 4. Partners")
parnters = set()
for row in rows:
    if row['Партнер']:
        parnters.add(row['Партнер'])
for p in parnters:
    print(f"INSERT IGNORE INTO Partner (partner_name) VALUES ('{p}');")

print("\n-- 5. SequencingRun")
runs = set()
for row in rows:
    runs.add((row['Номер запуска'], row['Тип секвенирования'], row['Дата секвенирования'][:10], row['Путь к файлам']))
for run, seq_type, date_seq, path in runs:
    print(f"INSERT IGNORE INTO SequencingRun (run_number, sequencing_type, date_sequencing, file_path) VALUES ('{run}', '{seq_type}', '{date_seq}', '{path}');")

print("\n-- 6. Patient")
for row in rows:
    # Получаем partner_id по имени партнера
    partner_id = "NULL"
    if row['Партнер'] and row['Партнер'].strip():
        partner_id = f"(SELECT partner_id FROM Partner WHERE partner_name = '{row['Партнер']}')"
    
    # Преобразование даты из формата дд.мм.гггг в гггг-мм-дд
    birth_date = row['Дата рождения']
    if birth_date and '.' in birth_date:
        parts = birth_date.split('.')
        birth_date = f"{parts[2]}-{parts[1]}-{parts[0]}"
    
    admission_date = row['Дата поступления'][:10] if row['Дата поступления'] and row['Дата поступления'].strip() else "NULL"
    
    print(f"""
INSERT INTO Patient (
    patient_uuid, uin1, sex, full_name, birth_date, 
    relationship, family_id, card_number, partner_id, admission_date
) VALUES (
    '{row['УИН2']}', {row['УИН1']}, '{row['Пол']}', '{row['ФИО']}', '{birth_date}',
    '{row['Степень родства']}', (SELECT family_id FROM Family WHERE family_code = '{row['Семья']}'), 
    {f"'{row['Номер карты']}'" if row['Номер карты'] and row['Номер карты'].strip() else "NULL"}, 
    {partner_id}, 
    {f"'{admission_date}'" if admission_date != "NULL" else "NULL"}
);
""")

print("\n-- 7. ParentChild")
family_members = {}
for row in rows:
    family_code = row['Семья']
    if family_code not in family_members:
        family_members[family_code] = {'proband': None, 'mother': None, 'father': None}
    
    if row['Степень родства'] == 'пробанд':
        family_members[family_code]['proband'] = row['УИН2']
    elif row['Степень родства'] == 'мать':
        family_members[family_code]['mother'] = row['УИН2']
    elif row['Степень родства'] == 'отец':
        family_members[family_code]['father'] = row['УИН2']

for family_code, members in family_members.items():
    if members['proband']:
        if members['mother']:
            print(f"INSERT IGNORE INTO ParentChild (child_uuid, parent_uuid) VALUES ('{members['proband']}', '{members['mother']}');")
        if members['father']:
            print(f"INSERT IGNORE INTO ParentChild (child_uuid, parent_uuid) VALUES ('{members['proband']}', '{members['father']}');")

print("\n-- 8. Analysis")
for row in rows:
    # Проект: подзапрос для получения project_id
    project_id = f"(SELECT project_id FROM Project WHERE project_name = '{row['Проект']}')" if row['Проект'] and row['Проект'].strip() else "NULL"
    
    # Диагноз: БЕРЁМ diagnosis_code ИЗ ФАЙЛА, ищем diagnosis_id в таблице Diagnosis
    diagnosis_id = "NULL"
    if row['Предполагаемый диагноз'] and row['Предполагаемый диагноз'].strip():
        diagnosis_id = f"(SELECT diagnosis_id FROM Diagnosis WHERE diagnosis_code = '{row['Предполагаемый диагноз']}')"
        
    run_id = f"(SELECT run_id FROM SequencingRun WHERE run_number = '{row['Номер запуска']}')"
    
    # Экранирование текстовых полей
    phenotype = row['Фенотип'].replace("'", "''") if row['Фенотип'] else ""
    pipeline = row['Пайплайн анализа'].replace("'", "''") if row['Пайплайн анализа'] else ""
    reference = row['Референсный геном'].replace("'", "''") if row['Референсный геном'] else ""
    
    # Числовые поля
    mean_cov = float(row['Средняя глубина покрытия']) if row['Средняя глубина покрытия'] and row['Средняя глубина покрытия'].strip() else 0
    coverage = float(row['Покрытие']) if row['Покрытие'] and row['Покрытие'].strip() else 0
    reads = int(float(row['Количество прочтений'])) if row['Количество прочтений'] and row['Количество прочтений'].strip() else 0
    uniformity = float(row['Униформность']) if row['Униформность'] and row['Униформность'].strip() else 0
    
    # Даты
    date_analysis = row['Дата анализа'][:10] if row['Дата анализа'] and row['Дата анализа'].strip() else "NULL"
    deadline = row['Дедлайн'][:10] if row['Дедлайн'] and row['Дедлайн'].strip() else "NULL"
    
    # Boolean
    results_shared = "TRUE" if str(row['Выданы результаты партнерам']).upper() == 'TRUE' else "FALSE"
    
    print(f"""
INSERT INTO Analysis (
    patient_uuid, run_id, project_id, diagnosis_id,
    phenotype, pipeline, reference_genome,
    mean_coverage, coverage_percent, reads_count, uniformity,
    date_analysis, deadline, results_shared
) VALUES (
    '{row['УИН2']}', {run_id}, {project_id}, {diagnosis_id},
    '{phenotype}', '{pipeline}', '{reference}',
    {mean_cov:.2f}, {coverage:.5f}, {reads}, {uniformity:.5f},
    {f"'{date_analysis}'" if date_analysis != "NULL" else "NULL"}, {f"'{deadline}'" if deadline != "NULL" else "NULL"}, {results_shared}
);
""")
