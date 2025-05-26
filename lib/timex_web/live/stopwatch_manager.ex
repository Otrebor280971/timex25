defmodule TimexWeb.StopwatchManager do
  use GenServer

  def init(ui) do
    :gproc.reg({:p, :l, :ui_event})
    count = ~T[00:00:00.000]
    GenServer.cast(ui, {:set_time_display, count |> Time.to_string |> String.slice(3, 8) })
    {:ok, %{ui_pid: ui, count: count, mode: Time, st1: Working, st2: Paused, timer: nil}}
  end

  #      Working - bottom-left -> Working
  def handle_info(:"bottom-left", %{ui_pid: ui, mode: SWatch, st1: Working} = state) do
    count = ~T[00:00:00.000]
    GenServer.cast(ui, {:set_time_display, count |> Time.to_string |> String.slice(3, 8) })
    {:noreply, %{state | count: count}}
  end

  # Working - top-left -> Working
  def handle_info(:"top-left", %{ui_pid: ui, mode: mode, count: count, st1: Working} = state) do
    mode =
      if mode == SWatch do
        Time
      else
        GenServer.cast(ui, {:set_time_display, count |> Time.to_string |> String.slice(3, 8) })
        SWatch
      end
    {:noreply, %{state | mode: mode}}
  end
  #----------------------------------------------------------------------------


  def handle_info(:"bottom-right", %{ui_pid: ui, mode: SWatch,st2: Paused, count: count} = state) do
    count = Time.add(count, 10, :millisecond)
    IO.inspect("Moving from Paused to Counting")
    timer = Process.send_after(self(), Counting_Counting, 10)
    GenServer.cast(ui, {:set_time_display, count |> Time.to_string |> String.slice(3, 8) })
    {:noreply, %{state | st2: Counting, count: count, timer: timer}}
  end

  def handle_info(:"bottom-right", %{st2: Counting, mode: SWatch,timer: timer} = state) do
    if timer != nil do
      Process.cancel_timer(timer)
    end
    IO.inspect("Moving from Counting to Paused")
    {:noreply, %{state | st2: Paused, timer: nil}}
  end

  def handle_info(Counting_Counting, %{ui_pid: ui, st2: Counting, mode: mode, count: count}= state) do
    count = Time.add(count, 10, :millisecond)
    timer = Process.send_after(self(), Counting_Counting, 10)
    if mode == SWatch do
      GenServer.cast(ui, {:set_time_display, count |> Time.to_string |> String.slice(3, 8) })
    end
    {:noreply, %{state | st2: Counting, count: count, timer: timer}}
  end

  def handle_info(_event, state) do
    {:noreply, state}
  end
end
