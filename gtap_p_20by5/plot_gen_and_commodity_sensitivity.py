import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle
import matplotlib.cm as cm
import matplotlib.colors as colors

# Load data
all_sens = pd.read_csv('results_final/experiment_gen_and_commodity_sensitivity_all_results.csv')
baseline_df = pd.read_csv('baseline_co2.csv')
baseline_results = pd.read_csv('results_final/experiment_gen_and_commodity_results.csv')

level_mapping = {'none': 0, 'low': 1, 'medium': 2, 'high': 3}

def compute_totals(rdf, fn_col):
    merged = rdf.merge(baseline_df, on='REG', suffixes=('', '_baseline'))
    merged['nominal_change_gt'] = (merged['Value'] / 100) * merged['Value_baseline'] / 1000
    totals = merged.groupby('sim_id').agg({
        'nominal_change_gt': 'sum',
        'renewable_level': 'first',
        'fossil_level': 'first',
        fn_col: 'first'
    }).reset_index()
    return totals[totals[fn_col] == 'none'].copy()

# Compute totals for each case at fuel-neutral = none
cases = {
    'cap_low': compute_totals(all_sens[all_sens['prm_file'] == 'cap_low'], 'fuel_neutral_level'),
    'cap_high': compute_totals(all_sens[all_sens['prm_file'] == 'cap_high'], 'fuel_neutral_level'),
    'type_low': compute_totals(all_sens[all_sens['prm_file'] == 'type_low'], 'fuel_neutral_level'),
    'type_high': compute_totals(all_sens[all_sens['prm_file'] == 'type_high'], 'fuel_neutral_level'),
}
baseline_totals = compute_totals(baseline_results, 'fuel_neutral_level')

# Shared color scale encompassing all cases and baseline
all_vals = pd.concat([df['nominal_change_gt'] for df in cases.values()] + [baseline_totals['nominal_change_gt']])
max_abs_value = max(abs(all_vals.min()), abs(all_vals.max()))

# Panel layout and labels
panel_order = ['cap_low', 'cap_high', 'type_low', 'type_high']
panel_titles = {
    'cap_low': 'Capital-Energy Substitution: -50%',
    'cap_high': 'Capital-Energy Substitution: +50%',
    'type_low': 'Power Type Substitution: -50%',
    'type_high': 'Power Type Substitution: +50%',
}

# Create 2x3 grid with the rightmost column for colorbar
fig = plt.figure(figsize=(14, 12))
gs = fig.add_gridspec(2, 3, width_ratios=[1, 1, 0.05], hspace=0.25, wspace=0.15,
                      left=0.08, right=0.94, top=0.88, bottom=0.08)

plot_axes = [
    fig.add_subplot(gs[0, 0]),
    fig.add_subplot(gs[0, 1]),
    fig.add_subplot(gs[1, 0]),
    fig.add_subplot(gs[1, 1]),
]

norm = colors.Normalize(vmin=-max_abs_value, vmax=max_abs_value)
cmap = cm.get_cmap('RdYlGn_r')

for idx, case_name in enumerate(panel_order):
    ax = plot_axes[idx]
    data = cases[case_name].copy()

    data['x_pos'] = data['renewable_level'].map(level_mapping)
    data['y_pos'] = data['fossil_level'].map(level_mapping)

    cell_size = 0.8
    for _, row in data.iterrows():
        x = row['x_pos']
        y = row['y_pos']
        value = row['nominal_change_gt']

        rect = Rectangle((x - cell_size/2, y - cell_size/2), cell_size, cell_size,
                        facecolor=cmap(norm(value)),
                        edgecolor='black',
                        linewidth=1)
        ax.add_patch(rect)

    ax.set_xlabel('Renewables Level', fontsize=15)
    ax.set_ylabel('Fossil Level', fontsize=15)
    ax.set_title(panel_titles[case_name], fontsize=17)

    ax.set_xticks([0, 1, 2, 3])
    ax.set_xticklabels(['None', 'Low', 'Medium', 'High'], fontsize=13)
    ax.set_yticks([0, 1, 2, 3])
    ax.set_yticklabels(['None', 'Low', 'Medium', 'High'], fontsize=13)

    for _, row in data.iterrows():
        ax.annotate(f'{row["nominal_change_gt"]:.1f}',
                    (row['x_pos'], row['y_pos']),
                    ha='center', va='center', fontsize=13, fontweight='bold', color='black')

    ax.set_xlim(-0.5, 3.5)
    ax.set_ylim(-0.5, 3.5)
    ax.set_aspect('equal', adjustable='box')

# Shared colorbar
cbar_ax = fig.add_subplot(gs[:, 2])
scatter = plot_axes[0].scatter([], [], c=[], cmap='RdYlGn_r', vmin=-max_abs_value, vmax=max_abs_value)
cbar = fig.colorbar(scatter, cax=cbar_ax, orientation='vertical')
cbar.set_label('Change in CO₂ Emissions (Gt)', rotation=270, labelpad=20, fontsize=15)

fig.suptitle('Sensitivity of CO₂ Emissions to Substitution Elasticity Parameters\n(Fuel-Neutral Adoption Level: None)',
             fontsize=20, y=0.98)

plt.savefig('experiment_gen_and_commodity_sensitivity_emissions.png', dpi=300, bbox_inches='tight')

# Print summary
print(f"Shared color scale: ±{max_abs_value:.2f} Gt")
for case_name in panel_order:
    data = cases[case_name]
    print(f"  {case_name}: {data['nominal_change_gt'].min():+.2f} to {data['nominal_change_gt'].max():+.2f} Gt")
print(f"  baseline: {baseline_totals['nominal_change_gt'].min():+.2f} to {baseline_totals['nominal_change_gt'].max():+.2f} Gt")
