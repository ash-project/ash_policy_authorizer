defmodule AshPolicyAccess.Check.BuiltInChecks do
  @moduledoc "The global authorization checks built into ash"

  def always() do
    {AshPolicyAccess.Check.Static, [result: true]}
  end

  def never() do
    {AshPolicyAccess.Check.Static, [result: false]}
  end

  def action_type(action_type) do
    {AshPolicyAccess.Check.ActionType, [type: action_type]}
  end

  def action(action) do
    {AshPolicyAccess.Check.Action, [action: action]}
  end

  # def attribute_equals(field, value) do
  #   {AshPolicyAccess.Check.AttributeEquals, field: field, value: value}
  # end

  # def related_to_user_via(relationship) do
  #   {AshPolicyAccess.Check.RelatedToUserVia, relationship: List.wrap(relationship)}
  # end

  # def setting_relationship(relationship) do
  #   {AshPolicyAccess.Check.SettingRelationship, relationship_name: relationship}
  # end

  # def setting_attribute(name, opts \\ []) do
  #   opts =
  #     opts
  #     |> Keyword.take([:to])
  #     |> Keyword.put(:attribute_name, name)

  #   AshPolicyAccess.Check.AttributeBuiltInChecks.setting(opts)
  # end

  # def user_attribute(field, value) do
  #   {AshPolicyAccess.Check.UserAttribute, field: field, value: value}
  # end

  def actor_attribute_matches_record(actor_field, record_field) do
    {AshPolicyAccess.Check.ActorAttributeMatchesRecord,
     actor_field: actor_field, record_field: record_field}
  end

  # def relating_to_user(relationship_name, opts) do
  #   {AshPolicyAccess.Check.RelatingToUser,
  #    Keyword.put(opts, :relationship_name, relationship_name)}
  # end

  # def relationship_set(relationship_name) do
  #   {AshPolicyAccess.Check.RelationshipSet, [relationship_name: relationship_name]}
  # end

  # def logged_in(), do: {AshPolicyAccess.Check.LoggedIn, []}
end
