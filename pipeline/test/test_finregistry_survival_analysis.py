import numpy as np
import pandas as pd
from pandas._testing import assert_frame_equal
from risteys_pipeline.config import FOLLOWUP_START, FOLLOWUP_END
from risteys_pipeline.finregistry.survival_analysis import (
    build_cph_dataset,
    build_exposure_dataset,
    build_outcome_dataset,
)


def generate_df(birth_year, death_year, exposure_year, outcome_year):
    """Generate a test dataframe for build_cph_dataset() tests"""
    df = pd.DataFrame(
        {
            "finregistryid": [0],
            "birth_year": birth_year,
            "death_year": death_year,
            "exposure_year": exposure_year,
            "outcome_year": outcome_year,
            "weight": [0],
            "female": [0],
            "case": [np.isnan(exposure_year).astype(int)],
        }
    )
    return df


def test_build_exposure_dataset():
    """
    Test building the exposure dataset: exposure during follow-up
                  start                    end
    >----- -----|-----X-----O           |
    """
    df = generate_df(
        birth_year=FOLLOWUP_START - 10,
        death_year=np.nan,
        exposure_year=FOLLOWUP_START + 5,
        outcome_year=FOLLOWUP_START + 10,
    )
    res = build_exposure_dataset(df)
    cols = ["finregistryid", "duration", "exposure"]
    expected = pd.DataFrame([[0, 5, 1]], columns=cols)
    assert_frame_equal(res[cols], expected, check_dtype=False)


def test_build_cph_dataset_outcome_exposure():
    """
    Test building the cph dataset: exposure and outcome during follow-up
              start                    end
    >----- -----|-----X-----O           |
    """
    df = generate_df(
        birth_year=FOLLOWUP_START - 10,
        death_year=np.nan,
        exposure_year=FOLLOWUP_START + 5,
        outcome_year=FOLLOWUP_START + 10,
    )
    cols = ["start", "stop", "exposure", "outcome"]
    res = build_cph_dataset(df, "time-on-study")
    expected = pd.DataFrame([[0, 5, 0, 0], [5, 10, 1, 1]], columns=cols)
    assert_frame_equal(res[cols], expected, check_dtype=False)


def test_build_cph_dataset_no_exposure_no_outcome():
    """
    Test building the cph dataset: no exposure, no outcome
              start                    end
    >----- -----|----- ----- ----- -----|----
    """
    df = generate_df(
        birth_year=FOLLOWUP_START - 10,
        death_year=np.nan,
        exposure_year=np.nan,
        outcome_year=np.nan,
    )
    cols = ["start", "stop", "exposure", "outcome"]
    res = build_cph_dataset(df, "time-on-study")
    expected = pd.DataFrame([[0, FOLLOWUP_END - FOLLOWUP_START, 0, 0]], columns=cols)
    assert_frame_equal(res[cols], expected, check_dtype=False)


def test_build_cph_dataset_outcome_no_exposure():
    """
    Test building the cph dataset: no exposure, outcome during follow-up
              start                    end
    >----- -----|----- -----O           |
    """
    df = generate_df(
        birth_year=FOLLOWUP_START - 10,
        death_year=np.nan,
        exposure_year=np.nan,
        outcome_year=FOLLOWUP_START + 10,
    )
    cols = ["start", "stop", "exposure", "outcome"]
    res = build_cph_dataset(df, "time-on-study")
    expected = pd.DataFrame([[0, 10, 0, 1]], columns=cols)
    assert_frame_equal(res[cols], expected, check_dtype=False)


def test_build_cph_dataset_no_outcome_exposure():
    """
    Test building the cph dataset: no outcome, exposure during follow-up
              start                    end
    >----- -----|----- -----X----- -----|
    """
    df = generate_df(
        birth_year=FOLLOWUP_START - 10,
        death_year=np.nan,
        exposure_year=FOLLOWUP_START + 10,
        outcome_year=np.nan,
    )
    cols = ["start", "stop", "exposure", "outcome"]
    res = build_cph_dataset(df, "time-on-study")
    expected = pd.DataFrame(
        [[0, 10, 0, 0], [10, FOLLOWUP_END - FOLLOWUP_START, 1, 0]], columns=cols
    )
    assert_frame_equal(res[cols], expected, check_dtype=False)


def test_build_cph_dataset_exposure_after_followup():
    """
    Test building the cph dataset: exposure after follow-up, no outcome
              start                    end
    >----- -----|----- ----- ----- -----|----X
    """
    df = generate_df(
        birth_year=FOLLOWUP_START - 10,
        death_year=np.nan,
        exposure_year=FOLLOWUP_END + 5,
        outcome_year=np.nan,
    )
    cols = ["start", "stop", "exposure", "outcome"]
    res = build_cph_dataset(df, "time-on-study")
    expected = pd.DataFrame([[0, FOLLOWUP_END - FOLLOWUP_START, 0, 0]], columns=cols)
    assert_frame_equal(res[cols], expected, check_dtype=False)


def test_build_cph_dataset_exposure_before_followup():
    """
    Test building the cph dataset: exposure before follow-up, no outcome
              start                    end
    >-----X-----|----- ----- ----- -----|----
    """
    df = generate_df(
        birth_year=FOLLOWUP_START - 10,
        death_year=np.nan,
        exposure_year=FOLLOWUP_START - 5,
        outcome_year=np.nan,
    )
    cols = ["start", "stop", "exposure", "outcome"]
    res = build_cph_dataset(df, "time-on-study")
    expected = pd.DataFrame([[0, FOLLOWUP_END - FOLLOWUP_START, 0, 0]], columns=cols)
    assert_frame_equal(res[cols], expected, check_dtype=False)


def test_build_cph_dataset_outcome_before_followup():
    """
    Test building the cph dataset: outcome before follow-up, no exposure
                  start                    end
    >-----O-----|----- ----- ----- -----|----
    """
    df = generate_df(
        birth_year=FOLLOWUP_START - 10,
        death_year=np.nan,
        exposure_year=np.nan,
        outcome_year=FOLLOWUP_START - 5,
    )
    cols = ["start", "stop", "exposure", "outcome"]
    res = build_cph_dataset(df, "time-on-study")
    expected = pd.DataFrame([[0, FOLLOWUP_END - FOLLOWUP_START, 0, 0]], columns=cols)
    assert_frame_equal(res[cols], expected, check_dtype=False)


def test_build_cph_dataset_late_entry():
    """
    Test building the cph dataset: late entry
              start                    end
                |     >-----X-----O     |
    """
    df = generate_df(
        birth_year=FOLLOWUP_START + 5,
        death_year=np.nan,
        exposure_year=FOLLOWUP_START + 10,
        outcome_year=FOLLOWUP_START + 15,
    )
    cols = ["start", "stop", "exposure", "outcome"]
    res = build_cph_dataset(df, "time-on-study")
    expected = pd.DataFrame([[5, 10, 0, 0], [10, 15, 1, 1]], columns=cols)
    assert_frame_equal(res[cols], expected, check_dtype=False)


def test_build_cph_dataset_outcome_before_exposure():
    """
    Test building the cph dataset: outcome before exposure
              start                    end
                |     >-----O     X     |
    """
    df = generate_df(
        birth_year=FOLLOWUP_START + 5,
        death_year=np.nan,
        exposure_year=FOLLOWUP_START + 15,
        outcome_year=FOLLOWUP_START + 10,
    )
    cols = ["start", "stop", "exposure", "outcome"]
    res = build_cph_dataset(df, "time-on-study")
    expected = pd.DataFrame([[5, 10, 0, 1]], columns=cols)
    assert_frame_equal(res[cols], expected, check_dtype=False)


def test_build_cph_dataset_exposure_and_death():
    """
    Test building the cph dataset: exposure, death
              start                    end
                |     >-----X-----D     |
    """
    df = generate_df(
        birth_year=FOLLOWUP_START + 5,
        death_year=FOLLOWUP_START + 15,
        exposure_year=FOLLOWUP_START + 10,
        outcome_year=np.nan,
    )
    cols = ["start", "stop", "exposure", "outcome"]
    res = build_cph_dataset(df, "time-on-study")
    expected = pd.DataFrame([[5, 10, 0, 0], [10, 15, 1, 0]], columns=cols)
    assert_frame_equal(res[cols], expected, check_dtype=False)


def test_build_cph_dataset_outcome_and_death():
    """
    Test building the cph dataset: exposure, death
              start                    end
                |     >-----O     D     |
    """
    df = generate_df(
        birth_year=FOLLOWUP_START + 5,
        death_year=FOLLOWUP_START + 15,
        exposure_year=np.nan,
        outcome_year=FOLLOWUP_START + 10,
    )
    cols = ["start", "stop", "exposure", "outcome"]
    res = build_cph_dataset(df, "time-on-study")
    expected = pd.DataFrame([[5, 10, 0, 1]], columns=cols)
    assert_frame_equal(res[cols], expected, check_dtype=False)


def test_build_cph_dataset_same_time():
    """
    Test building the cph dataset: exposure and outcome at the same time
              start                    end
    >----- -----|----- -----XO          |
    """
    df = generate_df(
        birth_year=FOLLOWUP_START - 10,
        death_year=np.nan,
        exposure_year=FOLLOWUP_START + 10,
        outcome_year=FOLLOWUP_START + 10,
    )
    cols = ["start", "stop", "exposure", "outcome"]
    res = build_cph_dataset(df, "time-on-study")
    expected = pd.DataFrame([[0, 10, 0, 1]], columns=cols)
    assert_frame_equal(res[cols], expected, check_dtype=False)


def test_build_cph_dataset_age_as_timescale():
    """
    Test building the cph dataset: age as timescale
              start                    end
    >----- -----|-----X-----O           |
    """
    df = generate_df(
        birth_year=FOLLOWUP_START - 10,
        death_year=np.nan,
        exposure_year=FOLLOWUP_START + 5,
        outcome_year=FOLLOWUP_START + 10,
    )
    cols = ["start", "stop", "exposure", "outcome"]
    res = build_cph_dataset(df, "age")
    expected = pd.DataFrame([[10, 15, 0, 0], [15, 20, 1, 1]], columns=cols)
    assert_frame_equal(res[cols], expected, check_dtype=False)
