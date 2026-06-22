# How to Contribute

We'd love to accept your patches and contributions to this project. There are
just a few small guidelines you need to follow.

## Contributor License Agreement

Contributions to this project must be accompanied by a Contributor License
Agreement. You (or your employer) retain the copyright to your contribution;
this simply gives us permission to use and redistribute your contributions as
part of the project. Head over to <https://cla.developers.google.com/> to see
your current agreements on file or to sign a new one.

You generally only need to submit a CLA once, so if you've already submitted one
(even if it was for a different project), you probably don't need to do it
again.

## Support questions

Please do not paste API keys, account IDs, billing identifiers, private prompts,
or complete request payloads into public issues or discussions. If you already
posted a key, revoke or rotate it with the provider before continuing.

For quota, billing, suspension, or rate-limit problems, include the provider
name, model name, error code, PaperBanana surface used, and redacted run status.
Provider account limits and suspensions must be resolved through the provider's
official dashboard or support channel.

## Large agent and prompt changes

Open an issue or discussion before sending a large pull request that changes an
agent, prompt strategy, renderer, critic loop, retrieval mode, or provider
contract. Keep the proposal focused on one pipeline stage when possible.

Useful proposals include:
- the affected stage, such as Retriever, Planner, Stylist, Visualizer, Critic,
  or prompt templates
- a short design summary and the reason this belongs upstream
- before/after examples on a small reproducible set
- evaluation criteria, failure cases, and dependency changes
- a split plan for small reviewable pull requests

Prefer guarded modes or flags for experimental behavior. Avoid mixing prompt
rewrites, model-provider changes, UI changes, and dependency additions in one
pull request.

## Code reviews

All submissions, including submissions by project members, require review. We
use GitHub pull requests for this purpose. Consult
[GitHub Help](https://help.github.com/articles/about-pull-requests/) for more
information on using pull requests.

## Community Guidelines

This project follows
[Google's Open Source Community Guidelines](https://opensource.google/conduct/).
