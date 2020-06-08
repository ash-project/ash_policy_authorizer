defmodule AshPolicyAuthorizer.Check.Static do
  use AshPolicyAuthorizer.SimpleCheck

  @impl true
  def describe(options) do
    "always #{inspect(options[:result])}"
  end

  @impl true
  def match?(_user, _request, options) do
    options[:result]
  end
end
