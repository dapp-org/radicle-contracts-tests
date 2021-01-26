pragma solidity ^0.6.7;

import "ds-test/test.sol";

import "./RadicleContractsTests.sol";

contract RadicleContractsTestsTest is DSTest {
    RadicleContractsTests tests;

    function setUp() public {
        tests = new RadicleContractsTests();
    }

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }
}
