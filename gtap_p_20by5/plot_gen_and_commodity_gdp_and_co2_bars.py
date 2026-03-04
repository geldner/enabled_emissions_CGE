import pandas as pd
import matplotlib.pyplot as plt
import numpy as np

# Load GDP results and baseline
gdp_df = pd.read_csv('results_final/experiment_gen_and_commodity_gdp_results.csv')
baseline_gdp_df = pd.read_csv('results_final/baseline_gdp.csv')
baseline_gdp_df['REG'] = baseline_gdp_df['REG'].str.replace(r'^\d+\s+', '', regex=True)

# Load CO2 results and baseline
co2_df = pd.read_csv('results_final/experiment_gen_and_commodity_results.csv')
baseline_co2_df = pd.read_csv('baseline_co2.csv')

# Compute global baseline totals
global_baseline_gdp = baseline_gdp_df['gdp'].sum()  # millions $
global_baseline_co2 = baseline_co2_df['Value'].sum()  # Mt CO2

# Compute GDP: nominal change per region, then sum to global, then % change
gdp_df = gdp_df.merge(baseline_gdp_df, on='REG', how='left')
gdp_df['gdp_change'] = (gdp_df['Value'] / 100) * gdp_df['gdp']  # change in millions $

gdp_totals = gdp_df.groupby('sim_id').agg({
    'gdp_change': 'sum',
    'renewable_level': 'first',
    'fossil_level': 'first',
    'fuel_neutral_level': 'first'
}).reset_index()
gdp_totals['gdp_pct_change'] = gdp_totals['gdp_change'] / global_baseline_gdp * 100

# Compute CO2: nominal change per region, then sum to global, then % change
co2_df = co2_df.merge(baseline_co2_df, on='REG', how='left', suffixes=('', '_baseline'))
co2_df['co2_change'] = (co2_df['Value'] / 100) * co2_df['Value_baseline']  # change in Mt

co2_totals = co2_df.groupby('sim_id').agg({
    'co2_change': 'sum'
}).reset_index()
co2_totals['co2_pct_change'] = co2_totals['co2_change'] / global_baseline_co2 * 100

# Merge
sim_totals = gdp_totals.merge(co2_totals, on='sim_id', how='inner')

# Filter to diagonal cases: none/none, low/low, medium/medium, high/high
diagonal_levels = ['none', 'low', 'medium', 'high']
diagonal = sim_totals[
    sim_totals.apply(lambda r: r['renewable_level'] == r['fossil_level']
                     and r['renewable_level'] in diagonal_levels, axis=1)
].copy()

fn_levels = ['none', 'low', 'baseline', 'high']
fn_labels = ['None', 'Low', 'Medium', 'High']
diag_labels = ['None', 'Low', 'Medium', 'High']

# Set up figure with shared y-axis scale
fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(12, 10), sharex=True, sharey=True)

n_groups = len(fn_levels)
n_bars = len(diagonal_levels)
bar_width = 0.18
group_positions = np.arange(n_groups)

colors = ['#4daf4a', '#377eb8', '#ff7f00', '#e41a1c']

for i, diag_level in enumerate(diagonal_levels):
    gdp_vals = []
    co2_vals = []
    for fn_level in fn_levels:
        row = diagonal[
            (diagonal['renewable_level'] == diag_level) &
            (diagonal['fuel_neutral_level'] == fn_level)
        ]
        gdp_vals.append(row['gdp_pct_change'].values[0])
        co2_vals.append(row['co2_pct_change'].values[0])

    offsets = group_positions + (i - (n_bars - 1) / 2) * bar_width
    ax1.bar(offsets, gdp_vals, bar_width, label=f'{diag_labels[i]}',
            color=colors[i], edgecolor='black', linewidth=0.5)
    ax2.bar(offsets, co2_vals, bar_width,
            color=colors[i], edgecolor='black', linewidth=0.5)

# Top pane: GDP
ax1.set_ylabel('Change in Global GDP (%)', fontsize=15)
ax1.set_title('Percentage Change in Global GDP by Scenario', fontsize=17)
ax1.legend(title='AI Adoption Scenario\n(Equal Adoption)', fontsize=12, title_fontsize=13)
ax1.axhline(y=0, color='black', linewidth=0.5)
ax1.tick_params(axis='y', labelsize=13)

# Bottom pane: CO2
ax2.set_ylabel('Change in Global CO₂ Emissions (%)', fontsize=15)
ax2.set_title('Percentage Change in Global CO₂ Emissions by Scenario', fontsize=17)
ax2.set_xticks(group_positions)
ax2.set_xticklabels(fn_labels, fontsize=13)
ax2.set_xlabel('Fuel-Neutral Adoption Level', fontsize=15)
ax2.axhline(y=0, color='black', linewidth=0.5)
ax2.tick_params(axis='y', labelsize=13)

plt.tight_layout()
plt.savefig('experiment_gen_and_commodity_gdp_and_co2_bars.png', dpi=300, bbox_inches='tight')

# Print summary
print(f"Global baseline GDP: {global_baseline_gdp/1e6:.1f} Tn $")
print(f"Global baseline CO₂: {global_baseline_co2/1e3:.1f} Gt CO₂")
print(f"\nDiagonal cases (renewable_level = fossil_level):")
for fn_level, fn_label in zip(fn_levels, fn_labels):
    print(f"\n  Fuel-Neutral: {fn_label}")
    for diag_level in diagonal_levels:
        row = diagonal[
            (diagonal['renewable_level'] == diag_level) &
            (diagonal['fuel_neutral_level'] == fn_level)
        ]
        gdp_pct = row['gdp_pct_change'].values[0]
        co2_pct = row['co2_pct_change'].values[0]
        print(f"    {diag_level}/{diag_level}: GDP {gdp_pct:+.2f}%, CO₂ {co2_pct:+.2f}%")
