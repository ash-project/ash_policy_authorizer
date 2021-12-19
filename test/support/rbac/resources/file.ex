defmodule AshPolicyAuthorizer.Test.Rbac.File do
  @moduledoc false
  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets,
    authorizers: [AshPolicyAuthorizer.Authorizer]

  import AshPolicyAuthorizer.Test.Rbac.Checks.RoleChecks, only: [can?: 1]

  policies do
    policy always() do
      authorize_if can?(:file)
    end
  end

  ets do
    private?(true)
  end

  actions do
    create(:create)
    read(:read)
    update(:update)
    destroy(:destroy)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:name, :string)
  end

  relationships do
    belongs_to(:organization, AshPolicyAuthorizer.Test.Rbac.Organization)
  end
end
