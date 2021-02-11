const ethUtil = require('ethereumjs-util');
const sigUtil = require('eth-sig-util');
const utils = sigUtil.TypedDataUtils;

//Our lad Cal wants to send 2 dai to del, by signing a cheque and paying a 1 dai fee to msg.sender

const calprivKeyHex = '4af1bceebf7f3634ec3cff8a2c38e51178d5d4ce585c52d6043e5e2cc3418bb0'
const calprivKey = new Buffer(calprivKeyHex, 'hex')
const cal = ethUtil.privateToAddress(calprivKey);
//const Registrar = new Buffer('2D6B98058E84Dcb8b57fb8C79613bD858af65975', 'hex');
const del = new Buffer('dd2d5d3f7f1b35b7a0601d6a00dbb7d44af58479', 'hex');
const dai = new Buffer('E58d97b6622134C0436d60daeE7FBB8b965D9713', 'hex');
console.log('cals address: ' + '0x' + cal.toString('hex'));
console.log('dels address: ' + '0x' + del.toString('hex'));
let typedData = {
  types: {
      EIP712Domain: [
          { name: 'name', type: 'string' },
          { name: 'chainId', type: 'uint256' },
          { name: 'verifyingContract', type: 'address' },
      ],
    Commit: [
          { name: 'commitment', type: 'bytes32' }, 
          { name: 'nonce', type: 'uint256' },
          { name: 'expiry', type: 'uint256' },
          { name: 'submissionFee', type: 'uint256' },
      ],
  },
  primaryType: 'Commit',
  domain: {
      name: 'Registrar',
      chainId: 1,
      verifyingContract: '0xfcbcd8c32305228f205c841c03f59d2491f92cb4', //in hevm
  },
  message: {
    commitment: '0x23ac000000000000000000000000000000000000000000000000000000000000',
    nonce: 0,
    expiry: '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
    submissionFee: 0
  },
};

let hash = ethUtil.bufferToHex(utils.hashType('EIP712Domain', typedData.types))

console.log('EI712Domain typehash: ' + hash);
hash = ethUtil.bufferToHex(utils.hashStruct('EIP712Domain', typedData.domain, typedData.types))
console.log('EIP712DomainHash: ' + hash);
hash = ethUtil.bufferToHex(utils.hashType('Commit', typedData.types))
console.log('Commit Typehash: ' + hash);
hash = ethUtil.bufferToHex(utils.hashStruct('Commit', typedData.message, typedData.types))
console.log('Commit hash: ' + hash);
const sig = sigUtil.signTypedData(calprivKey, { data: typedData });
console.log('signed commit: ' + sig);

let r = sig.slice(0,66);
let s = '0x'+ sig.slice(66,130);
let v = ethUtil.bufferToInt(ethUtil.toBuffer('0x'+sig.slice(130,132),'hex'));

console.log('r: ' + r)
console.log('s: ' + s)
console.log('v: ' + v)
