defmodule RisteysWeb.LabTestHTML do
  use RisteysWeb, :html

  embed_templates "lab_test_html/*"

  defp prettify_stats(stats, overall_stats) do
    assigns = %{}
    pretty_stats = stats

    sex_female_percent =
      case stats.sex_female_percent do
        nil -> nil
        value -> RisteysWeb.Utils.round_and_str(value, 2) <> "%"
      end

    plot_sex_female_percent = plot_sex(stats.sex_female_percent)

    plot_npeople_absolute = plot_count(stats.npeople_total, overall_stats.npeople)

    plot_median_n_measurements =
      plot_count(stats.median_n_measurements, overall_stats.median_n_measurements)

    tick_every_year = 365.25

    plot_median_ndays_first_to_last_measurement =
      plot_count(
        stats.median_ndays_first_to_last_measurement,
        overall_stats.median_ndays_first_to_last_measurement,
        tick_every_year
      )

    pretty_stats =
      Map.merge(pretty_stats, %{
        sex_female_percent: sex_female_percent,
        plot_npeople_absolute: plot_npeople_absolute,
        plot_sex_female_percent: plot_sex_female_percent,
        plot_median_n_measurements: plot_median_n_measurements,
        plot_median_ndays_first_to_last_measurement: plot_median_ndays_first_to_last_measurement
      })

    missing_value = ~H"""
    <span class="missing-value">&mdash;</span>
    """

    pretty_stats =
      for {key, value} <- pretty_stats, into: %{} do
        {key, value || missing_value}
      end

    pretty_stats
  end

  defp plot_sex(nil), do: ""

  defp plot_sex(female_percent) do
    assigns = %{female_percent: female_percent}

    ~H"""
    <div style="width: 100%; height: 0.3em; background-color: #bfcde6;">
      <div style={"width: #{@female_percent}%; height: 100%; background-color: #dd9fbd; border-right: 1px solid #777;"}>
      </div>
    </div>
    """
  end

  defp plot_count(npeople, npeople_max, tick_every \\ nil)

  defp plot_count(nil, _, _), do: ""

  defp plot_count(npeople, npeople_max, tick_every) do
    tick_percents =
      case tick_every do
        nil ->
          []

        _ ->
          last = round(npeople_max)
          step = round(tick_every)
          Range.to_list(step..last//step)
      end
      |> Enum.map(&(100 * &1 / npeople_max))

    assigns = %{
      npeople_percent: 100 * npeople / npeople_max,
      tick_percents: tick_percents
    }

    ~H"""
    <div style="width: 100%; height: 0.3em; background-color: var(--bg-color-plot-empty); position: relative;">
      <div style={"width: #{@npeople_percent}%; height: 100%; background-color: var(--bg-color-plot); position: absolute;"}>
      </div>
      <%= for tick_percent <- @tick_percents do %>
        <div style={"width: #{tick_percent}%; height: 100%; border-right: 1px solid var(--bg-color-plot-empty); position: absolute;"}>
        </div>
      <% end %>
    </div>
    """
  end
end