declare global {
  namespace Express {
    interface Request {
      auth?: {
        userId: string;
        phone: string;
      };
      roleSession?: {
        role: 'RIDER' | 'MERCHANT';
        profileId: string;
      };
    }
  }
}

export {};

