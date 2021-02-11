pragma solidity ^0.7.5;
pragma abicoder v2;

import {Phase0}        from "radicle-contracts/deploy/phase0.sol";
import {RadicleToken}  from "radicle-contracts/Governance/RadicleToken.sol";
import {Governor}      from "radicle-contracts/Governance/Governor.sol";
import {Timelock}      from "radicle-contracts/Governance/Timelock.sol";
import {VestingToken}  from "radicle-contracts/Governance/VestingToken.sol";
import {Registrar, Commitments} from "radicle-contracts/Registrar.sol";

import {ENS}           from "@ensdomains/ens/contracts/ENS.sol";
import {ENSRegistry}   from "@ensdomains/ens/contracts/ENSRegistry.sol";
import {IERC721}       from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import {DSTest} from "ds-test/test.sol";
import {DSMath} from "ds-math/math.sol";

import {Hevm, Utils} from "./Utils.sol";

contract RegistrarRPCTests is DSTest {
    ENS ens;
    RadicleToken rad;
    Registrar registrar;
    bytes32 domain;
    uint tokenId;
    Hevm hevm = Hevm(HEVM_ADDRESS);
    Governor gov;

    function setUp() public {
        domain = Utils.namehash(["radicle", "eth"]);
        ens = ENS(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e);
        tokenId = uint(keccak256(abi.encodePacked("radicle"))); // seth keccak radicle
        Phase0 phase0 = new Phase0( address(this)
                                    , 2 days
                                    , address(this)
                                    , ens
                                    , domain
                                    , "radicle"
                                    );
        registrar = phase0.registrar();
        rad = phase0.token();
        gov = phase0.governor();
        log_named_address("Registrar", address(registrar));

        // make this contract the owner of the radicle.eth domain
        hevm.store(
            address(ens),
            keccak256(abi.encodePacked(domain, uint(0))),
            Utils.asBytes32(address(this))
        );

        // make this contract the owner of the radicle.eth 721 token
        address ethRegistrarAddr = ens.owner(Utils.namehash(["eth"]));

        // set owner["radicle"] = address(registrar)
        // TODO: make this less inscrutible
        hevm.store(
            ethRegistrarAddr,
            0x7906724a382e1baec969d07da2f219928e717131ddfd68dbe3d678f62fa3065b,
            Utils.asBytes32(address(this))
        );

        // ownedTokensCount[address(this)]
        // TODO: make this less inscrutible
        hevm.store(
            ethRegistrarAddr,
            bytes32(uint(99769381792979770997497849739242275106480790460331428765085642759382986339262)),
            bytes32(uint(1))
        );

        // transfer ownership of the ENS record to the registrar
        ens.setOwner(domain, address(registrar));

        // transfer ownership of the 721 token to the registrar
        IERC721(ethRegistrarAddr).transferFrom(address(this), address(registrar), tokenId);
    }

    // --- tests ---

    // the ownership of the correct node in ens changes after domain registration
    function test_register(string memory name) public {
        if (bytes(name).length == 0) return;
        if (bytes(name).length > 32) return;
        bytes32 node = Utils.namehash([name, "radicle", "eth"]);

        assertEq(ens.owner(node), address(0));
        registerWith(registrar, name);
        assertEq(ens.owner(node), address(this));
    }

    // BUG: the resolver is address(0x0) for radicle subdomains
    function test_resolverUnset() public {
        bytes32 node = Utils.namehash(["microsoft", "radicle", "eth"]);

        assertEq(ens.owner(node), address(0));
        registerWith(registrar, "microsoft");
        assertEq(ens.owner(node), address(this));
        assertEq(ens.resolver(node), ens.resolver(Utils.namehash(["radicle", "eth"])));
    }

    // BUG: names transfered to the zero address can never be reregistered
    function test_reregistration(string memory name) public {
        if (bytes(name).length == 0) return;
        if (bytes(name).length > 32) return;
        bytes32 node = Utils.namehash([name, "radicle", "eth"]);
        registerWith(registrar, name, 666);

        ens.setOwner(node, address(0));
        assertEq(ens.owner(node), address(0));
        assertTrue(ens.recordExists(node));

        registerWith(registrar, name, 667);
        assertEq(ens.owner(node), address(this));
    }

    // domain registration still works after transfering ownership of the
    // "radicle.eth" domain to a new registrar
    // TODO: the Timelock is the admin of the Registrar,
    // so we will need to make a proposal to perform this transition.
    function test_register_with_new_owner() public {
        string memory name = "mrchico";
        Registrar registrar2 = new Registrar(
            ens,
            rad,
            address(this),
            50,
            domain,
            tokenId
        );
        log_named_address("registrar2", address(registrar2));
        rad.delegate(address(this));
        hevm.roll(block.number + 1);
        // This proposal was generated with `radgov propose newRegistrar`!
        // where newRegistrar is:
        //
        // This proposal migrates the radicle.eth domain and token
        // to a new Registrar.
        //
        // ## PROPOSAL ##
        //
        // ```
        // 0xFCBcd8C32305228F205c841c03f59D2491f92Cb4 0 "setDomainOwner(address)" 0xEcEDFd8BA8ae39a6Bd346Fe9E5e0aBeA687fFF31
        // ```
        (bool success, bytes memory retdata) = address(gov).call(hex"da95691a00000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000e0000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000001a000000000000000000000000000000000000000000000000000000000000002200000000000000000000000000000000000000000000000000000000000000001000000000000000000000000fcbcd8c32305228f205c841c03f59d2491f92cb400000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000017736574446f6d61696e4f776e6572286164647265737329000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000020000000000000000000000000ecedfd8ba8ae39a6bd346fe9e5e0abea687fff31000000000000000000000000000000000000000000000000000000000000004b546869732070726f706f73616c206d69677261746573207468652072616469636c652e65746820646f6d61696e20616e6420746f6b656e20746f2061206e6577205265676973747261722e000000000000000000000000000000000000000000"); 
        assertTrue(success);
        uint id = abi.decode(retdata, (uint));
        assertEq(id, 1);
        (address[] memory targets, uint256[] memory values, string[] memory signatures, bytes[] memory calldatas) = gov.getActions(1);
        assertEq(targets[0], address(registrar));
        assertEq(values[0], 0);
        assertEq(signatures[0], "setDomainOwner(address)");
        assertEq0(calldatas[0], abi.encode(address(registrar2)));

        // advance the time and vote the proposal through
        hevm.roll(block.number + gov.votingDelay() + 1);
        assertEq(uint(gov.state(id)), 1, "proposal is active");

        // votes cast must have been checkpointed by delegation, and
        // exceed the quorum and votes against
        gov.castVote(id, true);
        hevm.roll(block.number + gov.votingPeriod());
        assertEq(uint(gov.state(id)), 4, "proposal is successful");

        // queueing succeeds unless already queued
        // (N.B. cannot queue multiple calls to same signature as-is)
        gov.queue(id);
        assertEq(uint(gov.state(id)), 5, "proposal is queued");

        // can only execute following time delay
        hevm.warp(block.timestamp + 2 days);
        gov.execute(id);
        assertEq(uint(gov.state(id)), 7, "proposal is executed");

        // the new registrar is now the owner of the domain
        assertEq(ens.owner(domain), address(registrar2));

        // and so we can register with it
        registerWith(registrar2, name);

        assertEq(ens.owner(Utils.namehash([name, "radicle", "eth"])), address(this));
    }

    // a domain that has already been registered cannot be registered again
    function testFail_double_register(string memory name) public {
        require(bytes(name).length > 0);
        require(bytes(name).length <= 32);

        registerWith(registrar, name);
        registerWith(registrar, name);
    }

    // unfortunately we need something like `hevm.callFrom` to test this properly
    // this test is really just testing the scenario where the call is frontrun by an attacker
    // we are still able to validate that:
    // - the permit is correct
    // - the attacker still pays
    function test_commit_with_permit(uint sk, string memory name, uint salt) public {
        if (sk == 0) return;
        if (!registrar.valid(name)) return;
        address owner = hevm.addr(sk);

        {
            uint preBal = rad.balanceOf(address(this));
            uint preSupply = rad.totalSupply();
            rad.approve(address(registrar), registrar.registrationFeeRad());

            // sign the `permit` message
            uint value = registrar.registrationFeeRad();
            uint deadline = type(uint).max;
            bytes32 structHash = keccak256(abi.encode(
                rad.PERMIT_TYPEHASH(), owner, address(registrar), value, rad.nonces(owner), deadline
            ));
            bytes32 digest = keccak256(abi.encodePacked("\x19\x01", rad.DOMAIN_SEPARATOR(), structHash));
            (uint8 v, bytes32 r, bytes32 s) = hevm.sign(sk, digest);

            // generate the name commitment
            bytes32 commitment = keccak256(abi.encodePacked(name, owner, salt));

            // commit to the name using permit
            registrar.commitWithPermit(commitment, owner, value, deadline, v, r, s);

            assertEq(
                preBal - rad.balanceOf(address(this)), registrar.registrationFeeRad(),
                "frontrunner had to pay"
            );
            assertEq(
                rad.allowance(owner, address(registrar)), registrar.registrationFeeRad(),
                "owner approved registrar for registrationFeeRad"
            );
            assertEq(
                preSupply - rad.totalSupply(), registrar.registrationFeeRad(),
                "rad totalSupply has decreased by registrationFeeRad rad"
            );
            assertEq(
                registrar.commitments().commited(commitment), block.number,
                "name was commited to"
            );
        }

        {
            // jump forward until name can be registered
            hevm.roll(block.number + registrar.minCommitmentAge() + 1);
            registrar.register(name, owner, salt);

            assertEq(
                ens.owner(Utils.namehash([name, "radicle", "eth"])), owner,
                "owner controls the name in ens"
            );
        }
    }

    /*
       here we test the full end to end flow commitBySig flow, validating that:

        - the relayer is compensated
        - the registration fee is burned
        - the name is commited to
        - the owner paid for both the registration and the relaying fee
        - the name can subsequently be registered
    */
    function test_commit_by_sig(
        uint sk, string memory name, uint salt, uint expiry, uint64 submissionFee
    ) public {
        if (sk == 0) return;
        if (!registrar.valid(name)) return;
        if (expiry < block.timestamp) return;

        address owner = hevm.addr(sk);
        uint totalFee = registrar.registrationFeeRad() + submissionFee;

        // commit
        {
            // give `owner` some rad and approve the registrar for them
            rad.transfer(address(owner), totalFee);
            hevm.store(
                address(rad),
                keccak256(abi.encodePacked(
                    uint(address(registrar)),
                    keccak256(abi.encodePacked(uint(owner), uint(1)))
                )),
                bytes32(totalFee)
            );
            require(rad.allowance(owner, address(registrar)) == totalFee, "incorrect allowance");


            // generate the commitment
            bytes32 commitment = keccak256(abi.encodePacked(name, owner, salt));

            // produce the signed commit message
            bytes32 digest;
            { // stack too deep...
                bytes32 domainSeparator =
                    keccak256(
                        abi.encode(
                            registrar.DOMAIN_TYPEHASH(),
                            keccak256(bytes(registrar.NAME())),
                            Utils.getChainId(),
                            address(registrar)
                        )
                    );

                bytes32 structHash =
                    keccak256(
                        abi.encode(
                            registrar.COMMIT_TYPEHASH(),
                            commitment,
                            registrar.nonces(owner),
                            expiry,
                            submissionFee
                        )
                    );

                digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
            }
            (uint8 v, bytes32 r, bytes32 s) = hevm.sign(sk, digest);

            // cache some values
            uint preBalThis = rad.balanceOf(address(this));
            uint preBalOwner = rad.balanceOf(owner);
            uint preSupply = rad.totalSupply();

            // submit the signed commitment
            registrar.commitBySig(commitment, registrar.nonces(owner), expiry, submissionFee, v, r, s);

            // assertions
            assertEq(
                registrar.commitments().commited(commitment), block.number,
                "commitment was made at the current block"
            );
            assertEq(
                rad.balanceOf(address(this)) - preBalThis, submissionFee,
                "relayer was paid submissionFee"
            );
            assertEq(
                preSupply - rad.totalSupply(), registrar.registrationFeeRad(),
                "registration fee was burned"
            );
            assertEq(
                preBalOwner - rad.balanceOf(owner), totalFee,
                "owner paid submissionFee + registrationFeeRad"
            );
        }

        // register
        {
            // jump forward until name can be registered
            hevm.roll(block.number + registrar.minCommitmentAge() + 1);
            registrar.register(name, owner, salt);

            assertEq(
                ens.owner(Utils.namehash([name, "radicle", "eth"])), owner,
                "owner controls the name in ens"
            );

        }
    }

    struct Signature {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    struct PermitParams {
        address owner;
        address spender;
        uint value;
        uint expiry;
    }

    struct CommitParams {
        bytes32 commitment;
        uint nonce;
        uint expiry;
        uint submissionFee;
    }

    struct TestParams {
        uint sk;
        string name;
        uint salt;
        uint expiry;
        uint112 submissionFee;
    }

    /*
    function test_commit_by_sig_with_permit(TestParams memory args) public {
        if (args.sk == 0) return;
        if (!registrar.valid(args.name)) return;
        if (args.expiry < block.timestamp) return;

        PermitParams memory permitParams;
        {
            permitParams = PermitParams(
                hevm.addr(args.sk),
                address(registrar),
                registrar.registrationFeeRad() + args.submissionFee,
                args.expiry
            );
        }

        CommitParams memory commitParams;
        {
            commitParams = CommitParams(
                keccak256(abi.encodePacked(args.name, hevm.addr(args.sk), args.salt)),
                registrar.nonces(hevm.addr(args.sk)),
                args.expiry,
                args.submissionFee
            );
        }

        Signature memory permitSig;
        { permitSig = signPermit(args.sk, permitParams); }

        Signature memory commitSig;
        { commitSig = signCommit(args.sk, commitParams); }

        // make the commitment
        registrar.commitBySigWithPermit(
            commitParams.commitment,
            commitParams.nonce,
            commitParams.expiry,
            commitParams.submissionFee,
            commitSig.v, commitSig.r, commitSig.s,
            permitParams.owner,
            permitParams.value,
            permitParams.expiry,
            permitSig.v, permitSig.r, permitSig.s
        );
    }
    */

    // Utils.nameshash does the right thing for radicle.eth subdomains
    function test_namehash(string memory name) public {
        bytes32 node = Utils.namehash([name, "radicle", "eth"]);
        assertEq(node, keccak256(abi.encodePacked(
            keccak256(abi.encodePacked(
                keccak256(abi.encodePacked(
                    bytes32(uint(0)),
                    keccak256("eth")
                )),
                keccak256("radicle")
            )),
            keccak256(bytes(name))
        )));
    }

    // --- helpers ---

    function registerWith(Registrar reg, string memory name) internal {
        registerWith(reg, name, 42069);
    }

    /* function registerFor(Registrar reg, address owner, string memory name, bytes32 r, bytes32 s, uint8 v, bytes32 permit_r, bytes32 permit_s, uint8 permit_v) internal { */
    /*     uint salt = 150987; */
    /*     bytes32 commitment = keccak256(abi.encodePacked(name, owner, salt)); */
    /*     reg.commitBySigWithPermit(commitment, 0, uint(-1), 1 ether, owner, uint(-1), uint(-1), permit_v, permit_r, permit_s); */
    /*     hevm.roll(block.number + 100); */
    /*     reg.register(name, owner, salt); */
    /* } */

    function registerWith(Registrar reg, string memory name, uint salt) internal {
        uint preBal = rad.balanceOf(address(this));

        bytes32 commitment = keccak256(abi.encodePacked(name, address(this), salt));
        rad.approve(address(reg), uint(-1));

        reg.commit(commitment);
        hevm.roll(block.number + 100);
        reg.register(name, address(this), salt);

        assertEq(rad.balanceOf(address(this)), preBal - 1 ether);
    }

    function signPermit(uint sk, PermitParams memory args) internal returns (Signature memory) {
        require(args.owner == hevm.addr(sk), "signPermit: signing from wrong address");
        bytes32 structHash =
            keccak256(
                abi.encode(
                    rad.PERMIT_TYPEHASH(),
                    args.owner,
                    args.spender,
                    args.value,
                    rad.nonces(args.owner),
                    args.expiry
                )
            );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", rad.DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = hevm.sign(sk, digest);
        return Signature(v, r, s);
    }

    function signCommit(uint sk, CommitParams memory args) internal returns (Signature memory) {
        address signer = hevm.addr(sk);
        bytes32 domainSeparator =
            keccak256(
                abi.encode(
                    registrar.DOMAIN_TYPEHASH(),
                    keccak256(bytes(registrar.NAME())),
                    Utils.getChainId(),
                    address(registrar)
                )
            );

        bytes32 structHash =
            keccak256(
                abi.encode(
                    registrar.COMMIT_TYPEHASH(),
                    args.commitment,
                    args.nonce,
                    args.expiry,
                    args.submissionFee
                )
            );

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        (uint8 v, bytes32 r, bytes32 s) = hevm.sign(sk, digest);
        return Signature(v, r, s);
    }
}
