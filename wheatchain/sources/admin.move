module wheatchain::admin {
use sui::transfer;
use sui::coin::{Self, Coin};
use sui::sui::SUI;
use sui::tx_context::{Self, TxContext};
use wheatchain::staking::{Self, StakingPool, AdminCap};

/// Set the reward rate
public entry fun set_reward_rate(
_cap: &AdminCap,
pool: &mut StakingPool,
new_rate: u64,
_ctx: &mut TxContext
) {
staking::set_reward_rate(pool, new_rate);
}

/// Deposit revenue to fund rewards
public entry fun deposit_revenue(
_cap: &AdminCap,
sui: Coin<SUI>,
  pool: &mut StakingPool,
  _ctx: &mut TxContext
  ) {
  let sui_balance = coin::into_balance(sui);
  staking::add_revenue(pool, sui_balance);
  }
  
  /// Withdraw SUI from the staking pool (for WheatChain use)
  public entry fun withdraw_staked_sui(
  _cap: &AdminCap,
  pool: &mut StakingPool,
  amount: u64,
  recipient: address,
  ctx: &mut TxContext
  ) {
  let sui = staking::take_staked_sui(pool, amount, ctx);
  transfer::public_transfer(sui, recipient);
  }
  }