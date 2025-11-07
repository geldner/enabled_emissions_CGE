import pandas as pd
import matplotlib.pyplot as plt
import numpy as np

# Load the results and baseline emissions
df = pd.read_csv('results/experiment_gen_and_commodity_results.csv')
baseline_df = pd.read_csv('baseline_co2.csv')

# Merge with baseline emissions
df = df.merge(baseline_df, left_on='REG', right_on='REG', how='left', suffixes=('', '_baseline'))

# Convert percentage values to actual changes in millions of tons
df['nominal_change_mt'] = (df['Value'] / 100) * df['Value_baseline']

# Sum values by sim_id (aggregating over REG)
sim_totals = df.groupby('sim_id').agg({
    'nominal_change_mt': 'sum',
    'renewable_level': 'first',
    'fossil_level': 'first',
    'rest_of_economy_level': 'first'
}).reset_index()

# Extract values for renewable (fossil none, ROE none)
renewable_low = sim_totals[
    (sim_totals['renewable_level'] == 'low') &
    (sim_totals['fossil_level'] == 'none') &
    (sim_totals['rest_of_economy_level'] == 'none')
]['nominal_change_mt'].values[0]

renewable_medium = sim_totals[
    (sim_totals['renewable_level'] == 'medium') &
    (sim_totals['fossil_level'] == 'none') &
    (sim_totals['rest_of_economy_level'] == 'none')
]['nominal_change_mt'].values[0]

renewable_high = sim_totals[
    (sim_totals['renewable_level'] == 'high') &
    (sim_totals['fossil_level'] == 'none') &
    (sim_totals['rest_of_economy_level'] == 'none')
]['nominal_change_mt'].values[0]

# Extract values for fossil (renewable none, ROE none)
fossil_low = sim_totals[
    (sim_totals['renewable_level'] == 'none') &
    (sim_totals['fossil_level'] == 'low') &
    (sim_totals['rest_of_economy_level'] == 'none')
]['nominal_change_mt'].values[0]

fossil_medium = sim_totals[
    (sim_totals['renewable_level'] == 'none') &
    (sim_totals['fossil_level'] == 'medium') &
    (sim_totals['rest_of_economy_level'] == 'none')
]['nominal_change_mt'].values[0]

fossil_high = sim_totals[
    (sim_totals['renewable_level'] == 'none') &
    (sim_totals['fossil_level'] == 'high') &
    (sim_totals['rest_of_economy_level'] == 'none')
]['nominal_change_mt'].values[0]

# Extract values for net effect (low/low/none, medium/medium/none, high/high/none)
net_low = sim_totals[
    (sim_totals['renewable_level'] == 'low') &
    (sim_totals['fossil_level'] == 'low') &
    (sim_totals['rest_of_economy_level'] == 'none')
]['nominal_change_mt'].values[0]

net_medium = sim_totals[
    (sim_totals['renewable_level'] == 'medium') &
    (sim_totals['fossil_level'] == 'medium') &
    (sim_totals['rest_of_economy_level'] == 'none')
]['nominal_change_mt'].values[0]

net_high = sim_totals[
    (sim_totals['renewable_level'] == 'high') &
    (sim_totals['fossil_level'] == 'high') &
    (sim_totals['rest_of_economy_level'] == 'none')
]['nominal_change_mt'].values[0]

# Create bar chart
fig, ax = plt.subplots(figsize=(12, 8))

# Define bar positions and width
x = np.array([0, 1.5, 2.5, 3.5, 5])  # Gaps for separators
width = 0.6

# Data for each category
categories = ['Datacenters\n(1st order)', 'Renewable\n(2nd order)', 'Fossil\n(2nd order)', 'Net Effect\n(2nd order)', 'Net Effect\n(1st and 2nd order)']
low_values = [180, renewable_low, fossil_low, net_low, net_low + 180]
medium_values = [300, renewable_medium, fossil_medium, net_medium, net_medium + 300]
high_values = [500, renewable_high, fossil_high, net_high, net_high + 500]

# For each bar, we'll create segments from 0 to low, low to medium, medium to high
for i, (low, med, high) in enumerate(zip(low_values, medium_values, high_values)):
    # Determine if values are positive or negative to handle properly
    # We'll use three segments with different shading

    # Sort values to determine bottom and top of each segment
    values_sorted = sorted([0, low, med, high])

    # Segment 1: from 0 to low (lightest shade)
    bottom_1 = min(0, low)
    height_1 = abs(low)
    if i == 0:  # Datacenters bar - use grey
        color_1 = 'lightgrey'
    else:
        color_1 = 'lightcoral' if low > 0 else 'lightgreen'

    # Segment 2: from low to medium (medium shade)
    bottom_2 = min(low, med)
    height_2 = abs(med - low)
    if i == 0:  # Datacenters bar - use grey
        color_2 = 'grey'
    else:
        color_2 = 'indianred' if med > low else 'mediumseagreen'

    # Segment 3: from medium to high (darkest shade)
    bottom_3 = min(med, high)
    height_3 = abs(high - med)
    if i == 0:  # Datacenters bar - use grey
        color_3 = 'darkgrey'
    else:
        color_3 = 'darkred' if high > med else 'darkgreen'

    # Draw the three segments
    ax.bar(x[i], height_1, width, bottom=bottom_1, color=color_1, edgecolor='black', linewidth=1.5, label='Low' if i == 0 else '')
    ax.bar(x[i], height_2, width, bottom=bottom_2, color=color_2, edgecolor='black', linewidth=1.5, label='Medium' if i == 0 else '')
    ax.bar(x[i], height_3, width, bottom=bottom_3, color=color_3, edgecolor='black', linewidth=1.5, label='High' if i == 0 else '')

    # Add text labels for each level
    ax.text(x[i], low, f'{low:.1f}', ha='center', va='center', fontsize=10, fontweight='bold',
            bbox=dict(boxstyle='round,pad=0.3', facecolor='white', edgecolor='black', linewidth=0.5))
    ax.text(x[i], med, f'{med:.1f}', ha='center', va='center', fontsize=10, fontweight='bold',
            bbox=dict(boxstyle='round,pad=0.3', facecolor='white', edgecolor='black', linewidth=0.5))
    ax.text(x[i], high, f'{high:.1f}', ha='center', va='center', fontsize=10, fontweight='bold',
            bbox=dict(boxstyle='round,pad=0.3', facecolor='white', edgecolor='black', linewidth=0.5))

# Add vertical line separators
ax.axvline(x=0.75, color='black', linestyle='-', linewidth=2)  # After datacenters
ax.axvline(x=4.25, color='black', linestyle='-', linewidth=2)  # Before final net effect

# Customize plot
ax.set_ylabel('Change in CO₂ Emissions (Million Tons)', fontsize=14)
ax.set_title('Emission Changes by Policy Level', fontsize=16, fontweight='bold')
ax.set_xticks(x)
ax.set_xticklabels(categories, fontsize=12)
ax.axhline(y=0, color='black', linestyle='-', linewidth=2)
ax.grid(axis='y', alpha=0.3, linestyle='--')
ax.legend(title='Policy Level', fontsize=10, title_fontsize=11)

plt.tight_layout()
plt.savefig('emission_decomposition_bars.png', dpi=300, bbox_inches='tight')

# Print summary
print("Emission Changes (Million Tons CO₂) - Fuel-Neutral Adoption: None")
print("=" * 75)
print(f"\n{'Category':<30} {'Low':>12} {'Medium':>12} {'High':>12}")
print("-" * 75)
print(f"{'Datacenters':<30} {180:>12.2f} {300:>12.2f} {500:>12.2f}")
print("-" * 75)
print(f"{'Renewable':<30} {renewable_low:>12.2f} {renewable_medium:>12.2f} {renewable_high:>12.2f}")
print(f"{'Fossil':<30} {fossil_low:>12.2f} {fossil_medium:>12.2f} {fossil_high:>12.2f}")
print(f"{'Net Effect (2nd order)':<30} {net_low:>12.2f} {net_medium:>12.2f} {net_high:>12.2f}")
print("-" * 75)
print(f"{'Net Effect (1st and 2nd order)':<30} {net_low + 180:>12.2f} {net_medium + 300:>12.2f} {net_high + 500:>12.2f}")
print("=" * 75)
