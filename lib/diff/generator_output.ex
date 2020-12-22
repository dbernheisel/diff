defmodule Diff.GeneratorOutput do
  @known %{
    "phx_new" => [%{
      command: "phx.new",
      default_flags: ["my_app"],
      flags: [
        "--binary-id",
        "--database=mssql",
        "--database=mysql",
        "--database=postgres",
        "--live",
        "--no-dashboard",
        "--no-ecto",
        "--no-gettext",
        "--no-html",
        "--no-webpack",
        "--umbrella"
      ]
    }],
    "nerves_bootstrap" => [%{
      command: "nerves.new",
      default_flags: ["my_app"],
      flags: [],
    }],
    "scenic_new" => [%{
      command: "scenic.new",
      default_flags: ["my_app"],
      flags: [],
    }],
  }

  require Logger

  def packages, do: Map.keys(@known)

  def generators(package), do: Enum.map(@known[package], & &1[:command])

  def generator(package, %{command: command}), do: generator(package, command)
  def generator(package, command), do: Enum.find(@known[package], & &1[:command] == command)

  def flags(package, %{command: command}), do: flags(package, command)
  def flags(package, command), do: generator(package, command)[:flags]

  def default_flags(package, command), do: generator(package, command)[:default_flags]

  @generator_prefix "HexDiffGenerator"
  def build_id(package, id) do
    Enum.join([@generator_prefix, package, id], "|")
  end

  def build_id(package, generator, from, to, from_flags, to_flags) do
    id = Enum.join([generator, from, to, from_flags, to_flags])
    Enum.join([@generator_prefix, package, :crypto.hash(:md5, id) |> Base.encode16()], "|")
  end

  def diff(package, cmd, from, to, from_flags, to_flags) do
    path_from = tmp_path("package-#{package}-#{from}-")
    path_to = tmp_path("package-#{package}-#{to}-")
    path_diff = tmp_path("diff-#{package}-#{from}-#{to}-")

    try do
      with {:ok, tarball_from} <- Diff.Hex.get_tarball(package, from),
           :ok <- Diff.Hex.unpack_tarball(tarball_from, path_from),
           {:ok, generated_from} <- generate_app(package, cmd, path_from, from_flags),
           {:ok, tarball_to} <- Diff.Hex.get_tarball(package, to),
           :ok <- Diff.Hex.unpack_tarball(tarball_to, path_to),
           {:ok, generated_to} <- generate_app(package, cmd, path_to, to_flags),
           :ok <- Diff.Hex.git_diff(generated_from, generated_to, path_diff) do
        stream =
          File.stream!(path_diff, [:read_ahead])
          |> GitDiff.stream_patch(relative_from: path_from, relative_to: path_to)
          |> Stream.transform(
            fn -> :ok end,
            fn elem, :ok -> {[elem], :ok} end,
            fn :ok -> File.rm(path_diff) end
          )

        {:ok, stream}
      else
        error ->
          Logger.error("Failed to create diff #{package} #{from}..#{to} with: #{inspect(error)}")
          :error
      end
    after
      File.rm_rf(path_from)
      File.rm_rf(path_to)
    end
  end

  def generate_app("phx_new", command, path, flags) do
    mix_run!(["archive.uninstall", "--force", "phx_new"], path)
    mix_run!(["deps.get"], path)
    mix_run!(["archive.build", "-o", "phx_new.ez"], path)
    mix_run!(["archive.install", "--force", "phx_new.ez"], path)
    mix_run!([command] ++ default_flags("phx_new", command) ++ flags, path)
    mix_run!(["archive.uninstall", "--force", "phx_new.ez"], path)
    File.rm_rf!(Path.join([path, "phx_new.ez"]))
    File.rm_rf!(Path.join([path, "_build"]))
    File.rm_rf!(Path.join([path, "deps"]))
    {:ok, Path.join([path, "my_app"])}
  rescue
    _ -> :invalid
  end

  def generate_app("nerves_bootstrap", command, path, flags) do
    mix_run!(["archive.uninstall", "--force", "nerves_bootstrap"], path)
    mix_run!(["deps.get"], path)
    mix_run!(["archive.build", "-o", "nerves_bootstrap.ez"], path)
    mix_run!(["archive.install", "--force", "nerves_bootstrap.ez"], path)
    mix_run!([command] ++ default_flags("nerves_bootstrap", command) ++ flags, path)
    mix_run!(["archive.uninstall", "--force", "nerves_bootstrap.ez"], path)
    File.rm_rf!(Path.join([path, "nerves_bootstrap.ez"]))
    File.rm_rf!(Path.join([path, "_build"]))
    File.rm_rf!(Path.join([path, "deps"]))
    {:ok, Path.join([path, "my_app"])}
  rescue
    _ -> :invalid
  end

  def generate_app("scenic_new", command, path, flags) do
    mix_run!(["archive.uninstall", "--force", "scenic_new"], path)
    mix_run!(["deps.get"], path)
    mix_run!(["archive.build", "-o", "scenic_new.ez"], path)
    mix_run!(["archive.install", "--force", "scenic_new.ez"], path)
    mix_run!([command] ++ default_flags("scenic_new", command) ++ flags, path)
    mix_run!(["archive.uninstall", "--force", "scenic_new.ez"], path)
    File.rm_rf!(Path.join([path, "scenic_new.ez"]))
    File.rm_rf!(Path.join([path, "_build"]))
    File.rm_rf!(Path.join([path, "deps"]))
    {:ok, Path.join([path, "my_app"])}
  rescue
    _ -> :invalid
  end

  def generate_app(_, _), do: "Not a recognized generator"

  def mix_run!(args, app_path, opts \\ [])
  when is_list(args) and is_binary(app_path) and is_list(opts) do
    Logger.debug("Running #{inspect(args)} in #{app_path}")
    case mix_run(args, app_path, opts) do
      {output, 0} ->
        output

      {output, exit_code} ->
        raise """
        mix command failed with exit code: #{inspect(exit_code)}

        mix #{Enum.join(args, " ")}

        #{output}

        Options
        cd: #{Path.expand(app_path)}
        env: #{opts |> Keyword.get(:env, []) |> inspect()}
        """
    end
  end

  def mix_run(args, app_path, opts \\ [])
      when is_list(args) and is_binary(app_path) and is_list(opts) do
    System.cmd(Path.join([File.cwd!(), "bin", "mixn.sh"]), args, [stderr_to_stdout: true, cd: Path.expand(app_path)] ++ opts)
  end

  defp tmp_path(prefix) do
    random_string = Base.encode16(:crypto.strong_rand_bytes(4))
    Path.join([System.tmp_dir!(), "diff", prefix <> random_string])
  end
end
