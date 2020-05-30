defmodule AshPolicyAccess.Check.ActorAttributeMatchesRecord do
  @moduledoc """
  Simple equality check between a field on the actor and a field
  on the record
  """

  use AshPolicyAccess.FilterCheck

  @impl true
  def describe(opts) do
    "user.#{opts[:user_field]} == this_record.#{opts[:record_field]}"
  end

  @impl true
  def filter(opts) do
    [{opts[:record_field], {:_actor, opts[:record_field]}}]
  end
end
