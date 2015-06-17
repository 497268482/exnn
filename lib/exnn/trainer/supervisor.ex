defmodule EXNN.Trainer.Supervisor do
  use Supervisor
  use EXNN.Utils.Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    IO.puts "starting trainer supervisor"
    []
    |> child(EXNN.Fitness.Starter, [])
    |> child(EXNN.Trainer.Mutations, [])
    |> child(EXNN.Trainer.Sync, [])
    |> supervise(strategy: :one_for_all)
  end
end