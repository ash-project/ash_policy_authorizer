defmodule AshPolicyAccess.Policy do
  defstruct [
    :condition,
    :policies,
    access_type: :strict
  ]

  defmodule Check do
    defstruct [:check_module, :check_opts, :type]

    def new(type, check_module, check_opts) do
      %__MODULE__{
        type: type,
        check_module: check_module,
        check_opts: check_opts
      }
    end
  end

  def new(condition, policies, access_type) do
    %__MODULE__{
      condition: condition,
      policies: policies,
      access_type: access_type
    }
  end

  def solve(authorizer) do
    expression = build_requirements_expression(authorizer.policies, authorizer.facts)

    expression
    |> add_negations_and_solve()
    |> get_all_scenarios(expression)
    |> case do
      [] ->
        {:error, :unsatisfiable}

      scenarios ->
        {:ok,
         scenarios
         |> Enum.uniq()
         |> remove_irrelevant_clauses()}
    end
  end

  defp get_all_scenarios(scenario_result, expression, scenarios \\ [])
  defp get_all_scenarios({:error, :unsatisfiable}, _, scenarios), do: scenarios

  defp get_all_scenarios({:ok, scenario}, expression, scenarios) do
    expression
    |> add_negations_and_solve([Map.drop(scenario, [true, false]) | scenarios])
    |> get_all_scenarios(expression, [Map.drop(scenario, [true, false]) | scenarios])
  end

  defp remove_irrelevant_clauses([scenario]), do: [scenario]

  defp remove_irrelevant_clauses(scenarios) do
    new_scenarios =
      scenarios
      |> Enum.uniq()
      |> Enum.map(fn scenario ->
        unnecessary_fact =
          Enum.find_value(scenario, fn
            {fact, value_in_this_scenario} ->
              matching =
                Enum.find(scenarios, fn potential_irrelevant_maker ->
                  potential_irrelevant_maker != scenario &&
                    Map.delete(scenario, fact) == Map.delete(potential_irrelevant_maker, fact)
                end)

              case matching do
                %{^fact => value} when is_boolean(value) and value != value_in_this_scenario ->
                  fact

                _ ->
                  false
              end
          end)

        Map.delete(scenario, unnecessary_fact)
      end)
      |> Enum.uniq()

    if new_scenarios == scenarios do
      scenarios
    else
      remove_irrelevant_clauses(new_scenarios)
    end
  end

  defp add_negations_and_solve(requirements_expression, negations \\ []) do
    negations =
      Enum.reduce(negations, nil, fn negation, expr ->
        negation_statement =
          negation
          |> Map.drop([true, false])
          |> facts_to_statement()

        if expr do
          {:and, expr, {:not, negation_statement}}
        else
          {:not, negation_statement}
        end
      end)

    full_expression =
      if negations do
        {:and, requirements_expression, negations}
      else
        requirements_expression
      end

    Ash.SatSolver.solve_expression(full_expression)
  end

  defp facts_to_statement(facts) do
    Enum.reduce(facts, nil, fn {fact, true?}, expr ->
      expr_component =
        if true? do
          fact
        else
          {:not, fact}
        end

      if expr do
        {:and, expr, expr_component}
      else
        expr_component
      end
    end)
  end

  defp build_requirements_expression(policies, facts) do
    policy_expression = compile_policy_expression(policies, facts)

    facts_expression = facts_to_statement(Map.drop(facts, [true, false]))

    if facts_expression do
      {:and, facts_expression, policy_expression}
    else
      policy_expression
    end
  end

  def fetch_fact(facts, %{check_module: mod, check_opts: opts}) do
    fetch_fact(facts, {mod, opts})
  end

  def fetch_fact(facts, {mod, opts}) do
    Map.fetch(facts, {mod, Keyword.delete(opts, :__auto_filter__)})
  end

  defp compile_policy_expression(policies, facts, access_type \\ :strict)

  defp compile_policy_expression([], _facts, _) do
    false
  end

  defp compile_policy_expression(
         [%__MODULE__{condition: condition, policies: policies} = policy],
         facts,
         _access_type
       ) do
    if is_nil(condition) or match?({:ok, true}, fetch_fact(facts, condition)) do
      compile_policy_expression(policies, facts, policy.access_type)
    else
      true
    end
  end

  defp compile_policy_expression(
         [
           %__MODULE__{condition: condition, policies: policies} = policy | rest
         ],
         facts,
         access_type
       ) do
    if is_nil(condition) or match?({:ok, true}, fetch_fact(facts, condition)) do
      {:and, compile_policy_expression(policies, facts, policy.access_type),
       compile_policy_expression(rest, facts, access_type)}
    else
      compile_policy_expression(rest, facts, access_type)
    end
  end

  defp compile_policy_expression([%{type: :authorize_if} = clause], facts, access_type) do
    case fetch_fact(facts, clause) do
      {:ok, true} ->
        true

      {:ok, false} ->
        false

      :error when access_type == :strict ->
        false

      :error when access_type == :filter ->
        {clause.check_module, Keyword.put(clause.check_opts, :__auto_filter__, true)}

      :error ->
        {clause.check_module, clause.check_opts}
    end
  end

  defp compile_policy_expression([%{type: :authorize_if} = clause | rest], facts, access_type) do
    case fetch_fact(facts, clause) do
      {:ok, true} ->
        true

      {:ok, false} ->
        compile_policy_expression(rest, facts, access_type)

      :error when access_type == :strict ->
        compile_policy_expression(rest, facts, access_type)

      :error when access_type == :filter ->
        {:or, {clause.check_module, Keyword.put(clause.check_opts, :__auto_filter__, true)},
         compile_policy_expression(rest, facts, access_type)}

      :error ->
        {:or, {clause.check_module, clause.check_opts},
         compile_policy_expression(rest, facts, access_type)}
    end
  end

  defp compile_policy_expression([%{type: :authorize_unless} = clause], facts, access_type) do
    case fetch_fact(facts, clause) do
      {:ok, true} ->
        false

      {:ok, false} ->
        true

      :error when access_type == :strict ->
        false

      :error when access_type == :filter ->
        {clause.check_module, Keyword.put(clause.check_opts, :__auto_filter__, false)}

      :error ->
        {clause.check_module, clause.check_opts}
    end
  end

  defp compile_policy_expression([%{type: :authorize_unless} = clause | rest], facts, access_type) do
    case fetch_fact(facts, clause) do
      {:ok, true} ->
        compile_policy_expression(rest, facts, access_type)

      {:ok, false} ->
        true

      :error when access_type == :strict ->
        compile_policy_expression(rest, facts, access_type)

      :error when access_type == :filter ->
        {:or, {clause.check_module, Keyword.put(clause.check_opts, :__auto_filter__, false)},
         compile_policy_expression(rest, facts, access_type)}

      :error ->
        {:or, {clause.check_module, clause.check_opts},
         compile_policy_expression(rest, facts, access_type)}
    end
  end

  defp compile_policy_expression([%{type: :forbid_if}], _facts, _) do
    false
  end

  defp compile_policy_expression([%{type: :forbid_if} = clause | rest], facts, access_type) do
    case fetch_fact(facts, clause) do
      {:ok, true} ->
        false

      {:ok, false} ->
        compile_policy_expression(rest, facts, access_type)

      :error when access_type == :strict ->
        false

      :error when access_type == :filter ->
        {:and, {clause.check_module, Keyword.put(clause.check_opts, :__auto_filter__, false)},
         compile_policy_expression(rest, facts, access_type)}

      :error ->
        {:and, {:not, clause}, compile_policy_expression(rest, facts, access_type)}
    end
  end

  defp compile_policy_expression([%{type: :forbid_unless}], _facts, _) do
    false
  end

  defp compile_policy_expression([%{type: :forbid_unless} = clause | rest], facts, access_type) do
    case fetch_fact(facts, clause) do
      {:ok, true} ->
        compile_policy_expression(rest, facts)

      {:ok, false} ->
        false

      :error when access_type == :strict ->
        false

      :error when access_type == :filter ->
        {:and, {clause.check_module, Keyword.put(clause.check_opts, :__auto_filter__, true)},
         compile_policy_expression(rest, facts, access_type)}

      :error ->
        {:and, clause, compile_policy_expression(rest, facts)}
    end
  end
end
