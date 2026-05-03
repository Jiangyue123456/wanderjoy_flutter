import http from 'node:http';

const port = Number(process.env.PORT ?? 8787);
const workflowId =
  process.env.OPENAI_SOCIAL_WORKFLOW_ID ??
  'wf_69f4e4ada5c88190b7b870e722f44ec800a39a9d7f76457b';

const candidateUsers = [
  {
    userId: 'user_002',
    displayName: 'Mina',
    city: 'Tokyo',
    interests: ['coffee', 'photo', 'museum', 'bookstore'],
    travelIntensity: 'relaxed',
    distanceKm: 1.8,
    safetyRating: 4.8,
    profileSummary:
      '喜欢咖啡馆、书店和慢节奏城市散步，常在代官山和清澄白河附近活动。',
  },
  {
    userId: 'user_003',
    displayName: 'Aki',
    city: 'Tokyo',
    interests: ['walking', 'photo', 'food', 'architecture'],
    travelIntensity: 'moderate',
    distanceKm: 3.2,
    safetyRating: 4.6,
    profileSummary: '喜欢街拍、建筑和轻量美食探索，可以接受半天步行路线。',
  },
  {
    userId: 'user_004',
    displayName: 'Yuna',
    city: 'Tokyo',
    interests: ['coffee', 'art', 'gallery', 'walking'],
    travelIntensity: 'relaxed',
    distanceKm: 2.4,
    safetyRating: 4.9,
    profileSummary: '偏好安静画廊、小众咖啡店和轻松散步路线，旅行节奏慢。',
  },
  {
    userId: 'user_005',
    displayName: 'Ren',
    city: 'Tokyo',
    interests: ['nightlife', 'food', 'shopping', 'photo'],
    travelIntensity: 'active',
    distanceKm: 4.7,
    safetyRating: 4.3,
    profileSummary: '喜欢热闹街区、夜景和美食打卡，适合节奏更满的城市探索。',
  },
  {
    userId: 'user_006',
    displayName: 'Sora',
    city: 'Yokohama',
    interests: ['walking', 'sea', 'photo', 'coffee'],
    travelIntensity: 'relaxed',
    distanceKm: 28.5,
    safetyRating: 4.7,
    profileSummary: '喜欢海边散步、咖啡和拍照，距离东京稍远但旅行节奏很匹配。',
  },
];

function jsonResponse(response, statusCode, body) {
  response.writeHead(statusCode, {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Content-Type': 'application/json; charset=utf-8',
  });
  response.end(JSON.stringify(body));
}

function readJson(request) {
  return new Promise((resolve, reject) => {
    let body = '';
    request.on('data', (chunk) => {
      body += chunk;
    });
    request.on('end', () => {
      if (!body.trim()) {
        resolve({});
        return;
      }
      try {
        resolve(JSON.parse(body));
      } catch (error) {
        reject(error);
      }
    });
    request.on('error', reject);
  });
}

function normalizeInterests(value) {
  if (Array.isArray(value)) {
    return value.map((item) => String(item).toLowerCase().trim()).filter(Boolean);
  }

  return String(value ?? '')
    .split(',')
    .map((item) => item.toLowerCase().trim())
    .filter(Boolean);
}

function scoreUser(user, request) {
  const requestedInterests = normalizeInterests(request.interests);
  const sharedInterests = user.interests.filter((interest) =>
    requestedInterests.includes(interest),
  );
  const requestedCity = String(request.city ?? '').toLowerCase();
  const requestedIntensity = String(request.travelintensity ?? request.travelIntensity ?? '')
    .toLowerCase()
    .trim();

  let score = 45;
  score += sharedInterests.length * 12;
  score += user.city.toLowerCase() === requestedCity ? 14 : -6;
  score += user.travelIntensity === requestedIntensity ? 14 : 0;
  score += user.safetyRating * 2;
  score -= Math.min(user.distanceKm / 3, 10);

  return {
    ...user,
    sharedInterests,
    matchScore: Math.round(Math.max(0, Math.min(score, 100))),
  };
}

function compatibilityLabel(user, requestedIntensity) {
  if (user.travelIntensity === requestedIntensity) {
    return `高度兼容：同为 ${user.travelIntensity}，旅行节奏很接近。`;
  }
  if (
    (user.travelIntensity === 'moderate' && requestedIntensity === 'relaxed') ||
    (user.travelIntensity === 'relaxed' && requestedIntensity === 'moderate')
  ) {
    return '较兼容：节奏略有差异，但可以安排半天轻量路线。';
  }
  return `兼容度较低：对方偏 ${user.travelIntensity}，可能和你的节奏不同。`;
}

function buildSocialMatch(body) {
  const currentUserId = String(body.currentuserid ?? body.currentUserId ?? '');
  const requestedIntensity = String(body.travelintensity ?? body.travelIntensity ?? '')
    .toLowerCase()
    .trim();

  const recommendedUsers = candidateUsers
    .filter((user) => user.userId !== currentUserId)
    .map((user) => scoreUser(user, body))
    .sort((a, b) => b.matchScore - a.matchScore)
    .map((user, index) => ({
      userId: user.userId,
      displayName: user.displayName,
      sharedInterests: user.sharedInterests,
      travelIntensityCompatibility: compatibilityLabel(user, requestedIntensity),
      shortMatchReason: user.profileSummary,
      distanceKm: user.distanceKm,
      safetyRating: user.safetyRating,
      matchScore: user.matchScore,
      matchRank: index + 1,
    }));

  return {
    recommendedUsers,
    messageToUser:
      '已根据你的城市、兴趣、旅行节奏、距离和安全评分，为你按综合匹配度排序推荐旅伴。',
  };
}

async function createChatKitSession(request, response) {
  if (!process.env.OPENAI_API_KEY) {
    jsonResponse(response, 500, {
      error: 'Missing OPENAI_API_KEY. Keep it on the backend, never in Flutter.',
    });
    return;
  }

  const body = await readJson(request);
  const user = String(body.user ?? body.currentuserid ?? 'preview_user');
  const openaiResponse = await fetch('https://api.openai.com/v1/chatkit/sessions', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${process.env.OPENAI_API_KEY}`,
      'Content-Type': 'application/json',
      'OpenAI-Beta': 'chatkit_beta=v1',
    },
    body: JSON.stringify({
      workflow: { id: workflowId },
      user,
    }),
  });

  const payload = await openaiResponse.json();
  jsonResponse(response, openaiResponse.status, payload);
}

const server = http.createServer(async (request, response) => {
  try {
    if (request.method === 'OPTIONS') {
      jsonResponse(response, 204, {});
      return;
    }

    const url = new URL(request.url ?? '/', `http://${request.headers.host}`);

    if (request.method === 'GET' && url.pathname === '/health') {
      jsonResponse(response, 200, { ok: true, workflowId });
      return;
    }

    if (request.method === 'POST' && url.pathname === '/api/social-match') {
      const body = await readJson(request);
      jsonResponse(response, 200, buildSocialMatch(body));
      return;
    }

    if (request.method === 'POST' && url.pathname === '/api/chatkit/session') {
      await createChatKitSession(request, response);
      return;
    }

    jsonResponse(response, 404, { error: 'Not found' });
  } catch (error) {
    jsonResponse(response, 500, { error: String(error?.message ?? error) });
  }
});

server.listen(port, () => {
  console.log(`WanderJoy backend listening on http://localhost:${port}`);
});
