defmodule AshPolicyAuthorizer.Check.Action do
  use AshPolicyAuthorizer.SimpleCheck

  @impl true
  def describe(options) do
    "action == #{inspect(options[:action])}"
  end

  @impl true
  def match?(_user, %{action: %{name: name}}, options) do
    name == options[:action]
  end
end
