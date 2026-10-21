# Changelog

All notable changes to this project will be documented in this file.

This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

- Drop the timex dependency. Dates are handled with the standard library and tzdata, which is now an explicit dependency
  and is passed explicitly instead of relying on the `:time_zone_database` config of the host application.
- The Windows to Olson time zone table moved into `ICalendar.Util.WindowsZones` (same 100 entries).
- A local time that occurs twice because the clocks go back now resolves to the later one (standard time) in
  `ICalendar.Util.Deserialize.to_date/2` and `ICalendar.Util.DateParser.parse/2`, instead of returning a
  `%Timex.AmbiguousDateTime{}`. A local time that does not exist is still an error.
- Zone names such as `Etc/GMT+5`, `Dateline Standard Time` and `UTC-11` now resolve instead of returning a parse error.

## v1.1.3 - 2026-02-10

- Fix atom generation vulnerability.

## v1.1.2 - 2022-01-16

- Handle calendars that wrap output such as Google Calendar

## v1.1.1 - 2021-12-26

- Fixed a bug where newlines were incorrectly handled.

## v1.1.0 - 2020-10-06

- The `ICalendar.Recurrence.get_recurrences` function has been added to enable
  calculation of recurring events from RRULE.

## v1.0.3 - 2020-08-19

- Calendars with empty lines in events are now parsed successfully.

## v1.0.2 - 2019-10-06

- Calendars with empty lines are now parsed successfully.

## v1.0.1 - 2019-09-17

- Empty parameter values in a VEVENT are now parsed successfully.

## v1.0.0 - 2019-09-05

- First stable release.
