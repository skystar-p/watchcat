defmodule ServerSupervisor do
  use Supervisor
  require ClientMetricCollector

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_args) do
    children = [
      ClientMetricCollector,
      {Task.Supervisor, name: TaskSupervisor}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
