import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle
import matplotlib.cm as cm
import matplotlib.colors as colors
import numpy as np
from scipy.interpolate import griddata

# Load the results and baseline emissions
df = pd.read_csv('results/experiment_10x10_low_fn_generation_only_results.csv')
baseline_df = pd.read_csv('baseline_co2.csv')

# Merge with baseline emissions
df = df.merge(baseline_df, left_on='REG', right_on='REG', how='left', suffixes=('', '_baseline'))

# Convert percentage values to actual changes in millions of tons
df['nominal_change_mt'] = (df['Value'] / 100) * df['Value_baseline']

# Sum values by sim_id (aggregating over REG)
sim_totals = df.groupby('sim_id').agg({
    'nominal_change_mt': 'sum',
    'renewable_int': 'first',
    'fossil_int': 'first'
}).reset_index()

# Convert intensity values to shock magnitudes (0-100 scale)
sim_totals['renewable_shock_magnitude'] = sim_totals['renewable_int'] * 100
sim_totals['fossil_shock_magnitude'] = sim_totals['fossil_int'] * 100

# Create the 2D plot
fig, ax = plt.subplots(figsize=(12, 10))

# Calculate symmetric bounds around zero
max_abs_value = max(abs(sim_totals['nominal_change_mt'].min()), abs(sim_totals['nominal_change_mt'].max()))

# Get unique coordinates and create grid
x_coords = sorted(sim_totals['renewable_shock_magnitude'].unique())
y_coords = sorted(sim_totals['fossil_shock_magnitude'].unique())

# Calculate cell size
x_step = x_coords[1] - x_coords[0] if len(x_coords) > 1 else 10
y_step = y_coords[1] - y_coords[0] if len(y_coords) > 1 else 10

# Create colormap normalization
norm = colors.Normalize(vmin=-max_abs_value, vmax=max_abs_value)
cmap = cm.get_cmap('RdYlGn_r')

# Draw squares for each simulation
for _, row in sim_totals.iterrows():
    x = row['renewable_shock_magnitude']
    y = row['fossil_shock_magnitude']
    value = row['nominal_change_mt']

    # Create rectangle centered at (x, y)
    rect = Rectangle((x - x_step/2, y - y_step/2), x_step, y_step,
                    facecolor=cmap(norm(value)),
                    edgecolor='black',
                    linewidth=0.3)
    ax.add_patch(rect)

# Create a dummy scatter for colorbar
scatter = ax.scatter([], [], c=[], cmap='RdYlGn_r', vmin=-max_abs_value, vmax=max_abs_value)

# Add colorbar
cbar = plt.colorbar(scatter, ax=ax)
cbar.set_label('Change in CO₂ Emissions (Million Tons)', rotation=270, labelpad=20)

# Perform linear interpolation to find the zero level set
x_fine = np.linspace(min(x_coords), max(x_coords), 200)
y_fine = np.linspace(min(y_coords), max(y_coords), 200)
X_fine, Y_fine = np.meshgrid(x_fine, y_fine)
points = sim_totals[['renewable_shock_magnitude', 'fossil_shock_magnitude']].values
values = sim_totals['nominal_change_mt'].values
Z_fine = griddata(points, values, (X_fine, Y_fine), method='linear')

# Customize the plot
ax.set_xlabel("Renewable Efficiency Gains (percent change)")
ax.set_ylabel('Fossil Efficiency Gains (percent change)')
ax.set_title('Change in CO₂ Emissions - Low Fuel-Neutral Adoption, Generation Only\n(10×10 Grid, Each cell represents one simulation)')

# Set axis limits and ticks
ax.set_xlim(min(x_coords) - x_step/2, max(x_coords) + x_step/2)
ax.set_ylim(min(y_coords) - y_step/2, max(y_coords) + y_step/2)

# Set tick marks at intervals of 20
ax.set_xticks(range(0, 101, 20))
ax.set_yticks(range(0, 101, 20))

# Add grid
ax.grid(True, alpha=0.3)

# Find and draw the zero level set with masking
contour = ax.contour(X_fine, Y_fine, Z_fine, levels=[0], colors='none', linewidths=0)
exclusion_radius = 2
for level_idx, segments_at_level in enumerate(contour.allsegs):
    all_filtered_segments = []
    for segment in segments_at_level:
        current_segment = []
        for point in segment:
            too_close = False
            for _, row in sim_totals.iterrows():
                text_x = row['renewable_shock_magnitude']
                text_y = row['fossil_shock_magnitude']
                distance = np.sqrt((point[0] - text_x)**2 + (point[1] - text_y)**2)
                if distance < exclusion_radius:
                    too_close = True
                    break
            if not too_close:
                current_segment.append(point)
            else:
                if len(current_segment) > 1:
                    all_filtered_segments.append(np.array(current_segment))
                current_segment = []
        if len(current_segment) > 1:
            all_filtered_segments.append(np.array(current_segment))
    if all_filtered_segments:
        for seg in all_filtered_segments:
            ax.plot(seg[:, 0], seg[:, 1], color='grey', linewidth=2.5, linestyle='--', zorder=1)

# Add text annotations for values on each cell (smaller font for 10x10 grid)
for _, row in sim_totals.iterrows():
    ax.annotate(f'{row["nominal_change_mt"]:.0f}',
                (row['renewable_shock_magnitude'], row['fossil_shock_magnitude']),
                ha='center', va='center', fontsize=6, fontweight='bold', color='black', zorder=2)


# Add legend for the zero level set
ax.plot([], [], color='grey', linewidth=2.5, linestyle='--', label='Breakeven / Net Zero')
ax.legend(loc='upper right', fontsize=10, framealpha=0.9)
# Set aspect ratio to be equal for better visualization
ax.set_aspect('equal', adjustable='box')

plt.tight_layout()
plt.savefig('experiment_10x10_low_fn_generation_only_emissions.png', dpi=300, bbox_inches='tight')

# Print summary statistics
print(f"Total simulations: {len(sim_totals)}")
print(f"Value range: {sim_totals['nominal_change_mt'].min():.2f} to {sim_totals['nominal_change_mt'].max():.2f} Mt CO₂")
print(f"Renewable shock magnitude range: {sim_totals['renewable_shock_magnitude'].min():.0f} to {sim_totals['renewable_shock_magnitude'].max():.0f}")
print(f"Fossil shock magnitude range: {sim_totals['fossil_shock_magnitude'].min():.0f} to {sim_totals['fossil_shock_magnitude'].max():.0f}")
