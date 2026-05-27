import sqlite3
import json
import re
import random
import string
import os
from datetime import datetime

DB_PATH = os.environ.get("DB_PATH", "pb_data/data.db")

def generate_id():
    return ''.join(random.choices(string.ascii_lowercase + string.digits, k=15))

def get_timestamp():
    return datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S.') + f'{random.randint(0, 999):03d}Z'

def migrate():
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    print("Starting migration...")
    
    # 1. Add isAdmin to users collection
    print("Adding isAdmin field to users...")
    cursor.execute("SELECT fields FROM _collections WHERE name = 'users'")
    row = cursor.fetchone()
    if row:
        fields = json.loads(row[0])
        # Check if isAdmin already exists
        if not any(f.get('name') == 'isAdmin' for f in fields):
            fields.append({
                "system": False,
                "id": "bool_isAdmin_" + generate_id()[:8],
                "name": "isAdmin",
                "type": "bool",
                "required": False,
                "presentable": False,
                "unique": False,
                "options": {}
            })
            cursor.execute(
                "UPDATE _collections SET fields = ?, updated = ? WHERE name = 'users'",
                (json.dumps(fields), get_timestamp())
            )
            # Add column to users table
            try:
                cursor.execute("ALTER TABLE users ADD COLUMN isAdmin BOOLEAN DEFAULT 0")
            except:
                pass
            print("  Added isAdmin field")
    
    # 2. Create propriedades table
    print("Creating propriedades table...")
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS propriedades (
            id TEXT PRIMARY KEY,
            codigo TEXT UNIQUE NOT NULL,
            nome TEXT,
            created TEXT NOT NULL,
            updated TEXT NOT NULL
        )
    """)
    
    # 3. Create uts table
    print("Creating uts table...")
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS uts (
            id TEXT PRIMARY KEY,
            codigo TEXT NOT NULL,
            propriedade TEXT NOT NULL,
            created TEXT NOT NULL,
            updated TEXT NOT NULL,
            FOREIGN KEY (propriedade) REFERENCES propriedades(id)
        )
    """)
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_uts_propriedade ON uts(propriedade)")
    
    # 4. Add new columns to parcelas
    print("Adding new columns to parcelas...")
    try:
        cursor.execute("ALTER TABLE parcelas ADD COLUMN ut TEXT")
    except:
        pass
    try:
        cursor.execute("ALTER TABLE parcelas ADD COLUMN synced BOOLEAN DEFAULT 0")
    except:
        pass
    try:
        cursor.execute("ALTER TABLE parcelas ADD COLUMN prontaParaSync BOOLEAN DEFAULT 0")
    except:
        pass
    try:
        cursor.execute("ALTER TABLE parcelas ADD COLUMN userId TEXT")
    except:
        pass
    
    # 5. Migrate data: extract propriedades and uts from prop_ut
    print("Migrating data from prop_ut...")
    cursor.execute("SELECT DISTINCT prop_ut FROM parcelas WHERE prop_ut != ''")
    prop_uts = cursor.fetchall()
    
    propriedades = {}
    uts = {}
    
    for (prop_ut,) in prop_uts:
        match = re.match(r'([A-Z]+[0-9]+)\s*-\s*(UT[0-9]+)', prop_ut)
        if match:
            prop_codigo = match.group(1)
            ut_codigo = match.group(2)
            
            if prop_codigo not in propriedades:
                propriedades[prop_codigo] = generate_id()
            
            ut_key = f"{prop_codigo}_{ut_codigo}"
            if ut_key not in uts:
                uts[ut_key] = {
                    'id': generate_id(),
                    'codigo': ut_codigo,
                    'propriedade_id': propriedades[prop_codigo]
                }
    
    print(f"  Found {len(propriedades)} propriedades and {len(uts)} UTs")
    
    # Insert propriedades
    ts = get_timestamp()
    for codigo, pid in propriedades.items():
        cursor.execute(
            "INSERT OR IGNORE INTO propriedades (id, codigo, created, updated) VALUES (?, ?, ?, ?)",
            (pid, codigo, ts, ts)
        )
    
    # Insert uts
    for ut_key, ut_data in uts.items():
        cursor.execute(
            "INSERT OR IGNORE INTO uts (id, codigo, propriedade, created, updated) VALUES (?, ?, ?, ?, ?)",
            (ut_data['id'], ut_data['codigo'], ut_data['propriedade_id'], ts, ts)
        )
    
    # Update parcelas
    for (prop_ut,) in prop_uts:
        match = re.match(r'([A-Z]+[0-9]+)\s*-\s*(UT[0-9]+)', prop_ut)
        if match:
            prop_codigo = match.group(1)
            ut_codigo = match.group(2)
            ut_key = f"{prop_codigo}_{ut_codigo}"
            ut_id = uts[ut_key]['id']
            cursor.execute("UPDATE parcelas SET ut = ? WHERE prop_ut = ?", (ut_id, prop_ut))
    
    # Set synced = 1 for existing records
    cursor.execute("UPDATE parcelas SET synced = 1 WHERE ut IS NOT NULL")
    
    # 6. Register collections in PocketBase metadata
    print("Registering collections in PocketBase...")
    
    # Register propriedades collection
    cursor.execute("SELECT id FROM _collections WHERE name = 'propriedades'")
    if not cursor.fetchone():
        cursor.execute("""
            INSERT INTO _collections (id, system, type, name, fields, indexes, listRule, viewRule, createRule, updateRule, deleteRule, options, created, updated)
            VALUES (?, 0, 'base', 'propriedades', ?, '[]', '', '', NULL, NULL, NULL, '{}', ?, ?)
        """, (
            'prop_col_' + generate_id()[:10],
            json.dumps([
                {"system": False, "id": "text_id", "name": "id", "type": "text", "required": True, "primaryKey": True, "autogeneratePattern": "[a-z0-9]{15}"},
                {"system": False, "id": "text_codigo", "name": "codigo", "type": "text", "required": True, "unique": True, "presentable": True},
                {"system": False, "id": "text_nome", "name": "nome", "type": "text", "required": False},
                {"system": False, "id": "autodate_created", "name": "created", "type": "autodate", "onCreate": True},
                {"system": False, "id": "autodate_updated", "name": "updated", "type": "autodate", "onCreate": True, "onUpdate": True}
            ]),
            ts, ts
        ))
    
    # Register uts collection
    cursor.execute("SELECT id FROM _collections WHERE name = 'uts'")
    if not cursor.fetchone():
        cursor.execute("""
            INSERT INTO _collections (id, system, type, name, fields, indexes, listRule, viewRule, createRule, updateRule, deleteRule, options, created, updated)
            VALUES (?, 0, 'base', 'uts', ?, '[]', '', '', NULL, NULL, NULL, '{}', ?, ?)
        """, (
            'uts_col_' + generate_id()[:10],
            json.dumps([
                {"system": False, "id": "text_id", "name": "id", "type": "text", "required": True, "primaryKey": True, "autogeneratePattern": "[a-z0-9]{15}"},
                {"system": False, "id": "text_codigo", "name": "codigo", "type": "text", "required": True, "presentable": True},
                {"system": False, "id": "relation_prop", "name": "propriedade", "type": "relation", "required": True, "options": {"collectionId": "prop_col_001", "minSelect": 1, "maxSelect": 1}},
                {"system": False, "id": "autodate_created", "name": "created", "type": "autodate", "onCreate": True},
                {"system": False, "id": "autodate_updated", "name": "updated", "type": "autodate", "onCreate": True, "onUpdate": True}
            ]),
            ts, ts
        ))
    
    # Update parcelas collection metadata
    cursor.execute("SELECT fields FROM _collections WHERE name = 'parcelas'")
    row = cursor.fetchone()
    if row:
        fields = json.loads(row[0])
        # Add new fields
        new_fields = [
            {"system": False, "id": "relation_ut", "name": "ut", "type": "relation", "required": False, "options": {"collectionId": "uts_col_001", "maxSelect": 1}},
            {"system": False, "id": "bool_synced", "name": "synced", "type": "bool", "required": False},
            {"system": False, "id": "bool_pronta", "name": "prontaParaSync", "type": "bool", "required": False},
            {"system": False, "id": "relation_user", "name": "userId", "type": "relation", "required": False, "options": {"collectionId": "_pb_users_auth_", "maxSelect": 1}}
        ]
        for nf in new_fields:
            if not any(f.get('name') == nf['name'] for f in fields):
                fields.append(nf)
        cursor.execute("UPDATE _collections SET fields = ?, updated = ? WHERE name = 'parcelas'", (json.dumps(fields), ts))
    
    conn.commit()
    conn.close()
    print("Migration completed successfully!")

if __name__ == "__main__":
    migrate()
