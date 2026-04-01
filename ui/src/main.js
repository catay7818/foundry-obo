import {
    AGENT_SERVER_URL,
    loginRequest,
    msalInstance,
} from "./authConfig.js";

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

// Handle redirect response after login
await msalInstance.handleRedirectPromise();

function getAccount() {
    const accounts = msalInstance.getAllAccounts();
    return accounts.length > 0 ? accounts[0] : null;
}

async function getAccessToken() {
    const account = getAccount();
    if (!account) throw new Error("No account found");
    try {
        const response = await msalInstance.acquireTokenSilent({
            ...loginRequest,
            account,
        });
        return response.accessToken;
    } catch {
        const response = await msalInstance.acquireTokenPopup(loginRequest);
        return response.accessToken;
    }
}

function showChat(account) {
    loginScreen.classList.add("hidden");
    chatScreen.classList.remove("hidden");
    userName.textContent = account.name || account.username;
    chatInput.focus();
}

function showLogin() {
    chatScreen.classList.add("hidden");
    loginScreen.classList.remove("hidden");
}

// Check if already signed in
const account = getAccount();
if (account) {
    showChat(account);
} else {
    showLogin();
}

loginBtn.addEventListener("click", async () => {
    try {
        const response = await msalInstance.loginPopup(loginRequest);
      showChat(response.account);
  } catch (error) {
      console.error("Login failed:", error);
  }
});

logoutBtn.addEventListener("click", () => {
    msalInstance.logoutPopup();
});

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

chatForm.addEventListener("submit", (e) => {
    e.preventDefault();
    const input = chatInput.value.trim();
    if (!input) return;
    chatInput.value = "";
    sendMessage(input);
});

chatInput.focus();
