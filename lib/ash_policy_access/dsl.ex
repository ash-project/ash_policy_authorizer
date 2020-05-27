defmodule AshPolicyAccess.Dsl do
  defmacro policies(do: body) do
    quote do
      Module.register_attribute(__MODULE__, :wheres, accumulate: true)
      @access_type :strict

      import AshPolicyAccess.Check.BuiltInChecks

      import AshPolicyAccess.Dsl,
        only: [
          authorize_if: 1,
          forbid_if: 1,
          authorize_unless: 1,
          forbid_unless: 1,
          policy: 2,
          access_type: 1
        ]

      unquote(body)
      Module.delete_attribute(__MODULE__, :wheres)
      import AshPolicyAccess.Dsl, only: [policies: 1]
      import AshPolicyAccess.Check.BuiltInChecks, only: []
    end
  end

  defmacro access_type(type) when type in [:strict] do
    quote do
      @access_type unquote(type)
    end
  end

  defmacro access_type(type) do
    quote do
      raise "No such access type #{unquote(type)}"
    end
  end

  defmacro authorize_if(check, opts \\ []) do
    quote do
      {check_module, check_opts} = unquote(check)

      @ash_policies AshPolicyAccess.Policy.new(
                      @wheres,
                      :authorize_if,
                      unquote(opts[:access_type]) || @access_type,
                      check_module,
                      check_opts
                    )
    end
  end

  defmacro authorize_unless(check, opts \\ []) do
    quote do
      {check_module, check_opts} = unquote(check)

      @ash_policies AshPolicyAccess.Policy.new(
                      @wheres,
                      :authorize_unless,
                      unquote(opts[:access_type]) || @access_type,
                      check_module,
                      check_opts
                    )
    end
  end

  defmacro forbid_if(check, opts \\ []) do
    quote do
      {check_module, check_opts} = unquote(check)

      @ash_policies AshPolicyAccess.Policy.new(
                      @wheres,
                      :forbid_if,
                      unquote(opts[:access_type]) || @access_type,
                      check_module,
                      check_opts
                    )
    end
  end

  defmacro forbid_unless(check, opts \\ []) do
    quote do
      {check_module, check_opts} = unquote(check)

      @ash_policies AshPolicyAccess.Policy.new(
                      @wheres,
                      :forbid_unless,
                      unquote(opts[:access_type]) || @access_type,
                      check_module,
                      check_opts
                    )
    end
  end

  defmacro policy(where, do: body) do
    quote do
      existing_wheres = @wheres
      existing_access_type = @access_type
      @wheres unquote(where)
      unquote(body)

      Module.delete_attribute(__MODULE__, :wheres)
      Module.register_attribute(__MODULE__, :wheres, accumulate: true)
      Module.put_attribute(__MODULE__, :access_type, existing_access_type)
      Enum.each(existing_wheres, &Module.put_attribute(__MODULE__, :wheres, &1))
    end
  end
end
