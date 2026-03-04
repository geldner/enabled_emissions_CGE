import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle
import matplotlib.cm as cm
import matplotlib.colors as colors

# Load the results and baseline GDP
df = pd.read_csv('results_final/experiment_gen_and_commodity_gdp_results.csv')
baseline_df = pd.read_csv('results_final/baseline_gdp.csv')
baseline_df['REG'] = baseline_df['REG'].str.replace(r'^\d+\s+', '', regex=True)

# Merge with baseline GDP
df = df.merge(baseline_df, left_on='REG', right_on='REG', how='left')

# Convert percentage values to actual changes in trillions of dollars
# GDP values are percentage changes; baseline GDP is in millions of dollars
df['nominal_change_tn'] = (df['Value'] / 100) * df['gdp'] / 1e6

# Sum values by sim_id (aggregating over REG)
sim_totals = df.groupby('sim_id').agg({
    'nominal_change_tn': 'sum',
    'renewable_level': 'first',
    'fossil_level': 'first',
    'fuel_neutral_level': 'first'
}).reset_index()

# Create level mappings
level_mapping = {'none': 0, 'low': 1, 'medium': 2, 'high': 3}
fn_levels = ['none', 'low', 'baseline', 'high']

# Calculate symmetric bounds around zero for all data
max_abs_value = max(abs(sim_totals['nominal_change_tn'].min()), abs(sim_totals['nominal_change_tn'].max()))

# Create 2x3 grid with the rightmost column for colorbar
fig = plt.figure(figsize=(14, 12))
gs = fig.add_gridspec(2, 3, width_ratios=[1, 1, 0.05], hspace=0.25, wspace=0.15,
                      left=0.08, right=0.94, top=0.88, bottom=0.08)

# Create the 4 plot axes (2x2 on the left)
plot_axes = [
    fig.add_subplot(gs[0, 0]),  # Top left
    fig.add_subplot(gs[0, 1]),  # Top right
    fig.add_subplot(gs[1, 0]),  # Bottom left
    fig.add_subplot(gs[1, 1])   # Bottom right
]

for idx, fn_level in enumerate(fn_levels):
    ax = plot_axes[idx]

    # Filter data for this fuel-neutral level
    fn_data = sim_totals[sim_totals['fuel_neutral_level'] == fn_level].copy()

    # Map categorical levels to numeric positions
    fn_data['x_pos'] = fn_data['renewable_level'].map(level_mapping)
    fn_data['y_pos'] = fn_data['fossil_level'].map(level_mapping)

    # Create colormap normalization
    norm = colors.Normalize(vmin=-max_abs_value, vmax=max_abs_value)
    cmap = cm.get_cmap('RdYlGn')

    # Draw squares for each simulation
    cell_size = 0.8
    for _, row in fn_data.iterrows():
        x = row['x_pos']
        y = row['y_pos']
        value = row['nominal_change_tn']

        # Create rectangle centered at (x, y)
        rect = Rectangle((x - cell_size/2, y - cell_size/2), cell_size, cell_size,
                        facecolor=cmap(norm(value)),
                        edgecolor='black',
                        linewidth=1)
        ax.add_patch(rect)

    # Customize the plot
    ax.set_xlabel('Renewables Level', fontsize=15)
    ax.set_ylabel('Fossil Level', fontsize=15)
    # Map baseline to medium for display
    display_level = 'Medium' if fn_level == 'baseline' else fn_level.capitalize()
    ax.set_title(f'Fuel-Neutral Adoption Level: {display_level}', fontsize=17)

    # Set tick labels
    ax.set_xticks([0, 1, 2, 3])
    ax.set_xticklabels(['None', 'Low', 'Medium', 'High'], fontsize=13)
    ax.set_yticks([0, 1, 2, 3])
    ax.set_yticklabels(['None', 'Low', 'Medium', 'High'], fontsize=13)

    # Add text annotations for values on each cell
    for _, row in fn_data.iterrows():
        ax.annotate(f'{row["nominal_change_tn"]:.2f}',
                    (row['x_pos'], row['y_pos']),
                    ha='center', va='center', fontsize=13, fontweight='bold', color='black')

    # Set axis limits to show all squares properly
    ax.set_xlim(-0.5, 3.5)
    ax.set_ylim(-0.5, 3.5)

    # Set aspect ratio to be equal for better visualization
    ax.set_aspect('equal', adjustable='box')

# Add colorbar in the rightmost column spanning both rows
cbar_ax = fig.add_subplot(gs[:, 2])
scatter = plot_axes[0].scatter([], [], c=[], cmap='RdYlGn', vmin=-max_abs_value, vmax=max_abs_value)
cbar = fig.colorbar(scatter, cax=cbar_ax, orientation='vertical')
cbar.set_label('Change in GDP (Tn $)', rotation=270, labelpad=20, fontsize=15)

fig.suptitle('Change in GDP - Fossil (Generation and Extraction) and Renewables (Generation)\n(4×4 Grid for each Fuel-Neutral Adoption Level)',
             fontsize=20, y=0.98)

plt.savefig('experiment_gen_and_commodity_gdp.png', dpi=300, bbox_inches='tight')

# Print summary statistics
print(f"Total simulations: {len(sim_totals)}")
print(f"Value range: {sim_totals['nominal_change_tn'].min():.2f} to {sim_totals['nominal_change_tn'].max():.2f} Tn $")
print(f"\nBy fuel-neutral adoption level:")
for fn_level in fn_levels:
    fn_data = sim_totals[sim_totals['fuel_neutral_level'] == fn_level]
    print(f"  {fn_level}: {fn_data['nominal_change_tn'].min():.2f} to {fn_data['nominal_change_tn'].max():.2f} Tn $")
