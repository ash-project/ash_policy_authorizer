defmodule AshPolicyAuthorizer.Authorizer do
  @moduledoc false

  defstruct [
    :actor,
    :resource,
    :query,
    :changeset,
    :data,
    :action,
    :api,
    :verbose?,
    :scenarios,
    :real_scenarios,
    :check_scenarios,
    policies: [],
    facts: %{true => true, false => false},
    data_facts: %{}
  ]

  @type t :: %__MODULE__{}

  alias AshPolicyAuthorizer.{Checker, Policy}

  require Logger

  @check_schema [
    check: [
      type: {:custom, __MODULE__, :validate_check, []},
      required: true,
      doc: """
      A check is a tuple of `{module, keyword}`.

      The module must implement the `AshPolicyAuthorizer.Check` behaviour.
      Generally, you won't be passing `{module, opts}`, but will use one
      of the provided functions that return that, like `always()` or
      `actor_attribute_matches_record(:foo, :bar)`. To make custom ones
      define a module that implements the `AshPolicyAuthorizer.Check` behaviour,
      put a convenience function in that module that returns {module, opts}, and
      import that into your resource.

      ```elixir
      defmodule MyResource do
        use Ash.Resource, authorizers: [AshPolicyAuthorizer.Authorizer]

        import MyCustomCheck

        policies do
          ...
          policy do
            authorize_if my_custom_check(:foo)
          end
        end
      end
      ```
      """
    ],
    name: [
      type: :string,
      required: false,
      doc: "A short name or description for the check, used when explaining authorization results"
    ]
  ]

  @authorize_if %Ash.Dsl.Entity{
    name: :authorize_if,
    describe: "If the check is true, the request is authorized, otherwise run remaining checks.",
    args: [:check],
    schema: @check_schema,
    examples: [
      "authorize_if logged_in()",
      "authorize_if actor_attribute_matches_record(:group, :group)"
    ],
    target: AshPolicyAuthorizer.Policy.Check,
    transform: {AshPolicyAuthorizer.Policy.Check, :transform, []},
    auto_set_fields: [
      type: :authorize_if
    ]
  }

  @forbid_if %Ash.Dsl.Entity{
    name: :forbid_if,
    describe: "If the check is true, the request is forbidden, otherwise run remaining checks.",
    args: [:check],
    schema: @check_schema,
    target: AshPolicyAuthorizer.Policy.Check,
    transform: {AshPolicyAuthorizer.Policy.Check, :transform, []},
    examples: [
      "forbid_if not_logged_in()",
      "forbid_if actor_attribute_matches_record(:group, :blacklisted_groups)"
    ],
    auto_set_fields: [
      type: :forbid_if
    ]
  }

  @authorize_unless %Ash.Dsl.Entity{
    name: :authorize_unless,
    describe: "If the check is false, the request is authorized, otherwise run remaining checks.",
    args: [:check],
    schema: @check_schema,
    target: AshPolicyAuthorizer.Policy.Check,
    transform: {AshPolicyAuthorizer.Policy.Check, :transform, []},
    examples: [
      "authorize_unless not_logged_in()",
      "authorize_unless actor_attribute_matches_record(:group, :blacklisted_groups)"
    ],
    auto_set_fields: [
      type: :authorize_unless
    ]
  }

  @forbid_unless %Ash.Dsl.Entity{
    name: :forbid_unless,
    describe: "If the check is true, the request is forbidden, otherwise run remaining checks.",
    args: [:check],
    schema: @check_schema,
    target: AshPolicyAuthorizer.Policy.Check,
    transform: {AshPolicyAuthorizer.Policy.Check, :transform, []},
    examples: [
      "forbid_unless logged_in()",
      "forbid_unless actor_attribute_matches_record(:group, :group)"
    ],
    auto_set_fields: [
      type: :forbid_unless
    ]
  }

  @policy %Ash.Dsl.Entity{
    name: :policy,
    describe: """
    A policy has a name, a condition, and a list of checks.

    Checks apply logically in the order they are specified, from top to bottom.
    If no check explicitly authorizes the request, then the request is forbidden.
    This means that, if you want to "blacklist" instead of "whitelist", you likely
    want to add an `authorize_if always()` at the bottom of your policy, like so:

    ```elixir
    policy action_type(:read) do
      forbid_if not_logged_in()
      forbid_if user_is_denylisted()
      forbid_if user_is_in_denylisted_group()

      authorize_if always()
    end
    ```

    If the policy should always run, use the `always()` check, like so:

    ```elixir
    policy always() do
      ...
    end
    ```
    """,
    schema: [
      description: [
        type: :string,
        doc: "A description for the policy, used when explaining authorization results",
        required: true
      ],
      bypass?: [
        type: :boolean,
        doc: "If `true`, and the policy passes, no further policies will be run",
        default: false
      ],
      access_type: [
        type: {:one_of, [:strict, :filter, :runtime]},
        doc: """
        There are three choices for access_type:

        * `:strict` - authentication uses *only* the request context, failing when unknown.
        * `:filter` - this is probably what you want. Automatically removes unauthorized data by altering the request filter.
        * `:runtime` - tries to add a filter before the query, but if it cannot, it fetches the records and checks authorization.

        Be careful with runtime checks, as they can potentially cause a given scenario to fetch *all* records of a resource, because
        it can't figure out a common filter between all of the possible scenarios. Use sparingly, if at all.
        """
      ],
      condition: [
        type: {:custom, __MODULE__, :validate_condition, []},
        doc: """
        A check or list of checks that must be true in order for this policy to apply.

        If the policy does not apply, it is not run, and some other policy
        will need to authorize the request. If no policies apply, the request
        is forbidden. If multiple policies apply, they must each authorize the
        request.
        """
      ]
    ],
    args: [:condition],
    target: AshPolicyAuthorizer.Policy,
    entities: [
      policies: [
        @authorize_if,
        @forbid_if,
        @authorize_unless,
        @forbid_unless
      ]
    ]
  }

  @policies %Ash.Dsl.Section{
    name: :policies,
    describe: """
    A section for declaring authorization policies.

    Each policy that applies must pass independently in order for the
    request to be authorized.
    """,
    entities: [
      @policy
    ],
    imports: [
      AshPolicyAuthorizer.Check.BuiltInChecks
    ],
    schema: [
      default_access_type: [
        type: {:one_of, [:strict, :filter, :runtime]},
        default: :filter,
        doc: """
        The default access type of policies for this resource.

        See the access type on individual policies for more information.
        """
      ]
    ]
  }

  use Ash.Dsl.Extension, sections: [@policies]

  @behaviour Ash.Authorizer

  @doc false
  def validate_check({module, opts}) do
    if Ash.implements_behaviour?(module, AshPolicyAuthorizer.Check) do
      {:ok, {module, opts}}
    else
      {:error, "#{inspect({module, opts})} is not a valid check"}
    end
  end

  def validate_check(other) do
    {:error, "#{inspect(other)} is not a valid check"}
  end

  def validate_condition(conditions) when is_list(conditions) do
    Enum.reduce_while(conditions, {:ok, []}, fn condition, {:ok, conditions} ->
      {condition, opts} =
        case condition do
          {condition, opts} -> {condition, opts}
          condition -> {condition, []}
        end

      if Ash.implements_behaviour?(condition, AshPolicyAuthorizer.Check) do
        {:cont, {:ok, [{condition, opts} | conditions]}}
      else
        {:halt, {:error, "Expected all conditions to be valid checks"}}
      end
    end)
  end

  def validate_condition(condition) do
    validate_condition([condition])
  end

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
    [:query, :changeset, :api, :resource]
  end

  @impl true
  def check_context(_authorizer) do
    [:query, :changeset, :data, :api, :resource]
  end

  @impl true
  def check(authorizer, context) do
    check_result(%{authorizer | data: context.data})
  end

  @impl true
  def strict_check(authorizer, context) do
    %{
      authorizer
      | query: context.query,
        changeset: context.changeset,
        api: context.api
    }
    |> get_policies()
    |> do_strict_check_facts()
    |> strict_check_result()
  end

  defp strict_filter(authorizer) do
    {filterable, require_check} =
      authorizer.scenarios
      |> Enum.split_with(fn scenario ->
        scenario
        |> Enum.reject(fn {{_check_module, opts}, _} ->
          opts[:access_type] == :filter
        end)
        |> Enum.reject(fn {{check_module, opts}, _} ->
          match?(
            {:ok, _},
            AshPolicyAuthorizer.Policy.fetch_fact(authorizer.facts, {check_module, opts})
          ) || check_module.type() == :filter
        end)
        |> Enum.empty?()
      end)

    filter = strict_filters(filterable, authorizer)

    case {filter, require_check} do
      {[], []} ->
        raise "unreachable"

      {_filters, []} ->
        case filter do
          [filter] ->
            log(authorizer, "filtering with: #{inspect(filter)}, authorization complete")
            {:filter, filter}

          filters ->
            log(authorizer, "filtering with: #{inspect(or: filter)}, authorization complete")
            {:filter, [or: filters]}
        end

      {_filters, _require_check} ->
        case global_filters(authorizer) do
          nil ->
            maybe_forbid_strict(authorizer)

          {[single_filter], scenarios_without_global} ->
            log(
              authorizer,
              "filtering with: #{inspect(single_filter)}, continuing authorization process"
            )

            {:filter_and_continue, single_filter,
             %{authorizer | check_scenarios: scenarios_without_global}}

          {filters, scenarios_without_global} ->
            log(
              authorizer,
              "filtering with: #{inspect(and: filters)}, continuing authorization process"
            )

            {:filter_and_continue, [and: filters],
             %{authorizer | check_scenarios: scenarios_without_global}}
        end
    end
  end

  defp strict_filters(filterable, authorizer) do
    filterable
    |> Enum.reduce([], fn scenario, or_filters ->
      scenario
      |> Enum.filter(fn {{check_module, check_opts}, _} ->
        check_module.type() == :filter && check_opts[:access_type] in [:filter, :runtime]
      end)
      |> Enum.reject(fn {{check_module, check_opts}, result} ->
        match?({:ok, ^result}, Policy.fetch_fact(authorizer.facts, {check_module, check_opts}))
      end)
      |> Enum.map(fn
        {{check_module, check_opts}, true} ->
          check_module.auto_filter(authorizer.actor, authorizer, check_opts)

        {{check_module, check_opts}, false} ->
          [not: check_module.auto_filter(authorizer.actor, authorizer, check_opts)]
      end)
      |> case do
        [] -> or_filters
        filter -> [[and: filter] | or_filters]
      end
    end)
  end

  defp maybe_forbid_strict(authorizer) do
    log(authorizer, "could not determine authorization filter, checking at runtime")
    {:continue, %{authorizer | check_scenarios: authorizer.scenarios}}
  end

  defp global_filters(authorizer, scenarios \\ nil, filter \\ []) do
    scenarios = scenarios || authorizer.scenarios

    global_check_value =
      Enum.find_value(scenarios, fn scenario ->
        Enum.find(scenario, fn {{check_module, _opts} = check, value} ->
          check_module.type == :filter &&
            Enum.all?(scenarios, &(Map.fetch(&1, check) == {:ok, value}))
        end)
      end)

    case global_check_value do
      nil ->
        case filter do
          [] ->
            nil

          filter ->
            {filter, scenarios}
        end

      {{check_module, check_opts}, required_status} ->
        additional_filter =
          if required_status do
            check_module.auto_filter(authorizer.actor, authorizer, check_opts)
          else
            [not: check_module.auto_filter(authorizer.actor, authorizer, check_opts)]
          end

        scenarios = remove_clause(authorizer.scenarios, {check_module, check_opts})
        new_facts = Map.put(authorizer.facts, {check_module, check_opts}, required_status)
        global_filters(%{authorizer | facts: new_facts}, scenarios, [additional_filter | filter])
    end
  end

  defp remove_clause(scenarios, clause) do
    Enum.map(scenarios, &Map.delete(&1, clause))
  end

  defp check_result(authorizer) do
    Enum.reduce_while(authorizer.data, {:ok, authorizer}, fn record, {:ok, authorizer} ->
      authorizer.scenarios
      |> Enum.reject(&scenario_impossible?(&1, authorizer, record))
      |> case do
        [] ->
          {:halt, {:error, :forbidden, authorizer}}

        scenarios ->
          scenarios
          |> AshPolicyAuthorizer.SatSolver.remove_irrelevant_clauses()
          |> do_check_result(authorizer, record)
      end
    end)
  end

  defp do_check_result(cleaned_scenarios, authorizer, record) do
    if Enum.any?(cleaned_scenarios, &scenario_applies?(&1, authorizer, record)) do
      {:cont, {:ok, authorizer}}
    else
      check_facts_until_known(cleaned_scenarios, authorizer, record)
    end
  end

  defp scenario_applies?(scenario, authorizer, record) do
    Enum.all?(scenario, fn {clause, requirement} ->
      case Map.fetch(authorizer.facts, clause) do
        {:ok, ^requirement} ->
          true

        _ ->
          scenario_applies_to_record?(authorizer, clause, record)
      end
    end)
  end

  defp scenario_applies_to_record?(authorizer, clause, record) do
    case Map.fetch(authorizer.data_facts, clause) do
      {:ok, ids_that_match} ->
        pkey = Map.take(record, Ash.Resource.primary_key(authorizer.resource))

        MapSet.member?(ids_that_match, pkey)

      _ ->
        false
    end
  end

  defp scenario_impossible?(scenario, authorizer, record) do
    Enum.any?(scenario, fn {clause, requirement} ->
      case Map.fetch(authorizer.facts, clause) do
        {:ok, value} when value != requirement ->
          true

        _ ->
          scenario_impossible_by_data?(authorizer, clause, record)
      end
    end)
  end

  defp scenario_impossible_by_data?(authorizer, clause, record) do
    case Map.fetch(authorizer.data_facts, clause) do
      {:ok, ids_that_match} ->
        pkey = Map.take(record, Ash.Resource.primary_key(authorizer.resource))

        not MapSet.member?(ids_that_match, pkey)

      _ ->
        false
    end
  end

  defp check_facts_until_known(scenarios, authorizer, record) do
    new_authorizer =
      scenarios
      |> find_fact_to_check(authorizer)
      |> check_fact(authorizer)

    scenarios
    |> Enum.reject(&scenario_impossible?(&1, new_authorizer, record))
    |> case do
      [] ->
        log(authorizer, "Checked all facts, no real scenarios")
        {:halt, {:forbidden, authorizer}}

      scenarios ->
        cleaned_scenarios = AshPolicyAuthorizer.SatSolver.remove_irrelevant_clauses(scenarios)

        if Enum.any?(cleaned_scenarios, &scenario_applies?(&1, new_authorizer, record)) do
          {:cont, {:ok, new_authorizer}}
        else
          check_facts_until_known(scenarios, new_authorizer, record)
        end
    end
  end

  defp check_fact({check_module, check_opts}, authorizer) do
    if check_module.type() == :simple do
      raise "Assumption failed"
    else
      authorized_records =
        check_module.check(authorizer.actor, authorizer.data, authorizer, check_opts)

      pkey = Ash.Resource.primary_key(authorizer.resource)

      pkeys = MapSet.new(authorized_records, &Map.take(&1, pkey))

      %{
        authorizer
        | data_facts: Map.put(authorizer.data_facts, {check_module, check_opts}, pkeys)
      }
    end
  end

  defp find_fact_to_check(scenarios, authorizer) do
    scenarios
    |> Enum.concat()
    |> Enum.find(fn {key, _value} ->
      not Map.has_key?(authorizer.facts, key) and not Map.has_key?(authorizer.data_facts, key)
    end)
    |> case do
      nil -> raise "Assumption failed"
      {key, _value} -> key
    end
  end

  defp strict_check_result(authorizer) do
    case Checker.strict_check_scenarios(authorizer) do
      {:ok, scenarios} ->
        report_scenarios(authorizer, scenarios, "Potential Scenarios")

        case Checker.find_real_scenarios(scenarios, authorizer.facts) do
          [] ->
            maybe_strict_filter(authorizer, scenarios)

          real_scenarios ->
            report_scenarios(authorizer, real_scenarios, "Real Scenarios")
            :authorized
        end

      {:error, :unsatisfiable} ->
        {:error,
         AshPolicyAuthorizer.Forbidden.exception(
           verbose?: authorizer.verbose?,
           facts: authorizer.facts,
           scenarios: []
         )}
    end
  end

  defp maybe_strict_filter(authorizer, scenarios) do
    log(authorizer, "No real scenarios, attempting to filter")
    strict_filter(%{authorizer | scenarios: scenarios})
  end

  defp do_strict_check_facts(authorizer) do
    new_facts = Checker.strict_check_facts(authorizer)

    %{authorizer | facts: new_facts}
  end

  defp get_policies(authorizer) do
    %{
      authorizer
      | policies: AshPolicyAuthorizer.policies(authorizer.resource)
    }
  end

  defp report_scenarios(%{verbose?: true}, scenarios, title) do
    scenario_description =
      scenarios
      |> Enum.map(fn scenario ->
        scenario
        |> Enum.reject(fn {{module, _}, _} ->
          module == AshPolicyAuthorizer.Check.Static
        end)
        |> Enum.map(fn {{module, opts}, requirement} ->
          ["  ", module.describe(opts) <> " => #{requirement}"]
        end)
        |> Enum.intersperse("\n")
      end)
      |> Enum.intersperse("\n--\n")

    Logger.info([title, "\n", scenario_description])
  end

  defp report_scenarios(_, _, _), do: :ok

  defp log(%{verbose?: true}, message) do
    Logger.info(message)
  end

  defp log(_, _), do: :ok
end
