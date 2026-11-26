# eShop catalog chat investigation

## Scope

- Dedicated lab environment, resource group and deployed source commit:
- Investigator and UTC review time:
- No customer content, credentials or access tokens in this document.

## Symptoms and evidence

- Shopper-visible symptom:
- Chat outcome and HTTP status (record separately):
- UTC failure/recovery interval and correlated operation ID:
- Web, ChatApi and Foundry dependency facts:
- Missing evidence or unresolved checks:

## Verification

1. Confirm the workspace, time range, service roles, environment and source commit.
2. Use `chat-outcomes.kql` and `trace.kql`; do not infer completed answers from HTTP 200.
3. Check recent configuration changes, the model deployment name and the Foundry response code.
4. Treat missing, stale, sampled or incorrectly attributed data as unknown.

## Recovery and escalation

- Approved recovery action and saved previous configuration:
- How to verify a complete, catalog-grounded answer after recovery:
- When to stop and escalate instead of changing permissions or retrying:
- Alert owner and notification channel:
- Alert resolution alone is not proof of healthy chat.

## Reviewed improvement

- Facts versus hypotheses in the Copilot analysis:
- Accepted feedback item URL:
- Prevention or detection acceptance criteria:
- Evaluation on one successful and one failed operation; remaining limitations:
