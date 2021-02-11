import {RadicleToken}  from "radicle-contracts/Governance/RadicleToken.sol";
import {VestingToken}  from "radicle-contracts/Governance/VestingToken.sol";

interface Hevm {
    function warp(uint256) external;
    function roll(uint256) external;
    function store(address,bytes32,bytes32) external;
    function sign(uint,bytes32) external returns (uint8,bytes32,bytes32);
    function addr(uint) external returns (address);
}

library Utils {
    function create2Address(
        bytes32 salt, address creator, bytes memory creationCode, bytes memory args
    ) internal pure returns (address) {
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

    function asBytes32(address addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(addr)));
    }

    function namehash(string[] memory domain) internal pure returns (bytes32) {
        if (domain.length == 0) {
            return bytes32(uint(0));
        }
        if (domain.length == 1) {
            return keccak256(abi.encodePacked(bytes32(0), keccak256(bytes(domain[0]))));
        }
        else {
            bytes memory label = bytes(domain[0]);
            string[] memory remainder = new string[](domain.length - 1);
            for (uint i = 1; i < domain.length; i++) {
                remainder[i - 1] = domain[i];
            }
            return keccak256(abi.encodePacked(namehash(remainder), keccak256(label)));
        }
    }
    function namehash(string[1] memory domain) internal pure returns (bytes32) {
        string[] memory dyn = new string[](1);
        dyn[0] = domain[0];
        return namehash(dyn);
    }
    function namehash(string[2] memory domain) internal pure returns (bytes32) {
        string[] memory dyn = new string[](domain.length);
        for (uint i; i < domain.length; i++) {
            dyn[i] = domain[i];
        }
        return namehash(dyn);
    }
    function namehash(string[3] memory domain) internal pure returns (bytes32) {
        string[] memory dyn = new string[](domain.length);
        for (uint i; i < domain.length; i++) {
            dyn[i] = domain[i];
        }
        return namehash(dyn);
    }
    function namehash(string[4] memory domain) internal pure returns (bytes32) {
        string[] memory dyn = new string[](domain.length);
        for (uint i; i < domain.length; i++) {
            dyn[i] = domain[i];
        }
        return namehash(dyn);
    }
    function namehash(string[5] memory domain) internal pure returns (bytes32) {
        string[] memory dyn = new string[](domain.length);
        for (uint i; i < domain.length; i++) {
            dyn[i] = domain[i];
        }
        return namehash(dyn);
    }

    function getChainId() internal pure returns (uint chainId) {
        assembly { chainId := chainid() }
    }
}
