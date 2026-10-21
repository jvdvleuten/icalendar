defprotocol ICalendar.Value do
  @fallback_to_any true
  def to_ics(data)
end

alias ICalendar.Value

defmodule ICalendar.Value.Format do
  @moduledoc false

  # The iCal basic formats. The year is not padded, the other fields are padded to two digits.

  def date(%{year: year, month: month, day: day}) do
    Integer.to_string(year) <> pad2(month) <> pad2(day)
  end

  def datetime(%{hour: hour, minute: minute, second: second} = timestamp) do
    date(timestamp) <> "T" <> pad2(hour) <> pad2(minute) <> pad2(second)
  end

  defp pad2(number), do: number |> Integer.to_string() |> String.pad_leading(2, "0")
end

defimpl Value, for: BitString do
  def to_ics(x) do
    x
    |> String.replace(~S"\n", ~S"\\n")
    |> String.replace("\n", ~S"\n")
  end
end

defimpl Value, for: Tuple do
  defmacro elem2(x, i1, i2) do
    quote do
      unquote(x) |> elem(unquote(i1)) |> elem(unquote(i2))
    end
  end

  @doc """
  This macro is used to establish whether a tuple is in the Erlang Timestamp
  format (`{{year, month, day}, {hour, minute, second}}`).
  """
  defmacro is_datetime_tuple(x) do
    quote do
      # Year
      # Month
      # Day
      # Hour
      # Minute
      # Second
      unquote(x) |> elem2(0, 0) |> is_integer and
        unquote(x) |> elem2(0, 1) |> is_integer and
        unquote(x) |> elem2(0, 1) <= 12 and
        unquote(x) |> elem2(0, 1) >= 1 and
        unquote(x) |> elem2(0, 2) |> is_integer and
        unquote(x) |> elem2(0, 2) <= 31 and
        unquote(x) |> elem2(0, 2) >= 1 and
        unquote(x) |> elem2(1, 0) |> is_integer and
        unquote(x) |> elem2(1, 0) <= 23 and
        unquote(x) |> elem2(1, 0) >= 0 and
        unquote(x) |> elem2(1, 1) |> is_integer and
        unquote(x) |> elem2(1, 1) <= 59 and
        unquote(x) |> elem2(1, 1) >= 0 and
        unquote(x) |> elem2(1, 2) |> is_integer and
        unquote(x) |> elem2(1, 2) <= 60 and
        unquote(x) |> elem2(1, 2) >= 0
    end
  end

  @doc """
  This function converts Erlang timestamp tuples into DateTimes.
  """
  def to_ics(timestamp) when is_datetime_tuple(timestamp) do
    case NaiveDateTime.from_erl(timestamp) do
      {:ok, naive} -> naive |> DateTime.from_naive!("Etc/UTC") |> Value.to_ics()
      {:error, _} = error -> error
    end
  end

  def to_ics(x), do: x
end

defimpl Value, for: DateTime do
  @doc """
  This function converts DateTimes to UTC timezone and then into Strings in the
  iCal format.
  """
  def to_ics(%DateTime{} = timestamp) do
    ICalendar.Value.Format.datetime(timestamp)
  end
end

defimpl Value, for: Date do
  @doc """
  This function converts DateTimes to UTC timezone and then into Strings in the
  iCal format.
  """
  def to_ics(%Date{} = timestamp) do
    ICalendar.Value.Format.date(timestamp)
  end
end

defimpl Value, for: Any do
  def to_ics(x), do: x
end
