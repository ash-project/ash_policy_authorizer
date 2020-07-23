defmodule AshPolicyAuthorizer.Check.Action do
  @moduledoc "This check is true when the action name matches the provided action"
  use AshPolicyAuthorizer.SimpleCheck

  @impl true
  def describe(options) do
    "action == #{inspect(options[:action])}"
  end

  @impl true
  def match?(_actor, %{action: %{name: name}}, options) do
    name == options[:action]
  end
end
