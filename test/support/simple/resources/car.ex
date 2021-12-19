defmodule AshPolicyAuthorizer.Test.Simple.Car do
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
    many_to_many :users, AshPolicyAuthorizer.Test.Simple.User do
      through(AshPolicyAuthorizer.Test.Simple.CarUser)
      source_field_on_join_table(:car_id)
      destination_field_on_join_table(:user_id)
    end
  end
end
