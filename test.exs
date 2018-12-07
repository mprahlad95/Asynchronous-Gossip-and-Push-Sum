defmodule Proj2 do

  def main do
    # Take input arguments

    [num_nodes, topology, algorithm] = System.argv()
    num_nodes = String.to_integer(num_nodes)
    Proj2.Supervisor.main(num_nodes, topology, algorithm)

  end

  # def listen do
  #   receive do
  #     {:exit}  -> nil
  #   end
  # end

end

defmodule Proj2.Supervisor do
  @moduledoc """
  Documentation for GS.
  """
  use Supervisor

  def main(num_nodes, topology, _) do
    initialize(num_nodes, topology)

    listen_to_children(num_nodes)
  end


