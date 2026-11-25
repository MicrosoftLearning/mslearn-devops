(() => {
    "use strict";
    const root = document.getElementById("catalog-chat");
    if (!root) return;
    const form = document.getElementById("chat-form");
    const input = document.getElementById("chat-question");
    const log = document.getElementById("chat-messages");
    const send = document.getElementById("chat-send");
    const stop = document.getElementById("chat-stop");
    const reset = document.getElementById("chat-reset");
    const status = document.getElementById("chat-status");
    const maxMessages = Number(root.dataset.maxMessages);
    const maxHistory = Number(root.dataset.maxHistory);
    let history = [];
    let activeRequest = null;

    function addMessage(role, text) {
        const article = document.createElement("article");
        article.className = "esh-chat-message";
        article.dataset.role = role;
        const label = document.createElement("strong");
        label.textContent = role === "user" ? "You" : "Catalog assistant";
        const body = document.createElement("p");
        body.textContent = text;
        article.append(label, body);
        log.append(article);
        log.scrollTop = log.scrollHeight;
        return { article, body };
    }

    function showProducts(article, products) {
        if (!Array.isArray(products)) throw new Error("Invalid product cards.");
        const cards = document.createElement("div");
        cards.className = "esh-chat-products";
        for (const product of products) {
            const card = document.createElement("div");
            card.className = "esh-chat-product";
            const image = document.createElement("img");
            image.src = product.pictureUri;
            image.alt = product.name;
            const link = document.createElement("a");
            link.href = product.url;
            link.textContent = product.name;
            const price = document.createElement("span");
            price.textContent = `Catalog price: ${Number(product.price).toFixed(2)}`;
            card.append(image, link, price);
            cards.append(card);
        }
        article.append(cards);
    }

    function setBusy(busy) {
        send.disabled = busy;
        reset.disabled = busy;
        stop.hidden = !busy;
        input.disabled = busy;
        root.querySelectorAll("[data-question]").forEach(button => { button.disabled = busy; });
    }

    root.querySelectorAll("[data-question]").forEach(button => {
        button.addEventListener("click", () => {
            input.value = button.dataset.question;
            input.focus();
        });
    });
    stop.addEventListener("click", () => activeRequest?.abort());
    reset.addEventListener("click", () => {
        history = [];
        log.replaceChildren();
        status.textContent = "New chat started.";
        input.value = "";
        input.focus();
    });

    form.addEventListener("submit", async event => {
        event.preventDefault();
        const question = input.value.trim();
        if (!question || activeRequest) return;
        const userMessage = { role: "user", content: question };
        const messages = [...history, userMessage];
        while (messages.length > maxMessages ||
            messages.reduce((length, message) => length + message.content.length, 0) > maxHistory) {
            messages.splice(0, 2);
        }
        addMessage("user", question);
        const reply = addMessage("assistant", "Thinking...");
        const controller = new AbortController();
        activeRequest = controller;
        setBusy(true);
        status.textContent = "Waiting for the assistant...";
        let answer = "";
        let completed = false;
        let completedText = "";
        let reader;
        try {
            const response = await fetch(root.dataset.endpoint, {
                method: "POST",
                headers: {
                    "Content-Type": "application/json",
                    "RequestVerificationToken": form.querySelector('[name="__RequestVerificationToken"]').value
                },
                credentials: "same-origin",
                body: JSON.stringify({ messages }),
                signal: controller.signal
            });
            if (!response.ok) {
                const message = response.status === 429
                    ? "Too many questions. Wait a minute and try again."
                    : "The catalog assistant is unavailable. Please try again.";
                throw new Error(message);
            }
            if (!response.body || !response.headers.get("content-type")?.startsWith("text/event-stream")) {
                throw new Error("The assistant returned an invalid response.");
            }
            reader = response.body.getReader();
            const decoder = new TextDecoder();
            let buffer = "";
            while (!completed) {
                const chunk = await reader.read();
                if (chunk.done) throw new Error("The response was interrupted. Please try again.");
                buffer += decoder.decode(chunk.value, { stream: true });
                let boundary;
                while ((boundary = buffer.indexOf("\n\n")) !== -1) {
                    const block = buffer.slice(0, boundary);
                    buffer = buffer.slice(boundary + 2);
                    const data = block.split("\n").filter(line => line.startsWith("data:"))
                        .map(line => line.slice(5).trimStart()).join("\n");
                    if (!data) continue;
                    const item = JSON.parse(data);
                    if (item.type === "delta" && typeof item.text === "string") {
                        answer += item.text;
                        reply.body.textContent = answer.replace(/\[\[product:[0-9]+\]\]/g, "")
                            .replace(/\[\[product:[0-9]*$/, "");
                        status.textContent = "Receiving response...";
                        log.scrollTop = log.scrollHeight;
                    } else if (item.type === "completed" && typeof item.text === "string") {
                        showProducts(reply.article, item.products);
                        reply.body.textContent = item.text;
                        completedText = item.text;
                        completed = true;
                        break;
                    } else if (item.type === "error") {
                        throw new Error(item.error || "The assistant could not complete the response.");
                    } else {
                        throw new Error("The assistant returned an invalid event.");
                    }
                }
            }
            // Drain normal EOF rather than aborting a successfully completed response.
            while (!(await reader.read()).done) { }
            history = [...messages, { role: "assistant", content: completedText }];
            input.value = "";
            status.textContent = "Response complete.";
        } catch (error) {
            if (error.name !== "AbortError") {
                console.error("Catalog chat failed.", error);
            }
            const message = error.name === "AbortError" ? "Response stopped."
                : error.message || "The assistant could not complete the response.";
            reply.body.textContent = `${answer.replace(/\[\[product:[0-9]+\]\]/g, "")}\n${message}`.trim();
            reply.article.classList.add("esh-chat-error");
            status.textContent = message;
        } finally {
            if (reader) {
                if (!completed) {
                    try {
                        await reader.cancel();
                    } catch (error) {
                        console.error("Could not cancel the chat stream.", error);
                    }
                }
                reader.releaseLock();
            }
            activeRequest = null;
            setBusy(false);
            input.focus();
        }
    });
})();
