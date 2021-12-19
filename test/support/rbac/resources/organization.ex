defmodule AshPolicyAuthorizer.Test.Rbac.Organization do
  @moduledoc false
  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets

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
  end

  relationships do
    has_many :memberships, AshPolicyAuthorizer.Test.Rbac.Membership do
      destination_field(:organization_id)
    end
  end
end
