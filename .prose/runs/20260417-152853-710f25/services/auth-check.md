---
name: auth-check
kind: program
---

requires:
- env: the target environment — one of "local" | "alpha" | "stable"

ensures:
- auth-instructions: combined auth instructions — AUTH.md (universal, if it exists) merged with AUTH.{env}.md (environment-specific, if it exists), ready to pass to Theo

errors:
- auth-missing: neither AUTH.md nor AUTH.{env}.md exists; scaffolding was performed and the user was told to fill it in — the caller must stop

invariants:
- AUTH.md and AUTH.*.md are always in .gitignore before any auth file is created or read
- only AUTH.local.md gets a boilerplate scaffold; alpha and stable are project-specific and the user must create them
- AUTH.md holds cross-environment auth (e.g. OAuth, SSO) — AUTH.{env}.md holds environment-specific auth (e.g. cookies, tokens)

strategies:
- when both AUTH.md and AUTH.{env}.md exist: combine them — env-specific takes precedence where they overlap
- when only AUTH.md exists: use it alone (sufficient for auth methods that work across environments)
- when only AUTH.{env}.md exists: use it alone
- when neither exists and env is "local": scaffold AUTH.local.md with the boilerplate template, then signal auth-missing
- when neither exists and env is "alpha" or "stable": do not scaffold — just signal auth-missing

### Execution

# Ensure auth files are gitignored and untracked
Read .gitignore from the project root. If `AUTH.md` or `AUTH.*.md` are not already covered by patterns, append them.
Check if any AUTH*.md files are tracked by git. If so, untrack them (`git rm --cached`).
If .gitignore or tracking changed, commit with message "chore: gitignore auth files".

# Read auth files
Read AUTH.md from the project root (universal, may not exist).
Read AUTH.{env}.md from the project root (environment-specific, may not exist).

If neither AUTH.md nor AUTH.{env}.md exists:
  if env is "local":
    Create AUTH.local.md with this template:
    ```
    # Authentication — local
    # Target: localhost / local dev server
    <!-- This file is gitignored. Fill in the section that matches your app's auth method. -->

    ## Cookie-based
    <!-- Paste cookies to set in the browser before testing. Example: -->
    <!-- Cookie: session_token=abc123; Domain=localhost; Path=/ -->

    ## OAuth / SSO
    <!-- Step-by-step instructions for signing in via OAuth. Example: -->
    <!-- 1. Navigate to http://localhost:3000/login -->
    <!-- 2. Click "Sign in with Google" -->
    <!-- 3. Use email: test@example.com, password in 1Password under "Local Dev" -->

    ## Email + Password
    <!-- Direct credentials for form-based login. Example: -->
    <!-- URL: http://localhost:3000/login -->
    <!-- Email: test@example.com -->
    <!-- Password: hunter2 -->

    ## API Key / Bearer Token
    <!-- Tokens for API access. Example: -->
    <!-- Authorization: Bearer sk-test-xxxx -->

    ## Other
    <!-- Describe any other auth flow here. -->
    ```
    Tell the user via AskUserQuestion: "Created AUTH.local.md with a boilerplate template (already gitignored). Fill in your local auth details and re-run. You can also create AUTH.md for cross-environment auth (OAuth, SSO), or AUTH.alpha.md / AUTH.stable.md for environment-specific auth."
  else:
    Tell the user via AskUserQuestion: "No AUTH.md or AUTH.{env}.md found. Create at least one at the project root with your auth details and re-run."
  signal auth-missing

# Combine and return
Return the combined contents of AUTH.md (if it exists) and AUTH.{env}.md (if it exists) as auth-instructions.
