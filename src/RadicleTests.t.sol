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

import "ds-test/test.sol";

interface Hevm {
    function warp(uint256) external;
    function store(address,bytes32,bytes32) external;
}

contract VestingUser is DSTest {
    function withdrawVested(VestingToken vest) public {
        vest.withdrawVested();
    }
}

contract VestingTokenTests is DSTest {
    RadicleToken rad;
    VestingToken vest;
    VestingUser user;
    Hevm hevm = Hevm(HEVM_ADDRESS);

    function setUp() public {
        hevm.warp(12345678);

        rad = new RadicleToken(address(this));
        user = new VestingUser();

        // VestingToken calls transferFrom in the constructor, so we use
        // create2 to precompute the address of the token and approve the
        // VestingToken to move rad on behalf of the testing contract
        bytes32 salt = bytes32("0xacab");
        address token = address(rad);
        address owner = address(this);
        address beneficiary = address(user);
        uint amount = 1000000 ether;
        uint vestingStartTime = block.timestamp - 1;
        uint vestingPeriod = 2 weeks;
        uint cliffPeriod = 1 days;

        address vestAddress = Utils.create2Address(
            salt,
            address(this),
            type(VestingToken).creationCode,
            abi.encode(
                token, owner, beneficiary, amount, vestingStartTime, vestingPeriod, cliffPeriod
            )
        );

        rad.approve(vestAddress, uint(-1));
        vest = new VestingToken{salt: salt}(
            token, owner, beneficiary, amount, vestingStartTime, vestingPeriod, cliffPeriod
        );
        require(address(vest) == vestAddress);
    }

    // Demonstrates a bug where withdrawableBalance() always reverts after
    // vesting has been interrupted.
    function testFail_vesting_failure() public {
        hevm.warp(block.timestamp + 2 days);
        vest.terminateVesting();
        hevm.warp(block.timestamp + 1 days);

        // withdrawableBalance reverts if vesting was interrupted
        vest.withdrawableBalance();
    }

    // `withdrawableBalance()` should always return the actual amount that will
    // be withdrawan when calling `withdrawVested()`
    // TODO: allow `hevm.warp` for symbolic values
    function test_withdrawal_amount(uint24 jump) public {
        hevm.warp(block.timestamp + jump);

        uint amt = vest.withdrawableBalance();
        uint prebal = rad.balanceOf(address(user));

        user.withdrawVested(vest);
        uint postbal = rad.balanceOf(address(user));

        assertEq(postbal - prebal, amt);
    }
}

contract RegistrarTests is DSTest {
    ENS ens;
    RadicleToken rad;
    Registrar registrar;
    Hevm hevm = Hevm(HEVM_ADDRESS);

    function setUp() public {
        rad = new RadicleToken(address(this));
        ens = ENS(new ENSRegistry());
        registrar = new Registrar(
            ens,
            bytes32(0), // TODO
            0,          // TODO
            address(0), // TODO
            address(0), // TODO
            ERC20Burnable(address(rad)),
            address(this)
        );
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
}
