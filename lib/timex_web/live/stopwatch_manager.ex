defmodule TimexWeb.StopwatchManager do
  use GenServer

  def init(ui) do
    :gproc.reg({:p, :l, :ui_event})
    {:ok, %{ui_pid: ui, count: ~T[00:00:00.00]}}
  end
end
