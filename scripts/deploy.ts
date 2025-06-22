import fs from 'fs';
import path from 'path';
import {
  AztecAddress,
  createAztecNodeClient,
  DeployMethod,
  Fr,
  getContractInstanceFromDeployParams,
  PublicKeys,
  type PXE,
  SponsoredFeePaymentMethod,
  type Wallet,
} from '@aztec/aztec.js';
import { computeAuthWitMessageHash } from "@aztec/aztec.js";
import { createPXEService, getPXEServiceConfig } from '@aztec/pxe/server';
import { getEcdsaRAccount } from '@aztec/accounts/ecdsa';
import { createStore } from '@aztec/kv-store/lmdb';
import { getDefaultInitializer } from '@aztec/stdlib/abi';
import { SponsoredFPCContractArtifact } from '@aztec/noir-contracts.js/SponsoredFPC';
import { SPONSORED_FPC_SALT } from '@aztec/constants';
// @ts-ignore
import { CTFContract } from '../app/artifacts/CTF.ts';
import { ADDRGETNETWORKPARAMS } from 'dns';
import { CheatCodes } from '@aztec/aztec.js/testing';
import { WALLETS } from './generate_wallets.ts';
import { TokenContract } from '@aztec/noir-contracts.js/Token';

const AZTEC_NODE_URL = process.env.AZTEC_NODE_URL || 'http://localhost:8080';
const PROVER_ENABLED = process.env.PROVER_ENABLED === 'false' ? false : true;
const WRITE_ENV_FILE = process.env.WRITE_ENV_FILE === 'false' ? false : true;

const PXE_STORE_DIR = path.join(import.meta.dirname, '.store');

async function setupPXE() {
  const aztecNode = createAztecNodeClient(AZTEC_NODE_URL);

  fs.rmSync(PXE_STORE_DIR, { recursive: true, force: true });

  const store = await createStore('pxe', {
    dataDirectory: PXE_STORE_DIR,
    dataStoreMapSizeKB: 1e6,
  });

  const config = getPXEServiceConfig();
  config.dataDirectory = 'pxe';
  config.proverEnabled = false;
  const configWithContracts = {
    ...config,
  };

  const pxe = await createPXEService(
    aztecNode,
    configWithContracts,
    {
      store,
      useLogSuffix: true,
    },
  );
  return pxe;
}

async function getSponsoredPFCContract() {
  const instance = await getContractInstanceFromDeployParams(
    SponsoredFPCContractArtifact,
    {
      salt: new Fr(SPONSORED_FPC_SALT),
    }
  );

  return instance;
}

async function createAccount(pxe: PXE, index: number) {

  // const {salt, secretKey, signingKey} = WALLETS[index]

  // let saltFormat = Fr.fromHexString(salt)
  // let secretKeyFormat = Fr.fromHexString(secretKey)
  // let signingKeyFormat = new Buffer(signingKey, 'hex')
  // const ecdsaAccount = await getEcdsaRAccount(pxe, secretKeyFormat, signingKeyFormat, saltFormat);

  const salt = Fr.random();
  const secretKey = Fr.random();  
  const signingKey = Buffer.alloc(32, Fr.random().toBuffer());
  const ecdsaAccount = await getEcdsaRAccount(pxe, secretKey, signingKey, salt);

  const deployMethod = await ecdsaAccount.getDeployMethod();
  const sponsoredPFCContract = await getSponsoredPFCContract();
  const deployOpts = {
    contractAddressSalt: Fr.fromString(ecdsaAccount.salt.toString()),
    fee: {
      paymentMethod: await ecdsaAccount.getSelfPaymentMethod(
        new SponsoredFeePaymentMethod(sponsoredPFCContract.address)
      ),
    },
    universalDeploy: true,
    skipClassRegistration: true,
    skipPublicDeployment: true,
  };
  const provenInteraction = await deployMethod.prove(deployOpts);
  await provenInteraction.send().wait({ timeout: 120 });

  await ecdsaAccount.register();
  const wallet = await ecdsaAccount.getWallet();

  return {
    wallet,
    signingKey,
  };
}

async function deployContract(pxe: PXE, deployer: Wallet) {
  const salt = Fr.random();
  const contract = await getContractInstanceFromDeployParams(
    CTFContract.artifact,
    {
      publicKeys: PublicKeys.default(),
      constructorArtifact: getDefaultInitializer(
        CTFContract.artifact
      ),
      constructorArgs: [deployer.getAddress().toField()],
      deployer: deployer.getAddress(),
      salt,
    }
  );

  const deployMethod = new DeployMethod(
    contract.publicKeys,
    deployer,
    CTFContract.artifact,
    (address: AztecAddress, wallet: Wallet) =>
    CTFContract.at(address, wallet),
    [deployer.getAddress().toField()],
    // getDefaultInitializer(CTFContract.artifact)?.name
  );

  const sponsoredPFCContract = await getSponsoredPFCContract();

  const provenInteraction = await deployMethod.prove({
    contractAddressSalt: salt,
    fee: {
      paymentMethod: new SponsoredFeePaymentMethod(
        sponsoredPFCContract.address
      ),
    },
  });
  await provenInteraction.send().wait({ timeout: 120 });
  await pxe.registerContract({
    instance: contract,
    artifact: CTFContract.artifact,
  });

  return {
    contractAddress: contract.address.toString(),
    deployerAddress: deployer.getAddress().toString(),
    deploymentSalt: salt.toString(),
  };
}

async function deployTokenContract(pxe: PXE, deployer: Wallet) {

  console.log("DEPLOYER WALLTE ADDRESS IS ", deployer.getAddress());
  const deployMethod = TokenContract.deploy(deployer, deployer.getAddress(), 'Token', 'TKN', 18);
  const salt = Fr.random();
  const contract = await getContractInstanceFromDeployParams(
    TokenContract.artifact,
    {
      publicKeys: PublicKeys.default(),
      constructorArtifact: getDefaultInitializer(
        TokenContract.artifact
      ),
      constructorArgs: [deployer.getAddress().toField(), 'Token', 'TKN', 18],
      deployer: deployer.getAddress(),
      salt,
    }
  );

  const sponsoredPFCContract = await getSponsoredPFCContract();

  const provenInteraction = await deployMethod.prove({
    contractAddressSalt: salt,
    fee: {
      paymentMethod: new SponsoredFeePaymentMethod(
        sponsoredPFCContract.address
      ),
    },
  });
  await provenInteraction.send().wait({ timeout: 120 });
  await pxe.registerContract({
    instance: contract,
    artifact: TokenContract.artifact,
  });

  return {
    contractAddress: contract.address.toString(),
    deployerAddress: deployer.getAddress().toString(),
    deploymentSalt: salt.toString(),
  };
}


async function writeEnvFile(deploymentInfo, fileName) {
  const envFilePath = path.join(import.meta.dirname, `../.${fileName}`);
  const envConfig = Object.entries({
    CONTRACT_ADDRESS: deploymentInfo.contractAddress,
    DEPLOYER_ADDRESS: deploymentInfo.deployerAddress,
    DEPLOYMENT_SALT: deploymentInfo.deploymentSalt,
    AZTEC_NODE_URL,
  })
    .map(([key, value]) => `${key}=${value}`)
    .join('\n');

  fs.writeFileSync(envFilePath, envConfig);

  console.log(`
      \n\n\n
      Contract deployed successfully. Config saved to ${envFilePath}
      IMPORTANT: Do not lose this file as you will not be able to recover the contract address if you lose it.
      \n\n\n
    `);
}

async function createAccountAndDeployContract() {
  const pxe = await setupPXE();
  const ethRpcUrl = "http://localhost:8545";

  const cc = await CheatCodes.create([ethRpcUrl], pxe);

  // Register the SponsoredFPC contract (for sponsored fee payments)
  await pxe.registerContract({
    instance: await getSponsoredPFCContract(),
    artifact: SponsoredFPCContractArtifact,
  });

  // Create a new account
  const { wallet: wallet1, /* signingKey */ } = await createAccount(pxe, 0);
  const { wallet: wallet2, /* signingKey */ } = await createAccount(pxe, 1);
  const { wallet: wallet3, /* signingKey */ } = await createAccount(pxe, 2);

  const deploymentInfo = await deployContract(pxe, wallet1);

  const tokenDeploymentInfo = await deployTokenContract(pxe, wallet1)

  await writeEnvFile(tokenDeploymentInfo,'env.token');
  await writeEnvFile(deploymentInfo,'env.main');
  
  // TODO: CAN BE REPLACED
  const contractAddress = deploymentInfo.contractAddress
  // const contractAddress = '0x0ba2df805eeef88c7c78fc99eae684058170a8560df42184652f2ff00b9ff847'

  const blockNumber = await pxe.getBlockNumber()

  // const tokenContract1 = await TokenContract.at(
  //   AztecAddress.fromString(tokenDeploymentInfo.contractAddress),
  //   wallet1
  // );

  // const tokenContract3 = await TokenContract.at(
  //   AztecAddress.fromString(tokenDeploymentInfo.contractAddress),
  //   wallet3
  // );

  // Prepare the sponsored fee payment method
  const sponsoredPFCContract = await getSponsoredPFCContract();
  const sponsoredPaymentMethod = new SponsoredFeePaymentMethod(sponsoredPFCContract.address);
  
  // const bigAmount = 10000000000000000;
  // const smallAmount = 1000000000;

  // await tokenContract1.methods.mint_to_public(wallet1.getAddress(), bigAmount).send({
  //   fee: { paymentMethod: sponsoredPaymentMethod }
  // }).wait()

  // console.log("minted public to wallet 1");

  // await tokenContract1.methods.mint_to_private(wallet1.getAddress(), wallet1.getAddress(), smallAmount).send({
  //   fee: { paymentMethod: sponsoredPaymentMethod }
  // }).wait()

  // console.log("minted private to wallet 1");

  // await tokenContract1.methods.mint_to_public(wallet3.getAddress(), bigAmount).send({
  //   fee: { paymentMethod: sponsoredPaymentMethod }
  // }).wait()

  // console.log("minted public to wallet 3");

  // await tokenContract1.methods.mint_to_private(wallet3.getAddress(), wallet3.getAddress(), smallAmount).send({
  //   fee: { paymentMethod: sponsoredPaymentMethod }
  // }).wait()


  // console.log("minted private to wallet 3");

  // const wallet3PrivateBalance = await tokenContract3.methods.balance_of_private(wallet3.getAddress()).simulate()
  // console.log("wallet3PrivateBalance", wallet3PrivateBalance);

  const contract1 = await CTFContract.at(
      AztecAddress.fromString(contractAddress),
      wallet1
  );

    // const contract2 = await CTFContract.at(
    //   AztecAddress.fromString(contractAddress),
    //   wallet2
    // );

    const contract3 = await CTFContract.at(
      AztecAddress.fromString(contractAddress),
      wallet3
    );

    const depositAmount = 1000000000;

    await contract1.methods.initialize(
      blockNumber,
      blockNumber + 10,
      blockNumber + 15,
      0,
      1000,
      depositAmount,
      // @ts-ignore a
      tokenDeploymentInfo.contractAddress
      ).send({
      fee: { paymentMethod: sponsoredPaymentMethod }
    }).wait();

    console.log("INIT THE GAME")

    contract1.methods.join(true).send({
      fee: { paymentMethod: sponsoredPaymentMethod }
    }).wait()


    await contract3.methods.join(false).send({
      fee: { paymentMethod: sponsoredPaymentMethod }
    }).wait()

    console.log("User 3 joined the game")

    // User 3 challenges user 1 for the flag
    await contract3.methods.challenge(wallet1.getAddress()).send({
      fee: { paymentMethod: sponsoredPaymentMethod }
    }).wait();

    console.log("User 3 challenges user 1");

    await mine_block(2, contract1, sponsoredPaymentMethod)

    // // User 1 responds to challenge and User 3 gets the flag
    await contract1.methods.respond(wallet3.getAddress()).send({
      fee: { paymentMethod: sponsoredPaymentMethod }
    }).wait();

    console.log("User 1 responds to challenge and loses the flag :(");

    await mine_block(8, contract1, sponsoredPaymentMethod)

    await contract1.methods.submit_score().send({
      fee: { paymentMethod: sponsoredPaymentMethod }
    }).wait();

    console.log("user 1 submits the score")

    await mine_block(2, contract1, sponsoredPaymentMethod)

    await contract3.methods.submit_score().send({
      fee: { paymentMethod: sponsoredPaymentMethod }
    }).wait();

    console.log("user 3 submits the score")

    await mine_block(2, contract1, sponsoredPaymentMethod)

    const winner = await contract1.methods.winner().simulate({
      fee: { paymentMethod: sponsoredPaymentMethod }
    })
    console.log("winner is....hopefully user 3", winner)

    const winnerScore = await contract1.methods.winner_score().simulate({
      fee: { paymentMethod: sponsoredPaymentMethod }
    })

    console.log("winner score", winnerScore)

    const player1Score = await contract1.methods.user_score(wallet1.getAddress()).simulate({
      fee: { paymentMethod: sponsoredPaymentMethod }
    })

    const player3Score = await contract1.methods.user_score(wallet3.getAddress()).simulate({
      fee: { paymentMethod: sponsoredPaymentMethod }
    })

    console.log("player 1 score", player1Score)
    console.log("player 3 score", player3Score)

  // // Clean up the PXE store
  fs.rmSync(PXE_STORE_DIR, { recursive: true, force: true });
}

async function mine_block(count: number, contract: any, sponsoredPaymentMethod: any) {
  for(let i = 0; i < count; i++) {
    await contract.methods.nothing().send({
      fee: { paymentMethod: sponsoredPaymentMethod }
    }).wait();

    console.log("Mined block");
  }
}

createAccountAndDeployContract().catch((error) => {
  console.error(error);
  process.exit(1);
});

export { createAccountAndDeployContract };
