defmodule Mix.Tasks.CreateGeneratorDiffs do
  use Mix.Task
  @chunk_size 64 * 1024

  @shortdoc "Generate diffs between generator version outputs"
  def run(_) do
    {:ok, _} = Application.ensure_all_started(:hackney)
    {:ok, _} = Application.ensure_all_started(:hex_core)
    {:ok, _} = Diff.Package.Store.start_link([])
    Diff.Package.Updater.update()

    for package <- Diff.GeneratorOutput.packages() do
      IO.puts ""
      IO.puts "====== Generating for #{package} ======"
      {:ok, versions} = Diff.Package.DefaultStore.get_versions(package)
      version_combinations = versions |> combinations(2) |> Enum.map(& Enum.sort(&1, {:asc, Version}))

      for generator <- Diff.GeneratorOutput.generators(package) do
        IO.puts "=== #{generator}"

        for [from, to] <- version_combinations do
          flags = Diff.GeneratorOutput.flags(package, generator)

          for from_flags <- combinations(flags) do
            for to_flags <- combinations(flags) do
              IO.puts "--- #{from}#{inspect(from_flags)}..#{to}#{inspect(to_flags)}"
              id = Diff.GeneratorOutput.build_id(package, generator, from, to, from_flags, to_flags)

              case Diff.Storage.get(id, from, to) do
                {:ok, _stream} ->
                  :ok
                _ ->
                  {:ok, diff_stream} = Diff.GeneratorOutput.diff(package, generator, from, to, from_flags, to_flags)
                  diff_page = DiffWeb.PageController.render_diff(package, from, to, diff_stream) |> IO.inspect(label: "DIFF PAGE")
                  stream = File.stream!(diff_page, [:read_ahead], @chunk_size)
                  IO.inspect(id, label: "PUTTING")
                  Diff.Storage.put(id, from, to, stream)
              end
            end
          end
        end
      end
    end
  end

  def combinations(list) do
    (0..length(list))
    |> Enum.flat_map(&combinations(list, &1))
  end
  def combinations(list, num)
  def combinations(_list, 0), do: [[]]
  def combinations(list = [], _num), do: list
  def combinations([head | tail], num) do
    Enum.map(combinations(tail, num - 1), &[head | &1]) ++ combinations(tail, num)
  end
end
