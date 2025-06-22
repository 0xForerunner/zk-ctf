// Next.js API route support: https://nextjs.org/docs/api-routes/introduction
import type { NextApiRequest, NextApiResponse } from 'next';
import fs from 'fs';
import path from 'path';

export type Logs = {
  name: string;
};

export default function handler(req: any, res: any) {
  const LOG_FILE_PATH = path.join('log.json');
  
  try {
    if (fs.existsSync(LOG_FILE_PATH)) {
      const data = fs.readFileSync(LOG_FILE_PATH, 'utf8');
      const logs = JSON.parse(data);
      res.status(200).json(logs);
    } else {
      res.status(200).json([]);
    }
  } catch (error) {
    res.status(200).json([]);
  }
}
