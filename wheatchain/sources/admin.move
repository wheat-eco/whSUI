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
        pool.reward_rate = new_rate;
    }

    /// Deposit revenue to fund rewards
    public entry fun deposit_revenue(
        _cap: &AdminCap,
        sui: Coin<SUI>,
        pool: &mut StakingPool,
        _ctx: &mut TxContext
    ) {
        balance::join(&mut pool.revenue_pool, coin::into_balance(sui));
    }

    /// Withdraw SUI from the staking pool (for WheatChain use)
    public entry fun withdraw_staked_sui(
        _cap: &AdminCap,
        pool: &mut StakingPool,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext
    ) {
        let sui = coin::take(&mut pool.total_staked, amount, ctx);
        transfer::public_transfer(sui, recipient);
    }
}
