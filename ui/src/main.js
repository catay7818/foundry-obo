import { PublicClientApplication } from "@azure/msal-browser";
import { AGENT_SERVER_URL, loginRequest, msalConfig, tokenRequest } from "./authConfig.js";

const msalInstance = new PublicClientApplication(msalConfig);

// DOM elements
const loginScreen = document.getElementById("login-screen");
const chatScreen = document.getElementById("chat-screen");
const loginBtn = document.getElementById("login-btn");
const logoutBtn = document.getElementById("logout-btn");
const userName = document.getElementById("user-name");
const chatForm = document.getElementById("chat-form");
const chatInput = document.getElementById("chat-input");
const chatMessages = document.getElementById("chat-messages");
const sendBtn = document.getElementById("send-btn");

let currentAccount = null;

// Initialize MSAL and check for existing session
async function initialize() {
    await msalInstance.initialize();
    try {
        const response = await msalInstance.handleRedirectPromise();
        if (response) {
            currentAccount = response.account;
        } else {
            const accounts = msalInstance.getAllAccounts();
            if (accounts.length > 0) {
                currentAccount = accounts[0];
            }
        }

        if (currentAccount) {
            showChat();
        }
    } catch (error) {
        console.error("MSAL initialization error:", error);
    }
}

function showChat() {
    loginScreen.classList.add("hidden");
    chatScreen.classList.remove("hidden");
    userName.textContent = currentAccount.name || currentAccount.username;
    chatInput.focus();
}

function showLogin() {
    chatScreen.classList.add("hidden");
    loginScreen.classList.remove("hidden");
}

async function login() {
    try {
        const response = await msalInstance.loginPopup(loginRequest);
        currentAccount = response.account;
        showChat();
    } catch (error) {
        console.error("Login failed:", error);
    }
}

function logout() {
    msalInstance.logoutPopup({ account: currentAccount }).then(() => {
        currentAccount = null;
        chatMessages.innerHTML = "";
        showLogin();
    });
}

async function getAccessToken() {
    const request = { ...tokenRequest, account: currentAccount };
    try {
        const response = await msalInstance.acquireTokenSilent(request);
        return response.accessToken;
    } catch (error) {
        // Fallback to interactive if silent fails
        const response = await msalInstance.acquireTokenPopup(request);
        return response.accessToken;
    }
}

function appendMessage(role, text) {
    const msg = document.createElement("div");
    msg.className = `message ${role}`;

    const bubble = document.createElement("div");
    bubble.className = "bubble";
    bubble.textContent = text;

    msg.appendChild(bubble);
    chatMessages.appendChild(msg);
    chatMessages.scrollTop = chatMessages.scrollHeight;
}

function setLoading(loading) {
    sendBtn.disabled = loading;
    chatInput.disabled = loading;
    sendBtn.textContent = loading ? "..." : "Send";
}

async function sendMessage(input) {
    appendMessage("user", input);
    setLoading(true);

    try {
        const token = await getAccessToken();
        const response = await fetch(`${AGENT_SERVER_URL}/responses`, {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                Authorization: `Bearer ${token}`,
            },
            body: JSON.stringify({ input, stream: false }),
        });

        if (!response.ok) {
            const errorText = await response.text();
            throw new Error(`Server error ${response.status}: ${errorText}`);
        }

        const data = await response.json();

        // Extract text from the Responses API output
        let assistantText = "";
        if (data.output && Array.isArray(data.output)) {
            for (const item of data.output) {
                if (item.content && Array.isArray(item.content)) {
                    for (const part of item.content) {
                        if (part.text) {
                            assistantText += part.text;
                        }
                    }
                }
            }
        }

        appendMessage("assistant", assistantText || "(No response)");
    } catch (error) {
        console.error("Chat error:", error);
        appendMessage("error", `Error: ${error.message}`);
    } finally {
        setLoading(false);
        chatInput.focus();
    }
}

// Event listeners
loginBtn.addEventListener("click", login);
logoutBtn.addEventListener("click", logout);

chatForm.addEventListener("submit", (e) => {
    e.preventDefault();
    const input = chatInput.value.trim();
    if (!input) return;
    chatInput.value = "";
    sendMessage(input);
});

initialize();
