# Policy Breakdowns

## Explanation

Policy breakdowns can be fetched on demand for a given forbidden error (either an `Ash.Error.Forbidden` that contains one ore more `AshPolicyAuthorizer.Forbidden`
errors, or an `AshPolicyAuthorizer.Forbidden` error itself), via `AshPolicyAuthorizer.Forbidden.report/2`.

Here is an example policy breakdown from ash_policy_authorizer tests:

```text
Policy Breakdown
A check status of `?` implies that the solver did not need to determine that check.
Some checks may look like they failed when in reality there was simply no need to check them.
Look for policies with `✘` and `✓` in check statuses.

A check with a `⬇` means that it didn't determine if the policy was authorized or forbidden, and so moved on to the next check.
`🌟` and `⛔` mean that the check was responsible for producing an authorized or forbidden (respectively) status.

If no check results in a status (they all have `⬇`) then the policy is assumed to have failed. In some cases, however, the policy
may have just been ignored, as described above.

  Admins and managers can create posts | ⛔:
    authorize if: actor.admin == true | ✘ | ⬇    
    authorize if: actor.manager == true | ✘ | ⬇
```

To remove the help text, you can pass the `help_text?: false` option, which would leave you with:

```text
Policy Breakdown
  Admins and managers can create posts | ⛔:
    authorize if: actor.admin == true | ✘ | ⬇    
    authorize if: actor.manager == true | ✘ | ⬇
```

## Including in error message

### **IMPORTANT WARNING**

The following configuration should only ever be used in development mode!

### Instructions

For security reasons, authorization errors don't include any extra information, aside from `forbidden`. To have authorization errors include a policy breakdown (without help text)
use the following config.

```elixir
config :ash_policy_authorizer, show_policy_breakdowns?: true
```

## Logging

It is generally safe to log authorization error details, even in production. This can be very helpful when investigating certain classes of issue.

To have ash_policy_authorizer automatically log each authorization failure, use

```elixir
config :ash_policy_authorizer, log_policy_breakdowns: :error # Use whatever log level you'd like to use here
```
