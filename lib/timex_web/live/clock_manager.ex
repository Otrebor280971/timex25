defmodule TimexWeb.ClockManager do
  use GenServer

  def init(ui) do
    :gproc.reg({:p, :l, :ui_event})
    {_, now} = :calendar.local_time()

    Process.send_after(self(), :working_working, 1000)
    {:ok, %{ui_pid: ui, time: Time.from_erl!(now), st: Working}}
  end

  def handle_info(:working_working, %{ui_pid: ui, time: time, st: Working} = state) do
    Process.send_after(self(), :working_working, 1000)
    time = Time.add(time, 1)
    GenServer.cast(ui, {:set_time_display, Time.truncate(time, :second) |> Time.to_string })
    {:noreply, %{state | time: time}}
  end

  def handle_info(msg, state) do
    IO.inspect(msg)
    {:noreply, state}
  end
end
