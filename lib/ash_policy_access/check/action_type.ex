defmodule AshPolicyAccess.Check.ActionType do
  use AshPolicyAccess.SimpleCheck

  @impl true
  def describe(options) do
    "action.type == #{inspect(options[:type])}"
  end

  @impl true
  def match?(_user, %{action: %{type: type}}, options) do
    type == options[:type]
  end
end
