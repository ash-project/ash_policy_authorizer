defmodule AshPolicyAuthorizer.Check.Expression do
  @moduledoc "The check module used for `expr`s in policies"
  use AshPolicyAuthorizer.FilterCheck

  @impl true
  def describe(opts) do
    inspect(opts[:expr])
  end

  @impl true
  def filter(opts) do
    opts[:expr]
  end
end
