# BasicSplitter

UNTESTED

A Solidity smart contract which you can send ether or ERC20 tokens to guarantee
that it will be split evenly between the recipient addresses.

Ether is split automatically in the receive function and the sender pays a
small gas cost for the math.

ERC20 tokens can be sent to the contract. It will hold them until a withdraw
function is called. Anyone can pay the gas fee to call splitAndWithdrawToken or
splitAndWithdrawTokens without negative consequence.

This contract is configurable to help reduce contract size and gas costs
depending on the owner's needs. It is designed to be as simple as possible
to keep these fees to a minimum.

## Minimal example

Here is the minimal version of the BasicSplitterUnrolled contract with four fake recipient addresses.

```
// SPDX-License-Identifier: MIT

// Author: https://github.com/mikebolt
// This software is provided with NO WARRANTY.

pragma solidity >=0.7.0 <0.9.0;

import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/1f18fea1de4c69355c773090c40fe083c08947b4/contracts/token/ERC20/IERC20.sol";

contract BasicSplitterUnrolled {

    receive() external payable {} // This function must be present so that this contract can receive ether.

    function splitEther() public payable {

        uint256 portion = address(this).balance / 4;

        // The call function can return an error here but we assume that it will not.
        // As the developer, I have to make a decision here about whether to protect you
        // against your mistakes by checking errors at runtime, or skipping those error
        // checks to save you gas costs.
        // Double-check your recipient addresses and be aware of possible problems with
        // contract recipients.
        (address(0x14723A09ACff6D2A60DcdF7aA4AFf308FDDC160C)).call{value: portion}("");
        (address(0x4B0897b0513fdC7C541B6d9D7E929C4e5364D2dB)).call{value: portion}("");
        (address(0x583031D1113aD414F02576BD6afaBfb302140225)).call{value: portion}("");
        (address(0xdD870fA1b7C4700F2BD7f44238821C26f7392148)).call{value: portion}("");
    }

}
```

It is very simple and it designed to optimize gas costs.

## Comparison with PaymentSplitter

[OpenZeppelin's PaymentSplitter.sol](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/finance/PaymentSplitter.sol)

- PaymentSplitter is usually more expensive to use. See below.
- PaymentSplitter keeps the recipient (payee) addresses in storage. BasicSplitterUnrolled does not use any storage. Recipient addresses are hardcoded.
- PaymentSplitter also keeps logs in memory.
- PaymentSplitter supports arbitrary splits but BasicSplitter does not (this will be added later)
- PaymentSplitter requires one call to "release" for each recipient address. BasicSplitter only requires one call to "splitEther" to send the payment to all recipients.
- PaymentSplitter is not configurable. BasicSplitter uses a preprocessor to produce a custom contract.

## Gas costs

These gas costs estimated in a local development environment.

```
token transfer gas cost: 52157

PaymentSplitter w/ 4 address recipients optimized for 1000 calls

deployment: 1040918
release ether: [82239, 62639, 62639, 62639] total 270156
release tokens to recipients: [109757, 92657, 92657, 87857] total 382928
release tokens again: [58457, 58457, 58457, 53657] total 229028

BasicSplitterUnrolled "generic" w/ 4 address recipients, errors, and all functions - unoptimized

deployment: 1171597
ether payment: 21055
splitEther: 59775
splitAndWithdrawToken: 133208 then 64808 - first time payments to an address can be more expensive
splitAndWithdrawTokens: 65618

BasicSplitterUnrolled same as above but optimized for 1000 calls

deployment: 884897
splitEther: 58866
splitAndWithdrawToken: 131003 then 62603

BasicSplitterUnrolled w/ 4 address recipients, ether only minimal config, optimized for 1000 calls

deployment: 172975
splitEther: 58797
```

## Future work

More stuff will be added. Feedback is appreciated.

- add tests
- add more stuff to README
- create frontend for contract creation and easy withdraws
