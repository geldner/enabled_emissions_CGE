#!/usr/bin/env python3
"""
Driver script to run all plotting scripts and generate all figures.
"""

import subprocess
import sys

# List of all plotting scripts in order
plotting_scripts = [
    # Scenario experiments
    "plot_generation_only.py",
    "plot_gen_and_commodity.py",
    "plot_commodity_only.py",

    # 10x10 experiments - No Fuel-Neutral Adoption
    "plot_10x10_no_fn_generation_only.py",
    "plot_10x10_no_fn_gen_and_commodity.py",
    "plot_10x10_no_fn_commodity_only.py",

    # 10x10 experiments - Low Fuel-Neutral Adoption
    "plot_10x10_low_fn_generation_only.py",
    "plot_10x10_low_fn_gen_and_commodity.py",
    "plot_10x10_low_fn_commodity_only.py",

    # 10x10 experiments - Medium Fuel-Neutral Adoption
    "plot_10x10_medium_fn_generation_only.py",
    "plot_10x10_medium_fn_gen_and_commodity.py",
    "plot_10x10_medium_fn_commodity_only.py",

    # 10x10 experiments - High Fuel-Neutral Adoption
    "plot_10x10_high_fn_generation_only.py",
    "plot_10x10_high_fn_gen_and_commodity.py",
    "plot_10x10_high_fn_commodity_only.py",

    # Decomposition bars
    "plot_decomposition_bars.py",
    "plot_medium_scenario_decomposition.py",

    # Energy mix invariance
    "plot_energy_mix_invariance.py",

    # Sensitivity and robustness
    "plot_gen_and_commodity_sensitivity.py",
    "plot_gen_and_commodity_cap_low.py",
    "plot_gen_and_commodity_cap_high.py",
    "plot_gen_and_commodity_type_low.py",
    "plot_gen_and_commodity_type_high.py",

    # Carbon tax scenarios
    "plot_gen_and_commodity_ctax_69.py",
    "plot_gen_and_commodity_ctax_102.py",
    "plot_gen_and_commodity_ctax_160.py",
    "plot_gen_and_commodity_ctax_266.py",

    # Alternate baselines and GDP
    "plot_gen_and_commodity_2017.py",
    "plot_gen_and_commodity_gdp.py",
    "plot_gen_and_commodity_gdp_per_co2.py",
    "plot_gen_and_commodity_gdp_and_co2_bars.py",
]

def main():
    print("Starting plot generation...")
    print("=" * 60)

    total = len(plotting_scripts)
    failed = []

    for i, script in enumerate(plotting_scripts, 1):
        print(f"\n[{i}/{total}] Running {script}...")

        try:
            result = subprocess.run(
                [sys.executable, script],
                capture_output=True,
                text=True,
                check=True
            )

            # Print the script's output
            if result.stdout:
                print(result.stdout)

            print(f"✓ {script} completed successfully")

        except subprocess.CalledProcessError as e:
            print(f"✗ {script} failed!")
            print(f"Error output:\n{e.stderr}")
            failed.append(script)
        except Exception as e:
            print(f"✗ {script} failed with exception: {e}")
            failed.append(script)

    print("\n" + "=" * 60)
    if failed:
        print(f"Plot generation completed with {len(failed)} error(s):")
        for script in failed:
            print(f"  - {script}")
        sys.exit(1)
    else:
        print(f"All {total} plots generated successfully!")
        sys.exit(0)

if __name__ == "__main__":
    main()
