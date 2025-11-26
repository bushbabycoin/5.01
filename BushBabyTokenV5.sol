// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// OpenZeppelin v5 (non-upgradeable)
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.0.0/contracts/token/ERC20/ERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.0.0/contracts/access/Ownable.sol";

/**
 * @title BushBabyTokenV5 (BBBY V5 - Non-upgradeable)
 *
 * Features
 * --------
 * - Fixed 50,000,000,000 BBBY supply (18 decimals).
 * - Initial supply minted to six fund wallets:
 *      - Wealth Fund / Community Treasury      (50%)
 *      - Eco Reserve / Secondary Treasury      (20%)
 *      - Utility / Operations Reserve          (10%)
 *      - Founder Allocation                    (5%)
 *      - Charity Fund                          (5%)
 *      - Owner / Ops Wallet (LP + ops)        (10%)
 *
 * - Transfer tax (0–5%, capped) routed to:
 *      - Wealth Fund (80% of tax)
 *      - Charity Fund (20% of tax)
 *
 * - Launch safety:
 *      - tradingEnabled flag
 *      - maxTxAmount
 *      - maxWalletAmount
 *      - per-address exclusions from limits and fees
 *
 * - No minting, no burning, no upgradeability.
 * - Long-term fund locks handled by separate TokenTimelockVault contracts.
 */
contract BushBabyTokenV5 is ERC20, Ownable {
    // ---- Supply ----

    uint256 public constant INITIAL_SUPPLY = 50_000_000_000 * 10 ** 18;

    // ---- Fund wallets (immutable after deployment) ----

    address public immutable wealthFund;      // 50%
    address public immutable ecoReserve;      // 20%
    address public immutable utilityReserve;  // 10%
    address public immutable founderFund;     // 5%
    address public immutable charityFund;     // 5%
    address public immutable ownerOpsWallet;  // 10% - LP / operations

    // ---- Trading & anti-whale ----

    bool public tradingEnabled;

    uint256 public maxTxAmount;      // max tokens per transfer
    uint256 public maxWalletAmount;  // max tokens per wallet

    mapping(address => bool) public isExcludedFromLimits;
    mapping(address => bool) public isExcludedFromFees;

    // ---- Tax settings ----

    // Basis points: 10_000 = 100%
    uint16 public constant MAX_TAX_BPS = 500; // hard cap 5%

    uint16 public taxBps; // e.g. 300 = 3%

    // 80/20 split of tax between wealth and charity
    uint16 public constant WEALTH_TAX_SHARE_BPS = 8000;
    uint16 public constant CHARITY_TAX_SHARE_BPS = 2000;

    // ---- Events ----

    event TradingEnabled();
    event TaxBpsUpdated(uint16 oldTaxBps, uint16 newTaxBps);
    event LimitsUpdated(uint256 maxTxAmount, uint256 maxWalletAmount);
    event ExcludedFromLimitsUpdated(address indexed account, bool excluded);
    event ExcludedFromFeesUpdated(address indexed account, bool excluded);

    // ---- Constructor ----

    /**
     * @dev Pass the FINAL wallet addresses here when deploying.
     *
     * Suggested mapping from your Coinbase IDs (.cb.id):
     *
     *  - _wealthFund      = address of "wealthfundbbby.cb.id"
     *  - _ecoReserve      = address of "ecoreservebbbyfund.cb.id"
     *  - _utilityReserve  = address of "utilityreservebbby.cb.id"
     *  - _founderFund     = address of "foundersfundbbby.cb.id"
     *  - _charityFund     = address of "charityfundbbby.cb.id"
     *  - _ownerOpsWallet  = address of "wuuster.cb.id"
     *
     * IMPORTANT: in Remix / deployment you must use the actual hex
     * 0x... addresses, not the .cb.id names.
     */

    constructor(
        address _wealthFund,
        address _ecoReserve,
        address _utilityReserve,
        address _founderFund,
        address _charityFund,
        address _ownerOpsWallet
    ) ERC20("BushBaby Token", "BBBY") Ownable(msg.sender) {
        require(_wealthFund != address(0), "wealthFund = zero");
        require(_ecoReserve != address(0), "ecoReserve = zero");
        require(_utilityReserve != address(0), "utilityReserve = zero");
        require(_founderFund != address(0), "founderFund = zero");
        require(_charityFund != address(0), "charityFund = zero");
        require(_ownerOpsWallet != address(0), "ownerOpsWallet = zero");

        wealthFund = _wealthFund;
        ecoReserve = _ecoReserve;
        utilityReserve = _utilityReserve;
        founderFund = _founderFund;
        charityFund = _charityFund;
        ownerOpsWallet = _ownerOpsWallet;

        // ---- Mint distribution (matches white paper 50 / 20 / 10 / 5 / 5 / 10) ----

        // Wealth Fund (50%)
        _mint(_wealthFund, 25_000_000_000 * 10 ** 18);

        // Eco Reserve (20%)
        _mint(_ecoReserve, 10_000_000_000 * 10 ** 18);

        // Utility Reserve (10%)
        _mint(_utilityReserve, 5_000_000_000 * 10 ** 18);

        // Founder Allocation (5%)
        _mint(_founderFund, 2_500_000_000 * 10 ** 18);

        // Charity Fund (5%)
        _mint(_charityFund, 2_500_000_000 * 10 ** 18);

        // Owner / Ops Wallet (10%) - LP funded from here
        _mint(_ownerOpsWallet, 5_000_000_000 * 10 ** 18);

        require(totalSupply() == INITIAL_SUPPLY, "Bad initial supply");

        // ---- Default tax & limits ----

        taxBps = 300; // 3% initial tax (can be lowered to 0, never above MAX_TAX_BPS)

        maxTxAmount = INITIAL_SUPPLY / 100;   // 1% of total supply
        maxWalletAmount = INITIAL_SUPPLY / 50; // 2% of total supply

        // Exclude core wallets from holding limits (but not from tax by default).
        _setExcludedFromLimits(owner(), true);
        _setExcludedFromLimits(_wealthFund, true);
        _setExcludedFromLimits(_ecoReserve, true);
        _setExcludedFromLimits(_utilityReserve, true);
        _setExcludedFromLimits(_founderFund, true);
        _setExcludedFromLimits(_charityFund, true);
        _setExcludedFromLimits(_ownerOpsWallet, true);

        // Exclude deployer/owner from fees during setup (can be changed later).
        _setExcludedFromFees(owner(), true);
    }

    // ---- Trading control ----

    function enableTrading() external onlyOwner {
        require(!tradingEnabled, "Trading already enabled");
        tradingEnabled = true;
        emit TradingEnabled();
    }

    // ---- Tax configuration ----

    function setTaxBps(uint16 newTaxBps) external onlyOwner {
        require(newTaxBps <= MAX_TAX_BPS, "Tax too high");
        uint16 old = taxBps;
        taxBps = newTaxBps;
        emit TaxBpsUpdated(old, newTaxBps);
    }

    /**
     * @dev Convenience function to permanently set tax to zero.
     * Once set to 0 and owner renounces ownership, taxes cannot return.
     */
    function disableTaxesForever() external onlyOwner {
        uint16 old = taxBps;
        taxBps = 0;
        emit TaxBpsUpdated(old, 0);
    }

    // ---- Limits configuration ----

    function setLimits(uint256 _maxTxAmount, uint256 _maxWalletAmount) external onlyOwner {
        require(_maxTxAmount > 0, "maxTx = 0");
        require(_maxWalletAmount > 0, "maxWallet = 0");
        maxTxAmount = _maxTxAmount;
        maxWalletAmount = _maxWalletAmount;
        emit LimitsUpdated(_maxTxAmount, _maxWalletAmount);
    }

    function setExcludedFromLimits(address account, bool excluded) external onlyOwner {
        _setExcludedFromLimits(account, excluded);
    }

    function _setExcludedFromLimits(address account, bool excluded) internal {
        isExcludedFromLimits[account] = excluded;
        emit ExcludedFromLimitsUpdated(account, excluded);
    }

    function setExcludedFromFees(address account, bool excluded) external onlyOwner {
        _setExcludedFromFees(account, excluded);
    }

    function _setExcludedFromFees(address account, bool excluded) internal {
        isExcludedFromFees[account] = excluded;
        emit ExcludedFromFeesUpdated(account, excluded);
    }

    // ---- Core transfer logic with limits + tax ----

    function _update(address from, address to, uint256 amount) internal override {
        // Allow minting/burning without restrictions
        if (from == address(0) || to == address(0)) {
            super._update(from, to, amount);
            return;
        }

        // Trading gate: only excluded wallets can move prior to launch.
        if (!tradingEnabled) {
            require(
                isExcludedFromLimits[from] || isExcludedFromLimits[to],
                "BBBY: trading not enabled"
            );
        }

        // Max transaction limit (only for non-excluded)
        if (!isExcludedFromLimits[from] && !isExcludedFromLimits[to]) {
            require(amount <= maxTxAmount, "BBBY: transfer exceeds maxTxAmount");
        }

        uint256 sendAmount = amount;

        // Tax logic for standard transfers
        if (taxBps > 0 && !isExcludedFromFees[from] && !isExcludedFromFees[to]) {
            uint256 taxAmount = (amount * taxBps) / 10_000;

            if (taxAmount > 0) {
                uint256 toWealth = (taxAmount * WEALTH_TAX_SHARE_BPS) / 10_000;
                uint256 toCharity = taxAmount - toWealth;

                if (toWealth > 0) {
                    super._update(from, wealthFund, toWealth);
                }
                if (toCharity > 0) {
                    super._update(from, charityFund, toCharity);
                }

                sendAmount = amount - taxAmount;
            }
        }

        // Normal transfer of remaining tokens
        super._update(from, to, sendAmount);

        // Max wallet limit (post-transfer)
        if (!isExcludedFromLimits[to]) {
            require(balanceOf(to) <= maxWalletAmount, "BBBY: balance exceeds maxWalletAmount");
        }
    }
}
