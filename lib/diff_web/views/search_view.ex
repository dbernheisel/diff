defmodule DiffWeb.SearchView do
  use DiffWeb, :view

  def disabled(things) when is_list(things) do
    if Enum.any?(things, &(!&1)) do
      "disabled"
    else
      ""
    end
  end

  def disabled(thing), do: disabled([thing])

  def selected(x, x), do: "selected=selected"
  def selected(_, _), do: ""

  def checked(x, list) do
    if x in list do
      "checked=checked"
    else
      ""
    end
  end

  def hidden(nil), do: "class=hidden"
  def hidden([]), do: "class=hidden"
  def hidden(_), do: ""

  def generator_package_options() do
    Diff.GeneratorOutput.packages()
  end

  def generator_options(nil), do: []
  def generator_options(package_name) do
    Diff.GeneratorOutput.generators(package_name)
  end

  def flag_options(nil, _generator), do: []
  def flag_options(_package, nil), do: []
  def flag_options(package_name, generator) do
    Diff.GeneratorOutput.flags(package_name, generator)
  end
end
