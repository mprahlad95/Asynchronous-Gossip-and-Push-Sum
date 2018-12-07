
defmodule Proj2 do
  use Supervisor

  defp parse_inputs do
    command_line_args = System.argv()
    if length(command_line_args) < 3 do
      raise ArgumentError, message: "there must be at least three arguments: numNodes, topology, algorithm"
    end
    [numNodes, topology, algorithm | _tail] = command_line_args

    numNodes =
      try do
        numNodes |> String.trim_trailing |> String.to_integer
      rescue
        ArgumentError -> IO.puts("numNodes must be an integer. Defaulting #{numNodes} to 1")
        1
      end

    [numNodes, topology, algorithm]
  end

  def main do
    [numNodes, topology, algorithm] = parse_inputs()
    numNodes =
      case topology do
        "sphere" ->
          numNodes |> :math.sqrt |> :math.ceil |> :math.pow(2) |> round
        "3D" ->
          numNodes |> :math.pow(1/3) |> :math.ceil |> :math.pow(3) |> round
        _ ->
          numNodes
      end

    IO.puts "Updating node number as per topology. New node count : #{numNodes}"

    {:ok, super_pid} = start_link([numNodes, algorithm])

    node_id_map = make_id_map(%{}, Supervisor.which_children(super_pid), 1)

    random_starting_node_id = get_random_node_id(numNodes)
    random_starting_node_pid = get_pid(node_id_map, random_starting_node_id)

    set_neighbors_in_children(node_id_map, numNodes, topology)

    case algorithm do
      "gossip" -> GenServer.cast(random_starting_node_pid, {:step, "message"})
      "push-sum" -> GenServer.cast(random_starting_node_pid, {:step, random_starting_node_id, 1})
    end
    listen(numNodes)
  end

  defp get_random_node_id(numNodes) do
    :rand.uniform(numNodes)
  end

  defp set_neighbors_in_children(node_id_map, numNodes, topology) do
    IO.inspect map_size(node_id_map)

    Enum.each  node_id_map,  fn {node_id, [node_pid, _, _]} ->
      neighbor_list = get_neighbor_list(node_id, numNodes, node_id_map, topology)
      GenServer.call(node_pid, {:set_neighbors, neighbor_list})
    end
  end

  defp get_neighbor_list(node_id, numNodes, node_id_map, "full") do
    list = Enum.map(1..numNodes, fn nid->
      get_pid(node_id_map, nid)
    end)
    List.delete_at(list, node_id)
  end

  defp get_neighbor_list(node_id, numNodes, node_id_map, "3D") do
    size = round(:math.pow(numNodes, 1/3))
    n_list = []
    n_list = n_list ++ if node_id - size >= 1 and node_id - size <= numNodes, do: [node_id - size], else: []
    n_list = n_list ++ if node_id + 1 >= 1 and node_id + 1 <= numNodes, do: [node_id + 1], else: []
    n_list = n_list ++ if node_id + size >= 1 and node_id + size <= numNodes, do: [node_id + size], else: []
    n_list = n_list ++ if node_id - 1 >= 1 and  node_id - 1 <= numNodes, do: [node_id - 1], else: []
    n_list = n_list ++ if node_id - (size*size) >= 1 and  node_id - (size*size) <= numNodes, do: [node_id - (size*size)], else: []
    n_list = n_list ++ if node_id + (size*size) >= 1 and  node_id + (size*size) <= numNodes, do: [node_id + (size*size)], else: []
    Enum.map(n_list, fn nid->
      get_pid(node_id_map, nid)
    end)
  end

  defp get_neighbor_list(node_id, _numNodes, node_id_map, "rand2D") do
    [_, node_x, node_y] =  Map.get(node_id_map, node_id)
    new_map = Enum.filter(node_id_map, fn{_node_id, [_node_pid, x, y]} ->
                (:math.pow((node_x-x), 2) + :math.pow((node_y-y), 2)) |> :math.sqrt <= 0.1
              end)
    pid_list = Enum.map(new_map, fn{_node_id, [node_pid, _x, _y]} ->
                node_pid
              end)
    pid_list
  end

  defp get_neighbor_list(node_id, numNodes, node_id_map, "line") do
    cond do
      node_id == 1 and numNodes >=2 ->
        [get_pid(node_id_map, numNodes), get_pid(node_id_map, node_id+1)]
      node_id == numNodes and numNodes >= 2 ->
        [get_pid(node_id_map, node_id-1), get_pid(node_id_map, 1)]
      node_id > 1 and node_id < numNodes ->
        [get_pid(node_id_map, node_id-1), get_pid(node_id_map, node_id+1)]
      true ->
        []
    end
  end

  defp get_neighbor_list(node_id, numNodes, node_id_map, "imp2D") do
    list = get_neighbor_list(node_id, numNodes, node_id_map, "line")
    random_node_id = :rand.uniform(numNodes)
    list ++ [get_pid(node_id_map, random_node_id)]
  end

  defp get_neighbor_list(node_id, numNodes, node_id_map, "sphere") do
    size = round(:math.sqrt(numNodes))
    row = div(node_id, size) + 1
    col = rem(node_id, size)
    [col, row] = if col==0, do: [size, row - 1], else: [col, row]
    top_node_id =
      if row == 1 do
        numNodes - size + node_id
      else
        node_id - size
      end
    right_node_id =
      if col == size do
        node_id - size + 1
      else
        node_id+1
      end
    bottom_node_id =
      if row == size do
        node_id - (size* (size - 1))
      else
        node_id+size
      end
    left_node_id =
      if col == 1 do
        node_id + size - 1
      else
        node_id-1
      end
    Enum.map([top_node_id, right_node_id, bottom_node_id, left_node_id], fn nid->
      get_pid(node_id_map, nid)
    end)
  end

  defp make_id_map(node_ids_map, [node_obj | node_objs], node_id) do
    {_, node_pid, _, _} = node_obj
    rand_x = :rand.uniform()
    rand_y = :rand.uniform()
    node_ids_map = Map.put(node_ids_map, node_id, [node_pid, rand_x, rand_y])
    make_id_map(node_ids_map, node_objs, node_id + 1)
  end

  defp make_id_map(node_ids_map, [], _) do
    node_ids_map
  end

  defp get_pid(node_id_map, node_id) do
    [pid, _, _] = Map.get(node_id_map, node_id)
    pid
  end

  defp listen(numNodes, nodes_set\\MapSet.new(), start_time\\System.monotonic_time()) do
    receive do
      {:heard_max_times, node_id} ->

        if not MapSet.member?(nodes_set, node_id) do
          IO.puts "#{MapSet.size(nodes_set)+1} out of #{numNodes} have stopped transmitting"
        end
        nodes_set = MapSet.put(nodes_set, node_id)
        num_nodes_heard = MapSet.size(nodes_set)
        if num_nodes_heard < round(:math.floor(0.9*numNodes)) do
          listen(numNodes, nodes_set, start_time)
        else
          end_time = System.monotonic_time()
          time_taken = end_time - start_time
          IO.puts "It took #{time_taken} for all children to get the message"
        end
      {:converged, node_id, ratio} ->
        end_time = System.monotonic_time()
        time_taken = end_time - start_time

        if not MapSet.member?(nodes_set, node_id) do
          IO.puts "#{node_id} converged with ratio #{ratio}"
          IO.puts "It took #{time_taken} milliseconds to converge to ratio #{ratio}"
        end
        nodes_set = MapSet.put(nodes_set, node_id)
        num_nodes_converged = MapSet.size(nodes_set)
        if num_nodes_converged < round(:math.floor(0.8*numNodes)) do
          listen(numNodes, nodes_set, start_time)
        else
          IO.puts "It took #{time_taken} milliseconds to converge to ratio #{ratio}"
        end
    end
  end

  def get_children_list(children_list, numNodes, "gossip") do
    if numNodes == 0 do
      children_list
    else
      get_children_list(children_list, numNodes - 1, "gossip") ++ [%{
        id: numNodes,
        start: {GossipNode, :start_link, [%{:id => numNodes, :count_heard => 0, :super_pid => self(), :start_time => System.monotonic_time()}]}
      }]
    end
  end

  def get_children_list(children_list, numNodes, "push-sum") do
    if numNodes == 0 do
      children_list
    else
      get_children_list(children_list, numNodes - 1, "push-sum") ++ [%{
        id: numNodes,
        start: {PushSumNode, :start_link, [%{:id => numNodes, :s => numNodes, :w => 0.1, :super_pid => self(), :unchanged_for => 0, :start_time => System.monotonic_time()}]}
      }]
    end
  end

  def start_link([numNodes, algorithm]) do
    children = get_children_list([], numNodes, algorithm)
    Supervisor.start_link(children, strategy: :one_for_one)
  end

  def init([]) do
    nil
  end
end

defmodule GossipNode do
  use GenServer
  def start_link(state) do
    GenServer.start_link(__MODULE__, state)
  end

  def init(args) do
    {:ok, args}
  end

  defp get_random_neighbour(neighbor_list) do
    Enum.random(neighbor_list)
  end

  def handle_cast({:transmit_to_self}, state) do
    count_heard = Map.get(state, :count_heard)
    max_count = 10
    neighbor_list = Map.get(state, :neighbor_list)
    node_id = Map.get(state, :id)
    super_pid = Map.get(state, :super_pid)
    message = Map.get(state, :message)
    if(count_heard>=max_count) do
      Process.send(super_pid, {:heard_max_times, node_id}, [])
    else
      neighbor_pid = get_random_neighbour(List.delete(neighbor_list, node_id))
      GenServer.cast(neighbor_pid, {:step, message})
      GenServer.cast(self(), {:transmit_to_self})
    end

    {:noreply, state}
  end

  def handle_cast({:step, message}, state) do
    state = Map.put(state, :message, message)
    state = Map.update!(state, :count_heard, fn current_value ->
      current_value + 1
    end)
    count_heard = Map.get(state, :count_heard)
    super_pid = Map.get(state, :super_pid)
    max_count = 10
    neighbor_list = Map.get(state, :neighbor_list)
    node_id = Map.get(state, :id)
    #IO.puts "#{node_id} heard #{count_heard} times"
    if(count_heard>=max_count) do
      Process.send(super_pid, {:heard_max_times, node_id}, [])
    else
      neighbor_pid = get_random_neighbour(List.delete(neighbor_list, node_id))
      GenServer.cast(neighbor_pid, {:step, message})
      GenServer.cast(self(), {:transmit_to_self})
    end

    {:noreply, state}
  end

  def handle_call({:set_neighbors, neighbor_list}, _from, state) do
    state = Map.put(state, :neighbor_list, neighbor_list)
    {:reply, state, state}
  end
end

defmodule PushSumNode do
  use GenServer
  def start_link(state) do
    GenServer.start_link(__MODULE__, state)
  end

  def init(args) do
    {:ok, args}
  end

  defp get_random_neighbour(neighbor_list) do
    Enum.random(neighbor_list)
  end

  defp get_sum_estimate(state) do
    node_s = Map.get(state, :s)
    node_w = Map.get(state, :w)
    node_s/node_w
  end

  def handle_cast({:transmit_to_self}, state) do
    node_s = Map.get(state, :s)
    node_w = Map.get(state, :w)

    unchanged_for = Map.get(state, :unchanged_for)
    super_pid = Map.get(state, :super_pid)
    neighbor_list = Map.get(state, :neighbor_list)
    node_id = Map.get(state, :id)
    sum_estimate = get_sum_estimate(state)
    if(unchanged_for>=3) do
      #Process.exit(self(),:kill)
      Process.send(super_pid, {:converged, node_id, sum_estimate}, [])
    else
      neighbor_pid = get_random_neighbour(List.delete(neighbor_list, node_id))
      GenServer.cast(neighbor_pid, {:step, node_s/2, node_w/2})
      GenServer.cast(self(), {:transmit_to_self})
    end

    {:noreply, state}
  end

  def handle_cast({:step, s, w}, state) do
    prev_sum_estimate = get_sum_estimate(state)
    node_s = Map.get(state, :s)
    node_w = Map.get(state, :w)
    node_s = node_s + s
    node_w = node_w + w
    state = Map.put(state, :s, node_s)
    state = Map.put(state, :w, node_w)
    new_sum_estimate = get_sum_estimate(state)
    state =
      if abs(new_sum_estimate-prev_sum_estimate) <= :math.pow(10, -8) do
        Map.update!(state, :unchanged_for, fn unchanged_for ->
          unchanged_for + 1
        end)
      else
        state
      end

    unchanged_for = Map.get(state, :unchanged_for)
    super_pid = Map.get(state, :super_pid)
    neighbor_list = Map.get(state, :neighbor_list)
    node_id = Map.get(state, :id)
    #IO.puts "#{node_id} unchanged for #{unchanged_for}"
    if(unchanged_for>=3) do
      #Process.exit(self(),:kill)
      Process.send(super_pid, {:converged, node_id, new_sum_estimate}, [])
    else
      neighbor_pid = get_random_neighbour(List.delete(neighbor_list, node_id))
      GenServer.cast(neighbor_pid, {:step, node_s/2, node_w/2})
      GenServer.cast(self(), {:transmit_to_self})
    end

    {:noreply, state}
  end

  def handle_call({:set_neighbors, neighbor_list}, _from, state) do
    state = Map.put(state, :neighbor_list, neighbor_list)
    {:reply, state, state}
  end
end

Proj2.main
