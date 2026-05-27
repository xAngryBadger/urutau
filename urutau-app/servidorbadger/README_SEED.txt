SEED A PARTIR DO CSV (fora do workspace)
=========================================

1. Inicie o servidor: iniciar_servidor.ps1

2. Configure credenciais (uma vez):
   - Copie .env.seed.example para .env.seed
   - Edite .env.seed: defina PB_ADMIN_EMAIL e PB_ADMIN_PASSWORD (admin do PocketBase)
   - PB_URL ja vem como http://localhost:8090 no seed_badger.bat

3. Execute o seed: seed_badger.bat

   Opcional: passar CSV por argumento
   powershell -ExecutionPolicy Bypass -File seed_from_csv.ps1 -CsvPath "C:\Users\...\Planilha_ISAAC 1(mapeamento_area_pt).csv"

O script apaga todas as plantas e parcelas no servidor e insere as do CSV.
Nao faca commit de .env.seed (contem a sua senha).
