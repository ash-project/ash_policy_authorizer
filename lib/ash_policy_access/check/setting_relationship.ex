# defmodule AshPolicyAccess.Check.SettingRelationship do
#   use AshPolicyAccess.Check, action_types: [:create, :update]

#   @impl true
#   def describe(opts) do
#     "setting #{opts[:relationship_name]}"
#   end

#   @impl true
#   def strict_check(_user, %{changeset: changeset}, options) do
#     {:ok, Map.has_key?(changeset.__ash_relationships__, options[:relationship_name])}
#   end
# end
