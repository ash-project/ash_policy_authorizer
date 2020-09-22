defmodule AshPolicyAuthorizer.Check.ActionType do
  @moduledoc false
  use AshPolicyAuthorizer.SimpleCheck

  @impl true
  def describe(options) do
    "action.type == #{inspect(options[:type])}"
  end

  @impl true
  def match?(_actor, %{action: %{type: type}}, options) do
    type == options[:type]
  end
end
