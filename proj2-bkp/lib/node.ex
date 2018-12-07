defmodule Proj2.Node do
  use GenServer
  require Logger

  @node_registry_name :node_process_registry
  @fully_informed_nodes :fully_informed_nodes

  # State of the node
  defstruct node_id: 0,
            name: "",
            message: "",
            count_heard: 0,
            fully_informed: false

  def start_link(node_id) when is_integer(node_id) do
    name = via_tuple(node_id)
    GenServer.start_link(__MODULE__, [node_id], name: name)
  end

  defp via_tuple(node_id) do
    {:via, Registry, {@node_registry_name, node_id}}
  end

  @doc """
  Return some details (state) for this node process
  """
  def details(node_id) do
    GenServer.call(via_tuple(node_id), :get_details)
  end

  @doc """
  Function to increment the number of times the node has heard the message
  """
  def step(node_id, message) do
    GenServer.cast(via_tuple(node_id), {:step, message})
  end

  @doc """
  Function to increment the number of times the node has heard the message
  """
  def transmit(node_id) do
    GenServer.cast(via_tuple(node_id), {:transmit})
  end

  @doc """
  Init callback
  """
  def init([node_id]) do
    Logger.info("Process created... Node ID: #{node_id}")

    # Set initial state and return from `init`
    {:ok, %__MODULE__{ node_id: node_id }}
  end

  @doc """
  Gracefully end this process
  """
  def handle_info(:end_process, state) do
    Logger.info("Process terminating... Node ID: #{state.node_id}")
    {:stop, :normal, state}
  end

  def handle_call(:get_details, _from, state) do

    # maybe you'd want to transform the state a bit...
    response = %{
      id: state.node_id,
      name: state.name,
      message: state.message,
      count_heard: state.count_heard,
      fully_informed: state.fully_informed
    }

    {:reply, response, state}
  end

  def handle_cast({:transmit}, state) do
    {:ok, node_id} = Map.fetch(state, :node_id)
    {:ok, count_heard} = Map.fetch(state, :count_heard)
    {:ok, message} = Map.fetch(state, :message)
    {:ok, fully_informed} = Map.fetch(state, :fully_informed)

    cond do
      count_heard <= 3 ->
        node_process_count = Proj2.NodeSupervisor.node_process_count
        next_node_id = Enum.at(Proj2.NodeSupervisor.node_ids,:rand.uniform(node_process_count) - 1)
        IO.puts "#{node_id} calling any node from 1 to #{node_process_count}. Calling #{next_node_id}"

        GenServer.cast(via_tuple(next_node_id), {:step, message})
        GenServer.cast(via_tuple(node_id), {:transmit})
      not fully_informed ->
        # send message to supervisor
        state = Map.put(state, :fully_informed, true)
        send(Proj2.NodeSupervisor, {:informed, node_id})
        #Proj2.NodeSupervisor.informSupervisor(node_id)
    end
    {:noreply, state}
  end

  @doc false
  def handle_cast({:step, message}, state) do
    {:ok, node_id} = Map.fetch(state, :node_id)
    {:ok, count_heard} = Map.fetch(state, :count_heard)

    IO.puts "Process #{node_id} heard rumor #{count_heard} times."

    state = Map.put(state, :message, message)
    state = Map.update!(state, :count_heard, fn current_value ->
      current_value + 1
    end)

    GenServer.cast(via_tuple(node_id), {:transmit})
    {:noreply, state}
  end
end
