import {
    Fr,
  } from '@aztec/aztec.js';
  

// async function createAccount() {
//     const salt = Fr.random();
//     const secretKey = Fr.random();

    
//     const signingKey = Buffer.alloc(32, Fr.random().toBuffer());

//     // const signingKey3 = 

//     console.log(salt)
//     console.log(secretKey)
//     console.log(signingKey.toString('hex'))

//     console.log()
// }

// createAccount();
// createAccount();
// createAccount();


export const WALLETS = [
    {
        salt: '2ecc2d714777ede9e15cf09f5718ebd76d003abc24756aeada0421614680a8c6',
        secretKey: '0fd502b355f598818139a4de739c78f3b42e5c4f34dd040ed93d66913eb43ffb',
        signingKey: '10bb7c5aaccf3b4fa751570f2b9142ffacf290eee7432d103e23ec0e0775f694'
    },
    {
        salt: '050a69af47596793a1ab3d3ee95fcb421ccbb21080dfd2e945f3cb4e405d1be8',
        secretKey: '0d6e5c7080be6d6ebabf6548892d7471bceb80ae0eaaf7ea8ef2ffacf2434e05',
        signingKey: '1e67112da4bd20d5868f7cc22483f6585d5d0c6abcab030e3335fa7e11a8386f'
    },
    {
        salt: '0282c198a7a5d9f8497b3de69630b68b17cd8a333b48e537d0e47def3a67dac6',
        secretKey: '0033e1ce64fad1d58a7a2cbfacc5d12e22fb4ba339ea51b16150d66d7380f7e7',
        signingKey: '1f802bde469ea938ab7ed7ed6c6088ff1caee5e009f6bd5ed5af78cf7741f058'
    },

]