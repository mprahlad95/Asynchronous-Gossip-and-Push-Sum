# https://medium.com/elixirlabs/registry-in-elixir-1-4-0-d6750fb5aeb

defmodule Proj2 do
  use Application
  require Logger

  def main do
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
end

Proj2.main
