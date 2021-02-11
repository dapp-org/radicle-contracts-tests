pragma solidity ^0.7.5;
pragma abicoder v2;

import {RadicleToken}  from "radicle-contracts/Governance/RadicleToken.sol";
import {VestingToken}  from "radicle-contracts/Governance/VestingToken.sol";

import {DSTest} from "ds-test/test.sol";
import {DSMath} from "ds-math/math.sol";

import {Hevm, Utils} from "./Utils.sol";

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

    // Demonstrates a bug where withdrawableBalance() could revert after
    // vesting has been interrupted.
    function test_vesting_failure() public {
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
