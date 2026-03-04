import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle
import matplotlib.cm as cm
import matplotlib.colors as colors

# Load GDP results and baseline
gdp_df = pd.read_csv('results_final/experiment_gen_and_commodity_gdp_results.csv')
baseline_gdp_df = pd.read_csv('results_final/baseline_gdp.csv')
baseline_gdp_df['REG'] = baseline_gdp_df['REG'].str.replace(r'^\d+\s+', '', regex=True)

# Load CO2 results and baseline
co2_df = pd.read_csv('results_final/experiment_gen_and_commodity_results.csv')
baseline_co2_df = pd.read_csv('baseline_co2.csv')

# Compute GDP levels in millions of dollars for each scenario
gdp_df = gdp_df.merge(baseline_gdp_df, on='REG', how='left')
gdp_df['gdp_level'] = gdp_df['gdp'] * (1 + gdp_df['Value'] / 100)

gdp_totals = gdp_df.groupby('sim_id').agg({
    'gdp_level': 'sum',
    'renewable_level': 'first',
    'fossil_level': 'first',
    'fuel_neutral_level': 'first'
}).reset_index()

# Compute CO2 levels in Mt for each scenario
co2_df = co2_df.merge(baseline_co2_df, on='REG', how='left', suffixes=('', '_baseline'))
co2_df['co2_level'] = co2_df['Value_baseline'] * (1 + co2_df['Value'] / 100)

co2_totals = co2_df.groupby('sim_id').agg({
    'co2_level': 'sum'
}).reset_index()

# Merge GDP and CO2 totals
sim_totals = gdp_totals.merge(co2_totals, on='sim_id', how='inner')

# Compute emissions intensity in tonnes CO2 per million $
# CO2 is in Mt, GDP is in millions $; Mt / M$ * 1e6 = tonnes / M$
sim_totals['co2_per_gdp'] = sim_totals['co2_level'] / sim_totals['gdp_level'] * 1e6

# Create level mappings
level_mapping = {'none': 0, 'low': 1, 'medium': 2, 'high': 3}
fn_levels = ['none', 'low', 'baseline', 'high']

# Use baseline (none/none/none) as midpoint for symmetric color normalization
baseline_intensity = sim_totals[sim_totals['sim_id'] == 'sim_01']['co2_per_gdp'].values[0]
max_deviation = max(sim_totals['co2_per_gdp'].max() - baseline_intensity,
                    baseline_intensity - sim_totals['co2_per_gdp'].min())
min_value = baseline_intensity - max_deviation
max_value = baseline_intensity + max_deviation

# Create 2x3 grid with the rightmost column for colorbar
fig = plt.figure(figsize=(14, 12))
gs = fig.add_gridspec(2, 3, width_ratios=[1, 1, 0.05], hspace=0.25, wspace=0.15,
                      left=0.08, right=0.94, top=0.88, bottom=0.08)

# Create the 4 plot axes (2x2 on the left)
plot_axes = [
    fig.add_subplot(gs[0, 0]),
    fig.add_subplot(gs[0, 1]),
    fig.add_subplot(gs[1, 0]),
    fig.add_subplot(gs[1, 1])
]

for idx, fn_level in enumerate(fn_levels):
    ax = plot_axes[idx]

    # Filter data for this fuel-neutral level
    fn_data = sim_totals[sim_totals['fuel_neutral_level'] == fn_level].copy()

    # Map categorical levels to numeric positions
    fn_data['x_pos'] = fn_data['renewable_level'].map(level_mapping)
    fn_data['y_pos'] = fn_data['fossil_level'].map(level_mapping)

    # Create colormap normalization
    norm = colors.Normalize(vmin=min_value, vmax=max_value)
    cmap = cm.get_cmap('RdYlGn_r')

    # Draw squares for each simulation
    cell_size = 0.8
    for _, row in fn_data.iterrows():
        x = row['x_pos']
        y = row['y_pos']
        value = row['co2_per_gdp']

        rect = Rectangle((x - cell_size/2, y - cell_size/2), cell_size, cell_size,
                        facecolor=cmap(norm(value)),
                        edgecolor='black',
                        linewidth=1)
        ax.add_patch(rect)

    # Customize the plot
    ax.set_xlabel('Renewables Level', fontsize=15)
    ax.set_ylabel('Fossil Level', fontsize=15)
    display_level = 'Medium' if fn_level == 'baseline' else fn_level.capitalize()
    ax.set_title(f'Fuel-Neutral Adoption Level: {display_level}', fontsize=17)

    # Set tick labels
    ax.set_xticks([0, 1, 2, 3])
    ax.set_xticklabels(['None', 'Low', 'Medium', 'High'], fontsize=13)
    ax.set_yticks([0, 1, 2, 3])
    ax.set_yticklabels(['None', 'Low', 'Medium', 'High'], fontsize=13)

    # Add text annotations
    for _, row in fn_data.iterrows():
        ax.annotate(f'{row["co2_per_gdp"]:.0f}',
                    (row['x_pos'], row['y_pos']),
                    ha='center', va='center', fontsize=13, fontweight='bold', color='black')

    ax.set_xlim(-0.5, 3.5)
    ax.set_ylim(-0.5, 3.5)
    ax.set_aspect('equal', adjustable='box')

# Add colorbar
cbar_ax = fig.add_subplot(gs[:, 2])
scatter = plot_axes[0].scatter([], [], c=[], cmap='RdYlGn_r', vmin=min_value, vmax=max_value)
cbar = fig.colorbar(scatter, cax=cbar_ax, orientation='vertical')
cbar.set_label('CO₂ Emissions / GDP (tonnes CO₂ / million $)', rotation=270, labelpad=20, fontsize=15)

fig.suptitle('Emissions Intensity of GDP - Fossil (Generation and Extraction) and Renewables (Generation)\n(4×4 Grid for each Fuel-Neutral Adoption Level)',
             fontsize=20, y=0.98)

plt.savefig('experiment_gen_and_commodity_co2_per_gdp.png', dpi=300, bbox_inches='tight')

# Print summary statistics
baseline_ratio = sim_totals[sim_totals['sim_id'] == 'sim_01']['co2_per_gdp'].values[0]
print(f"Total simulations: {len(sim_totals)}")
print(f"Baseline emissions intensity: {baseline_ratio:.2f} tonnes CO₂ / million $")
print(f"Range: {min_value:.2f} to {max_value:.2f} tonnes CO₂ / million $")
print(f"\nBy fuel-neutral adoption level:")
for fn_level in fn_levels:
    fn_data = sim_totals[sim_totals['fuel_neutral_level'] == fn_level]
    if len(fn_data) > 0:
        print(f"  {fn_level}: {fn_data['co2_per_gdp'].min():.2f} to {fn_data['co2_per_gdp'].max():.2f} tonnes CO₂ / million $")
