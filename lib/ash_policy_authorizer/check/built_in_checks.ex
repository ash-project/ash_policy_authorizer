defmodule AshPolicyAuthorizer.Check.BuiltInChecks do
  @moduledoc "The global authorization checks built into ash"

  def always() do
    {AshPolicyAuthorizer.Check.Static, [result: true]}
  end

  def never() do
    {AshPolicyAuthorizer.Check.Static, [result: false]}
  end

  def action_type(action_type) do
    {AshPolicyAuthorizer.Check.ActionType, [type: action_type]}
  end

  def action(action) do
    {AshPolicyAuthorizer.Check.Action, [action: action]}
  end

  # def attribute_equals(field, value) do
  #   {AshPolicyAuthorizer.Check.AttributeEquals, field: field, value: value}
  # end

  # def related_to_user_via(relationship) do
  #   {AshPolicyAuthorizer.Check.RelatedToUserVia, relationship: List.wrap(relationship)}
  # end

  # def setting_relationship(relationship) do
  #   {AshPolicyAuthorizer.Check.SettingRelationship, relationship_name: relationship}
  # end

  # def setting_attribute(name, opts \\ []) do
  #   opts =
  #     opts
  #     |> Keyword.take([:to])
  #     |> Keyword.put(:attribute_name, name)

  #   AshPolicyAuthorizer.Check.AttributeBuiltInChecks.setting(opts)
  # end

  # def user_attribute(field, value) do
  #   {AshPolicyAuthorizer.Check.UserAttribute, field: field, value: value}
  # end

  def actor_attribute_matches_record(actor_field, record_field) do
    {AshPolicyAuthorizer.Check.ActorAttributeMatchesRecord,
     actor_field: actor_field, record_field: record_field}
  end

  # def relating_to_user(relationship_name, opts) do
  #   {AshPolicyAuthorizer.Check.RelatingToUser,
  #    Keyword.put(opts, :relationship_name, relationship_name)}
  # end

  # def relationship_set(relationship_name) do
  #   {AshPolicyAuthorizer.Check.RelationshipSet, [relationship_name: relationship_name]}
  # end

  # def logged_in(), do: {AshPolicyAuthorizer.Check.LoggedIn, []}
end
