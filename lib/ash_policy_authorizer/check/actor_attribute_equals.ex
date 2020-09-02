defmodule AshPolicyAuthorizer.Check.ActorAttributeEquals do
  @moduledoc "This check is true when the value of the specified attribute equals the specified value"
  use AshPolicyAuthorizer.SimpleCheck

  @impl true
  def describe(opts) do
    "actor.#{opts[:attribute]} == #{inspect(opts[:value])}"
  end

  @impl true
  def match?(nil, _, _), do: false

  def match?(actor, _context, opts) do
    Map.fetch(actor, opts[:attribute]) == {:ok, opts[:value]}
  end
end
