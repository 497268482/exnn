defmodule EXNNTest do
  use ExUnit.Case

  @moduledoc """
    Integrative Testing of a remote applicaion
  """
  setup_all do
    {:ok, pid} = HostApp.start(:normal, [])
    on_exit fn ->
      IO.puts "terminating app"
      HostApp.stop(:normal)
      # Process.exit(pid, :kill)
    end
    :ok
  end

  test "storing remote nodes and pattern in the store agent" do
    assert EXNN.Config.get_remote_nodes == [
      {:actuator, :a_1, HostApp.Recorder, []},
      {:sensor, :s_2, HostApp.SensTwo, [dim: 1]},
      {:sensor, :s_1, HostApp.SensOne, [dim: 1]}
    ]

    assert EXNN.Config.get_pattern == [sensor: [:s_1, :s_2], neuron: {3, 2}, actuator: [:a_1]]
  end

  test "storing genomes" do
    origin = self
    genomes = Agent.get EXNN.Connectome, &(&1)

    assert HashDict.to_list(genomes) == [neuron_l1_3: %{id: :neuron_l1_3,
              ins: [s_1: 0.14210821770124227, s_2: 0.20944855618709624],
              outs: [:neuron_l2_1, :neuron_l2_2], type: :neuron},
            s_2: %{id: :s_2, outs: [:neuron_l1_1, :neuron_l1_2, :neuron_l1_3],
              type: :sensor},
            neuron_l1_2: %{id: :neuron_l1_2,
              ins: [s_1: 0.47712105608919275, s_2: 0.5965100813402789],
              outs: [:neuron_l2_1, :neuron_l2_2], type: :neuron},
            neuron_l2_2: %{id: :neuron_l2_2,
              ins: [neuron_l1_1: 0.5014907142064751, neuron_l1_2: 0.311326754804393,
               neuron_l1_3: 0.597447524783298], outs: [:a_1], type: :neuron},
            s_1: %{id: :s_1, outs: [:neuron_l1_1, :neuron_l1_2, :neuron_l1_3],
              type: :sensor},
            neuron_l1_1: %{id: :neuron_l1_1,
              ins: [s_1: 0.915656206971831, s_2: 0.6669572934854013],
              outs: [:neuron_l2_1, :neuron_l2_2], type: :neuron},
            neuron_l2_1: %{id: :neuron_l2_1,
              ins: [neuron_l1_1: 0.4435846174457203, neuron_l1_2: 0.7230402056221108,
               neuron_l1_3: 0.94581636451987], outs: [:a_1], type: :neuron},
            a_1: %{id: :a_1, ins: [:neuron_l2_1, :neuron_l2_2], type: :actuator}]
    # [
    #   neuron_l1_3: %{id: :neuron_l1_3, ins: [s_1: 0.14210821770124227, s_2: 0.20944855618709624], outs: [:neuron_l2_1, :neuron_l2_2], type: :neuron},
    #   s_2: %{id: :s_2, type: :sensor},
    #   neuron_l1_2: %{id: :neuron_l1_2, ins: [s_1: 0.47712105608919275, s_2: 0.5965100813402789], outs: [:neuron_l2_1, :neuron_l2_2],
    #  type: :neuron},
    #   neuron_l2_2: %{id: :neuron_l2_2, ins: [neuron_l1_1: 0.5014907142064751, neuron_l1_2: 0.311326754804393, neuron_l1_3: 0.597447524783298], outs: [:a_1], type: :neuron},
    #   s_1: %{id: :s_1, type: :sensor},
    #  neuron_l1_1: %{id: :neuron_l1_1, ins: [s_1: 0.915656206971831, s_2: 0.6669572934854013], outs: [:neuron_l2_1, :neuron_l2_2], type: :neuron},
    #   neuron_l2_1: %{id: :neuron_l2_1, ins: [neuron_l1_1: 0.4435846174457203,
    #  neuron_l1_2: 0.7230402056221108, neuron_l1_3: 0.94581636451987], outs: [:a_1], type: :neuron},
    #   a_1: %{id: :a_1, ins: [:neuron_l2_1, :neuron_l2_2], type: :actuator}]
  end

  test "It should store all nodes as server" do
    assert EXNN.Nodes.names == [:neuron_l1_3,
                                :s_2,
                                :neuron_l1_2,
                                :neuron_l2_2,
                                :s_1,
                                :neuron_l1_1,
                                :neuron_l2_1,
                                :a_1]
  end

  test "It should launch a first Training task" do
    report = EXNN.Trainer.iterate(5)
    :timer.sleep 500
    recorded = GenServer.call(:a_1, :store)
    IO.puts "==== #{inspect(recorded)} =========="
    assert report == :ok
    refute Enum.empty?(recorded)
  end
end

defmodule HostApp do
  use EXNN.Application

  set_initial_pattern [
    sensor: [:s_1, :s_2],
    neuron: {3, 2},
    actuator: [:a_1]
  ]

  set_sensor :s_1, HostApp.SensOne, dim: 1
  set_sensor :s_2, HostApp.SensTwo, dim: 1
  set_actuator :a_1, HostApp.Recorder

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      # Define workers and child supervisors to be supervised
      # worker(HostApp.Worker, [arg1, arg2, arg3])
      supervisor(EXNN.Supervisor, [[config: __MODULE__]])
    ]

    opts = [strategy: :one_for_one, name: HostApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end


defmodule HostApp.Recorder do
  use EXNN.Actuator, with_state: [store: []]

  def act(state, {from, signal}) do
    store = [{from, signal} | state.store]
    %__MODULE__{state | store: store}
  end

  def handle_call(:store, _from, state) do
    {:reply, state.store, state}
  end
end

defmodule HostApp.SensOne do
  use EXNN.Sensor

  def sense(_sensor, {_origin, _value}) do
    # { 0.1 }
    0.1
  end
end

defmodule HostApp.SensTwo do
  use EXNN.Sensor

  def sense(_sensor, {_origin, _value}) do
    # { 0.9 }
    0.9
  end
end