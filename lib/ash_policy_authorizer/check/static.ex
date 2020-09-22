defmodule AshPolicyAuthorizer.Check.Static do
  @moduledoc false
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
