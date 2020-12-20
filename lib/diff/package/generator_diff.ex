defmodule Diff.Package.GeneratorDiff do
  require Logger

  def generate_app("phx_new", path) do
    mix_run!(["archive.uninstall", "--force", "phx_new"], path)
    mix_run!(["deps.get"], path)
    mix_run!(["archive.build", "-o", "phx_new.ez"], path)
    mix_run!(["archive.install", "--force", "phx_new.ez"], path)
    mix_run!(["phx.new", "my_app"], path)
    mix_run!(["archive.uninstall", "--force", "phx_new.ez"], path)
    File.rm_rf!(Path.join([path, "phx_new.ez"]))
    File.rm_rf!(Path.join([path, "_build"]))
    File.rm_rf!(Path.join([path, "deps"]))
    :ok
  end

  def generate_app("nerves_bootstrap", path) do
    mix_run!(["archive.uninstall", "--force", "nerves_bootstrap"], path)
    mix_run!(["deps.get"], path)
    mix_run!(["archive.build", "-o", "nerves_bootstrap.ez"], path)
    mix_run!(["archive.install", "--force", "nerves_bootstrap.ez"], path)
    mix_run!(["nerves.new", "my_app"], path)
    mix_run!(["archive.uninstall", "--force", "nerves_bootstrap.ez"], path)
    File.rm_rf!(Path.join([path, "nerves_bootstrap.ez"]))
    File.rm_rf!(Path.join([path, "_build"]))
    File.rm_rf!(Path.join([path, "deps"]))
    :ok
  end

  def generate_app(_, _), do: :ok

  def mix_run!(args, app_path, opts \\ [])
  when is_list(args) and is_binary(app_path) and is_list(opts) do
    Logger.info("Running #{inspect(args)} in #{app_path}")
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
end
