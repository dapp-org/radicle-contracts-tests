pragma solidity ^0.7.5;

import {RadicleToken}  from "radicle-contracts/contracts/Governance/RadicleToken.sol";
import {Governor}      from "radicle-contracts/contracts/Governance/Governor.sol";
import {Timelock}      from "radicle-contracts/contracts/Governance/Timelock.sol";
import {Treasury}      from "radicle-contracts/contracts/Governance/Treasury.sol";
import {VestingToken}  from "radicle-contracts/contracts/Governance/VestingToken.sol";
import {Registrar}     from "radicle-contracts/contracts/Registrar.sol";
import {ENS}           from "@ensdomains/ens/contracts/ENS.sol";
import {ENSRegistry}   from "@ensdomains/ens/contracts/ENSRegistry.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";


import {DSTest} from "ds-test/test.sol";
import {DSMath} from "ds-math/math.sol";

interface Hevm {
    function warp(uint256) external;
    function roll(uint256) external;
    function store(address,bytes32,bytes32) external;
}

contract VestingUser {
    function withdrawVested(VestingToken vest) public {
        vest.withdrawVested();
    }
}

contract VestingOwner {
    function terminateVesting(VestingToken vest) public {
        vest.terminateVesting();
    }
}

contract VestingTokenTests is DSTest, DSMath {
    RadicleToken rad;
    VestingUser user;
    VestingOwner owner;
    Hevm hevm = Hevm(HEVM_ADDRESS);

    function setUp() public {
        hevm.warp(12345678);

        rad = new RadicleToken(address(this));
        user = new VestingUser();
        owner = new VestingOwner();
    }

    // Demonstrates a bug where withdrawableBalance() always reverts after
    // vesting has been interrupted.
    function testFail_vesting_failure() public {
        VestingToken vest = Utils.mkVestingToken(
            address(rad),
            address(this),
            address(user),
            10000000 ether,
            block.timestamp - 1,
            2 weeks,
            1 days
        );

        hevm.warp(block.timestamp + 2 days);
        vest.terminateVesting();
        hevm.warp(block.timestamp + 1 days);

        // withdrawableBalance reverts if vesting was interrupted
        vest.withdrawableBalance();
    }

    // `withdrawableBalance()` should always return the actual amount that will
    // be withdrawan when calling `withdrawVested()`
    function test_withdrawal_amount(
        uint24 jump, uint24 amount, uint8 startOffset, uint24 vestingPeriod, uint24 cliffPeriod
    ) public {
        if (vestingPeriod == 0) return;
        if (startOffset == 0) return;
        if (amount == 0) return;
        if (amount > 10000000 ether) return;

        VestingToken vest = Utils.mkVestingToken(
            address(rad),
            address(this),
            address(user),
            amount,
            block.timestamp - startOffset,
            vestingPeriod,
            cliffPeriod
        );

        hevm.warp(block.timestamp + jump);

        uint amt = vest.withdrawableBalance();
        uint prebal = rad.balanceOf(address(user));

        user.withdrawVested(vest);
        uint postbal = rad.balanceOf(address(user));

        assertEq(postbal - prebal, amt, "withdrawn amount matches withdrawableBalance");
    }

    // The VestingToken should be empty after `terminateVesting()` has been called
    // The beneficiary should have received all vested tokens
    // The owner should have received all unvested tokens
    function test_empty_after_termination(
        uint24 jump, uint24 amount, uint8 startOffset, uint24 vestingPeriod, uint24 cliffPeriod
    ) public {
        if (vestingPeriod == 0) return;
        if (startOffset == 0) return;
        if (amount == 0) return;
        if (amount > 10000000 ether) return;

        VestingToken vest = Utils.mkVestingToken(
            address(rad),
            address(owner),
            address(user),
            amount,
            block.timestamp - startOffset,
            vestingPeriod,
            cliffPeriod
        );

        hevm.warp(block.timestamp + jump);

        assertEq(rad.balanceOf(address(vest)), amount);
        uint vested = vest.withdrawableBalance();
        log_named_uint("vested", vested);
        log_named_uint("amount", amount);
        uint unvested = sub(amount, vest.withdrawableBalance());

        owner.terminateVesting(vest);

        assertEq(
            rad.balanceOf(address(vest)), 0,
            "vesting token is empty"
        );
        assertEq(
            rad.balanceOf(address(user)), vested,
            "beneficiary has received all vested tokens"
        );
        assertEq(
            rad.balanceOf(address(owner)), unvested,
            "owner has received all unvested tokens"
        );
    }

    // The `withdrawn` attribute should always accurately reflect the actual amount withdrawn
    // Demonstrates a bug where the withdrawn attribute is set to a misleading value after termination
    function test_withdrawn_accounting(
        uint8 jump, uint24 amount, uint8 startOffset, uint24 vestingPeriod, uint24 cliffPeriod
    ) public {
        if (vestingPeriod == 0) return;
        if (startOffset == 0) return;
        if (amount == 0) return;
        if (amount > 10000000 ether) return;

        VestingToken vest = Utils.mkVestingToken(
            address(rad),
            address(owner),
            address(user),
            amount,
            block.timestamp - startOffset,
            vestingPeriod,
            cliffPeriod
        );

        uint withdrawn = 0;

        for (uint i; i < 10; i++) {
            hevm.warp(block.timestamp + jump);
            uint prebal = rad.balanceOf(address(user));
            user.withdrawVested(vest);

            uint postbal = rad.balanceOf(address(user));
            withdrawn = add(withdrawn, postbal - prebal);
        }

        assertEq(withdrawn, vest.withdrawn(), "pre-termination");

        hevm.warp(block.timestamp + jump);
        uint withdrawable = vest.withdrawableBalance();
        owner.terminateVesting(vest);

        assertEq(vest.withdrawn(), add(withdrawn, withdrawable), "post-termination");
    }
}

contract RegistrarRPCTests is DSTest {
    ENS ens;
    RadicleToken rad;
    Registrar registrar;
    bytes32 domain;
    uint tokenId;
    Hevm hevm = Hevm(HEVM_ADDRESS);

    function setUp() public {
        domain = nodeNames(); // radicle.eth
        tokenId = uint(keccak256(abi.encodePacked("radicle"))); // seth keccak radicle
        ens = ENS(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e);
        rad = new RadicleToken(address(this));
        registrar = new Registrar(
            ens,
            domain,
            tokenId,
            address(0), // irrelevant in this version
            address(0), // irrelevant in this version
            ERC20Burnable(address(rad)),
            address(this)
        );

        // make the registrar the owner of the radicle.eth domain
        // TODO: make this less inscrutible
        hevm.store(address(ens),0xac1257ce7bce314b8259fc2275d8baa2312a85d1f09c65060220d05a39515655, bytes32(uint256(uint160(address(registrar)))));

        // make the registrar the owner of the radicle.eth 721 token
        bytes32 ethNode = 0x93cdeb708b7545dc668eb9280176169d1c33cfd8ed6f04690a0bcc88a93fc4ae;
        address ethRegistrarAddr = ens.owner(ethNode);

        // owner[tokenId]
        // TODO: make this less inscrutible
        hevm.store(ethRegistrarAddr, 0x7906724a382e1baec969d07da2f219928e717131ddfd68dbe3d678f62fa3065b, bytes32(uint256(uint160(address(registrar)))));

        // ownedTokensCount[address(registrar)]
        // TODO: make this less inscrutible
        hevm.store(ethRegistrarAddr, 0x27a5c9c1f678324d928c72a6ff8a66d3c79aa98b4c10804760d4542336658cc7, bytes32(uint(1)));
    }

    function nodeNames() public returns (bytes32) {
        bytes32 noll = bytes32(uint(0));
        bytes32 eth = keccak256(abi.encodePacked("eth"));
        bytes32 top = keccak256(abi.encodePacked(noll, eth));
        log_named_bytes32("eth: ", top);
        bytes32 rad = keccak256(abi.encodePacked("radicle"));
        log_named_bytes32("radicle: ", rad);
        bytes32 radicleEth = keccak256(abi.encodePacked(top, rad));
        log_named_bytes32("radicle.eth ", radicleEth);
        return radicleEth;
    }

    function testRegister() public {
        registerWith(address(registrar), "mrchico");
        assertEq(ens.owner(keccak256(abi.encodePacked(domain, keccak256(abi.encodePacked("mrchico"))))), address(this));
    }

    function registerWith(address reg, string memory name) public {
        uint preBal = rad.balanceOf(address(this));

        rad.approve(reg, uint(-1));
        Registrar(reg).registerRad(name, address(this));

        assertEq(rad.balanceOf(address(this)), preBal - 1 ether);
    }

    function testRegisterWithNewOwner() public {
        Registrar registrar2 = new Registrar(
            ens,
            domain,
            tokenId,
            address(0), // irrelevant in this version
            address(0), // irrelevant in this version
            ERC20Burnable(address(rad)),
            address(this)
        );
        registrar.setDomainOwner(address(registrar2));
        registerWith(address(registrar2), "mrchico");
        assertEq(ens.owner(keccak256(abi.encodePacked(domain, keccak256(abi.encodePacked("mrchico"))))), address(this));
    }
}

contract RadUser {
    RadicleToken rad;
    constructor (RadicleToken rad_) public {
        rad = rad_;
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
}

contract RadicleTokenTest is DSTest {
    RadicleToken rad;
    RadUser usr;
    Hevm hevm = Hevm(HEVM_ADDRESS);

    function setUp() public {
        rad = new RadicleToken(address(this));
        usr = new RadUser(rad);
    }

    function nextBlock() public {
        hevm.roll(block.number + 1);
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
}

contract GovernanceTest is DSTest {
    Governor governor;
    RadicleToken rad;
    Timelock timelock;
    Hevm hevm = Hevm(HEVM_ADDRESS);

    function setUp() public {
        rad = new RadicleToken(address(this));
        timelock = new Timelock(address(this), 2 days);
        governor = new Governor(address(timelock), address(rad), address(this));
    }
}

library Utils {
    function create2Address(
        bytes32 salt, address creator, bytes memory creationCode, bytes memory args
    ) internal returns (address) {
        return address(uint(keccak256(abi.encodePacked(
            bytes1(0xff),
            creator,
            salt,
            keccak256(abi.encodePacked(creationCode, args))
        ))));
    }

    function mkVestingToken(
        address token,
        address owner,
        address beneficiary,
        uint amount,
        uint vestingStartTime,
        uint vestingPeriod,
        uint cliffPeriod
    ) internal returns (VestingToken) {
        bytes32 salt = bytes32("0xacab");

        address vestAddress = Utils.create2Address(
            salt,
            address(this),
            type(VestingToken).creationCode,
            abi.encode(
                token, owner, beneficiary, amount, vestingStartTime, vestingPeriod, cliffPeriod
            )
        );

        RadicleToken(token).approve(vestAddress, uint(-1));
        VestingToken vest = new VestingToken{salt: salt}(
            token, owner, beneficiary, amount, vestingStartTime, vestingPeriod, cliffPeriod
        );

        return vest;
    }
}
