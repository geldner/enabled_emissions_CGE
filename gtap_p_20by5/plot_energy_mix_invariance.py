import pandas as pd
import matplotlib.pyplot as plt
import numpy as np

# ── Load and compute emissions impacts ──────────────────────────────────────

# 2024 base year
df24 = pd.read_csv('results_final/experiment_gen_and_commodity_results.csv')
bl24 = pd.read_csv('baseline_co2.csv')
df24 = df24.merge(bl24, on='REG', suffixes=('', '_baseline'))
df24['change_gt'] = (df24['Value'] / 100) * df24['Value_baseline'] / 1000
sim24 = df24.groupby('sim_id').agg({
    'change_gt': 'sum', 'renewable_level': 'first',
    'fossil_level': 'first', 'fuel_neutral_level': 'first'
}).reset_index()

# 2017 base year
df17 = pd.read_csv('results_final/experiment_gen_and_commodity_2017_results.csv')
bl17 = pd.read_csv('baseline_co2_2017.csv')
df17 = df17.merge(bl17, on='REG', suffixes=('', '_baseline'))
df17['change_gt'] = (df17['Value'] / 100) * df17['Value_baseline'] / 1000
sim17 = df17.groupby('sim_id').agg({
    'change_gt': 'sum', 'renewable_level': 'first',
    'fossil_level': 'first', 'fuel_neutral_level': 'first'
}).reset_index()

# Extract no-fuel-neutral, single-sector shocks (fossil / renewable ratio)
levels = ['low', 'medium', 'high']

def get_emissions_ratios(sim, fn_col):
    ratios = []
    for lev in levels:
        ren = sim[(sim[fn_col] == 'none') & (sim['fossil_level'] == 'none') &
                  (sim['renewable_level'] == lev)]['change_gt'].values[0]
        fos = sim[(sim[fn_col] == 'none') & (sim['renewable_level'] == 'none') &
                  (sim['fossil_level'] == lev)]['change_gt'].values[0]
        ratios.append(fos / abs(ren))
    return ratios

ratios_17 = get_emissions_ratios(sim17, 'fuel_neutral_level')
ratios_24 = get_emissions_ratios(sim24, 'fuel_neutral_level')

# ── Load energy mix ─────────────────────────────────────────────────────────

mix = pd.read_csv('results_final/primary_energy_mix.csv')
fossil_ergs = ['Coal', 'Oil', 'Gas']
renew_ergs = ['NuclearBL', 'WindBL', 'HydroBL', 'OtherBL', 'SolarP', 'HydroP']

mix_ratios = {}
for ds, label in [('basedata_2017', '2017'), ('basedata_2024', '2024')]:
    m = mix[mix['dataset'] == ds]
    fos_out = m[m['ERG'].isin(fossil_ergs)]['output'].sum()
    ren_out = m[m['ERG'].isin(renew_ergs)]['output'].sum()
    mix_ratios[label] = fos_out / ren_out

# ── Figure: single grouped bar chart ───────────────────────────────────────

categories = ['Energy Mix', 'Low', 'Medium', 'High']
vals_17 = [mix_ratios['2017']] + ratios_17
vals_24 = [mix_ratios['2024']] + ratios_24

x = np.arange(len(categories))
width = 0.3

fig, ax = plt.subplots(figsize=(9, 6))

bars_17 = ax.bar(x - width/2, vals_17, width, label='2017 Base Year',
                 color='#1f77b4', edgecolor='black', linewidth=0.5)
bars_24 = ax.bar(x + width/2, vals_24, width, label='2024 Base Year',
                 color='#ff7f0e', edgecolor='black', linewidth=0.5)

# Annotate values
for bars in [bars_17, bars_24]:
    for bar in bars:
        h = bar.get_height()
        ax.text(bar.get_x() + bar.get_width()/2, h + 0.04,
                f'{h:.2f}', ha='center', va='bottom', fontsize=11, fontweight='bold')

# Divider between energy mix and emissions ratios
ax.axvline(x=0.5, color='grey', linestyle='--', linewidth=0.8, alpha=0.6)

ax.set_xticks(x)
ax.set_xticklabels(categories, fontsize=13)
ax.set_ylabel('Fossil / Renewable Ratio', fontsize=14)
ax.set_title(
    'Fossil-to-Renewable Ratio: Energy Mix vs. Emissions Impact\n'
    '(No Fuel-Neutral Adoption)',
    fontsize=15, fontweight='bold', pad=12
)
ax.legend(fontsize=12)
ax.spines['top'].set_visible(False)
ax.spines['right'].set_visible(False)

# Label the two sections
ax.text(0, -0.75, 'Output Ratio', ha='center', fontsize=11, fontstyle='italic', color='#555555')
ax.text(2, -0.75, 'Emissions Impact Ratio (by Shock Level)', ha='center', fontsize=11,
        fontstyle='italic', color='#555555')

ax.set_ylim(0, max(vals_17 + vals_24) * 1.18)

plt.subplots_adjust(bottom=0.18)
plt.savefig('energy_mix_invariance.png', dpi=300, bbox_inches='tight')
print("Saved energy_mix_invariance.png")
