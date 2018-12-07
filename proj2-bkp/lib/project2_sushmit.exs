defmodule Project2 do

  def main(args \\ []) do

    {_, input, _} = OptionParser.parse(args)
    numNodes = 0

    if length(input) == 3 do

      numNodes = String.to_integer(List.first(input))

      if numNodes > 1 do

        algorithm = List.last(input)
        {topology, _} = List.pop_at(input, 1)

        case algorithm do

          "gossip" ->
                IO.puts "Using Gossip algorithm"
                actors = init_actors(numNodes)
                init_algorithm(actors, topology, numNodes, algorithm)

          "push-sum" ->
                IO.puts "Using push-sum algorithm"
                actors = init_actors_push_sum(numNodes)
                init_algorithm(actors, topology, numNodes, algorithm)
           _ ->
             IO.puts "Invalid algorithm"
             IO.puts "Enter gossip or push-sum"
        end
      end

    else
      IO.puts "Invalid input. Number of arguments should be 3"
      IO.puts "Example: ./project2 30 2D gossip"
    end
  end

  def init_actors(numNodes) do
    middleNode = trunc(numNodes/2)
    Enum.map(1..numNodes, fn x -> cond  do
                                      x == middleNode -> {:ok, actor} = Client.start_link("This is rumour")
                                      true -> {:ok, actor} = Client.start_link("")
                                   end
                                   actor end)
  end

  def init_actors_push_sum(numNodes) do
    middleNode = trunc(numNodes/2)
    Enum.map(1..numNodes,
      fn x ->
        cond do
          x == middleNode ->
            x = Integer.to_string(x)
            {x, _} = Float.parse(x)
            #Client.start_link returns the pid of the process
            {:ok, actor} = Client.start_link([x] ++ ["This is rumour"])
          true ->
            x = Integer.to_string(x)
            {x, _} = Float.parse(x)
            #Client.start_link returns the pid of the process
            {:ok, actor} = Client.start_link([x] ++ [""])
        end
      actor
      end)
  end

  def init_algorithm(actors, topology, numNodes, algorithm) do

    :ets.new(:count, [:set, :public, :named_table])
    :ets.insert(:count, {"spread", 0})
    neighbors = %{}

    case topology do
      "full" ->
            IO.puts "Using full topology"
            neighbors = get_full_neighbors(actors)
      "2D" ->
            IO.puts "Using 2D topology"
            neighbors = get_2d_neighbors(actors, topology)
      "line" ->
            IO.puts "Using line topology"
            neighbors = get_line_neighbors(actors)  # Gives map of host, neighbors
      "imp2D" ->
            IO.puts "Using imp2D topology"
            neighbors = get_2d_neighbors(actors, topology)
       _ ->
            IO.puts "Invalid topology"
            IO.puts "Enter full/2D/line/imp2D"
    end

    set_neighbors(neighbors)
    prev = System.monotonic_time(:milliseconds)

    if (algorithm == "gossip") do
      gossip(actors, neighbors, numNodes)
    else
      push_sum(actors, neighbors, numNodes)
    end
    IO.puts "Time required: " <> to_string(System.monotonic_time(:milliseconds) - prev) <> " ms"
  end

  def gossip(actors, neighbors, numNodes) do

    for  {k, v}  <-  neighbors  do
      Client.send_message(k)
    end

    actors = check_actors_alive(actors)
    [{_, spread}] = :ets.lookup(:count, "spread")

    if ((spread/numNodes) < 0.9 && length(actors) > 1) do
      neighbors = Enum.filter(neighbors, fn {k,_} -> Enum.member?(actors, k) end)
      gossip(actors, neighbors, numNodes)
    else
      IO.puts "Spread: " <> to_string(spread * 100/numNodes) <> " %"
    end
  end

   def push_sum(actors, neighbors, numNodes) do
    for  {k, v}  <-  neighbors  do
      Client.send_message_push_sum(k)
    end

    actors = check_actors_alive_push_sum(actors)
    [{_, spread}] = :ets.lookup(:count, "spread")

    if ((spread/numNodes) < 0.9 && length(actors) > 1) do
      neighbors = Enum.filter(neighbors, fn ({k,_}) -> Enum.member?(actors, k) end)
      [{_, spread}] = :ets.lookup(:count, "spread")
      push_sum(actors, neighbors, numNodes)
    else
      IO.puts "Spread: " <> to_string(spread * 100/numNodes) <> " %"
    end
  end

  def check_actors_alive(actors) do
    current_actors = Enum.map(actors, fn x -> if (Process.alive?(x) && Client.get_count(x) < 10  && Client.has_neighbors(x)) do x end end)
    List.delete(Enum.uniq(current_actors), nil)
  end


  def push_sum(actors, neighbors, numNodes) do
    for  {k, v}  <-  neighbors  do
      Client.send_message_push_sum(k)
    end

    actors = check_actors_alive_push_sum(actors)
    [{_, spread}] = :ets.lookup(:count, "spread")

    if ((spread/numNodes) < 0.9 && length(actors) > 1) do
      neighbors = Enum.filter(neighbors, fn ({k,_}) -> Enum.member?(actors, k) end)
      push_sum(actors, neighbors, numNodes)
    end
  end

  def check_actors_alive_push_sum(actors) do
    current_actors = Enum.map(actors,
        fn x ->
          diff = Client.get_diff(x)
          if(Process.alive?(x) && Client.has_neighbors(x) && (abs(List.first(diff)) > :math.pow(10, -10)
                 || abs(List.last(diff)) > :math.pow(10, -10))) do
             x
          end
        end)
    List.delete(Enum.uniq(current_actors), nil)
  end

  def get_full_neighbors(actors) do
    Enum.reduce(actors, %{}, fn (x, acc) ->  Map.put(acc, x, Enum.filter(actors, fn y -> y != x end)) end)
  end

  def get_line_neighbors(actors) do
     # actors_with_index = %{pid1 => 0, pid2 => 1, pid3 => 2}
    actors_with_index = Stream.with_index(actors, 0) |> Enum.reduce(%{}, fn({v,k}, acc) -> Map.put(acc, v, k) end)
    first = Enum.at(actors,0)
    lastIndex = length(actors) - 1
    last = Enum.at(actors, lastIndex)
    Enum.reduce(actors, %{}, fn (x, acc) -> {:ok, currentIndex} = Map.fetch(actors_with_index, x)
                                            cond do
                                              x == first -> Map.put(acc, x, [Enum.at(actors, 1)])
                                              x == last -> Map.put(acc, x, [Enum.at(actors, lastIndex - 1)])
                                              true -> Map.put(acc, x, [Enum.at(actors, currentIndex - 1), Enum.at(actors, currentIndex + 1)])
                                            end end)
  end

  def get_2d_neighbors(actors, topology) do

    actors_with_index = Stream.with_index(actors, 0) |> Enum.reduce(%{}, fn({v,k}, acc) -> Map.put(acc, k, v) end)
    neighbors = %{}
    numNodes = length(actors)
    xMax = trunc(:math.ceil(:math.sqrt(numNodes)))
    yMax = xMax

    yMulti = yMax
    xLimit = xMax - 1
    yLimit = yMax - 1

    final_neighbors = Enum.reduce(0..yLimit, %{}, fn(y, neighbors) ->
                          Enum.reduce(0..xLimit, neighbors, fn (x, neighbors) ->
                                                              i = y * yMulti + x
                                                              if (i < numNodes) do
                                                                adjacents = []
                                                                if (x > 0) do adjacents = Enum.into([i - 1], adjacents) end
                                                                if (x < xLimit && (i + 1) < numNodes) do adjacents = Enum.into([i+1], adjacents) end
                                                                if (y > 0) do adjacents = Enum.into([i - yMulti], adjacents) end
                                                                if (y < yLimit && (i + yMulti) < numNodes) do adjacents = Enum.into([i + yMulti], adjacents) end
                                                                {:ok, actor} = Map.fetch(actors_with_index, i)

                                                                # Add random neighbor
                                                                case topology do
                                                                  "imp2D" -> adjacents = Enum.into(get_random_node_imp2D(adjacents, numNodes), adjacents) # :rand.uniform(n) gives random number: 1 <= x <= n
                                                                  _ ->
                                                                end

                                                                neighbor_pids = Enum.map(adjacents, fn x ->
                                                                                                      {:ok, n} = Map.fetch(actors_with_index, x)
                                                                                                      n end)
                                                                Map.put(neighbors, actor, neighbor_pids)
                                                              else
                                                                Map.put(neighbors, "dummy", "dummy")
                                                              end
                                                            end)
                                                          end)
    Map.delete(final_neighbors, "dummy")
  end

  def set_neighbors(neighbors) do
    for  {k, v}  <-  neighbors  do
      Client.set_neighbors(k, v)
    end
  end

  def get_random_node_imp2D(neighbors, numNodes) do
    random_node_index =  :rand.uniform(numNodes) - 1
    if(Enum.member?(neighbors, random_node_index)) do
      get_random_node_imp2D(neighbors, numNodes)
    end
    [random_node_index]
  end

  def print_rumour_count(actors) do
     Enum.each(actors, fn x -> IO.inspect x
                               IO.puts to_string(Client.get_rumour(x)) <> " Count: " <>to_string(Client.get_count(x))
                              end)
  end

end

defmodule Server do
  use GenServer

  def init(x) do
      if is_list(x) do
          {:ok, %{"s" => List.first(x), "rumour" => List.last(x), "w" => 1, "s_old_2" => 1, "w_old_2" => 1, "diff1" => 1, "diff2" => 1, "neighbors" => []}}
      else
          {:ok, %{"rumour" => x, "count" => 0, "neighbors" => []}}
      end
  end

  def handle_cast({:receive_message, rumour, sender}, state) do
      {:ok, count} = Map.fetch(state, "count")
      state = Map.put(state, "count", count + 1)

      if (count > 10) do
         _ = GenServer.cast(sender, {:remove_neighbor, self()})
         {:noreply, state}
      else
          {:ok, existing_rumour} = Map.fetch(state, "rumour")

          if(existing_rumour != "") do
              {:noreply, state}
          else
              [{_, spread}] = :ets.lookup(:count, "spread")
              :ets.insert(:count, {"spread", spread + 1})
              {:noreply, Map.put(state, "rumour", rumour)}
          end
      end
  end

  def handle_cast({:receive_message_push_sum, sender, s, w, rumour}, state) do
      {:ok, s_old} = Map.fetch(state, "s")
      {:ok, w_old} = Map.fetch(state, "w")
      {:ok, s_old_2} = Map.fetch(state, "s_old_2")
      {:ok, w_old_2} = Map.fetch(state, "w_old_2")
      {:ok, existing_rumour} = Map.fetch(state, "rumour")

      s_new = s_old + s
      w_new = w_old + w

      if(abs(s_new/w_new - s_old/w_old) < :math.pow(10, -10) && abs(s_old/w_old - s_old_2/w_old_2) < :math.pow(10, -10)) do
        GenServer.cast(sender, {:remove_neighbor, self()})
      else
        if(existing_rumour == "") do
          state = Map.put(state, "rumour", rumour)
          [{_, spread}] = :ets.lookup(:count, "spread")
          :ets.insert(:count, {"spread", spread + 1})
        end
        state = Map.put(state, "s", s_new)
        state = Map.put(state, "w", w_new)
        state = Map.put(state, "s_old_2", s_old)
        state = Map.put(state, "w_old_2", w_old)
        state = Map.put(state, "diff1", s_new/w_new - s_old/w_old)
        state = Map.put(state, "diff2", s_old/w_old - s_old_2/w_old_2)
      end
      {:noreply, state}
  end

  def handle_cast({:send_message}, state) do
      {:ok, rumour} = Map.fetch(state, "rumour")
      {:ok, neighbors} = Map.fetch(state, "neighbors")

      if (rumour != "" && length(neighbors) > 0) do
          _ = GenServer.cast(Enum.random(neighbors), {:receive_message, rumour, self()})
      end
      {:noreply, state}
  end

  def handle_cast({:send_message_push_sum}, state) do
      {:ok, s} = Map.fetch(state, "s")
      {:ok, w} = Map.fetch(state, "w")
      {:ok, rumour} = Map.fetch(state, "rumour")
      {:ok, neighbors} = Map.fetch(state, "neighbors")
      if (rumour != "" && length(neighbors) > 0) do
        s = s/2
        w = w/2
        state = Map.put(state, "s", s)
        state = Map.put(state, "w", w)
        GenServer.cast(Enum.random(neighbors), {:receive_message_push_sum, self(), s, w, rumour})
      end
      {:noreply, state}
  end

  def handle_cast({:remove_neighbor, neighbor}, state) do
      {:ok, neighbors} = Map.fetch(state, "neighbors")
      {:noreply, Map.put(state, "neighbors", List.delete(neighbors, neighbor))}
  end

  def handle_cast({:set_neighbors, neighbors}, state) do
      {:noreply, Map.put(state, "neighbors", neighbors)}
  end

  def handle_call({:get_count, count}, _from, state) do
      {:reply, Map.fetch(state, count), state}
  end

  def handle_call({:get_rumour, rumour}, _from, state) do
      {:reply, Map.fetch(state, rumour), state}
  end

  def handle_call({:get_neighbors}, _from, state) do
      {:reply, Map.fetch(state, "neighbors"), state}
  end

  def handle_call({:get_diff}, _from, state) do
      {:ok, diff1} = Map.fetch(state, "diff1")
      {:ok, diff2} = Map.fetch(state, "diff2")
      {:reply, [diff1] ++ [diff2], state}
  end
end

defmodule Client do
  use GenServer

  def start_link(x) do
      GenServer.start_link(Server, x)
  end

  def send_message(server) do
      GenServer.cast(server, {:send_message})
  end

  def send_message_push_sum(server) do
      GenServer.cast(server, {:send_message_push_sum})
  end

  def set_neighbors(server, neighbors) do
      GenServer.cast(server, {:set_neighbors, neighbors})
  end

  def get_count(server) do
      {:ok, count} = GenServer.call(server, {:get_count, "count"})
      count
  end

  def get_rumour(server) do
      {:ok, rumour} = GenServer.call(server, {:get_rumour, "rumour"})
      rumour
  end

  def has_neighbors(server) do
      {:ok, neighbors} = GenServer.call(server, {:get_neighbors})
      length(neighbors) > 0
  end

  def get_neighbors(server) do
      GenServer.call(server, {:get_neighbors})
  end

  def get_diff(server) do
      GenServer.call(server, {:get_diff})
  end
end

Project2.main(System.argv())
