defmodule AshPolicyAuthorizer.Check.ActionType do
  @moduledoc "This check is true when the action type matches the provided type"
  use AshPolicyAuthorizer.SimpleCheck

  @impl true
  def describe(options) do
    "action.type == #{inspect(options[:type])}"
  end

  @impl true
  def match?(_user, %{action: %{type: type}}, options) do
    type == options[:type]
  end
end
