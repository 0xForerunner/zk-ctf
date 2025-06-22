// Next.js API route support: https://nextjs.org/docs/api-routes/introduction
import type { NextApiRequest, NextApiResponse } from "next";
import { createAccountAndDeployContract } from "./deploy"

let isRunning = false;

export default async function handler(req: any, res: any) {
  if (isRunning) {
    return res.status(409).json({ message: 'Already running' });
  }

  try {
    isRunning = true;
    await createAccountAndDeployContract();
    res.status(200).json({ success: true });
  } catch (error) {
    console.error('Deploy error:', error);
    res.status(500).json({ 
      success: false, 
      error: error instanceof Error ? error.message : 'Unknown error' 
    });
  } finally {
    isRunning = false;
  }
}
