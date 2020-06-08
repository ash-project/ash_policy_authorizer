defmodule AshPolicyAuthorizer.FilterCheck do
  @type options :: Keyword.t()
  @callback filter(options()) :: Keyword.t()
  @optional_callbacks [filter: 1]

  defmacro __using__(_) do
    quote do
      @behaviour AshPolicyAuthorizer.FilterCheck
      @behaviour AshPolicyAuthorizer.Check

      def type(), do: :filter

      def strict_check_context(opts) do
        # field_access = AshPolicyAuthorizer.FilterCheck.fields(filter(opts))
        # TODO: At some point, we'll support partial actor evaluation
        # (A.K.A lazy evaluation of the actor. use this interface for that)

        [:query]
      end

      def strict_check(nil, _, _), do: false

      def strict_check(actor, %{query: %{filter: candidate}, resource: resource, api: api}, opts) do
        filter = AshPolicyAuthorizer.FilterCheck.build_filter(filter(opts), actor)

        # TODO: Move this filter building to compile-time, with some kind of provision
        # for sentinal values in the filter parsing (so {:_actor, :field} doesn't break)
        # type checking
        case Ash.Filter.parse(resource, filter, api) do
          %{errors: []} = parsed_filter ->
            if Ash.Filter.strict_subset_of?(parsed_filter, candidate) do
              {:ok, true}
            else
              case Ash.Filter.parse(resource, [not: filter], api) do
                %{errors: []} = negated_filter ->
                  if Ash.Filter.strict_subset_of?(negated_filter, candidate) do
                    {:ok, false}
                  else
                    {:ok, :unknown}
                  end

                %{errors: errors} ->
                  {:error, errors}
              end
            end

          %{errors: errors} ->
            {:error, errors}
        end
      end

      def auto_filter(actor, _auuthorizer, opts) do
        AshPolicyAuthorizer.FilterCheck.build_filter(filter(opts), actor)
      end

      def check(actor, data, authorizer, opts) do
        pkey = Ash.primary_key(authorizer.resource)

        filter =
          case data do
            [record] -> Map.take(record, pkey)
            records -> [or: Enum.map(data, &Map.take(&1, pkey))]
          end

        authorizer.resource
        |> authorizer.api.query()
        |> Ash.Query.filter(filter)
        |> Ash.Query.filter(auto_filter(authorizer.actor, authorizer, opts))
        |> authorizer.api.read()
        |> case do
          {:ok, authorized_data} ->
            authorized_pkeys = Enum.map(authorized_data, &Map.take(&1, pkey))

            Enum.filter(data, fn record ->
              Map.take(record, pkey) in authorized_pkeys
            end)

          {:error, error} ->
            {:error, error}
        end
      end
    end
  end

  def is_filter_check?(module) do
    :erlang.function_exported(module, :filter, 1)
  end

  def build_filter(filter, actor) do
    walk_filter(filter, fn
      {:_actor, field} ->
        Map.get(actor, field)

      other ->
        other
    end)
  end

  defp walk_filter(filter, mapper) when is_list(filter) do
    case mapper.(filter) do
      ^filter ->
        Enum.map(filter, &walk_filter(&1, mapper))

      other ->
        walk_filter(other, mapper)
    end
  end

  defp walk_filter(filter, mapper) when is_map(filter) do
    case mapper.(filter) do
      ^filter ->
        Enum.into(filter, %{}, &walk_filter(&1, mapper))

      other ->
        walk_filter(other, mapper)
    end

    Enum.into(filter, %{}, &walk_filter(&1, mapper))
  end

  defp walk_filter(tuple, mapper) when is_tuple(tuple) do
    case mapper.(tuple) do
      ^tuple ->
        tuple
        |> Tuple.to_list()
        |> Enum.map(&walk_filter(&1, mapper))
        |> List.to_tuple()

      other ->
        walk_filter(other, mapper)
    end
  end

  defp walk_filter(value, mapper), do: mapper.(value)
end
