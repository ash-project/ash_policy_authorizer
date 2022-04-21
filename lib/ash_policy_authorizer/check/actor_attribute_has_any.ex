defmodule AshPolicyAuthorizer.Check.ActorAttributeHasAny do
  @moduledoc false
  use AshPolicyAuthorizer.SimpleCheck

  @impl true
  def describe(opts) do
    "actor.#{opts[:attribute]} has any of #{inspect(opts[:values])}"
  end

  @impl true
  def match?(nil, _, _), do: false

  def match?(actor, _context, opts) do
    List.wrap(Map.get(actor, opts[:attribute], []))
    |> Enum.any?(fn value -> Enum.any?(opts[:values], &(&1 == value)) end)
  end
end
