# ChatterBox
**An anonymous, interest-based real-time text chat application. (Similar to Omegle)**

---

## Backend Design & Architecture

The backend utilizes an **Asynchronous Event Loop** model, allowing a single server process to handle thousands of concurrent WebSocket connections with a minimal memory footprint.

### 1. Atomic Matching Logic
To prevent race conditions (e.g., one user matching with multiple people simultaneously), the matching logic (and other redis operations that need to be atomic) is offloaded to **Redis Lua Scripts**.

<details>
<summary>Wanna dive deeper?</summary>
<br>
1. Understanding Why Lua
2. 
</details>

### 2. Fully asynchronous
To increase efficiency, better IO handling, and optimal memory usage.

<details>
<summary>Wanna dive deeper?</summary>
<br>
1. Understanding the CPU
    - If a CPU has 6 cores, it implies it can run 6 processes in a truly parallel manner (12 in the case of hyperthreading).
    - These cores are then context-switched by threads, and these threads are what are available to our applications for processing our logic.
2. Understanding Python
    - While Python can create many OS threads, the GIL acts as a bouncer, ensuring only one thread can execute Python bytecode at any given microsecond.
    - The Python interpreter controls this GIL for a given thread.
    - The OS context switches multiple threads for the interpreter to use. (pre-emptive switching)
    - This helps different parts of Python logic to get the CPU's attention in a non-biased manner.
3. Understanding Django and Web Servers
    - Django is a framework; its job is to ensure better design patterns are used, thus helping the development process. What actually takes care of the code execution is the web server (like uvicorn).
    - The web server watches for any requests to the app and executes them accordingly. These web servers can be sync or async.
4. Understanding Synchronous Web Server
    - If it is sync, it means that it has a pool of threads available to it. 
    - When a user connects, a thread is assigned only to serve him. Now, note that this user might not be doing anything that requires CPU attention. 
    - The user might just be idle or awaiting some IO or network request, but he will still occupy the thread.
    - Say the pool has 40 threads, when the 41st user tries to connect.. he won't be able to until one of the others disconnects.
    - Each thread has its own private memory (stack) to store that specific user's progress. This means workers cannot easily finish each other's jobs; a user is 'stuck' with their assigned thread until the task is complete.
    - Another issue is the fact that each thread requires 1MB, and if it isn't being utilized, then this causes a waste of resources for all the threads.
5. Understanding Asynchronous Web Server
    - If the web server is async, it means that an event loop is going to be used and a single thread.
    - Here, units of work are broken into tasks,s and these tasks are executed by the event loop.
    - If a task being executed reaches an await, then context switching happens, and another task is given execution time.
    - These tasks are pretty light, unlike threads, and thus context switching causes a very low overhead.
    - The key here is cooperative switching: switching will only happen if await is encountered. 
</details>

### 3. Data Structures
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
