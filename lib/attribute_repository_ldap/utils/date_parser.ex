defmodule AttributeRepositoryLdap.Utils.DateParser do
  import NimbleParsec

  year =
    ascii_string([?0..?9], 4)
    |> tag(:year)

  month =
    ascii_string([?0..?9], 2)
    |> tag(:month)

  day =
    ascii_string([?0..?9], 2)
    |> tag(:day)

  hour =
    ascii_string([?0..?9], 2)
    |> tag(:hour)

  minute =
    ascii_string([?0..?9], 2)
    |> tag(:minute)

  second =
    ascii_string([?0..?9], 2)
    |> tag(:second)

  leap_second =
    string("60")
    |> tag(:second)

  minute_second =
    minute
    |> optional(choice([second, leap_second]))

  fraction =
    choice([
      string("."),
      string(","),
    ])
    |> ignore()
    |> ascii_string([?0..?9], min: 1)
    |> tag(:fraction)

  g_time_zone =
    choice(
      [
        string("Z"),
        choice([string("+"), string("-")])
        |> ascii_string([?0..?9], 2)
        |> optional(ascii_string([?0..?9], 2))
      ]
    )
    |> tag(:timezone)

  defparsec :datetime,
  year
  |> concat(month)
  |> concat(day)
  |> concat(hour)
  |> optional(minute_second)
  |> optional(fraction)
  |> concat(g_time_zone)

  def to_datetime(iso8601_basic) do
    {:ok, m, _, _, _, _} = datetime(iso8601_basic)

    iso8601_extended =
      "#{m[:year]}"
      <> "-"
      <> "#{m[:month]}"
      <> "-"
      <> "#{m[:day]}"
      <> "T"
      <> "#{m[:hour]}"
      <> ":"
      <> "#{m[:minute] || 00}"
      <> ":"
      <> "#{m[:second] || 00}"
      <> "."
      <> "#{m[:fraction] || 0}"
      <> case m[:timezone] do
        ["Z"] ->
          "Z"

        [sign, hour] ->
          sign <> "#{hour}"
        [sign, hour, minute] ->
          sign <> "#{hour}" <> ":" <> "#{minute}"
      end

    DateTime.from_iso8601(iso8601_extended)
    |> elem(1)
  end
end
