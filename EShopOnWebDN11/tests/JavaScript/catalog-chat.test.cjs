const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const script = fs.readFileSync(path.join(__dirname, "..", "..", "src", "Web",
    "wwwroot", "js", "catalog-chat.js"), "utf8");

class Element {
    constructor() {
        this.children = [];
        this.listeners = {};
        this.dataset = {};
        this.value = "";
        this.textContent = "";
        this.classList = { add() {} };
    }
    append(...children) { this.children.push(...children); }
    replaceChildren() { this.children = []; }
    addEventListener(name, callback) { this.listeners[name] = callback; }
    querySelectorAll() { return []; }
    querySelector() { return { value: "test-antiforgery-token" }; }
    focus() {}
}

function event(item) {
    return `data: ${JSON.stringify(item)}\n\n`;
}

function createApp(responses) {
    const elements = new Map(["catalog-chat", "chat-form", "chat-question", "chat-messages",
        "chat-send", "chat-stop", "chat-reset", "chat-status"].map(id => [id, new Element()]));
    elements.get("catalog-chat").dataset = {
        endpoint: "/api/chat", maxMessages: "11", maxHistory: "24000"
    };
    const requests = [];
    const errors = [];
    const document = {
        cookie: "basket=preserve-this",
        getElementById: id => elements.get(id),
        createElement: () => new Element()
    };
    vm.runInNewContext(script, {
        document, TextDecoder, AbortController,
        console: { error: (...args) => errors.push(args) },
        fetch: async (_, options) => {
            requests.push(JSON.parse(options.body));
            const chunks = responses.shift();
            if (typeof chunks === "function") {
                return chunks(options);
            }
            let position = 0;
            return {
                ok: true,
                headers: { get: () => "text/event-stream" },
                body: {
                    getReader: () => ({
                        read: async () => position < chunks.length
                            ? { done: false, value: new TextEncoder().encode(chunks[position++]) }
                            : { done: true },
                        cancel: async () => {},
                        releaseLock() {}
                    })
                }
            };
        }
    });
    return {
        elements, requests, errors, document,
        submit: async question => {
            elements.get("chat-question").value = question;
            await elements.get("chat-form").listeners.submit({ preventDefault() {} });
        },
        answer: () => elements.get("chat-messages").children.at(-1).children[1].textContent
    };
}

const completeResponse = [
    event({ type: "delta", text: "The " }),
    event({ type: "delta", text: "mug." }) +
        event({ type: "completed", text: "The mug.", products: [] })
];

test("processes all chunks before completing a streamed answer", async () => {
    const app = createApp([completeResponse]);
    await app.submit("Show mugs.");
    assert.equal(app.answer(), "The mug.");
    assert.equal(app.elements.get("chat-status").textContent, "Response complete.");
    assert.equal(app.elements.get("chat-send").disabled, false);
    assert.equal(app.errors.length, 0);
});

test("reports an interrupted stream instead of a successful answer", async () => {
    const app = createApp([[event({ type: "delta", text: "Partial answer" })]]);
    await app.submit("Show mugs.");
    assert.match(app.answer(), /interrupted/);
    assert.match(app.elements.get("chat-status").textContent, /interrupted/);
    assert.equal(app.errors.length, 1);
});

test("treats a user stopping the response as cancellation, not an application error", async () => {
    const app = createApp([options => new Promise((_, reject) => {
        options.signal.addEventListener("abort", () => reject(new DOMException("Stopped", "AbortError")));
    })]);
    const pending = app.submit("Show mugs.");
    app.elements.get("chat-stop").listeners.click();
    await pending;
    assert.equal(app.elements.get("chat-status").textContent, "Response stopped.");
    assert.equal(app.errors.length, 0);
    assert.equal(app.elements.get("chat-send").disabled, false);
});

test("keeps successful history and resets only chat state", async () => {
    const app = createApp([completeResponse, completeResponse, completeResponse]);
    await app.submit("Show mugs.");
    await app.submit("Which is cheaper?");
    assert.deepEqual(app.requests[1].messages, [
        { role: "user", content: "Show mugs." },
        { role: "assistant", content: "The mug." },
        { role: "user", content: "Which is cheaper?" }
    ]);
    app.elements.get("chat-reset").listeners.click();
    assert.equal(app.elements.get("chat-messages").children.length, 0);
    assert.equal(app.document.cookie, "basket=preserve-this");
    await app.submit("New question.");
    assert.deepEqual(app.requests[2].messages, [{ role: "user", content: "New question." }]);
});
