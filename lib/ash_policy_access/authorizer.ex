defmodule AshPolicyAccess.Authorizer do
  defstruct [
    :actor,
    :action,
    :resource,
    :query,
    :changeset,
    :verbose?,
    :scenarios,
    policies: [],
    facts: %{true => true, false => false}
  ]

  alias AshPolicyAccess.Checker

  @behaviour Ash.Engine.Authorizer

  @impl true
  def initial_state(actor, resource, action, verbose?) do
    %__MODULE__{
      resource: resource,
      actor: actor,
      action: action,
      verbose?: verbose?
    }
  end

  @impl true
  def strict_check_context(_authorizer) do
    # TODO: Figure out what fields we actually need,
    # probably something on the check module
    [:query, :changeset]
  end

  @impl true
  def check_context(_authorizer) do
    [:query, :changeset, :data]
  end

  @impl true
  def check(_authorizer, _context) do
    :authorized
  end

  @impl true
  def strict_check(authorizer, context) do
    %{authorizer | query: context.query, changeset: context.changeset}
    |> get_policies()
    |> do_strict_check_facts()
    |> strict_check_result()
  end

  defp strict_check_result(authorizer) do
    case Checker.strict_check_scenarios(authorizer) do
      {:ok, scenarios} ->
        case Checker.find_real_scenario(scenarios, authorizer.facts) do
          nil ->
            {:continue, %{authorizer | scenarios: scenarios}}

          _ ->
            :authorized
        end

      {:error, :unsatisfiable} ->
        {:error,
         AshPolicyAccess.Forbidden.exception(
           verbose?: authorizer.verbose?,
           facts: authorizer.facts,
           scenarios: []
         )}
    end
  end

  defp do_strict_check_facts(authorizer) do
    new_facts = Checker.strict_check_facts(authorizer)

    %{authorizer | facts: new_facts}
  end

  defp get_policies(authorizer) do
    policies =
      authorizer.resource
      |> AshPolicyAccess.policies()
      |> Enum.filter(&policies_apply?(&1, authorizer))

    %{authorizer | policies: policies}
  end

  defp policies_apply?(%{wheres: []}, _), do: true

  defp policies_apply?(policy, context) do
    Enum.all?(policy.wheres, &where_clause_match?(&1, context))
  end

  defp where_clause_match?(where_clause, context) do
    Enum.all?(where_clause, fn {key, value} ->
      condition_met?(key, value, context)
    end)
  end

  defp condition_met?(:action, action_name, %{action: %{name: action_name}}), do: true
  defp condition_met?(:action_type, action_type, %{action: %{type: action_type}}), do: true
  defp condition_met?(_, _, _), do: false
end
