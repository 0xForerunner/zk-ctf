// Next.js API route support: https://nextjs.org/docs/api-routes/introduction
import type { NextApiRequest, NextApiResponse } from 'next';
export type Logs = {
  name: string;
};

export default function handler(req: any, res: any) {
  const logs = [
    {
      id: '1',
      action: 'Created CTF contract. Whoever holds the flag the longest wins!',
    },
    {
      id: '2',
      action: 'CTF contract is initialized for the context to last 10 blocks.',
    },
    {
      id: '3',
      action: 'Wallet 1 joins the game and grabs the flag.',
      timestamp: '2025-01-21T10:32:30Z',
    },
    {
      id: '4',
      action: 'Wallet 3 joins the game.',
      timestamp: '2025-01-21T10:33:45Z',
    },
    {
      id: '5',
      action: 'Wallet 3 challenges Wallet 1 for the flag.',
    },
    {
      id: '6',
      action: 'Block mined',
    },
    {
      id: '7',
      action: 'Block mined',
    },
    {
      id: '8',
      action:
        'Wallet 1 responds to the challenge and loses the flag to wallet 3',
    },
    {
      id: '9',
      action: 'Block mined',
    },
    {
      id: '10',
      action: 'Block mined - game is now over, no more points can be earned',
    },
    {
      id: '11',
      action: 'Block mined',
    },
    {
      id: '12',
      action: 'Block mined',
    },
    {
      id: '13',
      action: 'Block mined',
    },
    {
      id: '14',
      action: 'Block mined',
    },
    {
      id: '15',
      action: 'Block mined',
    },
    {
      id: '16',
      action: 'Block mined',
    },
    {
      id: '17',
      action: 'Wallet 1 reveals their score',
    },
    {
      id: '18',
      action: 'Block mined',
    },
    {
      id: '19',
      action: 'Wallet 3 reveals their score',
    },
    {
      id: '20',
      action: 'Block mined',
    },
    {
      id: '21',
      action: 'Block mined',
    },
    {
      id: '22',
      action: 'The winner is revealed - Wallet 3 wins with a score 6!',
    }
]
  res.status(200).json(logs);
}
