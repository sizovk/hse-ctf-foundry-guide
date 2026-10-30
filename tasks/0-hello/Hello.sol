// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


contract Hello {
  bool public done;
  uint256 public size;

  function setHello(address target) public returns (bool) {
    bytes4 selector = bytes4(keccak256("sayHi()"));
    (bool success, bytes memory result) = target.call(abi.encodeWithSelector(selector));

    if (success && keccak256(abi.decode(result, (bytes))) == keccak256(bytes("HelloFromHSE"))) {
      done = true;
    }

    return done;
  }
}