pragma solidity ^0.7.5;

import "../radicle-contracts/contracts/Governance/RadicleToken.sol";
import "../radicle-contracts/contracts/Governance/Governor.sol";
import "../radicle-contracts/contracts/Governance/Timelock.sol";
import "../radicle-contracts/contracts/Governance/Treasury.sol";
import {VestingToken} from  "../radicle-contracts/contracts/Governance/VestingToken.sol";
import {Registrar} from  "../radicle-contracts/contracts/Registrar.sol";
import "@ensdomains/ens/contracts/ENS.sol";
import "@ensdomains/ens/contracts/ENSRegistry.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";

import "ds-test/test.sol";

contract RadicleContractsTests is DSTest {
    ENS ens;
    Registrar registrar;
    Governor governor;
    RadicleToken token;
    Timelock timelock;

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

    function test_sanity() public {
        assertEq(address(governor.token()), address(token));
    }
}
