// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.0.0/contracts/token/ERC20/IERC20.sol";

/**
 * @title TokenTimelockVault
 *
 * @dev Simple timelock for any ERC20 token.
 *  - Holds tokens until a fixed unix timestamp.
 *  - No owner/admin functions.
 *  - Anyone can call release() after unlock time.
 *
 * You will deploy one instance per lock:
 *  - Wealth Fund vault
 *  - Eco Reserve vault
 *  - Utility vault
 *  - Founder vault
 *  - Charity vault
 *  - LP vault (for LP tokens)
 */
contract TokenTimelockVault {
    IERC20 public immutable token;
    address public immutable beneficiary;
    uint64 public immutable releaseTime; // unix timestamp (seconds)
    bool public released;

    event Released(uint256 amount);

    constructor(IERC20 _token, address _beneficiary, uint64 _releaseTime) {
        require(address(_token) != address(0), "token = zero");
        require(_beneficiary != address(0), "beneficiary = zero");
        require(_releaseTime > block.timestamp, "release time in past");

        token = _token;
        beneficiary = _beneficiary;
        releaseTime = _releaseTime;
    }

    /**
     * @dev Transfers all locked tokens to the beneficiary
     * once the release time is reached.
     */
    function release() external {
        require(!released, "Already released");
        require(block.timestamp >= releaseTime, "Too early");

        uint256 amount = token.balanceOf(address(this));
        require(amount > 0, "No tokens");

        released = true;
        token.transfer(beneficiary, amount);

        emit Released(amount);
    }
}
