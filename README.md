# BushBaby Token V5 (BBBY)

BushBaby Token (BBBY) is a fixed-supply ERC-20 token deployed on **Base Mainnet**.

V5 focuses on:
- Clear, simple tokenomics
- Strong fund transparency
- External timelocks for all major reserves
- Anti-whale and launch safety protections
- A small, understandable codebase (no upgradeable proxies)

---

## 1. Token Details

- **Name:** BushBaby Token  
- **Symbol:** BBBY  
- **Network:** Base (L2)  
- **Standard:** ERC-20 (OpenZeppelin v5, non-upgradeable)  
- **Total Supply:** 50,000,000,000 BBBY (18 decimals)

### Initial Allocation (100%)

| Category            | %   | Amount (BBBY)       | Wallet label (CB ID)            |
|---------------------|-----|---------------------|---------------------------------|
| Wealth Fund         | 50% | 25,000,000,000      | `wealthfundbbby.cb.id`         |
| Eco Reserve         | 20% | 10,000,000,000      | `ecoreservebbbyfund.cb.id`     |
| Utility Reserve     | 10% | 5,000,000,000       | `utilityreservebbby.cb.id`     |
| Founder Allocation  | 5%  | 2,500,000,000       | `foundersfundbbby.cb.id`       |
| Charity Fund        | 5%  | 2,500,000,000       | `charityfundbbby.cb.id`        |
| Owner / Ops Wallet  | 10% | 5,000,000,000       | `wuuster.cb.id`                |

> On-chain, these are normal `0x...` addresses. The `.cb.id` names are for humans.

---

## 2. Fund Lock Schedule (implemented via TokenTimelockVault)

Locking is **not** inside the token contract. It is enforced by separate `TokenTimelockVault` instances.

Assume **T₀ = launch timestamp** (approx. when BBBY V5 goes live).

| Category           | % of Supply | Lock Duration | Vesting / Unlock      | Notes                          |
|--------------------|-------------|---------------|------------------------|--------------------------------|
| Wealth Fund        | 50%         | 12 months     | 100% at month 12       | Strategic treasury             |
| Eco Reserve        | 20%         | 24 months     | 100% at month 24       | Long-term ecosystem fund       |
| Utility Reserve    | 10%         | 6 months      | 100% at month 6        | Ops, listing, partnerships     |
| Founder Allocation | 5%          | 12 months     | 100% at month 12       | Founder’s vested allocation    |
| Charity Fund       | 5%          | 6 months      | 100% at month 6        | Burns / donations post-unlock  |
| Owner / Ops        | 10%         | No lock       | Used for LP creation   | Ends with 0 BBBY before launch |

In practice:

- Each category (except Owner/Ops) sends its allocation into a dedicated `TokenTimelockVault` contract.
- When `releaseTime` is reached, anyone can call `release()` and tokens go to the beneficiary wallet.

---

## 3. Contract Overview

### BushBabyTokenV5.sol

Key properties:

- Non-upgradeable ERC-20 using OpenZeppelin.
- **No mint / no burn** after deployment.
- **Tax system:**
  - `taxBps` (0–500 bps, i.e. 0–5%).
  - Default `taxBps = 300` (3%).
  - Tax split: 80% → `wealthFund`, 20% → `charityFund`.
  - `disableTaxesForever()` can permanently set tax to 0.
- **Launch controls:**
  - `tradingEnabled` flag (false at deployment).
  - Only excluded wallets can move tokens before launch.
- **Anti-whale limits:**
  - `maxTxAmount` (default 1% of total supply).
  - `maxWalletAmount` (default 2% of total supply).
  - Both adjustable via `setLimits`.
- **Exclusions:**
  - `isExcludedFromLimits` – exempts key wallets, timelock vaults, and LP pair if desired.
  - `isExcludedFromFees` – exempts specific wallets from tax (e.g., owner during setup).

### TokenTimelockVault.sol

- Holds any ERC-20 token.
- Parameters:
  - `token` – ERC-20 contract address (BBBY or LP token).
  - `beneficiary` – wallet that will receive tokens at unlock.
  - `releaseTime` – unix timestamp when tokens can be released.
- Flow:
  1. Deploy vault.
  2. Send tokens to vault.
  3. Once `block.timestamp >= releaseTime`, call `release()`.

---

## 4. Deployment Guide (Base Mainnet)

You can deploy via Remix, Hardhat, or Foundry. Below is a Remix-oriented summary.

### 4.1 Prerequisites

- Base Mainnet RPC configured in your wallet (MetaMask or Coinbase Wallet).
- Enough ETH on Base for deployment gas.
- Six fund wallets created:
  - Wealth, Eco, Utility, Founder, Charity, Owner/Ops
- Their **hex addresses** ready to paste.

### 4.2 Deploy BushBabyTokenV5

1. Open **Remix**.
2. Create `BushBabyTokenV5.sol` and paste the contract.
3. In the **Compiler** tab:
   - Version: `0.8.20`
   - Enable optimization (e.g., 200 runs).
4. Compile.
5. In the **Deploy & Run** tab:
   - Environment: Injected Provider (Base Mainnet).
   - Contract: `BushBabyTokenV5`.
   - Constructor params:
     - `_wealthFund`      = hex address of `wealthfundbbby.cb.id`
     - `_ecoReserve`      = hex address of `ecoreservebbbyfund.cb.id`
     - `_utilityReserve`  = hex address of `utilityreservebbby.cb.id`
     - `_founderFund`     = hex address of `foundersfundbbby.cb.id`
     - `_charityFund`     = hex address of `charityfundbbby.cb.id`
     - `_ownerOpsWallet`  = hex address of `wuuster.cb.id`
6. Click **Deploy** and confirm in your wallet.
7. After deployment, verify the contract on BaseScan using the same compiler settings.

### 4.3 Deploy Timelock Vaults

For each locked category (Wealth, Eco, Utility, Founder, Charity, LP):

1. Create `TokenTimelockVault.sol` in Remix and compile.
2. For each vault:
   - Contract: `TokenTimelockVault`
   - `token`       = BBBY token address (or LP token address for the LP vault)
   - `beneficiary` = wallet that ultimately owns the funds
   - `releaseTime` = unix timestamp for unlock  
     - Wealth:  T₀ + 12 months  
     - Eco:     T₀ + 24 months  
     - Utility: T₀ + 6 months  
     - Founder: T₀ + 12 months  
     - Charity: T₀ + 6 months  
     - LP:      T₀ + 12 months (recommended)
3. Click **Deploy** for each vault and record the vault addresses.

### 4.4 Send Tokens Into Vaults

From each fund wallet:

- Use your wallet or Remix `transfer` to send the full amount to the vault address:

| Category           | Amount to vault (BBBY) |
|--------------------|------------------------|
| Wealth Fund        | 25,000,000,000         |
| Eco Reserve        | 10,000,000,000         |
| Utility Reserve    | 5,000,000,000          |
| Founder Allocation | 2,500,000,000          |
| Charity Fund       | 2,500,000,000          |

(Owner/Ops is not locked; used for LP creation.)

Check on BaseScan that each vault holds the correct balance.

### 4.5 Create Liquidity Pool & Lock LP

1. From **Owner/Ops** wallet:
   - Add BBBY + ETH liquidity on your chosen DEX (e.g., Uniswap-style interface on Base).
2. Receive LP tokens to Owner/Ops (or a multisig).
3. Deploy a `TokenTimelockVault` for the LP token with:
   - `token`       = LP token contract
   - `beneficiary` = your multisig / chosen wallet
   - `releaseTime` = T₀ + 12 months (or other duration)
4. Transfer **all LP tokens** into this LP vault.

Now the liquidity cannot be removed until the lock expires.

### 4.6 Enable Trading

1. (Optional) Use `setExcludedFromLimits` and `setExcludedFromFees` to:
   - Exclude timelock vaults from limits.
   - Exclude the LP pair from limits.
2. Confirm:
   - All funds are locked in their vaults.
   - LP tokens are locked.
   - Owner/Ops BBBY balance is at (or near) 0.
3. Call `enableTrading()` from the owner address.

---

## 5. Post-Launch Operations

- You may gradually lower `taxBps` and eventually call `disableTaxesForever()` for a zero-tax token.
- If you want to adjust anti-whale limits, call `setLimits`.
- At each vault’s `releaseTime`, anyone can call `release()`:
  - Tokens move from the vault to the beneficiary wallet.
  - You should announce each unlock ahead of time to the community.

---

## 6. Security Notes

- This repository does not include upgrade mechanisms; BBBY V5 is immutable once deployed.
- Always test on **Base Sepolia** before mainnet.
- Never deploy using `.cb.id` names—always use the resolved `0x...` addresses.
- For serious capital, consider getting an independent audit of the contracts before launch.

---

That’s the full bundle.  
If you’d like, next I can tailor a **“BBBY V5 Launch Checklist”** you can literally tick through step-by-step on launch day.
