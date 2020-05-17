defmodule AshPolicyAccess.Check.Static do
  use AshPolicyAccess.Check, pure?: true

  @impl true
  def describe(options) do
    "always #{inspect(options[:result])}"
  end

  @impl true
  def strict_check(_user, _request, options) do
    {:ok, options[:result]}
  end
end
