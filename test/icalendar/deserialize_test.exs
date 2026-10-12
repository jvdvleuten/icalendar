defmodule ICalendar.DeserializeTest do
  use ExUnit.Case

  alias ICalendar.Event

  describe "ICalendar.from_ics/1" do
    test "Single Event" do
      ics = """
      BEGIN:VEVENT
      DESCRIPTION:Escape from the world. Stare at some water.
      COMMENT:Don't forget to take something to eat !
      SUMMARY:Going fishing
      DTEND:20151224T084500Z
      DTSTART:20151224T083000Z
      LOCATION:123 Fun Street\\, Toronto ON\\, Canada
      STATUS:TENTATIVE
      CATEGORIES:Fishing,Nature
      CLASS:PRIVATE
      GEO:43.6978819;-79.3810277
      END:VEVENT
      """

      [event] = ICalendar.from_ics(ics)

      assert event == %Event{
               dtstart: Timex.to_datetime({{2015, 12, 24}, {8, 30, 0}}),
               dtend: Timex.to_datetime({{2015, 12, 24}, {8, 45, 0}}),
               summary: "Going fishing",
               description: "Escape from the world. Stare at some water.",
               location: "123 Fun Street, Toronto ON, Canada",
               status: "tentative",
               categories: ["Fishing", "Nature"],
               comment: "Don't forget to take something to eat !",
               class: "private",
               geo: {43.6978819, -79.3810277}
             }
    end

    test "Single event with wrapped description and summary" do
      ics = """
      BEGIN:VEVENT
      DESCRIPTION:Escape from the world. Stare at some water. Maybe you'll even
        catch some fish!
      COMMENT:Don't forget to take something to eat !
      SUMMARY:Going fishing at the lake that happens to be in the middle of fun
        street.
      DTEND:20151224T084500Z
      DTSTART:20151224T083000Z
      LOCATION:123 Fun Street\\, Toronto ON\\, Canada
      STATUS:TENTATIVE
      CATEGORIES:Fishing,Nature
      CLASS:PRIVATE
      GEO:43.6978819;-79.3810277
      END:VEVENT
      """

      [event] = ICalendar.from_ics(ics)

      assert event == %Event{
               dtstart: Timex.to_datetime({{2015, 12, 24}, {8, 30, 0}}),
               dtend: Timex.to_datetime({{2015, 12, 24}, {8, 45, 0}}),
               summary:
                 "Going fishing at the lake that happens to be in the middle of fun street.",
               description:
                 "Escape from the world. Stare at some water. Maybe you'll even catch some fish!",
               location: "123 Fun Street, Toronto ON, Canada",
               status: "tentative",
               categories: ["Fishing", "Nature"],
               comment: "Don't forget to take something to eat !",
               class: "private",
               geo: {43.6978819, -79.3810277}
             }
    end

    test "with Timezone" do
      ics = """
      BEGIN:VEVENT
      DTEND;TZID=America/Chicago:22221224T084500
      DTSTART;TZID=America/Chicago:22221224T083000
      END:VEVENT
      """

      [event] = ICalendar.from_ics(ics)
      assert event.dtstart.time_zone == "America/Chicago"
      assert event.dtend.time_zone == "America/Chicago"
    end

    test "with CR+LF line endings" do
      ics = """
      BEGIN:VEVENT
      DESCRIPTION:CR+LF line endings\r\nSUMMARY:Going fishing\r
      DTEND:20151224T084500Z\r\nDTSTART:20151224T083000Z\r
      END:VEVENT
      """

      [event] = ICalendar.from_ics(ics)
      assert event.description == "CR+LF line endings"
    end

    test "with URL" do
      ics = """
      BEGIN:VEVENT
      DESCRIPTION:Escape from the world. Stare at some water.
      COMMENT:Don't forget to take something to eat !
      URL:http://google.com
      SUMMARY:Going fishing
      DTEND:20151224T084500Z
      DTSTART:20151224T083000Z
      LOCATION:123 Fun Street\\, Toronto ON\\, Canada
      STATUS:TENTATIVE
      CATEGORIES:Fishing,Nature
      CLASS:PRIVATE
      GEO:43.6978819;-79.3810277
      END:VEVENT
      """

      [event] = ICalendar.from_ics(ics)
      assert event.url == "http://google.com"
    end

    test "quoted TZID resolves to the zone" do
      ics = """
      BEGIN:VEVENT
      DTSTART;TZID="Europe/Amsterdam":20261005T080000
      DTEND;TZID="Europe/Amsterdam":20261005T090000
      END:VEVENT
      """

      [event] = ICalendar.from_ics(ics)
      assert event.dtstart.time_zone == "Europe/Amsterdam"
      assert Timex.to_erl(event.dtstart) == {{2026, 10, 5}, {8, 0, 0}}
      assert event.dtend.time_zone == "Europe/Amsterdam"
    end

    test "Windows TZID that Timex maps resolves to the zone" do
      ics = """
      BEGIN:VEVENT
      DTSTART;TZID=W. Europe Standard Time:20261005T080000
      END:VEVENT
      """

      [event] = ICalendar.from_ics(ics)
      assert event.dtstart.time_zone == "Europe/Berlin"
      assert Timex.to_erl(event.dtstart) == {{2026, 10, 5}, {8, 0, 0}}
    end

    test "unresolvable TZID leaves the date unset and keeps the other events" do
      ics = """
      BEGIN:VEVENT
      SUMMARY:Good before
      DTSTART;TZID=Europe/Amsterdam:20261005T080000
      END:VEVENT
      BEGIN:VEVENT
      SUMMARY:Bad zone
      DTSTART;TZID=Customized Time Zone:20261005T080000
      DTEND;TZID=Customized Time Zone:20261005T090000
      EXDATE;TZID=Customized Time Zone:20261006T080000
      END:VEVENT
      BEGIN:VEVENT
      SUMMARY:Empty zone
      DTSTART;TZID=:20261005T080000
      DTEND;TZID="":20261005T090000
      END:VEVENT
      BEGIN:VEVENT
      SUMMARY:Good after
      DTSTART:20261005T080000Z
      END:VEVENT
      """

      [last, empty, bad, before] = ICalendar.from_ics(ics)

      assert before.summary == "Good before"
      assert before.dtstart.time_zone == "Europe/Amsterdam"
      assert bad.summary == "Bad zone"
      assert bad.dtstart == nil
      assert bad.dtend == nil
      assert bad.exdates == []
      assert empty.summary == "Empty zone"
      assert empty.dtstart == nil
      assert empty.dtend == nil
      assert last.summary == "Good after"
      assert Timex.to_erl(last.dtstart) == {{2026, 10, 5}, {8, 0, 0}}
    end

    test "to_date/2 returns an error naming an unresolvable TZID" do
      assert ICalendar.Util.Deserialize.to_date("20261005T080000", %{"TZID" => "\"Nope\""}) ==
               {:error, "Unknown TZID `Nope`"}

      assert {:error, _} = ICalendar.Util.Deserialize.to_date("20261005T080000", %{"TZID" => ""})
      assert {:error, _} = ICalendar.Util.Deserialize.to_date("20261005T080000", %{"TZID" => nil})
    end

    test "parse_rrule/1 ignores a part it does not know instead of raising" do
      unknown = "X-NEVER-SEEN-#{System.unique_integer([:positive])}"

      assert ICalendar.Util.Deserialize.parse_rrule("FREQ=WEEKLY;#{unknown}=1;COUNT=3") ==
               %{freq: "WEEKLY", count: 3}
    end
  end
end
