defmodule DiffWeb.GeneratorLiveView do
  use DiffWeb, :live_view

  def render(assigns) do
    DiffWeb.SearchView.render("generator.html", assigns)
  end

  def mount(_params, _session, socket) do
    {:ok, reset_state(socket)}
  end

  def handle_event("select_package", %{"package" => package}, socket) do
    case Diff.Package.Store.get_versions(package) do
      {:ok, versions} ->
        from_releases = Enum.slice(versions, 0..(length(versions) - 2))
        to_releases = Enum.slice(versions, 0..-1)
        from = List.first(from_releases)
        to = List.last(to_releases)

        {:noreply,
         assign(socket,
           package: package,
           generators: Diff.GeneratorOutput.generators(package),
           generator: nil,
           releases: versions,
           from_releases: from_releases,
           to_releases: to_releases,
           to: to,
           from: from,
           not_found: nil
         )}

      {:error, :not_found} ->
        {:noreply,
         assign(socket,
           not_found: "Package #{package} not found.",
           to: nil,
           from: nil,
           releases: []
         )}
    end
  end

  def handle_event(
        "select_version",
        %{"_target" => ["from"], "from" => from},
        %{assigns: %{releases: releases}} = socket
      ) do
    index_of_selected_from = Enum.find_index(releases, &(&1 == from))
    to_releases = Enum.slice(releases, index_of_selected_from..-1)

    {:noreply, assign(socket, from: from, to_releases: to_releases)}
  end

  def handle_event(
        "select_version",
        %{"_target" => ["to"], "to" => to},
        socket
      ) do
    {:noreply, assign(socket, to: to)}
  end

  def handle_event("select_generator", %{"generator" => generator}, socket) do
    flags = Diff.GeneratorOutput.flags(socket.assigns.package, generator)
    {:noreply, assign(socket, generator: generator, from_flags: [], to_flags: [], flags: flags)}
  end

  def handle_event("select_flags", params, socket) do
    to_flags = params |> Map.get("to_flags") |> to_flags()
    from_flags = params |> Map.get("from_flags") |> to_flags()
    {:noreply, assign(socket, from_flags: from_flags, to_flags: to_flags)}
  end

  def handle_event("go", _params, socket) do
    %{from: from, to: to, package: package} = socket.assigns
    id = Diff.GeneratorOutput.build_id(package, socket.assigns.generator, from, to, socket.assigns.from_flags, socket.assigns.to_flags) |> String.split("|") |> List.last()
    {:noreply, redirect(socket, to: "/generator/#{package}/#{from}..#{to}/#{id}")}
  end

  defp to_flags(nil), do: []
  defp to_flags(flags_map) do
    Enum.reduce(flags_map, [], fn
      {v, "true"}, acc -> [v | acc]
      _, acc -> acc
    end)
  end

  defp reset_state(socket) do
    assign(socket,
      package: nil,
      generator: nil,
      flags: [],
      from_flags: [],
      to_flags: [],
      releases: [],
      from: nil,
      to: nil,
      from_releases: [],
      to_releases: []
    )
  end
end
