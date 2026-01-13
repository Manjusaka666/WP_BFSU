import pandas as pd

# Load panel
panel = pd.read_csv(r'e:\研究生\WP_BFSU\data\processed\panel_quarterly.csv')

print("=== PANEL SHAPE ===")
print(f"Total rows: {panel.shape[0]}")
print(f"Total columns: {panel.shape[1]}")

print("\n=== KEY COLUMNS AVAILABILITY ===")
for col in ['CPI_QoQ_Ann', 'mu_cp', 'quarter']:
    if col in panel.columns:
        non_null = panel[col].notna().sum()
        print(f"{col}: {non_null}/{len(panel)} non-null values")
        if non_null > 0:
            print(f"  Sample values: {panel[col].dropna().head(3).tolist()}")
    else:
        print(f"{col}: **MISSING**")

print("\n=== TESTING FE/FR CALCULATION ===")
# Simulate the calculation
panel_test = panel.copy()
panel_test['CPI_target'] = panel_test['CPI_QoQ_Ann'].shift(-1)
panel_test['FE'] = panel_test['CPI_target'] - panel_test['mu_cp']
panel_test['FR'] = panel_test['mu_cp'] - panel_test['mu_cp'].shift(1)

print(f"CPI_target non-null: {panel_test['CPI_target'].notna().sum()}")
print(f"FE non-null: {panel_test['FE'].notna().sum()}")
print(f"FR non-null: {panel_test['FR'].notna().sum()}")

fe_fr_data = panel_test.dropna(subset=['FE', 'FR'])
print(f"\nSample with both FE and FR: N={len(fe_fr_data)}")

if len(fe_fr_data) > 0:
    print("\nFirst 3 rows with valid FE/FR:")
    print(fe_fr_data[['quarter', 'mu_cp', 'CPI_QoQ_Ann', 'CPI_target', 'FE', 'FR']].head(3))
else:
    print("\n**NO VALID FE/FR ROWS**")
    print("\nDiagnosing issue - showing first 10 rows:")
    print(panel_test[['quarter', 'mu_cp', 'CPI_QoQ_Ann', 'CPI_target', 'FE', 'FR']].head(10))
