defmodule AshPolicyAuthorizer.Checker do
  @moduledoc false

  alias AshPolicyAuthorizer.Policy
  alias AshPolicyAuthorizer.Policy.Check

  def strict_check_facts(%{policies: policies} = authorizer) do
    Enum.reduce(policies, authorizer.facts, &do_strict_check_facts(&1, authorizer, &2))
  end

  defp do_strict_check_facts(%Policy{} = policy, authorizer, facts) do
    facts =
      policy.condition
      |> List.wrap()
      |> Enum.reduce(facts, fn {check_module, opts}, facts ->
        do_strict_check_facts(
          %Check{check_module: check_module, check_opts: opts},
          authorizer,
          facts
        )
      end)

    Enum.reduce(policy.policies, facts, &do_strict_check_facts(&1, authorizer, &2))
  end

  defp do_strict_check_facts(%AshPolicyAuthorizer.Policy.Check{} = check, authorizer, facts) do
    check_module = check.check_module
    opts = check.check_opts

    case check_module.strict_check(authorizer.actor, authorizer, opts) do
      {:ok, boolean} when is_boolean(boolean) ->
        Map.put(facts, {check_module, opts}, boolean)

      {:ok, :unknown} ->
        facts

      other ->
        raise "Invalid return value from strict_check call #{check_module}.strict_check(actor, authorizer, #{
                inspect(opts)
              }) -  #{inspect(other)}"
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
    |> Enum.reduce_while(:reality, fn {fact, requirement}, status ->
      case Map.fetch(facts, fact) do
        {:ok, ^requirement} ->
          {:cont, status}

        {:ok, _} ->
          {:halt, :not_reality}

        :error ->
          {:cont, :maybe}
      end
    end)
  end

  def strict_check_scenarios(authorizer) do
    case AshPolicyAuthorizer.Policy.solve(authorizer) do
      {:ok, scenarios} ->
        {:ok, remove_scenarios_with_impossible_facts(scenarios, authorizer)}

      {:error, :unsatisfiable} ->
        {:error, :unsatisfiable}
    end
  end

  defp remove_scenarios_with_impossible_facts(scenarios, authorizer) do
    # Remove any scenarios with a fact that must be a certain value, but are not, at strict check time
    # They aren't true, so that scenario isn't possible

    Enum.reject(scenarios, fn scenario ->
      Enum.any?(scenario, fn {{mod, opts}, required_value} ->
        opts[:access_type] == :strict &&
          not match?(
            {:ok, ^required_value},
            Policy.fetch_fact(authorizer.facts, {mod, opts})
          )
      end)
    end)
  end
end
