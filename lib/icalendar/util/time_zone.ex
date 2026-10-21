defmodule ICalendar.Util.TimeZone do
  @moduledoc false

  # Resolves local (wall clock) times in a named time zone. The library never relies on
  # the `:time_zone_database` of the host application, it always uses tzdata.

  @database Tzdata.TimeZoneDatabase

  @doc "The time zone database used for every conversion in this library."
  def database, do: @database

  @doc """
  Normalizes the UTC aliases the library has always accepted to `"Etc/UTC"`.
  """
  def normalize(:utc), do: "Etc/UTC"
  def normalize(name) when name in ["Etc/UTC", "Etc/GMT", "GMT", "UTC", "UT", "Z"], do: "Etc/UTC"
  def normalize(name), do: name

  @doc """
  Turns a naive datetime into a `DateTime` in the given zone.

  A wall clock time that occurs twice (the clocks go back) resolves to the later of the
  two, the standard time one. A wall clock time that does not exist (the clocks go
  forward) resolves according to `on_gap`: `:after` gives the first valid moment after the
  gap, `:error` gives `{:error, {:could_not_resolve_timezone, zone, gregorian_seconds, :wall}}`.
  """
  @spec localize(NaiveDateTime.t(), String.t() | :utc, :after | :error) ::
          {:ok, DateTime.t()} | {:error, term}
  def localize(%NaiveDateTime{} = naive, zone, on_gap) when on_gap in [:after, :error] do
    zone = normalize(zone)

    case DateTime.from_naive(naive, zone, @database) do
      {:ok, datetime} ->
        {:ok, datetime}

      {:ambiguous, _first, second} ->
        {:ok, second}

      {:gap, _before, just_after} when on_gap == :after ->
        {:ok, just_after}

      {:gap, _before, _after} ->
        seconds = naive |> NaiveDateTime.to_erl() |> :calendar.datetime_to_gregorian_seconds()
        {:error, {:could_not_resolve_timezone, zone, seconds, :wall}}

      {:error, _} = error ->
        error
    end
  end
end
