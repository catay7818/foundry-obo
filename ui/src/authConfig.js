import { PublicClientApplication } from "@azure/msal-browser";

export const AGENT_SERVER_URL = "http://localhost:8088";

const msalConfig = {
    auth: {
        clientId: "41199aa4-83a2-41a5-992d-4bf569be5e8b",
        authority:
            "https://login.microsoftonline.com/5113c164-f41a-4f8a-aaae-96d81e693b93",
        redirectUri: window.location.origin,
    },
    cache: {
        cacheLocation: "sessionStorage",
    },
};

export const loginRequest = {
    scopes: ["api://95c8825e-d2d0-43c0-ae5b-787c47fc2df2/user_impersonation"],
};

export const msalInstance = new PublicClientApplication(msalConfig);
await msalInstance.initialize();
