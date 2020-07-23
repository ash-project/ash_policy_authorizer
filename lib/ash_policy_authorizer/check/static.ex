defmodule AshPolicyAuthorizer.Check.Static do
  @moduledoc "This check is true when the provided result is true, and false otherwise"
  use AshPolicyAuthorizer.SimpleCheck

  @impl true
  def describe(options) do
    "always #{inspect(options[:result])}"
  end

  @impl true
  def match?(_actor, _request, options) do
    options[:result]
  end
end
