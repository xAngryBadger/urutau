# Seed PocketBase from CSV

This script **cleans** all parcelas/plantas on your PocketBase server and **re-seeds** them from the Planilha ISAAC CSV. It uses your **PocketBase admin** (dashboard) account to do that — not the app’s “admin” user.

- **PocketBase admin** = the account you use to open the PocketBase dashboard (create collections, see all data). The script uses this to call the PocketBase API and create/delete records.
- **App admin** = the user inside the app (e.g. login with Flora123). The script does **not** use this; it only needs PocketBase admin.

## How to run (pick one)

### 1) Command-line (no password in files)

From the **project root** (`inventario_florestal`):

```bash
dart run tool/seed_pocketbase_from_csv.dart --pb-url=YOUR_POCKETBASE_URL --admin-email=user@example.com --admin-password=YOUR_PB_ADMIN_PASSWORD "C:\Users\isaac\Downloads\Planilha_ISAAC 1(mapeamento_area_pt).csv"
```

Replace `YOUR_POCKETBASE_URL` with your real PocketBase URL (e.g. the ngrok URL you use in the app). Replace `YOUR_PB_ADMIN_PASSWORD` with your PocketBase dashboard password.

### 2) Local config file (password stays only on your PC)

1. Copy the example:  
   `copy tool\.env.seed.example tool\.env.seed`
2. Edit `tool/.env.seed` and set:
   - `PB_URL` = your PocketBase URL
   - `PB_ADMIN_EMAIL` = user@example.com
   - `PB_ADMIN_PASSWORD` = your PocketBase admin password
3. Run (CSV path optional):

```bash
dart run tool/seed_pocketbase_from_csv.dart "C:\Users\isaac\Downloads\Planilha_ISAAC 1(mapeamento_area_pt).csv"
```

`tool/.env.seed` is in `.gitignore`, so your password is never committed.

### 3) Environment variables

Set `PB_URL`, `PB_ADMIN_EMAIL`, `PB_ADMIN_PASSWORD` in your shell, then run the script with the CSV path as the first argument.

---

**Important:** Do not put your real PocketBase admin password in the repository (no committed files). Use args, env, or the local `tool/.env.seed` file only.
