pragma solidity ^0.7.5;
pragma abicoder v2;

import {Phase0}       from "radicle-contracts/deploy/phase0.sol";
import {RadicleToken} from "radicle-contracts/Governance/RadicleToken.sol";
import {Governor}     from "radicle-contracts/Governance/Governor.sol";
import {Timelock}     from "radicle-contracts/Governance/Timelock.sol";

import {ENS}           from "@ensdomains/ens/contracts/ENS.sol";
import {ENSRegistry}   from "@ensdomains/ens/contracts/ENSRegistry.sol";
import {IERC721}       from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import {DSTest}       from "ds-test/test.sol";
import {Hevm, Utils}  from "./Utils.sol";

contract RadUser {
    RadicleToken rad;
    Governor   gov;
    Timelock timelock;
    constructor (RadicleToken rad_, Governor gov_, Timelock timelock_) {
        rad = rad_;
        gov = gov_;
        timelock = timelock_;
    }
    function delegate(address to) public {
        rad.delegate(to);
    }
    function transfer(address to, uint amt) public {
        rad.transfer(to, amt);
    }
    function burn(uint amt) public {
        rad.burnFrom(address(this), amt);
    }

    function propose(address target, string memory sig, bytes memory cd) public returns (uint) {
        address[] memory targets = new address[](1);
        uint[] memory values = new uint[](1);
        string[] memory sigs = new string[](1);
        bytes[] memory calldatas = new bytes[](1);
        targets[0] = target;
        values[0] = 0;
        sigs[0] = sig;
        calldatas[0] = cd;
        return gov.propose(targets, values, sigs, calldatas, "");
    }
    function queue(uint proposalId) public {
        gov.queue(proposalId);
    }
    function castVote(uint proposalId, bool support) public {
        gov.castVote(proposalId, support);
    }

    function queueTimelock(address target, string memory sig, bytes memory cd, uint256 eta) public {
        timelock.queueTransaction(target, 0, sig, cd, eta);
    }
    function executeTimelock(address target, string memory sig, bytes memory cd, uint256 eta) public {
        timelock.executeTransaction(target, 0, sig, cd, eta);
    }

    function accept() public {
        timelock.acceptAdmin();
    }
}

contract GovernanceTest is DSTest {
    Governor gov;
    RadicleToken rad;
    RadUser usr;
    RadUser ali;
    RadUser bob;
    RadUser cal;
    Timelock timelock;

    uint x; // only writeable by timelock

    Hevm hevm = Hevm(HEVM_ADDRESS);

    function setUp() public {
        Phase0 phase0 = new Phase0( address(this)
                                  , 2 days
                                  , address(0)
                                  , ENS(address(this))
                                  , "namehash"
                                  , "label"
                                  );

        rad      = phase0.token();
        timelock = phase0.timelock();
        gov      = phase0.governor();

        usr = new RadUser(rad, gov, timelock);
        ali = new RadUser(rad, gov, timelock);
        bob = new RadUser(rad, gov, timelock);
        cal = new RadUser(rad, gov, timelock);
        // proposal threshold is 1%
        rad.transfer(address(ali), 500_000 ether);
        rad.transfer(address(bob), 500_001 ether);
        // quorum is 4%
        rad.transfer(address(cal), 5_000_000 ether);
    }

    function test_deploy() public {
        uint gas_before = gasleft();
        Phase0 phase0 = new Phase0( address(this)
                                  , 2 days
                                  , address(this)
                                  , ENS(address(this))
                                  , "namehash"
                                  , "label"
                                  );
        uint gas_after = gasleft();
        log_named_uint("deployment gas", gas_before - gas_after);
    }

    function test_radAddress() public {
        assertEq(address(rad), address(0x25E827B40a7D04de0D177BB228A99F69b83fA7FC));
    }

    function test_domainSeparator() public {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        bytes32 DOMAIN = rad.DOMAIN_SEPARATOR();
        assertEq(DOMAIN,
                 keccak256(
                           abi.encode(
                                      keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)"),
                                      keccak256(bytes(rad.NAME())),
                                      chainId,
                                      address(rad))));
        log_named_bytes32("DOMAIN_SEPARATOR()", DOMAIN);
    }

    // generated with
    // export NONCE=0; export ETH_KEYSTORE=./secrets; export ETH_PASSWORD=./secrets/radical; export ETH_FROM=0xd521c744831cfa3ffe472d9f5f9398c9ac806203
    // ./bin/permit 0x25E827B40a7D04de0D177BB228A99F69b83fA7FC 100 -1
    function test_permit() public {
        address owner = 0xD521C744831cFa3ffe472d9F5F9398c9Ac806203;
        assertEq(rad.nonces(owner), 0);
        assertEq(rad.allowance(owner, address(rad)), 0);
        rad.permit(owner, address(rad), 100, uint(-1),
                   28,
                   0xb1b88cc9bdd69831879b406e560b29fc6938d556f8f7be5c580ce11cfd3d354e,
                   0x4ab00b718c09a9f9fb2dd35c2555659bb2b45509b402845bd37b8ef82eb97661);
        assertEq(rad.allowance(owner, address(rad)), 100);
        assertEq(rad.nonces(owner), 1);
    }

    function test_permit_typehash() public {
        assertEq(rad.PERMIT_TYPEHASH(), 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9); // seth keccak $(seth --from-ascii "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)")
    }

    function testFail_permit_replay() public {
        address owner = 0xD521C744831cFa3ffe472d9F5F9398c9Ac806203;
        rad.permit(owner, address(rad), 100, uint(-1),
                   28,
                   0xb1b88cc9bdd69831879b406e560b29fc6938d556f8f7be5c580ce11cfd3d354e,
                   0x4ab00b718c09a9f9fb2dd35c2555659bb2b45509b402845bd37b8ef82eb97661);
        rad.permit(owner, address(rad), 100, uint(-1),
                   28,
                   0xb1b88cc9bdd69831879b406e560b29fc6938d556f8f7be5c580ce11cfd3d354e,
                   0x4ab00b718c09a9f9fb2dd35c2555659bb2b45509b402845bd37b8ef82eb97661);
    }

    function nextBlock() internal {
        hevm.roll(block.number + 1);
    }

    function set_x(uint _x) public {
        require(msg.sender == address(timelock));
        x = _x;
    }

    function test_Delegate(uint96 a, uint96 b, uint96 c, address d, address e) public {
        if (a > 100000000 ether) return;
        if (uint(b) + uint(c) > uint(a)) return;
        if (d == address(0) || e == address(0)) return;
        rad.transfer(address(usr), a);
        usr.delegate(address(usr)); // delegating to self should be a noop
        usr.delegate(d);
        nextBlock();
        assertEq(uint(rad.getCurrentVotes(address(d))), a);
        usr.transfer(e, b);
        nextBlock();
        assertEq(uint(rad.getCurrentVotes(address(d))), a - b);
        usr.burn(c);
        nextBlock();
        assertEq(uint(rad.getPriorVotes(address(d), block.number - 3)), a);
        assertEq(uint(rad.getPriorVotes(address(d), block.number - 2)), a - b);
        assertEq(uint(rad.getPriorVotes(address(d), block.number - 1)), a - b - c);
        assertEq(uint(rad.getCurrentVotes(address(d))), a - b - c);
    }

    function test_propose() public {
        uint proposals = gov.proposalCount();
        ali.delegate(address(bob));
        bob.delegate(address(bob));
        nextBlock();
        bob.propose(address(this), "set_x(uint256)", abi.encode(uint(1)));
        assertEq(gov.proposalCount(), proposals + 1);
    }

    // governance follows the flow:
    //   - propose
    //   - queue
    //   - execute OR cancel
    function test_vote_to_execution() public {
        ali.delegate(address(bob));
        bob.delegate(address(bob));
        cal.delegate(address(cal));
        nextBlock();
        uint id = bob.propose(address(this), "set_x(uint256)", abi.encode(uint(1)));
        assertEq(uint(gov.state(id)), 0 , "proposal is pending");

        // proposal is Pending until block.number + votingDelay + 1
        hevm.roll(block.number + gov.votingDelay() + 1);
        assertEq(uint(gov.state(id)), 1, "proposal is active");

        // votes cast must have been checkpointed by delegation, and
        // exceed the quorum and votes against
        cal.castVote(id, true);
        hevm.roll(block.number + gov.votingPeriod());
        assertEq(uint(gov.state(id)), 4, "proposal is successful");

        // queueing succeeds unless already queued
        // (N.B. cannot queue multiple calls to same signature as-is)
        bob.queue(id);
        assertEq(uint(gov.state(id)), 5, "proposal is queued");

        // can only execute following time delay
        assertEq(x, 0, "x is unmodified");
        hevm.warp(block.timestamp + 2 days);
        gov.execute(id);
        assertEq(uint(gov.state(id)), 7, "proposal is executed");
        assertEq(x, 1, "x is modified");
    }

    function test_change_timelock_admin() public {
        ali.delegate(address(bob));
        bob.delegate(address(bob));
        cal.delegate(address(cal));
        nextBlock();
        uint id = bob.propose(address(timelock), "setPendingAdmin(address)", abi.encode(address(bob)));
        assertEq(uint(gov.state(id)), 0 , "proposal is pending");

        // proposal is Pending until block.number + votingDelay + 1
        hevm.roll(block.number + gov.votingDelay() + 1);
        assertEq(uint(gov.state(id)), 1, "proposal is active");

        // votes cast must have been checkpointed by delegation, and
        // exceed the quorum and votes against
        cal.castVote(id, true);
        hevm.roll(block.number + gov.votingPeriod());
        assertEq(uint(gov.state(id)), 4, "proposal is successful");

        // queueing succeeds unless already queued
        // (N.B. cannot queue multiple calls to same signature as-is)
        bob.queue(id);
        assertEq(uint(gov.state(id)), 5, "proposal is queued");

        // can only execute following time delay
        assertEq(x, 0, "x is unmodified");
        hevm.warp(block.timestamp + 2 days);
        gov.execute(id);
        assertEq(uint(gov.state(id)), 7, "proposal is executed");

        bob.accept();
        assertEq(timelock.admin(), address(bob));

        assertEq(x, 0, "x is unmodified");
        uint eta = block.timestamp + timelock.delay();
        bob.queueTimelock(address(this), "set_x(uint256)", abi.encode(uint(1)), eta);
        hevm.warp(block.timestamp + 2 days);
        bob.executeTimelock(address(this), "set_x(uint256)", abi.encode(uint(1)), eta);
        assertEq(x, 1, "x is modified");
    }

    /* function testAbiEncode() public { */
    /*     address[] memory targets = new address[](1); */
    /*     uint256[] memory values  = new uint256[](1); */
    /*     string[]  memory sigs    = new string[](1); */
    /*     bytes[]   memory datas   = new bytes[](1); */
    /*     targets[0] = 0xFCBcd8C32305228F205c841c03f59D2491f92Cb4; */
    /*     values[0] = 0; */
    /*     sigs[0] = "setDomainOwner(address)"; */
    /*     datas[0] = abi.encode(address(0xEcEDFd8BA8ae39a6Bd346Fe9E5e0aBeA687fFF31)); */
    /*     bytes memory encoded = abi.encodeWithSignature("propose(address[],uint256[],string[],bytes[],string)", */
    /*                                                    targets, */
    /*                                                    values, */
    /*                                                    sigs, */
    /*                                                    datas, */
    /*                                                    "This proposal migrates the radicle.eth domain and token to a new Registrar."); */
    /*     assertEq0(encoded, hex"da95691a00000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000120000000000000000000000000000000000000000000000000000000000000018000000000000000000000000000000000000000000000000000000000000001e00000000000000000000000000000000000000000000000000000000000000001000000000000000000000000fcbcd8c32305228f205c841c03f59d2491f92cb400000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000017736574446f6d61696e4f776e6572286164647265737329000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000020000000000000000000000000ecedfd8ba8ae39a6bd346fe9e5e0abea687fff31000000000000000000000000000000000000000000000000000000000000004b546869732070726f706f73616c206d69677261746573207468652072616469636c652e65746820646f6d61696e20616e6420746f6b656e20746f2061206e6577205265676973747261722e000000000000000000000000000000000000000000"); */
    /* } */

    /* function testAbiEncode2() public { */
    /*     string[]  memory sigs    = new string[](1); */
    /*     sigs[0] = "setDomainOwner(address)"; */
    /*     bytes memory encoded = abi.encodeWithSignature("f(string[],string)", */
    /*                                                    sigs, */
    /*                                                    "This proposal migrates the radicle.eth domain and token to a new Registrar."); */
    /*     assertEq0(encoded, hex"07ac501f0000000 action "callas(address,address,bytes,uint)" [AbiAddressType, AbiAddressType, AbiBytesDynamicType, AbiUIntType 256] $
        \sig tps outOffset outSize input -> case decodeBuffer tps input of
          CAbi [AbiAddress caller', AbiAddress target, AbiBytesDynamic calldata, AbiUInt 256 val] ->
            let
              target' = litAddr target
              value' = num val
              stk = lookup (state . stack)
            in
            delegateCall caller' xGas target' target' value' xInOffset xInSize outOffset outSize stk $
              \callee -> do
                zoom state $ do
                  assign callvalue (litWord value')
                  assign caller (litAddr caller')
                  assign contract callee
                transfer caller' callee value'
                touchAccount caller'
                touchAccount callee
          _ -> vmError (BadCheatCode sig)00000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000017736574446f6d61696e4f776e6572286164647265737329000000000000000000000000000000000000000000000000000000000000000000000000000000004b546869732070726f706f73616c206d69677261746573207468652072616469636c652e65746820646f6d61696e20616e6420746f6b656e20746f2061206e6577205265676973747261722e000000000000000000000000000000000000000000"); */
    /* } */

    /* function testAbiEncode3() public { */
    /*     string[]  memory sigs    = new string[](1); */
    /*     sigs[0] = "setDomainOwner(address)"; */
    /*     bytes memory encoded = abi.encodeWithSignature("f(string[])", */
    /*                                                    sigs); */
    /*     assertEq0(encoded, hex"e9cc87800000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000017736574446f6d61696e4f776e6572286164647265737329000000000000000000"); */
    /* } */
}
