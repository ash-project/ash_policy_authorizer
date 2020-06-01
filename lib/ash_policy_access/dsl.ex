defmodule AshPolicyAccess.Dsl do
  defmacro policies(access_type \\ nil, do: body) do
    quote do
      Module.register_attribute(__MODULE__, :ash_policies, accumulate: true)
      @access_type unquote(access_type) || :strict
      global_access_type = @access_type
      AshPolicyAccess.Dsl.validate_access_type(@access_type)

      import AshPolicyAccess.Check.BuiltInChecks

      import AshPolicyAccess.Dsl,
        only: [
          authorize_if: 1,
          forbid_if: 1,
          authorize_unless: 1,
          forbid_unless: 1,
          policy: 2
        ]

      unquote(body)

      if Enum.any?(@ash_policies, fn policy -> match?(%AshPolicyAccess.Policy.Check{}, policy) end) do
        policies = @ash_policies
        Module.delete_attribute(__MODULE__, :ash_policies)

        Module.register_attribute(__MODULE__, :ash_policies, accumulate: true)

        @ash_policies %AshPolicyAccess.Policy{
          condition: nil,
          policies: policies,
          access_type: global_access_type
        }
      end

      import AshPolicyAccess.Dsl, only: [policies: 1]
      import AshPolicyAccess.Check.BuiltInChecks, only: []
    end
  end

  defmacro authorize_if(check) do
    quote do
      {check_module, check_opts} = unquote(check)

      @ash_policies AshPolicyAccess.Policy.Check.new(
                      :authorize_if,
                      check_module,
                      check_opts
                    )
    end
  end

  defmacro authorize_unless(check) do
    quote do
      {check_module, check_opts} = unquote(check)

      @ash_policies AshPolicyAccess.Policy.Check.new(
                      :authorize_unless,
                      check_module,
                      check_opts
                    )
    end
  end

  defmacro forbid_if(check) do
    quote do
      {check_module, check_opts} = unquote(check)

      @ash_policies AshPolicyAccess.Policy.Check.new(
                      :forbid_if,
                      check_module,
                      check_opts
                    )
    end
  end

  defmacro forbid_unless(check) do
    quote do
      {check_module, check_opts} = unquote(check)

      @ash_policies AshPolicyAccess.Policy.Check.new(
                      :forbid_unless,
                      check_module,
                      check_opts
                    )
    end
  end

  defmacro policy(condition, access_type \\ nil, do: body) do
    quote do
      case unquote(condition) do
        nil ->
          :ok

        {module, opts} ->
          if module.type != :simple do
            raise "Only simple checks can be used as policy conditions"
          end
      end

      existing_access_type = @access_type
      existing_policies = @ash_policies
      @access_type unquote(access_type) || @access_type || :strict
      AshPolicyAccess.Dsl.validate_access_type(@access_type)
      Module.delete_attribute(__MODULE__, :ash_policies)
      Module.register_attribute(__MODULE__, :ash_policies, accumulate: true)
      unquote(body)

      policy = AshPolicyAccess.Policy.new(unquote(condition), @ash_policies, @access_type)

      Module.delete_attribute(__MODULE__, :ash_policies)
      Module.register_attribute(__MODULE__, :ash_policies, accumulate: true)
      Module.put_attribute(__MODULE__, :ash_policies, policy)

      existing_policies
      |> Enum.reverse()
      |> Enum.each(&Module.put_attribute(__MODULE__, :ash_policies, &1))

      Module.put_attribute(__MODULE__, :access_type, existing_access_type)
    end
  end

  def validate_access_type(type) when type in [:strict, :filter, :runtime] do
    :ok
  end

  def validate_access_type(type) do
    raise "#{type} is not a valid access type"
  end
end
