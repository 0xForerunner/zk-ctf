# Dude, Where's My Flag?

![Flag](assets/flag.png)

A fully on chain, incomplete information based version of capture the flag!

### How to play

A user can create a game with various parameters

- start - The block height for when the game should start
- end - The block height for when the game should stop
- claim - The block height for when the pot can be claimed
- spend_limit - The maximum amount a user can spend on challenges
- challenge_fee - The amount of tokens required per challenge
- deposit_size - The deposit required, which is lost upon being slashed
- token - The token address that fees will be collected in

Once the game starts, a user will be selected who holds the flag.
In the future, we could implement a private bidding system to decide who starts with the flag.

If you don't currently hold the flag, you won't know who has it. 
Users can then submit challenges along with a small fee in an attempt to steal the flag from an address they suspect might hold it.
If the guess is correct, the challenger receives the flag. 
The winner is determined by whoever has held onto the flag for the longest duration and they receive the pot (sum of all chellenge fees).

One of the main challenges with this project is finding a way around having true shared private state (something that you might find in MPC for example).
We get around this by having the flag location and capture time be held in each users private state. 
To appropriatly release this information during a challenge we use a challenge and response architecture.
If a user fails to respond to a challenge, they may be slashed, losing their deposit.
When responding to a challenge a few things happen:

- The responder gets a new note both for their updated tally, and to update their status of not having the flag.
This happens regardless of wether they had the flag or not, since optionally nullifying their notes would give away the result of the challenge to observers (something we don't want).
- The challenger get a new note for their flag holding status (also issued regardless of wether they actually got it or not)
- The challenge is publically acked so the responder can no longer be slashed

All users can see when challenges are submited and responded to; However, only the challenger and responder are aware if the challenge was successful or not.
This creates a game environment with incomplete knowledge, and should encourage some interesting strategies to show up!

### Setup

1. Install the Aztec tools from the first few steps in [Quick Start Guide](https://docs.aztec.network/developers/getting_started).

Please note that this project uses `0.87.9` version of Aztec SDK. If you wish to use a different version, please update the dependencies in the `app/package.json` and in `contracts/Nargo.toml` file to match your version.

You can install a specific version of Aztec tools by running `aztec-up 0.X.X`


2. Compile smart contracts in `/contracts` and move into nextjs folder

```sh
yarn build-contracts
mv app/artifacts/* nextjs/my-app/pages/api/

```

The build script compiles the contract and generates the artifacts.

3. Deploy the contracts

Run the sandbox
```sh
aztec start --sandbox
```

The deploy script generates a few random accounts that repeatedly capture the flag from each other.

The script also writes the deployment info to `.env` (which our web-app reads from).

> Note that the script generates many client proofs and it may take a couple of seconds. For faster development, you can disable proving by calling with `PROVER_ENABLED=false` (Sandbox accepts transactions without a valid proof).

4. Run the app (development mode) and 

```sh
npm run dev

open http://localhost:3000

API call to http://localhost:3000/api/start to start the flow

```
