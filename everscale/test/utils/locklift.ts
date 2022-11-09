import BigNumber from "bignumber.js";
const logger = require('mocha-logger');
const chai = require('chai')

chai.use(require('chai-bignumber')());

export const locklift: LockLift = global.locklift;

export type Address = `0:${string}`;
export const isValidTonAddress = (address: string): address is Address => /^(?:-1|0):[0-9a-fA-F]{64}$/.test(address);

namespace ABI {

  export type TypeLabelPrimitive = `uint${number}` | `int${number}` | "address" | "bool" | "cell";
  export type TypeLabelComplex = `optional(${TypeLabelPrimitive})` | `mapping(${TypeLabelPrimitive},${"tuple" | TypeLabelPrimitive}})`;
  export type Input = { name: string; type: TypeLabelPrimitive | TypeLabelComplex; };
  export type InputComponents = { components: Input[]; };
  export type Output = { name: string; type: TypeLabelPrimitive | TypeLabelComplex; };
  export type Data = { key: number; name: string; type: TypeLabelPrimitive; };
  export type Function = {
    name: string;
    inputs: (Input | InputComponents)[];
    outputs: Output[];
  };

  export type Instance = {
    "ABI version": number;
    version: `${number}`;
    header: string[];
    functions: Function[];
    data: Data[];
    events: Function[];
    fields: { name: string; type: TypeLabelComplex; }[];
  };
}
/** TIP4.2
 *  Non-Fungible Token JSON Metadata Standard
 *
 *  See: https://github.com/nftalliance/docs/blob/main/src/standard/TIP-4/2.md for reference.
 * */

export namespace TIP4 {
  export type NftMetadata = {
    id: number;
    type: string;
    name: string;
    description: string;
    preview: {
      source: string;
      mimetype: string;
    };
    files: {
      source: string;
      mimetype: string;
    }[];
    external_url: string;
  };

  export const DEFAULT = {
    id: 0,
    name: '',
    type: '',
    description: '',
    preview: { source: '', mimetype: '' },
    files: [],
    external_url: ''
  }
}

export interface LockLift {
  network: string;
  factory: { getContract: (contract: string, build?: string) => Promise<Contract>; getAccount: (type: string) => Promise<Account>; };
  keys: { getKeyPairs: () => Promise<KeyPair[]>; };
  utils: {
    getRandomNonce(); convertCrystal: (balance: number | `${number}`, type: 'nano' | string) => string; zeroAddress: Address;
  };
  ton: {
      client: any; getBalance: (address: Address) => Promise<BigNumber>; 
};
  giver: Giver;
}

export interface KeyPair { public: string; secret: string; }

export interface Contract {
  setKeyPair(keyPair: KeyPair);
  afterRun: any;
  name: string;
  address: Address;
  keyPair: KeyPair;
  code: string;
  abi: ABI.Instance;
  setAddress: (address: Address) => void;
  call: (opts: { method: string; params?: any; }) => Promise<any>;
}

export interface Giver {
  giver: Account;
  deployContract: (opts: { contract: Contract; constructorParams: any; initParams: any; keyPair?: KeyPair; }, value?: string) => Promise<Contract>;
}

export interface Account extends Contract {
  setKeyPair: (keyPair: KeyPair) => void;
  deployContract: (opts: { contract: Contract; constructorParams: any; initParams: any; keyPair: KeyPair; }, value?: string) => Promise<Contract>;
  runTarget: (opts: { contract: Contract; method: string; params: any; keyPair?: KeyPair; value?: string; }) => Promise<Tx>;
  run: (opts: { method: string; params: any; keyPair?: KeyPair; }) => Promise<Tx>;
}

export interface Tx {
  transaction: {
    json_version: number;
    id: string;
    boc: string;
    status: number;
    status_name: string;
    storage: {
      storage_fees_collected: string;
      status_change: number;
      status_change_name: string;
    };
    action: {
      success: boolean;
      valid: boolean;
      no_funds: boolean;
      result_code: number;
    };
    now: number;
    in_msg: string;
    out_msgs: string[];
    account_addr: string;
    old_hash: string;
    new_hash: string;
  };
  out_messages: string[];
}

export const getRandomNonce = () => Math.random() * 64000 | 0;
export const toAddrs = (i: number): Address => {
  let zeroAddrs = locklift.utils.zeroAddress;
  let si = i.toString();
  return zeroAddrs.substr(0, zeroAddrs.length - si.length).concat(si) as Address
}

export async function logContract(contract: Contract) {
  const balance = await locklift.ton.getBalance(contract.address);
  logger.log(`${contract.name} (${contract.address}) - ${locklift.utils.convertCrystal(balance.toNumber(), 'ton')}`);
}

export async function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

export async function afterRun() {
  if (locklift.network === 'dev' || locklift.network === 'prod') {
    await sleep(100000);
  }
};

export async function getAccount(keyPair: KeyPair, address: Address): Promise<Account> {
  const account = await locklift.factory.getAccount("Wallet");
  account.setKeyPair(keyPair);
  account.setAddress(address);
  return account;
}

export async function deployAccount(keyPair: KeyPair, balance: number, name = 'Account'): Promise<Account> {
  const _randomNonce = locklift.utils.getRandomNonce();

  // Deploy initializer account
  const Account = await locklift.factory.getAccount('Wallet');
  const account = await locklift.giver.deployContract({
    contract: Account,
    constructorParams: {},
    initParams: {
      _randomNonce,
    },
    keyPair,
  }, locklift.utils.convertCrystal(20, 'nano'));

  account.setKeyPair(keyPair);
  account.afterRun = afterRun;
  account.name = name;

  return account as Account;
}