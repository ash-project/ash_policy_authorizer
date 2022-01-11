defmodule AshPolicyAuthorizer.Test.Simple.Organization do
  @moduledoc false
  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets

  ets do
    private?(true)
  end

  actions do
    create(:create) do
      argument(:owner, :uuid)
      change(manage_relationship(:owner, type: :replace))
    end

    read(:read)
    update(:update)
    destroy(:destroy)
  end

  attributes do
    uuid_primary_key(:id)
  end

  relationships do
    has_many(:users, AshPolicyAuthorizer.Test.Simple.User)
    has_many(:posts, AshPolicyAuthorizer.Test.Simple.Post)
    belongs_to(:owner, AshPolicyAuthorizer.Test.Simple.User)
  end
end
