# LinkedIn developer app setup

The workflow posts through the official LinkedIn API using your own developer app and an OAuth2 credential in n8n.

## 1. Create the app

1. Go to [linkedin.com/developers/apps](https://www.linkedin.com/developers/apps) and click **Create app**.
2. Enter a name, link it to a **LinkedIn Company Page** you admin (LinkedIn requires one; it does not change who the post is from), upload a logo and accept the terms.
3. On the **Settings** tab, verify the app with the Company Page if asked.

## 2. Add products

On the **Products** tab, request:

| Product | Gives scopes | Used by |
| --- | --- | --- |
| Sign In with LinkedIn using OpenID Connect | `openid`, `profile` | `Get LinkedIn profile` (reads your member id) |
| Share on LinkedIn | `w_member_social` | `Init image upload`, `Upload image`, `Create LinkedIn post` |

Both are usually approved instantly.

## 3. Redirect URL and keys

On the **Auth** tab:

1. Under **Authorized redirect URLs**, add `<N8N_PUBLIC_URL>/rest/oauth2-credential/callback`, for example `http://192.168.1.20:5678/rest/oauth2-credential/callback`. The n8n credential screen shows the exact value as "OAuth Redirect URL"; copy it from there to be sure.
2. Copy the **Client ID** and **Primary Client Secret**. Treat the secret like a password.

## 4. Create the credential in n8n

In n8n: **Credentials -> Add credential -> OAuth2 API**.

| Field | Value |
| --- | --- |
| Grant Type | Authorization Code |
| Authorization URL | `https://www.linkedin.com/oauth/v2/authorization` |
| Access Token URL | `https://www.linkedin.com/oauth/v2/accessToken` |
| Client ID | from the Auth tab |
| Client Secret | from the Auth tab |
| Scope | `openid profile w_member_social` (space-separated) |
| Auth URI Query Parameters | leave empty |
| Authentication | Send credentials in body |

Click **Connect my account**, sign in to LinkedIn in the popup and approve. The credential should show "Account connected".

## 5. Token expiry

LinkedIn access tokens last 60 days, and apps on the self-serve products normally get no refresh token. After about 60 days every LinkedIn node fails with `401`. Open the credential and click **Connect my account** again. Set a reminder for day 50.

## 6. API version header

`Init image upload` and `Create LinkedIn post` send `LinkedIn-Version: YYYYMM`. LinkedIn supports each version for about a year. When posts start failing with `426` or `NONEXISTENT_VERSION`, set both nodes to a recent month (see the [LinkedIn API versioning page](https://learn.microsoft.com/en-us/linkedin/marketing/versioning)).
