defmodule ICalendar.TimeZoneTest do
  # The expected values in this file were generated with the Timex based version of this
  # library (911afeb) and must stay identical, except where a test says otherwise.
  use ExUnit.Case, async: true

  alias ICalendar.{Event, Recurrence}
  alias ICalendar.Util.{DateParser, Deserialize, WindowsZones}

  defp to_date(string, tzid), do: Deserialize.to_date(string, %{"TZID" => tzid})

  describe "Windows time zone names" do
    test "the table has the same size as the one Timex shipped" do
      assert map_size(WindowsZones.all()) == 100
    end

    test "to_olson/1 is an exact match and returns nil otherwise" do
      assert WindowsZones.to_olson("W. Europe Standard Time") == "Europe/Berlin"
      assert WindowsZones.to_olson("India Standard Time") == "Asia/Calcutta"
      assert WindowsZones.to_olson("UTC") == "Etc/GMT"
      assert WindowsZones.to_olson("w. europe standard time") == nil
      assert WindowsZones.to_olson("Customized Time Zone") == nil
      assert WindowsZones.to_olson(nil) == nil
    end

    test "every table entry resolves in tzdata" do
      for {windows, olson} <- WindowsZones.all() do
        assert {:ok, _} = to_date("20250715T093000", windows),
               "#{windows} -> #{olson} does not resolve"
      end
    end

    test "a TZID in Windows notation gives the same instant Timex gave" do
      cases = [
        {"W. Europe Standard Time", "20250115T093000",
         "2025-01-15 09:30:00+01:00 CET Europe/Berlin"},
        {"W. Europe Standard Time", "20250715T093000",
         "2025-07-15 09:30:00+02:00 CEST Europe/Berlin"},
        {"\"W. Europe Standard Time\"", "20250715T093000",
         "2025-07-15 09:30:00+02:00 CEST Europe/Berlin"},
        {"Pacific Standard Time", "20250715T093000",
         "2025-07-15 09:30:00-07:00 PDT America/Los_Angeles"},
        {"Eastern Standard Time", "20250715T093000",
         "2025-07-15 09:30:00-04:00 EDT America/New_York"},
        {"GMT Standard Time", "20250715T093000", "2025-07-15 09:30:00+01:00 BST Europe/London"},
        {"India Standard Time", "20250715T093000", "2025-07-15 09:30:00+05:30 IST Asia/Calcutta"},
        {"Romance Standard Time", "20250715T093000",
         "2025-07-15 09:30:00+02:00 CEST Europe/Paris"},
        {"UTC", "20250715T093000", "2025-07-15 09:30:00Z"},
        {"Etc/UTC", "20250715T093000", "2025-07-15 09:30:00Z"}
      ]

      for {tzid, string, expected} <- cases do
        assert {:ok, date} = to_date(string, tzid)
        assert to_string(date) == expected
      end
    end

    test "names that are not Windows names and have no slash are unknown, as before" do
      for tzid <- ["CET", "EST", "UTC+01:00", "e. europe standard time", "Customized Time Zone"] do
        assert to_date("20250715T093000", tzid) == {:error, "Unknown TZID `#{tzid}`"}
      end
    end

    test "unknown Olson names are an error" do
      assert to_date("20250715T093000", "Foo/Bar") == {:error, :time_zone_not_found}
      assert to_date("20250715T093000", "europe/amsterdam") == {:error, :time_zone_not_found}
    end

    # Timex could not parse these zone names because of the "+" in the name. They now resolve.
    test "fixed offset zones resolve" do
      assert {:ok, date} = to_date("20250715T093000", "Dateline Standard Time")
      assert date.utc_offset == -12 * 3600
      assert {:ok, date} = to_date("20250715T093000", "UTC-11")
      assert date.utc_offset == -11 * 3600
    end
  end

  describe "DST transitions in a TZID" do
    test "a local time in the gap is an error, like before" do
      assert to_date("20250330T023000", "Europe/Amsterdam") ==
               {:error, {:could_not_resolve_timezone, "Europe/Amsterdam", 63_910_521_000, :wall}}

      assert to_date("20250309T023000", "America/New_York") ==
               {:error, {:could_not_resolve_timezone, "America/New_York", 63_908_706_600, :wall}}

      assert DateParser.parse("20250330T023000", "Europe/Amsterdam") ==
               {:error, {:could_not_resolve_timezone, "Europe/Amsterdam", 63_910_521_000, :wall}}
    end

    # Timex returned a %Timex.AmbiguousDateTime{} with both candidates here, which a plain
    # DateTime consumer cannot use. The later candidate (standard time) is what the
    # recurrence code always took from that struct.
    test "an ambiguous local time resolves to the later one" do
      assert {:ok, date} = to_date("20251026T023000", "Europe/Amsterdam")
      assert to_string(date) == "2025-10-26 02:30:00+01:00 CET Europe/Amsterdam"

      assert {:ok, date} = to_date("20251102T013000", "America/New_York")
      assert to_string(date) == "2025-11-02 01:30:00-05:00 EST America/New_York"

      assert to_string(DateParser.parse("20251026T023000", "Europe/Amsterdam")) ==
               "2025-10-26 02:30:00+01:00 CET Europe/Amsterdam"
    end

    test "times next to the transitions are unaffected" do
      assert {:ok, date} = to_date("20250330T015959", "Europe/Amsterdam")
      assert date.utc_offset + date.std_offset == 3600
      assert {:ok, date} = to_date("20250330T030000", "Europe/Amsterdam")
      assert date.utc_offset + date.std_offset == 7200
    end
  end

  describe "malformed dates keep their error messages" do
    test "field errors" do
      assert Deserialize.to_date("") == {:error, "Expected `1-4 digit year` at line 1, column 1."}

      assert Deserialize.to_date("1993/04/07") ==
               {:error, "Expected `2 digit month` at line 1, column 5."}

      assert Deserialize.to_date("199304") ==
               {:error, "Expected `day of month` at line 1, column 7."}

      assert Deserialize.to_date("19930407X153022Z") ==
               {:error, "Expected `T`, but found `X` at line 1, column 9."}

      assert Deserialize.to_date("19930407T") ==
               {:error, "Expected `hour between 0 and 24` at line 1, column 10."}

      assert Deserialize.to_date("19930407T1") ==
               {:error, "Expected `hour between 0 and 24` at line 1, column 10."}

      assert Deserialize.to_date("19930407T156022Z") ==
               {:error, "Expected `minute` at line 1, column 12."}

      assert Deserialize.to_date("19930407T1530") ==
               {:error, "Expected `second` at line 1, column 14."}

      assert Deserialize.to_date("19930407T153022 ") ==
               {:error, "Expected `Z`, but found ` ` at line 1, column 16."}
    end

    test "values that do not exist" do
      assert Deserialize.to_date("19930229T153022Z") == {:error, :invalid_date}
      assert Deserialize.to_date("19930407T240000Z") == {:error, :invalid_time}
    end

    test "a leap second rolls over into the next minute" do
      assert {:ok, date} = Deserialize.to_date("19930407T153060Z")
      assert to_string(date) == "1993-04-07 15:31:00.000000Z"
    end
  end

  describe "recurrence across a DST change" do
    defp event(zone, naive, rrule) do
      date = DateTime.from_naive!(naive, zone, Tzdata.TimeZoneDatabase)
      %Event{rrule: rrule, dtstart: date, dtend: date, exdates: []}
    end

    defp starts(event, until) do
      event |> Recurrence.get_recurrences(until) |> Enum.map(&to_string(&1.dtstart))
    end

    test "daily over the spring forward change moves a nonexistent time to the end of the gap" do
      event =
        event("Europe/Amsterdam", ~N[2025-03-28 02:30:00], %{
          freq: "DAILY",
          until: ~U[2025-04-03 00:00:00Z]
        })

      assert starts(event, ~U[2025-04-05 00:00:00Z]) == [
               "2025-03-29 02:30:00+01:00 CET Europe/Amsterdam",
               "2025-03-30 03:00:00+02:00 CEST Europe/Amsterdam",
               "2025-03-31 03:00:00+02:00 CEST Europe/Amsterdam",
               "2025-04-01 03:00:00+02:00 CEST Europe/Amsterdam",
               "2025-04-02 03:00:00+02:00 CEST Europe/Amsterdam"
             ]
    end

    test "daily over the fall back change takes the later of two equal local times" do
      event =
        event("Europe/Amsterdam", ~N[2025-10-24 02:30:00], %{
          freq: "DAILY",
          until: ~U[2025-10-29 00:00:00Z]
        })

      assert starts(event, ~U[2025-10-31 00:00:00Z]) == [
               "2025-10-25 02:30:00+02:00 CEST Europe/Amsterdam",
               "2025-10-26 02:30:00+01:00 CET Europe/Amsterdam",
               "2025-10-27 02:30:00+01:00 CET Europe/Amsterdam",
               "2025-10-28 02:30:00+01:00 CET Europe/Amsterdam"
             ]
    end

    test "weekly with a count over both changes in New York" do
      spring = event("America/New_York", ~N[2025-03-02 02:30:00], %{freq: "WEEKLY", count: 4})

      assert starts(spring, ~U[2025-04-30 00:00:00Z]) == [
               "2025-03-09 03:00:00-04:00 EDT America/New_York",
               "2025-03-16 03:00:00-04:00 EDT America/New_York",
               "2025-03-23 03:00:00-04:00 EDT America/New_York"
             ]

      fall = event("America/New_York", ~N[2025-10-26 01:30:00], %{freq: "WEEKLY", count: 4})

      assert starts(fall, ~U[2025-12-30 00:00:00Z]) == [
               "2025-11-02 01:30:00-05:00 EST America/New_York",
               "2025-11-09 01:30:00-05:00 EST America/New_York",
               "2025-11-16 01:30:00-05:00 EST America/New_York"
             ]
    end

    test "byday across the spring forward change" do
      event =
        event("Europe/Amsterdam", ~N[2025-03-26 09:00:00], %{
          freq: "WEEKLY",
          byday: ["MO", "FR", "XX"],
          count: 4
        })

      assert starts(event, ~U[2025-05-30 00:00:00Z]) == [
               "2025-03-31 09:00:00+02:00 CEST Europe/Amsterdam",
               "2025-04-04 09:00:00+02:00 CEST Europe/Amsterdam",
               "2025-04-07 09:00:00+02:00 CEST Europe/Amsterdam",
               "2025-04-11 09:00:00+02:00 CEST Europe/Amsterdam",
               "2025-04-14 09:00:00+02:00 CEST Europe/Amsterdam",
               "2025-04-18 09:00:00+02:00 CEST Europe/Amsterdam"
             ]
    end

    test "monthly moves a day that does not exist to the end of the month" do
      event = event("Europe/Amsterdam", ~N[2025-01-31 09:00:00], %{freq: "MONTHLY", count: 5})

      assert starts(event, ~U[2025-12-30 00:00:00Z]) == [
               "2025-02-28 09:00:00+01:00 CET Europe/Amsterdam",
               "2025-03-28 09:00:00+01:00 CET Europe/Amsterdam",
               "2025-04-28 09:00:00+02:00 CEST Europe/Amsterdam",
               "2025-05-28 09:00:00+02:00 CEST Europe/Amsterdam"
             ]
    end

    test "yearly moves Feb 29 to Mar 1 in a year that is not a leap year" do
      event = event("Europe/Amsterdam", ~N[2024-02-29 09:00:00], %{freq: "YEARLY", count: 3})

      assert starts(event, ~U[2030-12-30 00:00:00Z]) == [
               "2025-03-01 09:00:00+01:00 CET Europe/Amsterdam",
               "2026-03-01 09:00:00+01:00 CET Europe/Amsterdam"
             ]
    end
  end

  describe "serialization" do
    test "date and datetime formats" do
      alias ICalendar.Value

      assert Value.to_ics(~U[2025-07-15 09:30:05Z]) == "20250715T093005"
      assert Value.to_ics(~D[2025-07-15]) == "20250715"
      assert Value.to_ics({{2025, 7, 15}, {9, 30, 5}}) == "20250715T093005"
      assert Value.to_ics(~U[0099-07-15 09:30:05Z]) == "990715T093005"

      local =
        DateTime.from_naive!(~N[2025-07-15 09:30:05], "Europe/Amsterdam", Tzdata.TimeZoneDatabase)

      assert Value.to_ics(local) == "20250715T093005"
    end
  end
end
