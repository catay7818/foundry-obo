/**
 * MSAL configuration for Entra ID authentication.
 *
 * Update CLIENT_ID with your SPA app registration's Application (client) ID.
 * Update TENANT_ID with your Azure AD tenant ID.
 * Update API_SCOPE with the scope exposed by your backend API app registration.
 * Update AGENT_SERVER_URL if the agent server runs on a different host/port.
 */
export const msalConfig = {
    auth: {
        clientId: "41199aa4-83a2-41a5-992d-4bf569be5e8b",
        authority: "https://login.microsoftonline.com/5113c164-f41a-4f8a-aaae-96d81e693b93",
        redirectUri: window.location.origin,
    },
    cache: {
        cacheLocation: "sessionStorage",
        storeAuthStateInCookie: false,
    },
};

export const loginRequest = {
    scopes: ["openid", "profile"],
};

export const tokenRequest = {
    scopes: ["api://95c8825e-d2d0-43c0-ae5b-787c47fc2df2/user_impersonation"],
};

export const AGENT_SERVER_URL = "http://localhost:8088";
