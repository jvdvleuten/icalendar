ExUnit.start()

defmodule TestHelper do
  @moduledoc false

  @database Tzdata.TimeZoneDatabase

  def to_datetime(erl, zone \\ "Etc/UTC") do
    erl |> NaiveDateTime.from_erl!() |> DateTime.from_naive!(zone, @database)
  end

  def to_erl(%DateTime{} = datetime),
    do: datetime |> DateTime.to_naive() |> NaiveDateTime.to_erl()

  def convert(%DateTime{} = datetime, zone), do: DateTime.shift_zone!(datetime, zone, @database)
end
