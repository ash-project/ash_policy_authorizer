defmodule AshPolicyAccess.Checker do
  @moduledoc """
  Determines if a set of authorization requests can be met or not.

  To read more about boolean satisfiability, see this page:
  https://en.wikipedia.org/wiki/Boolean_satisfiability_problem. At the end of
  the day, however, it is not necessary to understand exactly how Ash takes your
  authorization requirements and determines if a request is allowed. The
  important thing to understand is that Ash may or may not run any/all of your
  authorization rules as they may be deemed unnecessary. As such, authorization
  checks should have no side effects. Ideally, the checks built-in to ash should
  cover the bulk of your needs.

  If you need to write your own checks see #TODO: Link to a guide about writing checks here.
  """

  alias AshPolicyAccess.Policy
  alias AshPolicyAccess.Policy.Check

  def strict_check_facts(%{policies: policies} = authorizer) do
    Enum.reduce(policies, authorizer.facts, &do_strict_check_facts(&1, authorizer, &2))
  end

  defp do_strict_check_facts(%Policy{} = policy, authorizer, facts) do
    facts =
      case policy.condition do
        nil ->
          facts

        {check_module, opts} ->
          do_strict_check_facts(
            %Check{check_module: check_module, check_opts: opts},
            authorizer,
            facts
          )
      end

    Enum.reduce(policy.policies, facts, &do_strict_check_facts(&1, authorizer, &2))
  end

  defp do_strict_check_facts(%AshPolicyAccess.Policy.Check{} = check, authorizer, facts) do
    check_module = check.check_module
    opts = check.check_opts

    case check_module.strict_check(authorizer.actor, authorizer, opts) do
      {:ok, boolean} when is_boolean(boolean) ->
        Map.put(facts, {check_module, opts}, boolean)

      _other ->
        facts
    end
  end

  def find_real_scenarios(scenarios, facts) do
    Enum.filter(scenarios, fn scenario ->
      scenario_is_reality(scenario, facts) == :reality
    end)
  end

  defp scenario_is_reality(scenario, facts) do
    scenario
    |> Map.drop([true, false])
    |> Enum.reduce_while(:reality, fn {{check_module, opts} = fact, requirement}, status ->
      if Keyword.has_key?(opts, :__auto_filter__) and
           AshPolicyAccess.Check.defines_check?(check_module) do
        {:cont, status}
      else
        case Map.fetch(facts, fact) do
          {:ok, value} ->
            cond do
              value == requirement ->
                {:cont, status}

              true ->
                {:halt, :not_reality}
            end

          :error ->
            {:cont, :maybe}
        end
      end
    end)
  end

  def strict_check_scenarios(authorizer) do
    case AshPolicyAccess.Policy.solve(authorizer) do
      {:ok, scenarios} ->
        {:ok, scenarios}

      {:error, :unsatisfiable} ->
        {:error, :unsatisfiable}
    end
  end

  # def run_checks(engine, %{data: []}, _clause) do
  #   {:ok, engine}
  # end

  # def run_checks(engine, request, clause) do
  #   case clause.check_module().check(engine.user, request.data, %{}, clause.check_opts) do
  #     {:error, error} ->
  #       {:error, error}

  #     {:ok, check_result} ->
  #       pkey = Ash.primary_key(request.resource)

  #       {authorized, unauthorized} =
  #         Enum.split_with(request.data, fn data ->
  #           data_pkey = Map.take(data, pkey)

  #           Enum.find(check_result, fn authorized ->
  #             Map.take(authorized, pkey) == data_pkey
  #           end)
  #         end)

  #       case {authorized, unauthorized} do
  #         {_, []} ->
  #           {:ok, %{engine | facts: Map.put(engine.facts, clause, true)}}

  #         {[], _} ->
  #           {:ok, %{engine | facts: Map.put(engine.facts, clause, false)}}

  #         {authorized, unauthorized} ->
  #           # TODO: Handle this error
  #           {:ok, authorized_values} =
  #             Ash.Actions.PrimaryKeyHelpers.values_to_primary_key_filters(
  #               request.resource,
  #               authorized
  #             )

  #           authorized_filter =
  #             Ash.Filter.parse(request.resource, [or: authorized_values], engine.api)

  #           {:ok, unauthorized_values} =
  #             Ash.Actions.PrimaryKeyHelpers.values_to_primary_key_filters(
  #               request.resource,
  #               unauthorized
  #             )

  #           unauthorized_filter =
  #             Ash.Filter.parse(request.resource, [or: unauthorized_values], engine.api)

  #           authorized_clause = %{clause | filter: authorized_filter}
  #           unauthorized_clause = %{clause | filter: unauthorized_filter}

  #           new_facts =
  #             engine.facts
  #             |> Map.delete(clause)
  #             |> Map.put(authorized_clause, true)
  #             |> Map.put(unauthorized_clause, false)

  #           {:ok, %{engine | facts: new_facts}}
  #       end
  #   end
  # end
end
