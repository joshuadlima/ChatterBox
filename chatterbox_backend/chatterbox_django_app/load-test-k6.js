import ws from 'k6/ws';
import { sleep } from 'k6';
import { sha256 } from 'k6/crypto';

export const options = {
  scenarios: {
    user_a: {
      executor: 'ramping-vus', // gradually increase VUs over time
      startVUs: 0,
      stages: [
        { duration: '30s', target: 5 }, // 5 in 30s
        { duration: '60s', target: 25 }, // 25 in 60s
        { duration: '120s', target: 25 }, // hold 25 for 120s
      ],
      exec: 'userA',  // runs userA function
    },
    user_b: {
      executor: 'ramping-vus', // gradually increase VUs over time
      startVUs: 0,
      stages: [
        { duration: '30s', target: 5 }, // 5 in 30s
        { duration: '60s', target: 25 }, // 25 in 60s
        { duration: '120s', target: 25 }, // hold 25 for 120s
      ],
      exec: 'userB',  // runs userB function
      startTime: '1s',  // slight delay so userA is in queue first
    },
  },
};

function generateHashedId() {
  const rawId = `${Math.random()}-${Date.now()}-${__VU}-${__ITER}`;
  return sha256(rawId, 'hex');
}

// User A - enters queue first
export function userA() {
  const id = generateHashedId();
  const url = `ws://localhost:8000/ws/textchat?id=${id}`;

  ws.connect(url, {}, function (socket) {
    socket.on('open', () => { // when connection is open
      socket.send(JSON.stringify({
        type: 'submit_interests',
        timestamp: new Date().toISOString(),
        description: 'submit interests',
        data: { interests: ['coding', 'gaming'] }  // fixed interests for overlap
      }));

      sleep(0.5);

      socket.send(JSON.stringify({
        type: 'start_matching',
        timestamp: new Date().toISOString(),
        description: 'start matching',
      }));
    });

    socket.on('message', (data) => { // fire each time server sends a message
      const msg = JSON.parse(data);

      if (msg.type === 'success') {
        // Send a few messages once matched
        for (let i = 0; i < 3; i++) {
          socket.send(JSON.stringify({
            type: 'chat_message',
            timestamp: new Date().toISOString(),
            description: 'chat message',
            data: { message: 'Hello from user A!' }
          }));
          sleep(1);
        }

        socket.send(JSON.stringify({
          type: 'end_chat',
          timestamp: new Date().toISOString(),
          description: 'end chat',
        }));

        socket.close();
      }
    });

    socket.setTimeout(() => socket.close(), 30000);
  });
}

// User B - enters queue second, should match with A
export function userB() {
  const id = generateHashedId();
  const url = `ws://localhost:8000/ws/textchat?id=${id}`;

  ws.connect(url, {}, function (socket) {
    socket.on('open', () => {
      socket.send(JSON.stringify({
        type: 'submit_interests',
        timestamp: new Date().toISOString(),
        description: 'submit interests',
        data: { interests: ['coding', 'music'] }  // overlaps on 'coding'
      }));

      sleep(0.5);

      socket.send(JSON.stringify({
        type: 'start_matching',
        timestamp: new Date().toISOString(),
        description: 'start matching',
      }));
    });

    socket.on('message', (data) => {
      const msg = JSON.parse(data);

      if (msg.type === 'success') {
        for (let i = 0; i < 3; i++) {
          socket.send(JSON.stringify({
            type: 'chat_message',
            timestamp: new Date().toISOString(),
            description: 'chat message',
            data: { message: 'Hello from user B!' }
          }));
          sleep(1);
        }

        socket.send(JSON.stringify({
          type: 'end_chat',
          timestamp: new Date().toISOString(),
          description: 'end chat',
        }));

        socket.close();
      }
    });

    socket.setTimeout(() => socket.close(), 30000);
  });
}