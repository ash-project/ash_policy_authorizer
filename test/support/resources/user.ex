defmodule AshPolicyAuthorizer.Test.User do
  @moduledoc false
  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets

  ets do
    private?(true)
  end

  attributes do
    uuid_primary_key(:id)
  end

  actions do
    create(:create)
    read(:read)
    update(:update)
    destroy(:destroy)
  end

  relationships do
    has_many(:memberships, AshPolicyAuthorizer.Test.Membership, destination_field: :user_id)
  end
end
