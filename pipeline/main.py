"""Run analyses for FinRegistry data"""

from random import sample
import pandas as pd

from itertools import product

from risteys_pipeline.finregistry.load_data import (
    load_endpoints_data,
    load_minimal_phenotype_data,
    load_wide_first_events_data,
)
from risteys_pipeline.finregistry.sample import sample_cases_and_controls

# Load and preprocess endpoint definitions and minimal phenotype data
endpoints = load_endpoints_data(preprocess=True)
minimal_phenotype = load_minimal_phenotype_data(preprocess=True)

# Set up outcomes and exposures
outcomes = ["DEATH"]
exposures = ["T2D", "5_SCHZPHR"]

# Loop through outcomes and exposures

for outcome, exposure in product(outcomes, exposures):
    # Load and preprocess first events data
    first_events = load_wide_first_events_data(exposure, outcome, preprocess=True)

    # Merge minimal phenotype with first events
    # Note: only subjects in minimal phenotype are included
    df = minimal_phenotype.merge(first_events, how="left", on="finregistryid")

    # Sample cases and controls based on outcome
    df = sample_cases_and_controls(df, n_cases=250000, controls_per_case=2)
