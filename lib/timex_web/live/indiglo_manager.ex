defmodule TimexWeb.IndigloManager do
  alias Mix.ProjectStack
  use GenServer

  def init(ui) do
    :gproc.reg({:p, :l, :ui_event})
    {:ok, %{ui_pid: ui, st: IndigloOff}}
  end
  def handle_info(:start_alarm, %{ui_pid: ui, st: IndigloOff} = state) do
    Process.send_after(self(), :AlarmOn_AlarmOff, 1000)
    GenServer.cast(ui, :set_indiglo)
    {:noreply, %{state | st: AlarmOn}}
  end
  def handle_info(:AlarmOn_AlarmOff, %{ui_pid: ui, st: AlarmOn} = state) do
    Process.send_after(self(), :AlarmOff_AlarmOn, 1000)
    GenServer.cast(ui, :unset_indiglo)
    {:noreply, %{state | st: AlarmOff}}
  end
  def handle_info(:AlarmOff_AlarmOn, %{ui_pid: ui, st: AlarmOff} = state) do
    Process.send_after(self(), :AlarmOn_AlarmOff, 1000)
    GenServer.cast(ui, :set_indiglo)
    {:noreply, %{state | st: AlarmOn}}
  end
  def handle_info(msg, state) do
    IO.inspect(msg)
    {:noreply, state}
  end
end
