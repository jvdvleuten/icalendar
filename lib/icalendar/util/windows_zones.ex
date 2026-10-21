defmodule ICalendar.Util.WindowsZones do
  @moduledoc """
  Maps Windows time zone names (as written by Outlook and Exchange, for example
  `"W. Europe Standard Time"`) to Olson / IANA time zone names (for example
  `"Europe/Berlin"`).

  The table has 100 entries. It is copied from `priv/standard_to_olson.exs` of
  Timex 3.7.13 (https://github.com/bitwalker/timex), which is licensed under the MIT
  License, Copyright (c) 2016 Paul Schoenfelder. The mapping and the lookup semantics
  are unchanged: an exact, case sensitive match on the Windows name, `nil` when the
  name is not in the table. Note that a few Windows names map to a fixed offset zone
  (`"UTC"` maps to `"Etc/GMT"`, `"Dateline Standard Time"` to `"Etc/GMT+12"`).
  """

  @zones %{
    "AUS Central Standard Time" => "Australia/Darwin",
    "AUS Eastern Standard Time" => "Australia/Sydney",
    "Afghanistan Standard Time" => "Asia/Kabul",
    "Alaskan Standard Time" => "America/Anchorage",
    "Arab Standard Time" => "Asia/Riyadh",
    "Arabian Standard Time" => "Asia/Dubai",
    "Arabic Standard Time" => "Asia/Baghdad",
    "Argentina Standard Time" => "America/Buenos_Aires",
    "Atlantic Standard Time" => "America/Halifax",
    "Azerbaijan Standard Time" => "Asia/Baku",
    "Azores Standard Time" => "Atlantic/Azores",
    "Bahia Standard Time" => "America/Bahia",
    "Bangladesh Standard Time" => "Asia/Dhaka",
    "Canada Central Standard Time" => "America/Regina",
    "Cape Verde Standard Time" => "Atlantic/Cape_Verde",
    "Caucasus Standard Time" => "Asia/Yerevan",
    "Cen. Australia Standard Time" => "Australia/Adelaide",
    "Central America Standard Time" => "America/Guatemala",
    "Central Asia Standard Time" => "Asia/Almaty",
    "Central Brazilian Standard Time" => "America/Cuiaba",
    "Central Europe Standard Time" => "Europe/Budapest",
    "Central European Standard Time" => "Europe/Warsaw",
    "Central Pacific Standard Time" => "Pacific/Guadalcanal",
    "Central Standard Time" => "America/Chicago",
    "Central Standard Time (Mexico)" => "America/Mexico_City",
    "China Standard Time" => "Asia/Shanghai",
    "Dateline Standard Time" => "Etc/GMT+12",
    "E. Africa Standard Time" => "Africa/Nairobi",
    "E. Australia Standard Time" => "Australia/Brisbane",
    "E. Europe Standard Time" => "Asia/Nicosia",
    "E. South America Standard Time" => "America/Sao_Paulo",
    "Eastern Standard Time" => "America/New_York",
    "Egypt Standard Time" => "Africa/Cairo",
    "Ekaterinburg Standard Time" => "Asia/Yekaterinburg",
    "FLE Standard Time" => "Europe/Kiev",
    "Fiji Standard Time" => "Pacific/Fiji",
    "GMT Standard Time" => "Europe/London",
    "GTB Standard Time" => "Europe/Bucharest",
    "Georgian Standard Time" => "Asia/Tbilisi",
    "Greenland Standard Time" => "America/Godthab",
    "Greenwich Standard Time" => "Atlantic/Reykjavik",
    "Hawaiian Standard Time" => "Pacific/Honolulu",
    "India Standard Time" => "Asia/Calcutta",
    "Iran Standard Time" => "Asia/Tehran",
    "Israel Standard Time" => "Asia/Jerusalem",
    "Jordan Standard Time" => "Asia/Amman",
    "Kaliningrad Standard Time" => "Europe/Kaliningrad",
    "Korea Standard Time" => "Asia/Seoul",
    "Libya Standard Time" => "Africa/Tripoli",
    "Magadan Standard Time" => "Asia/Magadan",
    "Mauritius Standard Time" => "Indian/Mauritius",
    "Middle East Standard Time" => "Asia/Beirut",
    "Montevideo Standard Time" => "America/Montevideo",
    "Morocco Standard Time" => "Africa/Casablanca",
    "Mountain Standard Time" => "America/Denver",
    "Mountain Standard Time (Mexico)" => "America/Chihuahua",
    "Myanmar Standard Time" => "Asia/Rangoon",
    "N. Central Asia Standard Time" => "Asia/Novosibirsk",
    "Namibia Standard Time" => "Africa/Windhoek",
    "Nepal Standard Time" => "Asia/Katmandu",
    "New Zealand Standard Time" => "Pacific/Auckland",
    "Newfoundland Standard Time" => "America/St_Johns",
    "North Asia East Standard Time" => "Asia/Irkutsk",
    "North Asia Standard Time" => "Asia/Krasnoyarsk",
    "Pacific SA Standard Time" => "America/Santiago",
    "Pacific Standard Time" => "America/Los_Angeles",
    "Pacific Standard Time (Mexico)" => "America/Santa_Isabel",
    "Pakistan Standard Time" => "Asia/Karachi",
    "Paraguay Standard Time" => "America/Asuncion",
    "Romance Standard Time" => "Europe/Paris",
    "Russian Standard Time" => "Europe/Moscow",
    "SA Eastern Standard Time" => "America/Cayenne",
    "SA Pacific Standard Time" => "America/Bogota",
    "SA Western Standard Time" => "America/La_Paz",
    "SE Asia Standard Time" => "Asia/Bangkok",
    "Samoa Standard Time" => "Pacific/Apia",
    "Singapore Standard Time" => "Asia/Singapore",
    "South Africa Standard Time" => "Africa/Johannesburg",
    "Sri Lanka Standard Time" => "Asia/Colombo",
    "Syria Standard Time" => "Asia/Damascus",
    "Taipei Standard Time" => "Asia/Taipei",
    "Tasmania Standard Time" => "Australia/Hobart",
    "Tokyo Standard Time" => "Asia/Tokyo",
    "Tonga Standard Time" => "Pacific/Tongatapu",
    "Turkey Standard Time" => "Europe/Istanbul",
    "US Eastern Standard Time" => "America/Indianapolis",
    "US Mountain Standard Time" => "America/Phoenix",
    "UTC" => "Etc/GMT",
    "UTC+12" => "Etc/GMT-12",
    "UTC-02" => "Etc/GMT+2",
    "UTC-11" => "Etc/GMT+11",
    "Ulaanbaatar Standard Time" => "Asia/Ulaanbaatar",
    "Venezuela Standard Time" => "America/Caracas",
    "Vladivostok Standard Time" => "Asia/Vladivostok",
    "W. Australia Standard Time" => "Australia/Perth",
    "W. Central Africa Standard Time" => "Africa/Lagos",
    "W. Europe Standard Time" => "Europe/Berlin",
    "West Asia Standard Time" => "Asia/Tashkent",
    "West Pacific Standard Time" => "Pacific/Port_Moresby",
    "Yakutsk Standard Time" => "Asia/Yakutsk"
  }

  @doc """
  Returns the Olson time zone name for a Windows time zone name, or `nil` when the name
  is unknown.

  ## Examples

      iex> ICalendar.Util.WindowsZones.to_olson("W. Europe Standard Time")
      "Europe/Berlin"

      iex> ICalendar.Util.WindowsZones.to_olson("Azores Standard Time")
      "Atlantic/Azores"

      iex> ICalendar.Util.WindowsZones.to_olson("Customized Time Zone")
      nil
  """
  @spec to_olson(String.t()) :: String.t() | nil
  def to_olson(windows_name) when is_binary(windows_name), do: Map.get(@zones, windows_name)
  def to_olson(_), do: nil

  @doc "Returns the whole Windows to Olson table."
  @spec all() :: %{String.t() => String.t()}
  def all, do: @zones
end
