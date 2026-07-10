// An abstraction that works with local memory or Redis for Horizontal Scaling

export class DuelQueueManager {
  private memoryQueue: Record<string, string[]> = {
    'MATH_DASH': [],
    'QUIZ_PLANET': [],
    'WORD_QUEST': [],
    'GRAVITY_RUN': []
  };

  private redisClient: any = null;

  constructor() {
    const redisUrl = process.env.REDIS_URL;
    if (redisUrl && redisUrl.trim() !== '') {
      try {
        // Try importing ioredis dynamically to avoid crash if not installed
        // eslint-disable-next-line @typescript-eslint/no-var-requires
        const IoRedis = require('ioredis');
        this.redisClient = new IoRedis(redisUrl);
        console.log('🔌 Connected to Redis for Duel Queue scaling');
      } catch (err) {
        console.log('ℹ️ Redis client (ioredis) not found or could not connect. Using local in-memory fallback.');
      }
    }
  }

  async joinQueue(gameType: string, userId: string): Promise<string[]> {
    if (this.redisClient) {
      const key = `queue:${gameType}`;
      const inQueue = await this.redisClient.lrange(key, 0, -1);
      if (!inQueue.includes(userId)) {
        await this.redisClient.rpush(key, userId);
      }
      return this.redisClient.lrange(key, 0, -1);
    } else {
      if (!this.memoryQueue[gameType]) {
        this.memoryQueue[gameType] = [];
      }
      if (!this.memoryQueue[gameType].includes(userId)) {
        this.memoryQueue[gameType].push(userId);
      }
      return this.memoryQueue[gameType];
    }
  }

  async leaveQueue(gameType: string, userId: string): Promise<void> {
    if (this.redisClient) {
      const key = `queue:${gameType}`;
      await this.redisClient.lrem(key, 0, userId);
    } else {
      if (this.memoryQueue[gameType]) {
        this.memoryQueue[gameType] = this.memoryQueue[gameType].filter(id => id !== userId);
      }
    }
  }

  async getMatch(gameType: string): Promise<{ p1: string; p2: string } | null> {
    if (this.redisClient) {
      const key = `queue:${gameType}`;
      const len = await this.redisClient.llen(key);
      if (len >= 2) {
        const p1 = await this.redisClient.lpop(key);
        const p2 = await this.redisClient.lpop(key);
        if (p1 && p2) {
          return { p1, p2 };
        }
        if (p1) await this.redisClient.lpush(key, p1);
      }
      return null;
    } else {
      if (this.memoryQueue[gameType] && this.memoryQueue[gameType].length >= 2) {
        const p1 = this.memoryQueue[gameType].shift()!;
        const p2 = this.memoryQueue[gameType].shift()!;
        return { p1, p2 };
      }
      return null;
    }
  }
}

export const queueManager = new DuelQueueManager();
