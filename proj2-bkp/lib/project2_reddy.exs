defmodule Project2 do
  def main(args) do
    args |> parse_args
  end

  def parse_args(args) when length(args) != 3 do
    IO.puts "error : incorrect number of arguments passed!!"
  end

  def parse_args(args) when length(args) == 3 do
    [n, topology, algorithm] = args
    {n, _} = Integer.parse(n);
    IO.puts "Inputs : #{n} #{topology} #{algorithm}"

    nodes = Topology.build(topology, n, algorithm) # a list that contains pids of all processes started
    :global.register_name("head", self())

    start_time = System.monotonic_time()

    case algorithm do
      "gossip" -> Gossip.gossip(nodes, "gaby is getting married!", 1, start_time)
      "push-sum" -> Pushsum.start(nodes, start_time)
    end
  end

end


defmodule Gossip do
  def gossipNode(counter, neighbors) do
      receive do
          {:initialize_neighbors, neighborlist} ->
              neighbors = neighbors ++ neighborlist
              gossipNode(counter, neighbors)

          {:gossip_propagate, rumor} ->
              Process.sleep(5)

              if counter >= 10 do
                  gossipNode(counter, neighbors)
              else
                  nid = Util.pickRandom(neighbors)
                  send(nid, {:gossip_propagate, rumor})

                  send(self(), {:gossip_start, rumor})
                  gossipNode(counter, neighbors)
              end

          {:gossip_start, rumor} ->
              if counter == 0 do
                  head = :global.whereis_name("head")
                  if head != :undefined do send(head, {:informed}) else Process.exit(self(), :kill) end
              end

              send(self(), {:gossip_propagate, rumor})
              gossipNode(counter+1, neighbors)
      end
  end

  def gossip(nodes, rumor, informed, start) do
      startnode = Util.pickRandom(nodes)
      send(startnode, {:gossip_start, rumor})

      listen(nodes, informed, start)
  end

  def listen(nodes, informed, start) do
      receive do
          {:informed} ->
              informed = informed + 1
              n = length(nodes)
              a = (informed*100)/n |> :math.ceil |> round
              #IO.puts "#{informed}/#{n} nodes have heard the rumor"

              if a < 90 do
                  listen(nodes, informed, start)
              else
                  Enum.each(nodes, fn x ->
                      Process.exit(x, :kill)
                  end)

                  end_time = System.monotonic_time()
                  IO.puts "System converged in #{(end_time - start)} ms"
              end
      end
  end
end

defmodule Pushsum do
  @accuracy 0.000000001

  def start(nodes, _start_time) do
      #initialization
      Enum.each(0..length(nodes)-1, fn x ->
          send(Enum.at(nodes, x), {:start, x+1, 1})
      end)

      listen(length(nodes), 0, System.monotonic_time())
  end

  def listen(n, converged, start_time) do
      receive do
          {:converged, ratio} ->
              converged = converged + 1

              if converged >= 0.9*(n-1) do
                  #end_time = :erlang.system_time / 1.0e6 |> round
                    end_time = System.monotonic_time()
                  IO.puts "System converged with ratio #{ratio} in #{(end_time - start_time)}"

                  System.halt(0)
              else
                  #IO.puts "#{converged}/#{n} nodes converged, latest ratio: #{ratio}"
                  listen(n, converged, start_time)
              end
      end
  end

  def pushsumNode(s, w, delta1, delta2, isConverged, neighbors\\[]) do
      receive do
          {:initialize_neighbors, neighborlist} ->
              neighbors = neighbors ++ neighborlist
              pushsumNode(0, 0, -1, -1, isConverged, neighbors)

          {:receive, s_i, w_i} ->
              s = s + s_i
              w = w + w_i
              pushsumNode(s, w, delta1, delta2, isConverged, neighbors)

          {:start, s_0, w_0} ->
              send(self(), {:receive, s_0, w_0})
              pushsumNode(0, 0, -1, -1, isConverged, neighbors)
      after
          0_010 ->
              #present values of s and w, calculate delta1 and delta2 here and send converged messages

              w = if w == 0 do 0.1 else w end
              ratio = s/w
              #IO.puts "#{delta1} , #{delta2}, #{ratio}"
              if !isConverged do
                  {delta1, delta2} = updateDeltas(delta1, delta2, ratio)

                  isConverged = if delta1 == 2 and delta2 == 2 do true else false end

                  nid = Util.pickRandom(neighbors)
                  send(nid, {:receive, s/2, w/2})
                  send(self(), {:receive, s/2, w/2})
                  pushsumNode(0, 0, delta1, delta2, isConverged, neighbors)
              else
                  head = :global.whereis_name("head")
                  send(head, {:converged, ratio})

                  receive do
                      {_} -> "waiting forever to be killed"
                  end
              end
      end
  end

  def updateDeltas(delta1, delta2, ratio) do

      if delta1 == -1 do
          {ratio, -1}
      else
          if delta2 == -1 do
              diff = delta1 - ratio |> abs

              if diff > 0 and diff < @accuracy do
                  {delta1, ratio}
              else
                  {ratio, -1}
              end
          else
              diff = delta2 - ratio |> abs

              if diff > 0 and diff < @accuracy do
                  #IO.puts "#{delta1} , #{delta2}, #{ratio}"
                  {2, 2}
              else
                  {ratio, -1}
              end
          end
      end

  end

end

defmodule Topology do
  def build(topology, n, algorithm) do
      nodes = generateActors(n, algorithm)

      case topology do
          "full" ->
              Enum.each(nodes, fn x ->
                  neighborlist = nodes -- [x]
                  send(x, {:initialize_neighbors, neighborlist})
              end)
          "2D" ->
              form2Dgrid("perfect", nodes)
          "line" ->
              neighborlist = []

              Enum.each(0..n-1, fn x ->
                  neighborlist = neighborlist ++ if x-1 >= 0 do [Enum.at(nodes, x-1)] else [Enum.at(nodes, x-1+length(nodes))] end
                  neighborlist = neighborlist ++ if x+1 < n do [Enum.at(nodes, x+1)] else [Enum.at(nodes, x+1-length(nodes))] end

                  send(Enum.at(nodes, x), {:initialize_neighbors, neighborlist})
              end)
          "imp2D" ->
              form2Dgrid("imperfect", nodes)
      end

      nodes
  end

  def generateActors(n, algorithm) do
      Enum.map(1..n, fn _ ->
          case algorithm do
              "gossip" ->
                  spawn(fn -> Gossip.gossipNode(0, []) end)
              "push-sum" ->
                  spawn(fn -> Pushsum.pushsumNode(0, 0, -1, -1, false, []) end)
          end
      end)
  end

  def form2Dgrid(type, nodes) do
      n = length(nodes)
      dim = round(:math.ceil(:math.sqrt(n)))
      grid = Enum.chunk_every(nodes, dim)
      neighborlist = []

      Enum.each(0..dim*dim, fn x ->
          if x < n do
              i = round(:math.floor(x/dim)); j = rem(x, dim);

              left = if j-1 < 0 do j-1 + length(Enum.at(grid, i)) else j-1 end
              right = if j+1 >= length(Enum.at(grid, i)) do j+1 - length(Enum.at(grid, i)) else j+1 end
              top = if i-1 < 0 do i - 1 + length(grid) else i-1 end
              bottom = if i+1 >= length(grid) do i+1-length(grid)  else i+1 end

              neighborlist = _2DHelper([top, bottom, left, right], i, j, grid)
              neighborlist = neighborlist ++ if type == "imperfect" do [Util.pickRandom(nodes -- ([Enum.at(Enum.at(grid, i), j)] ++ neighborlist) )] else [] end

              send(Enum.at(Enum.at(grid, i), j), {:initialize_neighbors, neighborlist})
          end
      end)
  end

  def _2DHelper([top, bottom, left, right], i, j, grid) do
      top    = Enum.at(Enum.at(grid, top), j)
      bottom = Enum.at(Enum.at(grid, bottom), j)
      left   = Enum.at(Enum.at(grid, i), left)
      right  = Enum.at(Enum.at(grid, i), right)

      #filtering out nil nodes
      Enum.reduce([top, bottom, left, right], [], fn(x, l) ->
          if x == nil do l else [x | l] end
      end)
  end
end

defmodule Util do
  # Utility functions

  # picks a random node from a given list
  def pickRandom(nodesList) do
    :random.seed(:erlang.system_time())
    Enum.random(nodesList)
  end

end

Project2.main(System.argv())
