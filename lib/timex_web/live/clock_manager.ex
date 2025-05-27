defmodule TimexWeb.ClockManager do
  use GenServer

  def init(ui) do
    :gproc.reg({:p, :l, :ui_event})
    {_, now} = :calendar.local_time()
    time = Time.from_erl!(now)
    alarm = Time.add(time, 5)
    Process.send_after(self(), :working_working, 1000)
    {:ok, %{ui_pid: ui,time: time, alarm: alarm, st: Working, mode: :Time, last_click: nil, show: false, count: 0, edit_time: nil, edit_alarm: nil, selection: nil}}
  end

  # Normal clock mode
  def handle_info(:working_working, %{ui_pid: ui, time: time, alarm: alarm, st: Working, mode: :Time} = state) do
    Process.send_after(self(), :working_working, 1000)
    time = Time.add(time, 1)
    if time  == alarm do
      IO.inspect("Boooh..")
      :gproc.send({:p, :l, :ui_event}, :start_alarm)
    end
    GenServer.cast(ui, {:set_time_display, Time.truncate(time, :second) |> Time.to_string })
    {:noreply, %{state | time: time}}
  end

  # Edit selection (hour, minute, second)
  def handle_info(:"bottom-right", %{st: st, selection: selection} = state) when st in [Editing, EditingAlarm] do
    new_selection = case selection do
      :hour -> :minute
      :minute -> :second
      :second -> :hour
    end
    {:noreply, %{state | selection: new_selection, count: 0}}
  end

  # Time editing mode if bottom-right is double-pressed
  def handle_info(:"bottom-right", %{st: Working, mode: mode, time: time, last_click: last_click} = state) when mode != SWatch do
    now = System.monotonic_time(:millisecond)

    cond do
      last_click != nil and now - last_click < 500 ->
        IO.inspect("Modo de edicion de tiempo")
        edit_time = time
        GenServer.cast(state.ui_pid, {:set_time_display, "EDIT TIME"})
        Process.send_after(self(), :editing_blink, 250)
        {:noreply, %{state | st: Editing, selection: :hour, show: true, count: 0, edit_time: edit_time, last_click: nil}}

      true ->
        IO.inspect("esperando segundo click tiempo")
        {:noreply, %{state | last_click: now}}
    end
  end

  # Alarm editing mode if bottom-left is double-pressed
  def handle_info(:"bottom-left", %{st: Working, mode: mode, alarm: alarm, last_click: last_click} = state) when mode != SWatch do
    now = System.monotonic_time(:millisecond)

    cond do
      last_click != nil and now - last_click < 500 ->
        IO.inspect("Modo de edicion de alarma")
        GenServer.cast(state.ui_pid, {:set_time_display, "EDIT ALARM"})
        Process.send_after(self(), :editing_blink_alarm, 250)
        {:noreply, %{state | st: EditingAlarm, edit_alarm: alarm, selection: :hour, show: true, count: 0, last_click: nil}}

      true ->
        IO.inspect("esperando segundo click alarma")
        {:noreply, %{state | last_click: now}}
    end
  end

  # Text blinking inside time edition mode
  def handle_info(:editing_blink, %{st: Editing, show: show, ui_pid: ui, edit_time: edit_time, selection: selection, count: count} = state) do
    new_show = !show
    new_count = if new_show, do: count + 1, else: count

    if new_count == 20 do
      send(self(), :exit_editing)
      {:noreply, state}

    else
      {h, m, s} = {edit_time.hour, edit_time.minute, edit_time.second}

      display =
        case selection do
          :hour ->
            hour = if new_show, do: pad(h), else: " "
            "#{hour}:#{pad(m)}:#{pad(s)}"

          :minute ->
            minute = if new_show, do: pad(m), else: " "
            "#{pad(h)}:#{minute}:#{pad(s)}"

          :second ->
            second = if new_show, do: pad(s), else: " "
            "#{pad(h)}:#{pad(m)}:#{second}"
        end

      GenServer.cast(ui, {:set_time_display, display})
      Process.send_after(self(), :editing_blink, 250)

      {:noreply, %{state | show: new_show, count: new_count}}
    end
  end

  # Text blinking inside alarm editing mode
  def handle_info(:editing_blink_alarm, %{st: EditingAlarm, show: show, ui_pid: ui, edit_alarm: edit_alarm, selection: selection, count: count} = state) do
    new_show = !show
    new_count = if new_show, do: count + 1, else: count

    if new_count == 20 do
      send(self(), :exit_editing_alarm)
      {:noreply, state}

    else
      {h, m, s} = {edit_alarm.hour, edit_alarm.minute, edit_alarm.second}

      display =
        case selection do
          :hour ->
            hour = if new_show, do: pad(h), else: " "
            "#{hour}:#{pad(m)}:#{pad(s)}"

          :minute ->
            minute = if new_show, do: pad(m), else: " "
            "#{pad(h)}:#{minute}:#{pad(s)}"

          :second ->
            second = if new_show, do: pad(s), else: " "
            "#{pad(h)}:#{pad(m)}:#{second}"
        end

      GenServer.cast(ui, {:set_time_display, display})
      Process.send_after(self(), :editing_blink_alarm, 250)

      {:noreply, %{state | show: new_show, count: new_count}}
    end
  end

  # Increment time counter
  def handle_info(:"bottom-left", %{st: Editing, edit_time: edit_time, selection: selection, ui_pid: ui} = state) do
    new_edit_time = increment_time(edit_time, selection)
    GenServer.cast(ui, {:set_time_display, Time.to_string(new_edit_time)})
    {:noreply, %{state | edit_time: new_edit_time, count: 0}}
  end

  # Increment alarm counter
  def handle_info(:"bottom-left", %{st: EditingAlarm, edit_alarm: alarm, selection: sel, ui_pid: ui} = state) do
    new_alarm = increment_time(alarm, sel)
    GenServer.cast(ui, {:set_time_display, Time.to_string(new_alarm)})
    {:noreply, %{state | edit_alarm: new_alarm, count: 0}}
  end

  # Exit and save new time
  def handle_info(:exit_editing, %{st: Editing, edit_time: edit_time, ui_pid: ui} = state) do
    GenServer.cast(ui, {:set_time_display, Time.to_string(edit_time)})
    Process.send_after(self(), :working_working, 1000)
    {:noreply, %{state | st: Working, time: edit_time, edit_time: nil, selection: nil, show: false, count: 0}}
  end

  # Exit and save new alarm
  def handle_info(:exit_editing_alarm, %{st: EditingAlarm, edit_alarm: new_alarm, ui_pid: ui} = state) do
    GenServer.cast(ui, {:set_time_display, Time.to_string(new_alarm)})
    Process.send_after(self(), :working_working, 1000)
    {:noreply, %{state | st: Working, alarm: new_alarm, edit_alarm: nil, selection: nil, show: false, count: 0}}
  end

  # Handle other calls
  def handle_info(msg, state) do
    IO.inspect(msg)
    {:noreply, state}
  end

  # Function to increment time
  defp increment_time(time, :hour) do
    %{time | hour: rem(time.hour + 1, 24)}
  end
  defp increment_time(time, :minute) do
    %{time | minute: rem(time.minute + 1, 60)}
  end
  defp increment_time(time, :second) do
    %{time | second: rem(time.second + 1, 60)}
  end

  defp pad(n) when n < 10, do: "0#{n}"
  defp pad(n), do: "#{n}"
end
