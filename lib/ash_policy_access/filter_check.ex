defmodule AshPolicyAccess.FilterCheck do
  @type options :: Keyword.t()
  @callback describe(options()) :: String.t()
  @callback filter(options()) :: Keyword.t()
  @optional_callbacks [filter: 1]

  defmacro __using__(_) do
    quote do
      @behaviour AshPolicyAccess.FilterCheck
      @behaviour AshPolicyAccess.Check

      def type(), do: :filter

      def strict_check_context(opts) do
        # field_access = AshPolicyAccess.FilterCheck.fields(filter(opts))
        # TODO: At some point, we'll support partial actor evaluation
        # (A.K.A lazy evaluation of the actor. use this interface for that)

        [:query]
      end

      def check()

      def strict_check(nil, _, _), do: false

      def strict_check(actor, %{query: %{filter: candidate}, resource: resource}, opts) do
        filter = AshPolicyAccess.FilterCheck.build_filter(filter(opts), actor)

        # TODO: Move this filter building to compile-time, with some kind of provision
        # for sentinal values in the filter parsing (so {:_actor, :field} doesn't break)
        # type checking
        case Ash.Filter.parse(resource, filter) do
          %{errors: []} = filter ->
            if AshPolicyAccess.Filter.strict_subset_of?(filter, candidate) do
              {:ok, true}
            else
              case Ash.Filter.parse(resource, not: filter) do
                %{errors: []} = negated_filter ->
                  if AshPolicyAccess.Filter.strict_subset_of?(negated_filter, candidate) do
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
    end
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
    Enum.map(filter, &walk_filter(&1, mapper))
  end

  defp walk_filter(filter, mapper) when is_map(filter) do
    Enum.into(filter, %{}, &walk_filter(&1, mapper))
  end

  defp walk_filter({key, value}, mapper) do
    {walk_filter(key, mapper), walk_filter(value, mapper)}
  end

  defp walk_filter(value, mapper), do: mapper.(value)
end
