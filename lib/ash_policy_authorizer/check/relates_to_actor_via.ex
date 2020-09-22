defmodule AshPolicyAuthorizer.Check.RelatesToActorVia do
  @moduledoc false
  use AshPolicyAuthorizer.FilterCheck

  @impl true
  def describe(opts) do
    path = Enum.join(opts[:relationship_path], ".")
    "record.#{path} == actor"
  end

  @impl true
  def filter(opts) do
    put_in_path(opts[:relationship_path], {:_actor, :_primary_key})
  end

  defp put_in_path([], value) do
    value
  end

  defp put_in_path([key | rest], value) do
    [{key, put_in_path(rest, value)}]
  end
end
