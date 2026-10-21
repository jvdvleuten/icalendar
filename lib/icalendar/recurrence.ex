defmodule ICalendar.Recurrence do
  @moduledoc """
  Adds support for recurring events.

  Events can recur by frequency, count, interval, and/or start/end date. To
  see the specific rules and examples, see `add_recurring_events/2` below.

  Credit to @fazibear for this module.
  """

  alias ICalendar.Event

  # ignore :byhour, :monthday, :byyearday, :byweekno, :bymonth for now
  @supported_by_x_rrules [:byday]

  @doc """
  Given an event, return a stream of recurrences for that event.

  Warning: this may create a very large sequence of event recurrences.

  ## Parameters

    - `event`: The event that may contain an rrule. See `ICalendar.Event`.

    - `end_date` *(optional)*: A date time that represents the fallback end date
      for a recurring event. This value is only used when the options specified
      in rrule result in an infinite recurrance (ie. when neither `count` nor
      `until` is set). If no end_date is set, it will default to
      `DateTime.utc_now()`.

  ## Event rrule options

    Event recurrance details are specified in the `rrule`. The following options
    are considered:

    - `freq`: Represents how frequently the event recurs. Allowed frequencies
      are `DAILY`, `WEEKLY`, and `MONTHLY`. These can be further modified by
      the `interval` option.

    - `count` *(optional)*: Represents the number of times that an event will
      recur. This takes precedence over the `end_date` parameter and the
      `until` option.

    - `interval` *(optional)*: Represents the interval at which events occur.
      This option works in concert with `freq` above; by using the `interval`
      option, an event could recur every 5 days or every 3 weeks.

    - `until` *(optional)*: Represents the end date for a recurring event.
      This takes precedence over the `end_date` parameter.

    - `byday` *(optional)*: Represents the days of the week at which events occur.

    The `freq` option is required for a valid rrule, but the others are
    optional. They may be used either individually (ex. just `freq`) or in
    concert (ex. `freq` + `interval` + `until`).

  ## Future rrule options (not yet supported)

    - `byhour` *(optional)*: Represents the hours of the day at which events occur.
    - `byweekno` *(optional)*: Represents the week number at which events occur.
    - `bymonthday` *(optional)*: Represents the days of the month at which events occur.
    - `bymonth` *(optional)*: Represents the months at which events occur.
    - `byyearday` *(optional)*: Represents the days of the year at which events occur.

  ## Examples

      iex> dt = ~U[2016-08-13 00:00:00Z]
      iex> dt_end = ~U[2016-08-23 00:00:00Z]
      iex> event = %ICalendar.Event{rrule:%{freq: "DAILY"}, dtstart: dt, dtend: dt}
      iex> recurrences =
            ICalendar.Recurrence.get_recurrences(event)
            |> Enum.to_list()

  """
  @spec get_recurrences(%Event{}) :: %Stream{}
  @spec get_recurrences(%Event{}, %DateTime{}) :: %Stream{}
  def get_recurrences(event, end_date \\ DateTime.utc_now()) do
    by_x_rrules =
      if is_map(event.rrule), do: Map.take(event.rrule, @supported_by_x_rrules), else: %{}

    reference_events =
      if by_x_rrules != %{} do
        # If there are any by_x modifiers in the rrule, build reference events based on them
        # Remove the invalid reference events later on
        build_refernce_events_by_x_rules(event, by_x_rrules)
      else
        [event]
      end

    case event.rrule do
      nil ->
        Stream.map([nil], fn _ -> [] end)

      %{freq: "DAILY", count: count, interval: interval} ->
        add_recurring_events_count(event, reference_events, count, days: interval)

      %{freq: "DAILY", until: until, interval: interval} ->
        add_recurring_events_until(event, reference_events, until, days: interval)

      %{freq: "DAILY", count: count} ->
        add_recurring_events_count(event, reference_events, count, days: 1)

      %{freq: "DAILY", until: until} ->
        add_recurring_events_until(event, reference_events, until, days: 1)

      %{freq: "DAILY", interval: interval} ->
        add_recurring_events_until(event, reference_events, end_date, days: interval)

      %{freq: "DAILY"} ->
        add_recurring_events_until(event, reference_events, end_date, days: 1)

      %{freq: "WEEKLY", until: until, interval: interval} ->
        add_recurring_events_until(event, reference_events, until, days: interval * 7)

      %{freq: "WEEKLY", count: count} ->
        add_recurring_events_count(event, reference_events, count, days: 7)

      %{freq: "WEEKLY", until: until} ->
        add_recurring_events_until(event, reference_events, until, days: 7)

      %{freq: "WEEKLY", interval: interval} ->
        add_recurring_events_until(event, reference_events, end_date, days: interval * 7)

      %{freq: "WEEKLY"} ->
        add_recurring_events_until(event, reference_events, end_date, days: 7)

      %{freq: "MONTHLY", count: count, interval: interval} ->
        add_recurring_events_count(event, reference_events, count, months: interval)

      %{freq: "MONTHLY", until: until, interval: interval} ->
        add_recurring_events_until(event, reference_events, until, months: interval)

      %{freq: "MONTHLY", count: count} ->
        add_recurring_events_count(event, reference_events, count, months: 1)

      %{freq: "MONTHLY", until: until} ->
        add_recurring_events_until(event, reference_events, until, months: 1)

      %{freq: "MONTHLY", interval: interval} ->
        add_recurring_events_until(event, reference_events, end_date, months: interval)

      %{freq: "MONTHLY"} ->
        add_recurring_events_until(event, reference_events, end_date, months: 1)

      %{freq: "YEARLY", count: count, interval: interval} ->
        add_recurring_events_count(event, reference_events, count, years: interval)

      %{freq: "YEARLY", until: until, interval: interval} ->
        add_recurring_events_until(event, reference_events, until, years: interval)

      %{freq: "YEARLY", count: count} ->
        add_recurring_events_count(event, reference_events, count, years: 1)

      %{freq: "YEARLY", until: until} ->
        add_recurring_events_until(event, reference_events, until, years: 1)

      %{freq: "YEARLY", interval: interval} ->
        add_recurring_events_until(event, reference_events, end_date, years: interval)

      %{freq: "YEARLY"} ->
        add_recurring_events_until(event, reference_events, end_date, years: 1)
    end
  end

  defp add_recurring_events_until(original_event, reference_events, until, shift_opts) do
    Stream.resource(
      fn -> [reference_events] end,
      fn acc_events ->
        # Use the previous batch of the events as the reference for the next batch
        [prev_event_batch | _] = acc_events

        case prev_event_batch do
          [] ->
            {:halt, acc_events}

          prev_event_batch ->
            new_events =
              Enum.map(prev_event_batch, fn reference_event ->
                new_event = shift_event(reference_event, shift_opts)

                case DateTime.compare(new_event.dtstart, until) do
                  :gt -> []
                  _ -> [new_event]
                end
              end)
              |> List.flatten()

            {remove_excluded_dates(new_events, original_event), [new_events | acc_events]}
        end
      end,
      fn recurrences ->
        recurrences
      end
    )
  end

  defp add_recurring_events_count(original_event, reference_events, count, shift_opts) do
    Stream.resource(
      fn -> {[reference_events], count} end,
      fn {acc_events, count} ->
        # Use the previous batch of the events as the reference for the next batch
        [prev_event_batch | _] = acc_events

        case prev_event_batch do
          [] ->
            {:halt, acc_events}

          prev_event_batch ->
            new_events =
              Enum.map(prev_event_batch, fn reference_event ->
                new_event = shift_event(reference_event, shift_opts)

                if count > 1 do
                  [new_event]
                else
                  []
                end
              end)
              |> List.flatten()

            {remove_excluded_dates(new_events, original_event),
             {[new_events | acc_events], count - 1}}
        end
      end,
      fn recurrences ->
        recurrences
      end
    )
  end

  defp shift_event(event, shift_opts) do
    Map.merge(event, %{
      dtstart: shift_date(event.dtstart, shift_opts),
      dtend: shift_date(event.dtend, shift_opts),
      rrule: Map.put(event.rrule, :is_recurrence, true)
    })
  end

  # Shifts the wall clock time of `date` in its own time zone, so a daily event stays at
  # the same local time across a DST change. A local time that occurs twice resolves to the
  # later one, a local time that does not exist resolves to the first moment after the gap.
  defp shift_date(date, []), do: date
  defp shift_date(%DateTime{} = date, [{_unit, 0}]), do: date

  defp shift_date(%DateTime{time_zone: time_zone} = date, shift_opts) do
    naive = date |> DateTime.to_naive() |> shift_naive(shift_opts)

    case ICalendar.Util.TimeZone.localize(naive, time_zone, :after) do
      {:ok, shifted} -> shifted
      {:error, _} = error -> error
    end
  end

  defp shift_date(_not_a_datetime, _shift_opts), do: {:error, :invalid_date}

  defp shift_naive(naive, shift_opts) do
    Enum.reduce(shift_opts, naive, fn
      {_unit, 0}, acc -> acc
      {:years, years}, acc -> shift_years(acc, years)
      {:months, months}, acc -> shift_months(acc, months)
      {:days, days}, acc -> shift_days(acc, days)
    end)
  end

  # Feb 29 moves to Mar 1 in a year that is not a leap year.
  defp shift_years(%NaiveDateTime{year: year, month: 2, day: 29} = naive, years) do
    new_year = year + years

    if :calendar.is_leap_year(new_year) do
      %{naive | year: new_year}
    else
      %{naive | year: new_year, month: 3, day: 1}
    end
  end

  defp shift_years(%NaiveDateTime{year: year} = naive, years), do: %{naive | year: year + years}

  # A day that does not exist in the target month moves to the last day of that month.
  defp shift_months(%NaiveDateTime{year: year, month: month, day: day} = naive, months) do
    total = year * 12 + (month - 1) + months
    new_year = Integer.floor_div(total, 12)
    new_month = Integer.mod(total, 12) + 1
    new_day = min(day, Calendar.ISO.days_in_month(new_year, new_month))
    %{naive | year: new_year, month: new_month, day: new_day}
  end

  defp shift_days(naive, days) do
    date = naive |> NaiveDateTime.to_date() |> Date.add(days)
    %{naive | year: date.year, month: date.month, day: date.day}
  end

  defp build_refernce_events_by_x_rules(event, by_x_rrules) do
    by_x_rrules
    |> Map.keys()
    |> Enum.map(fn by_x ->
      build_refernce_events_by_x_rule(event, by_x)
    end)
    |> List.flatten()
  end

  @valid_days ["SU", "MO", "TU", "WE", "TH", "FR", "SA"]
  @day_values %{su: 0, mo: 1, tu: 2, we: 3, th: 4, fr: 5, sa: 6}

  defp build_refernce_events_by_x_rule(
         %{rrule: %{byday: bydays}} = event,
         :byday
       ) do
    bydays
    |> Enum.map(fn byday ->
      if byday in @valid_days do
        day_atom = byday |> String.downcase() |> String.to_existing_atom()

        # determine the difference between the byday and the event's dtstart
        day_offset_for_reference =
          Map.get(@day_values, day_atom) - Date.day_of_week(event.dtstart)

        Map.merge(event, %{
          dtstart: shift_date(event.dtstart, days: day_offset_for_reference),
          dtend: shift_date(event.dtend, days: day_offset_for_reference)
        })
      else
        # Ignore the invalid byday value
        nil
      end
    end)
    |> Enum.filter(&(!is_nil(&1)))
  end

  defp remove_excluded_dates(recurrences, original_event) do
    Enum.filter(recurrences, fn new_event ->
      # Make sure new event doesn't fall on an EXDATE
      falls_on_exdate = not is_nil(new_event) and new_event.dtstart in new_event.exdates

      #  This removes any events which were created as references
      is_invalid_reference_event =
        DateTime.compare(new_event.dtstart, original_event.dtstart) == :lt

      !falls_on_exdate &&
        !is_invalid_reference_event
    end)
  end
end
