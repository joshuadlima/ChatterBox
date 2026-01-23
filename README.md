# ChatterBox
**An anonymous, interest-based real-time text chat application.**

ChatterBox allows users to instantly connect with strangers based on shared interests. Built with a high-concurrency architecture, it ensures atomic matching and seamless messaging using Django Channels and Redis Lua scripting.

---

## Backend Design & Architecture

The backend utilizes an **Asynchronous Event Loop** model, allowing a single server process to handle thousands of concurrent WebSocket connections with a minimal memory footprint.

### 1. Atomic Matching Logic
To prevent race conditions (e.g., one user matching with multiple people simultaneously), the matching logic is offloaded to **Redis Lua Scripts**. This ensures that the "check-and-match" operation is executed as a single uninterruptible unit of work.

### 2. Data Structures
* **`user_meta:{user_id}` (Hash):** Stores `{channel_id, interests, status}`.
* **`interest:{topic}` (Set):** A collection of `user_id`s waiting for a match in a specific category.
* **`active_matches` (Hash):** Bi-directional mapping of `user_id1 <-> user_id2` to maintain stateful chat sessions.

---

## Getting Started

### Prerequisites
* [Docker](https://www.docker.com/) & Docker Compose
* Git

### Running the Back-end Locally
1.  **Clone the repository:**
    ```bash
    git clone [https://github.com/joshuadlima/ChatterBox.git](https://github.com/joshuadlima/ChatterBox.git)
    cd ChatterBox/chatterbox_backend/chatterbox_django_app
    ```
2.  **Spin up the environment:**
    ```bash
    docker-compose up
    ```
3.  **Access the WebSocket:**
    The backend will be accessible at: `ws://localhost:8000/ws/textchat/`

---

## WebSocket API Reference

### 1. Submit Interests
Sets your profile tags. Must be done before matching.
```json
{
    "type": "submit_interests",
    "description": "Request to submit interests",
    "timestamp": "2025-10-01T12:00:00",
    "data": { "interests": ["coding", "gaming"] }
}
```

### 2. Start Matching
Finds a partner with overlapping interests.
```json
{
    "type": "start_matching",
    "description": "Request to start matching",
    "timestamp": "2025-10-01T12:00:00"
}
```

### 3. Stop Matching
Stops looking for a chat partner.
```json
{
    "type": "end_matching",
    "description": "Request to end matching",
    "timestamp": "2025-10-01T12:00:00"
}
```

### 4. Chat Message
Sends a message to your currently matched partner.
```json
{
    "type": "chat_message",
    "description": "Request to send chat message",
    "timestamp": "2025-10-01T12:00:00",
    "data": { "message": "Hello partner!" }
}
```
### 5. Chat Message
Sends a message to your currently matched partner.
```json
{
    "type": "chat_message",
    "description": "Request to send chat message",
    "timestamp": "2025-10-01T12:00:00",
    "data": { "message": "Hello partner!" }
}
```

### 6. End Chat
Ends the chat with the current partner.
```json
{
    "type": "end_chat",
    "description": "Request to end chat",
    "timestamp": "2025-10-01T12:00:00"
}
```
