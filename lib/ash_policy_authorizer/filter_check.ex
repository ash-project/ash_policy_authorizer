defmodule AshPolicyAuthorizer.FilterCheck do
  @moduledoc """
  A type of check that is represented by a filter statement

  That filter statement can be templated, currently only supporting `{:_actor, field}`
  which will replace that portion of the filter with the appropriate field value from the actor and
  `{:_actor, :_primary_key}` which will replace the value with a keyword list of the primary key
  fields of an actor to their values, like `[id: 1]`. If the actor is not present `{:_actor, field}`
  becomes `nil`, and `{:_actor, :_primary_key}` becomes `false`.

  You can customize what the "negative" filter looks like by defining `c:reject/1`. This is important for
  filters over related data. For example, given an `owner` relationship and a data layer like `ash_postgres`
  where `column != NULL` does *not* evaluate to true (see postgres docs on NULL for more):

      # The opposite of
      `owner.id == 1`
      # in most cases is not
      `not(owner.id == 1)`
      # because in postgres that would be `NOT (owner.id = NULL)` in cases where there was no owner
      # A better opposite would be
      `owner.id != 1 or is_nil(owner.id)`
      # alternatively
      `not(owner.id == 1) or is_nil(owner.id)`

  By being able to customize the `reject` filter, you can use related filters in your policies. Without it,
  they will likely have undesired effects.
  """
  @type options :: Keyword.t()
  @callback filter(options()) :: Keyword.t()
  @callback reject(options()) :: Keyword.t()
  @optional_callbacks [filter: 1, reject: 1]

  defmacro __using__(_) do
    quote do
      @behaviour AshPolicyAuthorizer.FilterCheck
      @behaviour AshPolicyAuthorizer.Check

      require Ash.Query

      def type, do: :filter

      def strict_check_context(opts) do
        []
      end

      def strict_check(_, _, _), do: {:ok, :unknown}

      def auto_filter(actor, authorizer, opts) do
        opts = Keyword.put_new(opts, :resource, authorizer.resource)
        Ash.Filter.build_filter_from_template(filter(opts), actor)
      end

      def auto_filter_not(actor, authorizer, opts) do
        opts = Keyword.put_new(opts, :resource, authorizer.resource)
        Ash.Filter.build_filter_from_template(reject(opts), actor)
      end

      def reject(opts) do
        [not: filter(opts)]
      end

      def check(actor, data, authorizer, opts) do
        pkey = Ash.Resource.Info.primary_key(authorizer.resource)

        filter =
          case data do
            [record] -> Map.take(record, pkey)
            records -> [or: Enum.map(data, &Map.take(&1, pkey))]
          end

        authorizer.resource
        |> authorizer.api.query()
        |> Ash.Query.filter(^filter)
        |> Ash.Query.filter(^auto_filter(authorizer.actor, authorizer, opts))
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

      defoverridable reject: 1
    end
  end

  def is_filter_check?(module) do
    :erlang.function_exported(module, :filter, 1)
  end
end
