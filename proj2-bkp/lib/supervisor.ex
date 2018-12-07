defmodule Proj2.NodeSupervisor do
  use Supervisor
  @node_registry_name :node_process_registry

  alias Proj2.Node

  def start_link do
    {:ok, supervisor_pid} = Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def node_process_count do
    Supervisor.which_children(__MODULE__) |> length
  end

  def create_node_process(node_id) when is_integer(node_id) do
    case Supervisor.start_child(__MODULE__, [node_id]) do
      {:ok, _pid} -> {:ok, node_id}
      {:error, {:already_started, _pid}} -> {:error, :process_already_exists}
      other -> {:error, other}
    end
  end

  def node_ids do
    Supervisor.which_children(__MODULE__)
    |> Enum.map(fn {_, node_proc_pid, _, _} ->
      Registry.keys(@node_registry_name, node_proc_pid)
      |> List.first
    end)
    |> Enum.sort
  end

  def init(_) do

    children = [
      worker(Proj2.Node, [], restart: :temporary)
    ]
    supervise(children, strategy: :simple_one_for_one)
  end

  def handle_info(msg, state) do
    IO.puts "hi #{inspect(msg)}"
    {:noreply, [], state}
  end

end
