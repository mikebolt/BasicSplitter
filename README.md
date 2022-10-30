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

# Future work

More stuff will be added soon. Feedback is appreciated.
