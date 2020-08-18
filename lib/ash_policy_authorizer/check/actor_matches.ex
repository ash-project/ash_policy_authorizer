defmodule AshPolicyAuthorizer.Check.ActorMatches do
  @moduledoc "This check is true when the provided function over the actor returns true"
  use AshPolicyAuthorizer.SimpleCheck

  @impl true
  def describe(opts) do
    "actor " <> opts[:description]
  end

  @impl true
  def match?(actor, _context, opts) do
    opts[:matcher].(actor)
  end
end
