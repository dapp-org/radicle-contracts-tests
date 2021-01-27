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


contract RadicleContractsTests is DSTest {
    ENS ens;
    Registrar registrar;
    Governor governor;
    RadicleToken token;
    Timelock timelock;
    Hevm hevm = Hevm(HEVM_ADDRESS);

    function setUp() public {
        ens = ENS(new ENSRegistry());
        token = new RadicleToken(address(this));
        registrar = new Registrar(
                                  ens,
                                  bytes32(0), // TODO
                                  0,          // TODO
                                  address(0), // TODO
                                  address(0), // TODO
                                  ERC20Burnable(address(token)),
                                  address(this)

        );
        timelock = new Timelock(address(this), 2 days);
        governor = new Governor(address(timelock), address(token), address(this));
    }

    // Demonstrates a bug where withdrawableBalance() always reverts after
    // vesting has been interrupted.
    function testFail_vesting_failure() public {
        hevm.warp(12345678);
        // Note that since the vestingtoken contract performs a transferFrom
        // in its constructor, we have to precalculate its address and approve
        // it before we construct it.
        token.approve(0xCaF5d8813B29465413587C30004231645FE1f680, uint(-1));
        VestingToken vest = new VestingToken(address(token),
                                             address(this),
                                             address(0xacab),
                                             1000000 ether,
                                             block.timestamp - 1,
                                             2 weeks,
                                             1 days);

        hevm.warp(block.timestamp + 2 days);
        vest.terminateVesting();
        hevm.warp(block.timestamp + 1 days);
        // withdrawableBalance reverts
        // if vesting was interrupted
        vest.withdrawableBalance();
    }
}
