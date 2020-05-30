defmodule AshPolicyAccess.Authorizer do
  defstruct [
    :actor,
    :resource,
    :query,
    :changeset,
    :action,
    :api,
    :verbose?,
    :scenarios,
    :real_scenarios,
    policies: [],
    facts: %{true => true, false => false}
  ]

  @type t :: %__MODULE__{}

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
    [:query, :changeset, :api, :resource]
  end

  @impl true
  def check_context(_authorizer) do
    [:query, :changeset, :data, :api, :resource]
  end

  @impl true
  def check(authorizer, data, context) do
    IO.inspect(authorizer, label: "check authorizer")
    IO.inspect(context, label: "check context")
    IO.inspect(data, label: "data")
    # Big TODO
    :authorized
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
        Enum.all?(scenario, fn {{check_module, opts}, _value} ->
          AshPolicyAccess.Policy.fetch_fact(authorizer.facts, {check_module, opts}) != :error ||
            (Keyword.has_key?(opts, :__auto_filter__) and
               AshPolicyAccess.Check.defines_auto_filter?(check_module))
        end)
      end)

    filter =
      filterable
      |> Enum.reduce([], fn scenario, or_filters ->
        and_filter =
          Enum.reduce(scenario, [], fn {{check_module, check_opts}, value}, and_filters ->
            if check_module.type() == :filter do
              required_status = check_opts[:__auto_filter__] && value

              if required_status do
                check_module.auto_filter(authorizer.actor, authorizer, check_opts)
              else
                [not: check_module.auto_filter(authorizer.actor, authorizer, check_opts)]
              end
            else
              and_filters
            end
          end)

        [and_filter | or_filters]
      end)

    case {filter, require_check} do
      {[], []} ->
        raise "unreachable"

      {_filters, []} ->
        {:filter, [or: filter]}

      {_filters, _require_check} ->
        {:continue, authorizer}
    end
  end

  defp strict_check_result(authorizer) do
    case Checker.strict_check_scenarios(authorizer) do
      {:ok, scenarios} ->
        case Checker.find_real_scenarios(scenarios, authorizer.facts) do
          [] ->
            strict_filter(%{authorizer | scenarios: scenarios})

          _real_scenarios ->
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
      |> validate_policies()

    %{authorizer | policies: policies}
  end

  defp validate_policies(policies) do
    Enum.each(policies, &validate_policy/1)

    policies
  end

  defp validate_policy(%AshPolicyAccess.Policy{condition: {mod, opts}, policies: policies}) do
    validate_policy({mod, opts})

    Enum.each(policies, &validate_policy/1)
  end

  defp validate_policy(%AshPolicyAccess.Policy.Check{check_module: mod, check_opts: opts}) do
    validate_policy({mod, opts})
  end

  defp validate_policy({mod, _opts}) do
    if mod.type() == :manual do
      raise "Manual policies are not supported yet!"
    end
  end
end
