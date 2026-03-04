import pandas as pd
import matplotlib.pyplot as plt
import numpy as np

# Load data
shocks = pd.read_csv('results_final/individual_shocks_medium.csv')
baseline_gdp = pd.read_csv('results_final/baseline_gdp.csv')
baseline_co2 = pd.read_csv('baseline_co2.csv')

# Clean region names (baseline_gdp has "1 USA" format)
baseline_gdp['REG'] = baseline_gdp['REG'].str.strip().str.split().str[-1]
baseline_co2['REG'] = baseline_co2['REG'].str.strip()

# Drop rows with missing region (e.g. the empty afeall NatRes Coal row)
shocks = shocks.dropna(subset=['region'])

# Build baseline lookup dicts
co2_lookup = dict(zip(baseline_co2['REG'], baseline_co2['Value']))
gdp_lookup = dict(zip(baseline_gdp['REG'], baseline_gdp['gdp']))

shocks['baseline_co2'] = shocks['region'].map(co2_lookup)
shocks['baseline_gdp'] = shocks['region'].map(gdp_lookup)

# Calculate nominal changes (percentage / 100 * baseline)
shocks['nominal_co2_change'] = (shocks['co2'] / 100) * shocks['baseline_co2']
shocks['nominal_gdp_change'] = (shocks['gdp'] / 100) * shocks['baseline_gdp']

# Global baselines
global_baseline_co2 = baseline_co2['Value'].sum()
global_baseline_gdp = baseline_gdp['gdp'].sum()

# Sum nominal changes by param to get global nominal change, then compute global % change
global_changes = shocks.groupby('param').agg(
    total_co2_change=('nominal_co2_change', 'sum'),
    total_gdp_change=('nominal_gdp_change', 'sum')
).reset_index()

global_changes['co2_pct_change'] = (global_changes['total_co2_change'] / global_baseline_co2) * 100
global_changes['gdp_pct_change'] = (global_changes['total_gdp_change'] / global_baseline_gdp) * 100

# Sort by absolute CO2 change for readability
global_changes = global_changes.sort_values('co2_pct_change', key=abs, ascending=True).reset_index(drop=True)

# Create short labels from param names
def shorten_param(p):
    p = p.strip()
    # Remove outer function call and REG
    for prefix in ['afeall(', 'afall(', 'aoall(']:
        if p.startswith(prefix):
            p = p[len(prefix):]
            break
    # Remove REG references, quotes, and clean up parens
    p = p.replace('"', '')
    p = p.replace('(REG)', '').replace(',REG', '').replace(', REG', '')
    p = p.strip(') ,')
    return p

global_changes['label'] = global_changes['param'].apply(shorten_param)

# Plot
fig, ax = plt.subplots(figsize=(12, max(8, len(global_changes) * 0.4)))

y = np.arange(len(global_changes))
bar_height = 0.35

bars_co2 = ax.barh(y - bar_height/2, global_changes['co2_pct_change'], bar_height,
                    label='CO$_2$ Emissions', color='indianred', edgecolor='black', linewidth=0.5)
bars_gdp = ax.barh(y + bar_height/2, global_changes['gdp_pct_change'], bar_height,
                    label='GDP', color='steelblue', edgecolor='black', linewidth=0.5)

ax.set_yticks(y)
ax.set_yticklabels(global_changes['label'], fontsize=10)
ax.set_xlabel('Global Percent Change (%)', fontsize=13)
ax.set_title('Medium Scenario: Global CO$_2$ and GDP Changes by Parameter Shock', fontsize=15, fontweight='bold')
ax.axvline(x=0, color='black', linewidth=1)
ax.legend(fontsize=12, loc='best')
ax.grid(axis='x', alpha=0.3, linestyle='--')

plt.tight_layout()
plt.savefig('medium_scenario_decomposition.png', dpi=300, bbox_inches='tight')
plt.close()

# Print summary table
print(f"\n{'Parameter':<45} {'CO2 % Change':>14} {'GDP % Change':>14}")
print("=" * 75)
for _, row in global_changes.iterrows():
    print(f"{row['label']:<45} {row['co2_pct_change']:>14.6f} {row['gdp_pct_change']:>14.6f}")
