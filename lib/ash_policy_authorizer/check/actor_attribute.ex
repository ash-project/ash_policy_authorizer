defmodule AshPolicyAuthorizer.Check.ActorAttribute do
  @moduledoc "This check is true when a field on the actor equals a specific value"
  use AshPolicyAuthorizer.SimpleCheck

  @impl true
  def describe(opts) do
    "actor.#{opts[:field]} == #{inspect(opts[:value])}"
  end

  @impl true
  def match?(actor, _context, opts) do
    value = opts[:value]
    match?({:ok, ^value}, Map.fetch(actor, opts[:field]))
  end
end
