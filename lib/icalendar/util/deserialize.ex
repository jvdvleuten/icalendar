defmodule ICalendar.Util.Deserialize do
  @moduledoc """
  Deserialize ICalendar Strings into Event structs.
  """

  alias ICalendar.Event
  alias ICalendar.Property

  def build_event(lines) when is_list(lines) do
    lines
    |> Enum.filter(&(&1 != ""))
    |> Enum.map(&retrieve_kvs/1)
    |> Enum.reduce(%Event{}, &parse_attr/2)
  end

  @doc ~S"""
  This function extracts the key and value parts from each line of a iCalendar
  string.

      iex> ICalendar.Util.Deserialize.retrieve_kvs("lorem:ipsum")
      %ICalendar.Property{key: "LOREM", params: %{}, value: "ipsum"}

  """
  def retrieve_kvs(line) do
    # Split Line up into key and value
    {key, value, params} =
      case String.split(line, ":", parts: 2, trim: true) do
        [key, value] ->
          [key, params] = retrieve_params(key)
          {key, value, params}

        [key] ->
          {key, nil, %{}}
      end

    %Property{key: String.upcase(key), value: value, params: params}
  end

  @doc ~S"""
  This function extracts parameter data from a key in an iCalendar string.

      iex> ICalendar.Util.Deserialize.retrieve_params(
      ...>   "DTSTART;TZID=America/Chicago")
      ["DTSTART", %{"TZID" => "America/Chicago"}]

  It should be able to handle multiple parameters per key:

      iex> ICalendar.Util.Deserialize.retrieve_params(
      ...>   "KEY;LOREM=ipsum;DOLOR=sit")
      ["KEY", %{"LOREM" => "ipsum", "DOLOR" => "sit"}]

  """
  def retrieve_params(key) do
    [key | params] = String.split(key, ";", trim: true)

    params =
      params
      |> Enum.reduce(%{}, fn param, acc ->
        case String.split(param, "=", parts: 2, trim: true) do
          [key, val] -> Map.merge(acc, %{key => val})
          [key] -> Map.merge(acc, %{key => nil})
          _ -> acc
        end
      end)

    [key, params]
  end

  def parse_attr(%Property{key: _, value: nil}, acc), do: acc

  def parse_attr(
        %Property{key: "DESCRIPTION", value: description},
        acc
      ) do
    %{acc | description: desanitized(description)}
  end

  def parse_attr(
        %Property{key: "DTSTART", value: dtstart, params: params},
        acc
      ) do
    case to_date(dtstart, params) do
      {:ok, timestamp} -> %{acc | dtstart: timestamp}
      {:error, _} -> acc
    end
  end

  def parse_attr(
        %Property{key: "DTEND", value: dtend, params: params},
        acc
      ) do
    case to_date(dtend, params) do
      {:ok, timestamp} -> %{acc | dtend: timestamp}
      {:error, _} -> acc
    end
  end

  def parse_attr(
        %Property{key: "RRULE", value: rrule},
        acc
      ) do
    # Value will have the format FREQ=MONTHLY;BYDAY=MO,TU,WE,TH,FR;BYSETPOS=-1
    # Defined here: https://icalendar.org/iCalendar-RFC-5545/3-3-10-recurrence-rule.html

    rrule = parse_rrule(rrule)

    %{acc | rrule: rrule}
  end

  def parse_attr(
        %Property{key: "EXDATE", value: exdate, params: params},
        acc
      ) do
    exdates = Map.get(acc, :exdates, [])

    case to_date(exdate, params) do
      {:ok, timestamp} -> %{acc | exdates: [timestamp | exdates]}
      {:error, _} -> acc
    end
  end

  def parse_attr(
        %Property{key: "SUMMARY", value: summary},
        acc
      ) do
    %{acc | summary: desanitized(summary)}
  end

  def parse_attr(
        %Property{key: "LOCATION", value: location},
        acc
      ) do
    %{acc | location: desanitized(location)}
  end

  def parse_attr(
        %Property{key: "COMMENT", value: comment},
        acc
      ) do
    %{acc | comment: desanitized(comment)}
  end

  def parse_attr(
        %Property{key: "STATUS", value: status},
        acc
      ) do
    %{acc | status: status |> desanitized() |> String.downcase()}
  end

  def parse_attr(
        %Property{key: "CATEGORIES", value: categories},
        acc
      ) do
    %{acc | categories: String.split(desanitized(categories), ",")}
  end

  def parse_attr(
        %Property{key: "CLASS", value: class},
        acc
      ) do
    %{acc | class: class |> desanitized() |> String.downcase()}
  end

  def parse_attr(
        %Property{key: "GEO", value: geo},
        acc
      ) do
    %{acc | geo: to_geo(geo)}
  end

  def parse_attr(
        %Property{key: "UID", value: uid},
        acc
      ) do
    %{acc | uid: uid}
  end

  def parse_attr(
        %Property{key: "LAST-MODIFIED", value: modified},
        acc
      ) do
    case to_date(modified) do
      {:ok, timestamp} -> %{acc | modified: timestamp}
      {:error, _} -> acc
    end
  end

  def parse_attr(
        %Property{key: "ORGANIZER", params: _params, value: organizer},
        acc
      ) do
    %{acc | organizer: organizer}
  end

  def parse_attr(
        %Property{key: "ATTENDEE", params: params, value: value},
        acc
      ) do
    %{acc | attendees: [Map.put(params, :original_value, value)] ++ acc.attendees}
  end

  def parse_attr(
        %Property{key: "SEQUENCE", value: sequence},
        acc
      ) do
    %{acc | sequence: sequence}
  end

  def parse_attr(
        %Property{key: "URL", value: url},
        acc
      ) do
    %{acc | url: url |> desanitized() |> String.downcase()}
  end

  def parse_attr(_, acc), do: acc

  @doc ~S"""
  This function is designed to parse iCal datetime strings into erlang dates.

  It should be able to handle dates from the past:

      iex> {:ok, date} = ICalendar.Util.Deserialize.to_date("19930407T153022Z")
      ...> DateTime.to_naive(date) |> NaiveDateTime.to_erl()
      {{1993, 4, 7}, {15, 30, 22}}

  As well as the future:

      iex> {:ok, date} = ICalendar.Util.Deserialize.to_date("39930407T153022Z")
      ...> DateTime.to_naive(date) |> NaiveDateTime.to_erl()
      {{3993, 4, 7}, {15, 30, 22}}

  And should return error for incorrect dates:

      iex> ICalendar.Util.Deserialize.to_date("1993/04/07")
      {:error, "Expected `2 digit month` at line 1, column 5."}

  It should handle timezones from  the Olson Database:

      iex> {:ok, date} = ICalendar.Util.Deserialize.to_date("19980119T020000",
      ...> %{"TZID" => "America/Chicago"})
      ...> [DateTime.to_naive(date) |> NaiveDateTime.to_erl(), date.time_zone]
      [{{1998, 1, 19}, {2, 0, 0}}, "America/Chicago"]

  Windows time zone names, as written by Outlook, are translated to Olson names:

      iex> {:ok, date} = ICalendar.Util.Deserialize.to_date("20250715T093000",
      ...> %{"TZID" => "W. Europe Standard Time"})
      ...> [DateTime.to_naive(date) |> NaiveDateTime.to_erl(), date.time_zone]
      [{{2025, 7, 15}, {9, 30, 0}}, "Europe/Berlin"]

  A local time that occurs twice because the clocks go back resolves to the later one
  (standard time). A local time that does not exist because the clocks go forward is an
  error:

      iex> {:ok, date} = ICalendar.Util.Deserialize.to_date("20251026T023000",
      ...> %{"TZID" => "Europe/Amsterdam"})
      ...> date.utc_offset
      3600

      iex> ICalendar.Util.Deserialize.to_date("20250330T023000",
      ...> %{"TZID" => "Europe/Amsterdam"})
      {:error, {:could_not_resolve_timezone, "Europe/Amsterdam", 63910521000, :wall}}

  A TZID that cannot be resolved returns an error instead of guessing a zone:

      iex> ICalendar.Util.Deserialize.to_date("19980119T020000",
      ...> %{"TZID" => "Customized Time Zone"})
      {:error, "Unknown TZID `Customized Time Zone`"}
  """
  def to_date(date_string, %{"TZID" => timezone}) do
    # RFC 5545 allows quoted parameter values, and the parameter parser keeps the quotes
    timezone = original_timezone = String.trim(to_string(timezone), ~s("))

    # Handle date-only formats (8 chars or 9 chars with Z) before datetime parsing
    # These formats don't have time components: "20251011" or "20251011Z"
    cond do
      String.length(date_string) == 8 ->
        # Date-only without Z: "20251011" -> parse as date at midnight UTC
        to_date(date_string <> "T000000Z")

      String.length(date_string) == 9 and String.ends_with?(date_string, "Z") ->
        # Date-only with Z: "20251011Z" -> strip Z and parse as date at midnight UTC
        date_part = String.slice(date_string, 0, 8)
        to_date(date_part <> "T000000Z")

      true ->
        # Microsoft Outlook calendar .ICS files report times in Greenwich Standard Time (UTC +0)
        # so just convert this to UTC
        timezone =
          if Regex.match?(~r/\//, timezone) do
            timezone
          else
            ICalendar.Util.WindowsZones.to_olson(timezone)
          end

        case timezone do
          nil ->
            {:error, "Unknown TZID `#{original_timezone}`"}

          timezone ->
            date_string =
              case String.last(date_string) do
                "Z" -> date_string
                _ -> date_string <> "Z"
              end

            parse_local(date_string <> timezone)
        end
    end
  end

  def to_date(date_string, %{"VALUE" => "DATE"}) do
    to_date(date_string <> "T000000Z")
  end

  def to_date(date_string, %{}) do
    to_date(date_string, %{"TZID" => "Etc/UTC"})
  end

  def to_date(date_string) do
    to_date(date_string, %{"TZID" => "Etc/UTC"})
  end

  # Parses `YYYYMMDDTHHMMSSZ<zone name>` where the zone name is the rest of the string.
  # The error messages for a malformed date or time follow the wording this function has
  # always returned: `Expected <what> at line 1, column <n>.`
  defp parse_local(string) do
    with {:ok, year, rest} <- take_year(string),
         {:ok, month, rest} <- take_int(rest, string, 1..12, "2 digit month"),
         {:ok, day, rest} <- take_int(rest, string, 1..31, "day of month"),
         {:ok, rest} <- take_literal(rest, string, "T"),
         {:ok, hour, rest} <- take_int(rest, string, 0..24, "hour between 0 and 24"),
         {:ok, minute, rest} <- take_int(rest, string, 0..59, "minute"),
         {:ok, second, rest} <- take_int(rest, string, 0..60, "second"),
         {:ok, zone} <- take_literal(rest, string, "Z"),
         {:ok, naive} <- build_naive(year, month, day, hour, minute, second) do
      ICalendar.Util.TimeZone.localize(naive, zone, :error)
    end
  end

  # A leap second (:60) rolls over into the next minute, like it always did.
  defp build_naive(year, month, day, hour, minute, 60) do
    with {:ok, naive} <- NaiveDateTime.new(year, month, day, hour, minute, 59, {0, 6}) do
      {:ok, NaiveDateTime.add(naive, 1, :second)}
    end
  end

  defp build_naive(year, month, day, hour, minute, second) do
    NaiveDateTime.new(year, month, day, hour, minute, second)
  end

  defp take_year(string) do
    case Regex.run(~r/\A(\d{1,4})(.*)\z/s, string) do
      [_, digits, rest] ->
        case String.to_integer(digits) do
          0 -> {:error, "Expected `1-4 digit year` at line 1, column 1."}
          year -> {:ok, year, rest}
        end

      _ ->
        {:error, "Expected `1-4 digit year` at line 1, column 1."}
    end
  end

  defp take_int(rest, string, range, label) do
    with <<digits::binary-size(2), after_digits::binary>> <- rest,
         true <- digits =~ ~r/\A\d\d\z/,
         value = String.to_integer(digits),
         true <- value in range do
      {:ok, value, after_digits}
    else
      _ -> {:error, "Expected `#{label}` at line 1, column #{column(string, rest)}."}
    end
  end

  defp take_literal(rest, string, literal) do
    if String.starts_with?(rest, literal) do
      {:ok, binary_part(rest, 1, byte_size(rest) - 1)}
    else
      found = String.first(rest) || "end of input"

      {:error,
       "Expected `#{literal}`, but found `#{found}` at line 1, column #{column(string, rest)}."}
    end
  end

  defp column(string, rest), do: String.length(string) - String.length(rest) + 1

  defp to_geo(geo) do
    geo
    |> desanitized()
    |> String.split(";")
    |> Enum.map(fn x -> Float.parse(x) end)
    |> Enum.map(fn {x, _} -> x end)
    |> List.to_tuple()
  end

  @doc ~S"""

  This function should strip any sanitization that has been applied to content
  within an iCal string.

      iex> ICalendar.Util.Deserialize.desanitized(~s(lorem\\, ipsum))
      "lorem, ipsum"
  """
  def desanitized(string) do
    string
    |> String.replace(~s(\\), "")
  end

  @doc """
  This function builds an rrule struct.

  RRULE:FREQ=WEEKLY;WKST=SU;UNTIL=20201204T045959Z;INTERVAL=2;BYDAY=TH,WE;BYSETPOS=-1

  will get turned into:

  ```elixir
  %{
    byday: ["TH", "WE"],
    freq: "WEEKLY",
    bysetpos: [-1],
    interval: 2,
    until: ~U[2020-12-04 04:59:59Z]
  }
  ```
  """
  def parse_rrule(rrule) do
    rrule
    |> String.split(";")
    |> Enum.reduce(%{}, fn rule, hash ->
      [key, value] = rule |> String.split("=")

      case rrule_key(key) do
        :freq ->
          hash |> Map.put(:freq, value)

        :until ->
          hash |> Map.put(:until, ICalendar.Util.DateParser.parse(value))

        :count ->
          hash |> Map.put(:count, String.to_integer(value))

        :interval ->
          hash |> Map.put(:interval, String.to_integer(value))

        :bysecond ->
          hash |> Map.put(:bysecond, String.split(value, ","))

        :byminute ->
          hash |> Map.put(:byminute, String.split(value, ","))

        :byhour ->
          hash |> Map.put(:byhour, String.split(value, ","))

        :byday ->
          hash |> Map.put(:byday, String.split(value, ","))

        :bymonthday ->
          hash |> Map.put(:bymonthday, String.split(value, ","))

        :byyearday ->
          hash |> Map.put(:byyearday, String.split(value, ","))

        :byweekno ->
          hash |> Map.put(:byweekno, String.split(value, ","))

        :bymonth ->
          hash |> Map.put(:bymonth, String.split(value, ","))

        :bysetpos ->
          hash |> Map.put(:bysetpos, Enum.map(String.split(value, ","), &String.to_integer(&1)))

        :wkst ->
          hash |> Map.put(:wkst, value)

        _ ->
          hash
      end
    end)
  end

  # An unknown RRULE part has no existing atom; it is ignored instead of raising.
  defp rrule_key(key) do
    key |> String.downcase() |> String.to_existing_atom()
  rescue
    ArgumentError -> nil
  end
end
